# Hướng dẫn Docker

## Dịch vụ (docker-compose.yml)

| Service | Mô tả | Cổng |
|---|---|---|
| `postgres` | PostgreSQL 16. Lần đầu khởi tạo tự chạy `docker/postgres/init/01-create-runtime-role.sh`: tạo role runtime `hvp_app` (không owner → RLS có hiệu lực) và DB `hvp_test` | 5432 |
| `api` | Build từ `backend/Dockerfile` (target `runtime`). Entrypoint: migrate → seed dữ liệu tham chiếu → (tuỳ chọn) seed demo → chạy API | 4000 |
| `adminer` | Giao diện xem DB (profile `tools`) | 8080 |
| `api-tests` | Chạy toàn bộ test (profile `test`) | — |

## Lệnh thường dùng

```bash
docker compose up --build -d             # chạy postgres + api
docker compose logs -f api               # xem log
curl http://localhost:4000/health        # kiểm tra

SEED_DEMO=true docker compose up -d --force-recreate api   # nạp tài khoản demo (mật khẩu hvp12345)
docker compose --profile tools up -d adminer               # mở Adminer (server: postgres, user: hvp_owner, db: hvp)
docker compose --profile test run --rm api-tests           # chạy test
docker compose down                       # dừng (giữ dữ liệu)
docker compose down -v                    # dừng + XOÁ dữ liệu DB và ảnh upload
```

Tài khoản demo (khi `SEED_DEMO=true`): admin `0900000001`, head coach `0900000002`, coach `0900000003`, lễ tân `0900000004`, học viên `0911000001…04`; mật khẩu `hvp12345`.

## Biến môi trường (đặt trong file `.env` cạnh docker-compose.yml, không commit)

| Biến | Mặc định | Ghi chú |
|---|---|---|
| `HVP_OWNER_PASSWORD`, `HVP_APP_PASSWORD` | `hvp_owner_pw`, `hvp_app_pw` | ĐỔI khi deploy thật. `HVP_APP_PASSWORD` chỉ có tác dụng khi DB được khởi tạo lần đầu (`down -v` để khởi tạo lại) |
| `JWT_ACCESS_SECRET` | giá trị dev | Bắt buộc đổi, ≥ 32 ký tự |
| `API_PORT`, `POSTGRES_PORT`, `ADMINER_PORT` | 4000, 5432, 8080 | Đổi nếu trùng cổng |
| `PUBLIC_BASE_URL` | `http://localhost:4000` | URL công khai để app mở ảnh upload |
| `PUSH_PROVIDER`, `OTP_PROVIDER` | `console` | `fcm` cần cấu hình thêm; OTP email thật: `OTP_PROVIDER=resend` + `RESEND_API_KEY` + `MAIL_FROM` |

## Kết nối từ app
- Chạy app trên Chrome / iOS simulator: `API_BASE_URL=http://localhost:4000/api/v1`.
- Android emulator: `http://10.0.2.2:4000/api/v1`.
- Điện thoại thật cùng Wi-Fi: `http://<IP máy tính>:4000/api/v1`.

## Xử lý sự cố
- **`permission denied for table …`**: migration chạy bằng owner nhưng role `hvp_app` chưa được tạo trước. Chạy `docker compose down -v` rồi `up` lại để script khởi tạo chạy.
- **Cổng 5432 bị chiếm**: đặt `POSTGRES_PORT=5433`.
- **Sửa schema**: thêm migration mới (`backend/db/migrations/00NN_*.sql`); API tự migrate khi khởi động lại (`docker compose up -d --build api`).
- **Image runtime** chạy bằng user không phải root, cần `UPLOAD_DIR` ghi được (volume `uploads`).
- Sandbox phát triển của dự án không chạy được Docker, nên lần đầu hãy chạy `docker compose up --build` trên máy bạn và báo lỗi nếu có để chỉnh.
