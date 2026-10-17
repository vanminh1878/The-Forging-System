# Deploy backend + DB lên DigitalOcean

Áp dụng sau khi droplet đã có: Singapore 2 GB, SSH key, user riêng, firewall, swap, Docker.
Kiến trúc: `Internet → Caddy (80/443, HTTPS tự động) → api:4000 → postgres:5432`. Postgres chỉ nghe ở `127.0.0.1` của droplet (xem qua SSH tunnel), api không mở cổng, volume `pgdata` (DB) và `uploads` (ảnh) nằm trên đĩa của droplet. Cấu hình ở `docker-compose.prod.yml`.

## 0. Chuẩn bị
- **Firewall (DigitalOcean Cloud Firewall):** inbound chỉ mở `22` (SSH, nên giới hạn IP của bạn), `80`, `443`. Không mở `4000` và `5432`.
- **Tên miền:** app mobile trên Android/iOS bản release không gọi được HTTP thuần, nên cần HTTPS. Trỏ bản ghi `A` của domain về IP droplet. Chưa có domain thì dùng `<IP thay dấu chấm bằng gạch ngang>.sslip.io` (vd `203-0-113-10.sslip.io`), Caddy vẫn xin được chứng chỉ.

## 1. Lấy code lên droplet
```bash
ssh <user>@<ip-droplet>
git clone https://github.com/vanminh1878/The-Forging-System.git
cd The-Forging-System
```
Repo private thì dùng deploy key (Settings → Deploy keys) hoặc Personal Access Token.

## 2. Tạo file biến môi trường production
```bash
cp .env.prod.example .env.prod
chmod 600 .env.prod
nano .env.prod
```
Sinh mật khẩu bằng `openssl rand -hex 24` (JWT secret dùng `openssl rand -hex 32`). Dùng chuỗi hex để không vướng ký tự đặc biệt trong URL kết nối DB. Điền `API_DOMAIN` và `PUBLIC_BASE_URL=https://<domain>`. `.env.prod` bị `.gitignore` chặn, không bao giờ commit.

Lưu ý: `HVP_APP_PASSWORD` chỉ có tác dụng khi volume DB được tạo lần đầu. Muốn đổi sau này phải đổi bằng SQL (`ALTER ROLE hvp_app PASSWORD ...`) hoặc xoá volume khi chưa có dữ liệu thật.

## 3. Chạy
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f api
```
Lần đầu build mất vài phút. Khi khởi động, api tự chạy migration và seed dữ liệu tham chiếu (khoá học, gói tập, mẫu thông báo), idempotent.

## 4. Kiểm tra
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml ps     # 3 service đều Up / healthy
curl https://<domain>/health
sudo ss -tlnp | grep -E '5432|4000'                                    # 5432 chỉ được nghe ở 127.0.0.1, 4000 không có dòng nào
```
Từ máy của bạn: `Test-NetConnection <ip> -Port 5432` phải thất bại.

## 4b. Xem DB từ máy của bạn (SSH tunnel)
Postgres chỉ nghe ở `127.0.0.1` của droplet nên phải đi qua SSH. Mở tunnel và giữ cửa sổ này:
```bash
ssh -N -L 5439:127.0.0.1:5432 <user>@<ip-droplet>
```
Rồi nối DBeaver / pgAdmin vào `localhost:5439`, database `hvp`, user `hvp_owner`, mật khẩu `HVP_OWNER_PASSWORD`. Chỉ dùng user `hvp_owner` để xem và sửa dữ liệu tay; API chạy bằng `hvp_app` (bị row-level security chặn theo tenant).

## 5. Tạo tài khoản admin đầu tiên
DB mới không có ai đăng nhập được, và seed demo bị chặn khi `NODE_ENV=production`. Tạo admin bằng script:
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml exec \
  -e ADMIN_PHONE=09xxxxxxxx -e ADMIN_PASSWORD='MatKhauManh123' -e ADMIN_NAME='Quản trị' api \
  npx tsx scripts/create-admin.ts
```
Mật khẩu tối thiểu 10 ký tự, có chữ và số. Chạy xong nên xoá lệnh khỏi lịch sử shell (`history -d`).

## 6. Cập nhật phiên bản mới
```bash
cd ~/The-Forging-System && git pull
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build api
```
Migration mới (`backend/db/migrations/00NN_*.sql`) tự chạy khi api khởi động lại.

## 7. Sao lưu (làm ngay từ bây giờ)
```bash
mkdir -p ~/backups
docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T postgres \
  pg_dump -U hvp_owner -d hvp | gzip > ~/backups/hvp-$(date +%F).sql.gz
```
Nên đặt lệnh này vào `crontab` chạy mỗi đêm và bật thêm DigitalOcean Backups cho droplet. Ảnh upload nằm trong volume `uploads`, cũng cần sao lưu khi có dữ liệu thật.

## 8. Lưu ý vận hành
- **OTP / push mặc định ở chế độ `console`:** mã OTP chỉ ghi vào log (`docker compose ... logs api`). Để gửi email thật (đăng ký + quên mật khẩu), đặt trong `.env.prod`: `OTP_PROVIDER=resend`, `RESEND_API_KEY=...`, `MAIL_FROM=HVP <no-reply@domain-cua-ban>` (domain phải được xác minh trên Resend). Tuỳ chọn `MAIL_BCC=...` để nhận bản sao ẩn (BCC) của mọi email OTP.
- **Mobile:** build với `--dart-define=API_BASE_URL=https://<domain>/api/v1`.
- **Dọn dữ liệu thử rồi giữ master data:** master data (role, hạng, loại buổi tập, mức quà) nằm trong migration, còn khoá học, gói tập, mẫu thông báo do seed tạo lại mỗi lần api khởi động. Khi cần xoá dữ liệu vận hành, hãy `pg_dump` trước, rồi `TRUNCATE` các bảng giao dịch; đừng dùng `docker compose down -v` vì sẽ xoá luôn cả DB và ảnh.
