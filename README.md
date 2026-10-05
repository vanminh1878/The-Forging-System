# HVP The Forging System

Hệ thống thành viên & gamification cho chuỗi phòng tập boxing: gói tập, check-in, điểm kỷ luật (DP), HVP Marks,
hạng (rank), streak, thử thách và Armory (đổi quà).

| Thành phần | Công nghệ | Thư mục |
|---|---|---|
| API | Node.js 20, TypeScript, Express, PostgreSQL 16 (đa tenant, Row Level Security) | `backend/` |
| Mobile | Flutter, Riverpod, go_router, Dio | `mobile/` |
| Hạ tầng | Docker Compose, GitHub Actions, CodeRabbit | `docker/`, `.github/`, `.coderabbit.yaml` |

## Chạy nhanh bằng Docker

```bash
docker compose up --build            # postgres + api, tự migrate & seed dữ liệu tham chiếu
SEED_DEMO=true docker compose up -d --build api   # (tùy chọn) thêm tài khoản demo, mật khẩu hvp12345
curl http://localhost:4000/health
```

## Chạy backend không Docker

```bash
cd backend
cp .env.example .env     # cần PostgreSQL 16 với role hvp_owner / hvp_app (xem backend/README.md)
npm install
npm run migrate && npm run seed && npm run seed:demo
npm run dev
```

## Chạy frontend (Flutter, `mobile/`)

Cần cài sẵn [Flutter SDK](https://docs.flutter.dev/get-started/install) (kiểm tra bằng `flutter doctor`) và **chạy backend trước**
(`http://localhost:4000/health` phải trả về `{"status":"ok"}`).

```bash
cd mobile
flutter pub get                       # cài thư viện (lần đầu, hoặc khi đổi pubspec.yaml)

# Chạy bản web, mở http://localhost:3000 bằng Chrome
flutter run -d web-server --web-port 3000 --dart-define=API_BASE_URL=http://localhost:4000/api/v1

# hoặc để Flutter tự mở Chrome
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

Phím tắt khi đang chạy: `r` hot reload · `R` hot restart · `q` thoát. (Đổi `pubspec.yaml`, thêm asset hoặc đổi
`--dart-define` thì phải dừng và chạy lại, hot reload không đủ.)

| `--dart-define` | Mặc định | Ghi chú |
|---|---|---|
| `API_BASE_URL` | `http://localhost:4000/api/v1` | Android emulator: `http://10.0.2.2:4000/api/v1`; máy thật: IP LAN của máy chạy backend |
| `TENANT_CODE` | `hvp` | Gửi trong header `X-Tenant-Code` |

Chạy trên thiết bị khác:

```bash
flutter devices                                                          # liệt kê thiết bị / emulator
flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1   # Android emulator
```

Build bản phát hành:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://<api-domain>/api/v1
flutter build apk --release --dart-define=API_BASE_URL=https://<api-domain>/api/v1
```

Tài khoản demo (chỉ có khi backend đã chạy `npm run seed:demo` hoặc `SEED_DEMO=true`), mật khẩu chung `hvp12345`:

| Vai trò | Số điện thoại |
|---|---|
| Admin | `0900000001` |
| Head Coach | `0900000002` |
| Coach | `0900000003` |
| Lễ tân | `0900000004` |
| Học viên | `0911000001` … `0911000004` |

### Lệnh dọn dẹp và xử lý sự cố

```bash
flutter clean                         # xoá mobile/build và .dart_tool (xong phải chạy lại flutter pub get)
flutter pub get
flutter pub upgrade                   # cập nhật thư viện trong giới hạn pubspec.yaml (tuỳ chọn)
flutter doctor -v                     # kiểm tra môi trường
```

| Triệu chứng | Cách xử lý |
|---|---|
| `Flutter failed to delete a directory ... build/flutter_assets` | Xoá thư mục `mobile/build` (hoặc `flutter clean`) rồi chạy lại. Hay gặp khi project nằm trong thư mục đồng bộ OneDrive hoặc vừa copy sang máy khác. Nên đặt project **ngoài OneDrive**. |
| `Failed to bind web development server ... port 3000` | Cổng đang bị chiếm (thường do lần chạy trước chưa tắt). Đổi `--web-port 3001`, hoặc tắt tiến trình đang giữ cổng: `netstat -ano \| findstr :3000` rồi `taskkill /PID <pid> /F` (Windows). |
| Đăng nhập báo "Không kết nối được máy chủ" | Backend chưa chạy hoặc sai `API_BASE_URL`. Kiểm tra `http://localhost:4000/health`. |
| Font chữ hiện chậm / sai lần đầu mở | App tải font từ Google Fonts, cần có mạng; chờ vài giây là tự đổi. |

## Test

```bash
cd backend && npm test                 # unit (không cần DB)
cd backend && npm run test:integration # cần PostgreSQL, tự dùng DB hvp_test
cd mobile && flutter test               # 121 test, không cần backend
cd mobile && flutter analyze            # phân tích tĩnh
```

## Cấu trúc

```
backend/   API (src/modules/<module>/{routes,service,repository}), migrations, seeds, tests
mobile/    Flutter app (lib/core, lib/features/<feature>, lib/app)
docker/    Khởi tạo PostgreSQL (role runtime hvp_app, DB test)
```

Đây là **base project**: nền tảng đã chạy được và có test (đăng nhập, thành viên, sổ điểm DP/Marks,
hạng, thông báo, cấu hình, audit, upload) cùng khung để thêm các module nghiệp vụ còn lại.
