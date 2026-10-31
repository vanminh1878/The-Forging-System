# STF-06 - Admin form tạo nhân sự

## Phạm vi

STF-06 bổ sung form tạo nhân sự trong màn **Nhân sự** của Admin. Tính năng sử dụng API STF-02; sau khi tạo thành công, Admin nhận mật khẩu tạm duy nhất một lần để truyền an toàn cho nhân sự mới.

## Entry point

Đăng nhập `ADMIN` hoặc `SUPER_ADMIN` → tab **Thành viên** → màn **Nhân sự** → nút `+` (**Tạo nhân sự**).

## Form

| Trường | Quy tắc |
|---|---|
| Họ và tên | Bắt buộc, 2–100 ký tự |
| Số điện thoại | Tùy chọn; nếu có phải hợp lệ |
| Email | Tùy chọn; nếu có phải hợp lệ |
| Vai trò | Coach, Head Coach, Lễ tân, Admin hoặc Super Admin |
| Chi nhánh | Bắt buộc, lấy từ API chi nhánh/danh sách nhân sự |

Form yêu cầu ít nhất một trong số điện thoại hoặc email. Validation server vẫn là nguồn quyết định cuối cùng, gồm quyền tạo Super Admin, branch active và contact bị trùng.

## API phụ thuộc

```http
POST /api/v1/admin/staff
Content-Type: application/json

{
  "fullName": "Nguyễn Văn A",
  "phone": "0901234567",
  "email": "a@example.com",
  "role": "COACH",
  "branchId": "<branch-uuid>"
}
```

Response thành công `201`:

```json
{
  "data": {
    "staff": { "id": "<uuid>", "fullName": "Nguyễn Văn A" },
    "temporaryPassword": "<one-time-password>"
  }
}
```

## Hành vi sau khi tạo

1. Form đóng sau khi hiển thị sheet thành công.
2. Sheet hiển thị mật khẩu tạm dạng selectable text và cảnh báo không thể xem lại.
3. Nhân sự phải đổi mật khẩu tại lần đăng nhập đầu tiên (`mustChangePassword=true`, STF-04).
4. Danh sách nhân sự được invalidate để lần mở lại nhận dữ liệu mới.

## File chính

```text
mobile/lib/features/staff/domain/staff_models.dart
mobile/lib/features/staff/domain/staff_repository.dart
mobile/lib/features/staff/data/staff_repository_impl.dart
mobile/lib/features/staff/presentation/staff_providers.dart
mobile/lib/features/staff/presentation/widgets/create_staff_sheet.dart
mobile/lib/features/staff/presentation/screens/staff_directory_screen.dart
```

## Kiểm tra

```sh
cd mobile
flutter analyze
flutter test test/features/staff/staff_directory_screen_test.dart
```
