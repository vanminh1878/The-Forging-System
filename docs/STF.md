# STF — Quản lý nhân sự

## STF-05: Danh sách nhân sự và bộ lọc

### Entry point

Đăng nhập Admin/Super Admin → tab **Thành viên** → màn **Nhân sự** (`/admin/members`).

### Chức năng

- Danh sách nhân sự từ API thật; card hiển thị tên, role, chi nhánh và trạng thái tài khoản.
- Tìm theo tên/email/SĐT; debounce 350ms và hỗ trợ submit bàn phím.
- Lọc role có thể gán trong STF (Coach, Lễ tân, Admin), trạng thái `ACTIVE`/`LOCKED`/`DISABLED` và chi nhánh.
- Phân trang server 20 dòng/trang, refresh/retry, empty/error state và popup hồ sơ read-only.
- Cache theo query/user hiện tại; response tìm kiếm cũ không được ghi đè query mới.

### API

```http
GET /api/v1/admin/staff?q=&role=&status=&branchId=&page=1&limit=20
```

Options chi nhánh dùng `GET /branches`. Chỉ khi endpoint trả 404, UI mới tổng hợp các chi nhánh từ danh sách nhân sự; lỗi quyền/5xx không bị che bằng fallback.

## STF-06: Tạo nhân sự

### Entry point

Admin → **Nhân sự** → **Tạo nhân sự**.

### Form

| Trường | Quy tắc |
|---|---|
| Họ và tên | Bắt buộc, 2–100 ký tự |
| Số điện thoại | Tùy chọn; nếu có phải hợp lệ |
| Email | Tùy chọn; nếu có phải hợp lệ |
| Vai trò | Coach, Lễ tân hoặc Admin |
| Chi nhánh | Bắt buộc, lấy từ API chi nhánh/danh sách nhân sự |

Phải có ít nhất số điện thoại hoặc email. STF không cho tạo hoặc gán `HEAD_COACH`/`SUPER_ADMIN`; tài khoản legacy mang các role này vẫn hiển thị để tương thích dữ liệu.

```http
POST /api/v1/admin/staff
Content-Type: application/json

{ "fullName": "Nguyễn Văn A", "phone": "0901234567", "role": "COACH", "branchId": "<branch-uuid>" }
```

Response thành công trả `staff` và `temporaryPassword`. Mật khẩu tạm do server tạo, có độ dài 8–12 ký tự, chỉ hiển thị một lần; không nằm trong audit log.

Sau khi tạo, nhân sự có `mustChangePassword=true`; danh sách nhân sự được refresh.

## STF-07: Sửa nhân sự

Từ chi tiết một nhân sự, Admin có thể sửa role/chi nhánh hoặc vô hiệu hóa tài khoản; mọi thay đổi cần lý do ít nhất 3 ký tự.

| Thao tác | API |
|---|---|
| Cập nhật role/chi nhánh | `PATCH /api/v1/admin/staff/:staffId` |
| Vô hiệu hóa | `POST /api/v1/admin/staff/:staffId/status` với `status: "DISABLED"` |
| Reset mật khẩu tạm | `POST /api/v1/admin/staff/:staffId/reset-password` |

STF chỉ có thể gán Coach, Lễ tân hoặc Admin. Backend kiểm tra branch còn hoạt động, contact trùng và thu hồi session sau cập nhật/vô hiệu hóa/reset mật khẩu. UI hiển thị lỗi API bằng `InlineBanner`, refresh danh sách sau khi thành công và không hiện nút vô hiệu hóa với nhân sự đã `DISABLED`.

## STF-08: Đổi mật khẩu tạm lần đầu

Khi login hoặc `/auth/me` trả `mustChangePassword: true`, router buộc người dùng vào `/change-password`; không thể truy cập màn theo role.

```http
POST /api/v1/auth/password/change
{ "currentPassword": "...", "password": "...", "passwordConfirm": "..." }
```

Mật khẩu mới tối thiểu 8 ký tự, có chữ và số. Sau khi đổi thành công, backend thu hồi session và app xóa token local rồi điều hướng về đăng nhập.

## Mã nguồn

```text
mobile/lib/features/staff/
  domain/staff_models.dart
  domain/staff_repository.dart
  data/staff_dto.dart
  data/staff_repository_impl.dart
  presentation/staff_providers.dart
  presentation/screens/staff_directory_screen.dart
  presentation/widgets/staff_filter_sheet.dart
  presentation/widgets/staff_member_card.dart
  presentation/widgets/create_staff_sheet.dart
  presentation/widgets/staff_manage_sheet.dart
```

## Kiểm tra

```sh
cd backend && npm run typecheck && npm test -- --run tests/unit/staff.test.ts
cd mobile && flutter analyze && flutter test test/features/staff
```
