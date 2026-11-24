# Phát hành Android tự động (Google Play)

Workflow: [`.github/workflows/android-release.yml`](../../.github/workflows/android-release.yml)

## Cách hoạt động

Mỗi lần merge vào `main` có đụng `mobile/**` (hoặc bấm chạy tay ở tab Actions), GitHub Actions sẽ:

1. Kiểm tra đủ secret; thiếu secret thì dừng và báo rõ tên secret thiếu.
2. Chạy `flutter analyze` và `flutter test`. Không qua thì **không** phát hành.
3. Ký và build `.aab` bản release, `versionCode` = số lần chạy workflow (`github.run_number`) cộng `VERSION_CODE_OFFSET` (hiện là 100, vì bản upload tay đầu tiên đã dùng mã 42).
4. Lưu `.aab` thành artifact của lần chạy, đồng thời upload lên track **Thử nghiệm nội bộ** (`internal`) của Google Play.
5. Xóa keystore và `key.properties` khỏi máy chạy.

Người thử nghiệm trong danh sách tester nội bộ chỉ cần mở Play Store và cập nhật.

API trỏ về repo variable `API_BASE_URL` và `TENANT_CODE` (dùng chung với workflow iOS). Đổi sang server khác thì sửa variable, không cần sửa code.

## Thiết lập một lần

### 1. Keystore ký app

Phải dùng **đúng upload keystore** đã ký bản `.aab` đầu tiên bạn upload thủ công lên Play Console. Khác key thì Play từ chối bản upload.

Đường dẫn keystore nằm trong `mobile/android/key.properties` (file này bị gitignore, **không commit, không gửi cho ai**). Mã hóa keystore thành base64 để lưu vào secret:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\duong\dan\upload-keystore.jks")) | Set-Clipboard
```

Backup keystore và mật khẩu ở nơi an toàn ngoài GitHub. Mất upload key thì phải xin Google reset key.

### 2. Service account để GitHub upload lên Play

1. Google Cloud Console: tạo (hoặc chọn) project, bật **Google Play Android Developer API**.
2. Tạo **Service account**, sau đó tạo **Key** dạng JSON và tải file về.
3. Play Console: **Người dùng và quyền** > mời email của service account, cấp quyền cho app HVP Boxing (cần quyền phát hành lên các track thử nghiệm / quản lý bản phát hành).
4. Quyền có thể mất vài phút đến vài giờ mới có hiệu lực.

### 3. Thêm secret và variable vào GitHub

Repo > Settings > Secrets and variables > Actions.

| Loại | Tên | Giá trị |
| --- | --- | --- |
| Secret | `ANDROID_KEYSTORE_BASE64` | Chuỗi base64 ở bước 1 |
| Secret | `ANDROID_KEYSTORE_PASSWORD` | `storePassword` trong `key.properties` |
| Secret | `ANDROID_KEY_ALIAS` | `keyAlias` trong `key.properties` |
| Secret | `ANDROID_KEY_PASSWORD` | `keyPassword` trong `key.properties` |
| Secret | `PLAY_SERVICE_ACCOUNT_JSON` | Toàn bộ nội dung file JSON ở bước 2 |
| Variable | `API_BASE_URL`, `TENANT_CODE` | Đã có (dùng chung với iOS) |

### 4. Chạy thử

Actions > **Android Play Store** > Run workflow. Sau khi xanh, mở Play Console > Thử nghiệm nội bộ để xem bản mới.

## Lỗi thường gặp

| Triệu chứng | Nguyên nhân / cách xử lý |
| --- | --- |
| `Missing repo secret ...` | Chưa thêm secret tương ứng (bước 3). |
| Play báo sai chữ ký (`signed with the wrong key`) | Keystore trong secret không phải upload key mà Play ghi nhận (thường vì bản upload đầu tiên ký bằng khóa khác, ví dụ debug key). Dùng `keytool -list -v` so SHA1 của keystore với SHA1 Play báo mong đợi. Nếu khác nhau: Play Console > Được bảo vệ bằng Play > Ký ứng dụng > Khoá tải lên > **Yêu cầu đặt lại**, tải lên chứng chỉ `.pem` xuất từ keystore (`keytool -export -rfc`), chờ Google xác nhận rồi chạy lại. |
| `Version code ... has already been used` hoặc điện thoại không hiện cập nhật | `versionCode` phải lớn hơn mọi bản đã upload. Nếu có bản mới upload tay với mã lớn hơn `run_number + VERSION_CODE_OFFSET`, tăng `VERSION_CODE_OFFSET` trong workflow. Không bao giờ giảm giá trị này. |
| `The caller does not have permission` | Service account chưa được mời vào Play Console hoặc chưa đủ quyền (bước 2.3). |
| `Only releases with status draft may be created on draft app` | App chưa hoàn tất thông tin cửa hàng. Hoàn tất trong Play Console, hoặc tạm đổi `status: completed` thành `status: draft` trong workflow. |

## Lên production sau này

Đổi `PLAY_TRACK: internal` trong workflow thành `production` (hoặc `beta` / `alpha` cho closed/open testing). Lưu ý bản production phải qua duyệt của Google. Tài khoản cá nhân mới có thể phải chạy closed test đủ số tester và thời gian theo chính sách Google trước khi được lên production; kiểm tra trong Play Console.

## Build local

Máy dev có `mobile/android/key.properties` thì `flutter build appbundle --release` ký bằng key release. Không có file này thì tự rơi về debug key, đủ để `flutter run --release`, nhưng bản đó không upload lên Play được.
