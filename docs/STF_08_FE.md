# STF-08 - Đổi mật khẩu tạm lần đầu

Khi API đăng nhập hoặc `/auth/me` trả `mustChangePassword: true`, router bắt buộc người dùng vào `/change-password`; họ không thể truy cập các màn theo vai trò.

Màn hình yêu cầu mật khẩu tạm, mật khẩu mới và xác nhận mật khẩu mới. Mật khẩu mới tối thiểu 8 ký tự, gồm chữ và số. Form gọi:

```http
POST /api/v1/auth/password/change
{ "currentPassword": "...", "password": "...", "passwordConfirm": "..." }
```

Sau thành công, backend thu hồi phiên đăng nhập theo STF-04. Ứng dụng cũng xoá token cục bộ và chuyển về đăng nhập với thông báo thành công.

Kiểm tra:

```sh
cd mobile
flutter analyze
flutter test test/features/auth
```
