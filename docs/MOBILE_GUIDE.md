# Hướng dẫn Mobile (Flutter)

Hướng dẫn rút gọn nằm ở `mobile/README.md` (được commit). File này bổ sung phần chạy debug, design system và quy trình vibe-code.

## 1. Chạy debug KHÔNG cần cắm điện thoại, KHÔNG cần Android Studio

Cần: Flutter SDK (+ Chrome). Không cần Android Studio cho cách 1–2.

```bash
cd mobile
flutter create . --platforms=android,ios,web --org vn.hvp --project-name hvp_forging   # chỉ lần đầu (sinh thư mục nền tảng)
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

1. **Chrome (nhanh nhất)**: `flutter run -d chrome`. Mở DevTools để xem layout; thu nhỏ cửa sổ/ F12 → chế độ thiết bị để giả lập màn hình điện thoại. Hot reload bằng `r`, hot restart bằng `R`.
2. **Web server** (mở bằng bất kỳ trình duyệt/ điện thoại cùng Wi-Fi): `flutter run -d web-server --web-port 8081 --web-hostname 0.0.0.0`.
3. **Giả lập Android không mở Android Studio** (cần cài *command-line tools*): `sdkmanager "system-images;android-34;google_apis;x86_64"` → `avdmanager create avd -n hvp -k "system-images;android-34;google_apis;x86_64"` → `emulator -avd hvp` → `flutter run` (API: `http://10.0.2.2:4000/api/v1`).
4. **macOS**: iOS Simulator (`open -a Simulator` → `flutter run`).
5. **VS Code**: cài extension *Flutter*, mở thư mục `mobile`, bấm F5 và chọn thiết bị (Chrome / emulator).

Giới hạn: web không có camera quét QR thật (đã dùng `mobile_scanner`, web hỗ trợ qua webcam nhưng cần HTTPS hoặc localhost), không có haptic/push. Kiểm thử camera, thông báo đẩy và lưu trữ an toàn nên thử trên thiết bị thật/emulator.

## 2. Design system "ring-side after dark"

- **Theme**: mặc định tối (charcoal + vàng kim `#F2C450`/`#B7841E` + đỏ đấm bốc cho CTA + lục cho thành công); theme sáng giấy kem theo prototype. Người dùng chọn Sáng/Tối/Theo hệ thống (lưu `SharedPreferences`).
- **Font**: Bebas Neue (tiêu đề/số lớn), Oswald (nhãn), Inter (nội dung), JetBrains Mono (mã/số liệu) qua `google_fonts` (tải khi chạy lần đầu; muốn offline hãy bundle font vào `assets/fonts`).
- **Token**: chỉ dùng `context.hvp` (màu) và `context.txt` (kiểu chữ) — không hex trong widget tính năng.
- **Linh kiện** (`lib/core/widgets`, `lib/core/design`): `HvpButton`, `HvpCard` (viền vát chamfer), `HvpTextField`, `StatTile`, `SectionHeader`, `RankBadge` (7 huy hiệu kim loại, trạng thái khoá/thu hồi), `DpGauge` ("heat gauge"), `StreakFlame`, `TapeDivider` (băng quấn tay), `ScanFrame` (khung 4 góc quét QR), `AsyncBody` (shimmer + lỗi + retry), `EmptyState`, `ErrorState`, `HvpRefresh`, `EvidencePhotoPicker`, `BranchPicker`, `HvpToast`, `HvpBottomSheet`, `ConfettiBurst`, `CountUpText`, `.entrance(i)` (xuất hiện lần lượt), `HvpNavBar` nổi với nút Check-in giữa.
- **Icon**: `phosphor_flutter` (có găng tay, ngọn lửa, cúp, huy chương…) — khai báo tập trung ở `hvp_icons.dart`.
- **Mọi màn** phải có 3 trạng thái: loading (shimmer), rỗng (icon + câu tiếng Việt + CTA), lỗi (thử lại).

## 3. Thêm một tính năng (vibe-code)

Dùng `lib/features/fighter_record/` làm mẫu (xem công thức 7 bước ở `mobile/README.md`). Quy trình gợi ý khi dùng AI:

1. Đưa AI: use case liên quan + routes backend (`backend/src/modules/<module>/*.routes.ts`) + thư mục `fighter_record` làm mẫu.
2. Yêu cầu: "tạo feature `<x>` theo đúng cấu trúc fighter_record, màn hình gồm …, dùng widget ở core/widgets, đủ loading/empty/error".
3. Đăng ký route: thay `ComingSoonPage` của tab trong `lib/app/routes/<role>_routes.dart`.
4. Viết test (repository với `scripted_adapter`, màn với `pumpHvp` + fake repository).
5. Chạy `flutter analyze` + `flutter test` + `python3 tool/check_imports.py lib test`.

## 4. Bốn app theo vai trò (sau đăng nhập, theo `appRole`)

| Role | Tab (prototype đã duyệt) |
|---|---|
| student | Trang chủ · Lịch tập · **Check-in** (giữa) · Armory · Hồ sơ |
| coach | Hôm nay · Lớp & bài học · Challenge · Rank Trial · Lịch sử |
| reception | Check-in · Gói tập (Yêu cầu / Học viên / Theo gói) · Kho quà · Giao quà |
| admin | Dashboard · Thành viên · Đào tạo · Thử thách (Challenge / Đơn quà / Kho quà) · Thông báo · Cấu hình (Quy tắc / Hạng / Chi nhánh / Nhật ký) |

Hiện tại các tab là `ComingSoonPage`; đã hoàn chỉnh: đăng nhập/đăng ký/quên mật khẩu, khung 4 role, Fighter Record (Lên hạng / Huy hiệu / Sổ điểm).

## 5. Lưu ý quan trọng
- **Dart chưa được biên dịch** trong môi trường tạo base (không có Flutter SDK). Mã đã qua kiểm tra cú pháp bằng tree-sitter-dart và kiểm tra import. Lần đầu bạn chạy `flutter pub get && flutter analyze && flutter test` có thể còn vài lỗi nhỏ (tên tham số, phiên bản thư viện) — sửa theo thông báo của analyzer; nếu cần, dán lỗi cho AI để sửa.
- Phiên bản thư viện đặt theo caret major; nếu `pub get` báo xung đột chạy `flutter pub upgrade --major-versions` rồi sửa API đổi tên.
- Push notification: chưa gắn Firebase (không có package firebase trong `pubspec`). Hook `PushRegistrar` đã sẵn; thêm `firebase_messaging` khi bạn sẵn sàng.
- Không có thư mục `android/`, `ios/`, `web/` trong repo base: sinh bằng `flutter create .` (đã `.gitignore` các file build).
