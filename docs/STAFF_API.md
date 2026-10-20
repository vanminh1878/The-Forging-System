# Staff APIs — STF-01..04

Base URL: `/api/v1`. Gửi `X-Tenant-Code: hvp` và `Authorization: Bearer <accessToken>`.
API quản lý nhân sự dành cho `ADMIN` hoặc `SUPER_ADMIN`; chỉ `SUPER_ADMIN` được tạo/quản lý `SUPER_ADMIN`.
Không có permission matrix theo chức năng. Vai trò là catalogue cố định theo Database Design §4.9.

## Endpoints

| Task | Method/path | Nội dung |
|---|---|---|
| STF-01 / dữ liệu cho STF-05 | `GET /admin/staff` | Danh sách, tìm tên/email/SĐT, phân trang/bộ lọc |
| STF-01 | `GET /admin/staff/:staffId` | Chi tiết nhân sự, không có hash/mật khẩu |
| STF-02 | `POST /admin/staff` | Tạo user + role + chi nhánh, trả mật khẩu tạm một lần |
| STF-03 | `PATCH /admin/staff/:staffId` | Đổi role và/hoặc chi nhánh, bắt buộc reason |
| STF-03 | `POST /admin/staff/:staffId/status` | `ACTIVE` hoặc `DISABLED`, bắt buộc reason |
| STF-03 | `POST /admin/staff/:staffId/reset-password` | Sinh mật khẩu tạm mới, bắt buộc reason |
| STF-04 | `POST /auth/password/change` | Đổi mật khẩu hiện tại, xóa cờ bắt buộc đổi |

`staffId` là UUID của `users.id`. Nhân sự không có bản ghi `members`.
Roles: `COACH`, `HEAD_COACH`, `RECEPTIONIST`, `ADMIN`, `SUPER_ADMIN`.
Chi nhánh phải tồn tại, thuộc tenant hiện tại và `is_active=true` (phụ thuộc BR-01).

### Danh sách / tìm kiếm

```http
GET /api/v1/admin/staff?q=tuan&role=COACH&branchId=<uuid>&status=ACTIVE&page=1&limit=20
```

Tất cả bộ lọc đều tùy chọn; `limit` từ 1–100. Sắp xếp theo `fullName`, sau đó `id`.
Chỉ lấy tài khoản có staff role chưa bị revoke; tìm kiếm không trả học viên.

```json
{
  "data": [
    {
      "id": "<uuid>",
      "fullName": "Tuấn Lê",
      "phone": "0901234567",
      "email": "tuan@example.com",
      "branchId": "<uuid>",
      "branchName": "HVP Quận 7",
      "accountStatus": "ACTIVE",
      "mustChangePassword": true,
      "roles": ["COACH"]
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 1, "totalPages": 1 }
}
```

### Tạo nhân sự

```json
{
  "fullName": "Tuấn Lê",
  "phone": "0901234567",
  "email": "tuan@example.com",
  "role": "COACH",
  "branchId": "<uuid>"
}
```

`phone` hoặc `email` là bắt buộc (có thể gửi cả hai). Email/SĐT không được trùng user khác trong tenant.
Password được backend sinh ngẫu nhiên và lưu dưới dạng bcrypt hash.
Response `201`: `{ "data": { "staff": <StaffView>, "temporaryPassword": "..." } }`.
Không trả mật khẩu qua list/detail hoặc ghi mật khẩu vào audit.

### Đổi vai trò / chi nhánh

```json
{ "role": "RECEPTIONIST", "branchId": "<uuid>", "reason": "Điều chuyển nhân sự" }
```

Cho phép gửi riêng `role` hoặc `branchId`. Role cũ được đánh dấu `revoked_at`/`revoked_by`, role mới giữ thông tin `granted_by`.
Response `200`: `{ "data": <StaffView> }`.

### Vô hiệu hóa / kích hoạt lại

```json
{ "status": "DISABLED", "reason": "Nhân sự nghỉ việc" }
```

Không hard-delete. Response `200`: `{ "data": <StaffView> }`.
Không cho vô hiệu hóa hoặc thu hồi role của Super Admin hoạt động cuối cùng.

### Reset mật khẩu bởi Admin

```json
{ "reason": "Nhân sự quên mật khẩu" }
```

Response `200`:

```json
{ "data": { "staffId": "<uuid>", "temporaryPassword": "...", "mustChangePassword": true } }
```

## Luồng mật khẩu tạm / FE

1. Login bằng mật khẩu tạm qua API hiện có `POST /auth/login`.
2. `data.user.mustChangePassword=true`: FE chuyển đến màn đổi mật khẩu, chưa mở console nghiệp vụ.
3. Token này chỉ gọi được `GET /auth/me`, `POST /auth/logout`, `POST /auth/password/change`.
   API nghiệp vụ trả `403 PASSWORD_CHANGE_REQUIRED`.
4. Gọi API đổi mật khẩu:

```json
{
  "currentPassword": "<temporary password>",
  "password": "NewPassword123!",
  "passwordConfirm": "NewPassword123!"
}
```

5. Thành công `204`: xóa token local, đăng nhập lại bằng mật khẩu mới. `mustChangePassword=false`.

Password mới phải khác password hiện tại, khớp xác nhận, có chữ/số và đủ `security.password_min_length`.
Reset mật khẩu, đổi role/chi nhánh, thay trạng thái hoặc đổi mật khẩu sẽ thu hồi phiên cũ.
Access token có credential version (`ver`); API kiểm tra version và trạng thái user từ DB, không chỉ tin JWT cũ.

## Mã lỗi

| HTTP | Code | Ý nghĩa |
|---|---|---|
| 400 | `VALIDATION_ERROR` / `BAD_REQUEST` | Thiếu trường, UUID/role/body không hợp lệ |
| 400 | `INVALID_BRANCH` | Chi nhánh không hợp lệ/không active |
| 401 | `INVALID_CREDENTIALS` / `TOKEN_INVALID` | Mật khẩu sai hoặc phiên bị thu hồi |
| 403 | `FORBIDDEN` | Sai quyền, bao gồm quản lý Super Admin bởi Admin thường |
| 403 | `PASSWORD_CHANGE_REQUIRED` | Cần đổi mật khẩu tạm |
| 403 | `ACCOUNT_DISABLED` | Tài khoản không active |
| 404 | `NOT_FOUND` | Không có nhân sự trong tenant |
| 409 | `STAFF_CONTACT_TAKEN` / `DUPLICATE` | Email/SĐT đã tồn tại |
| 409 | `LAST_SUPER_ADMIN` | Không thể thu hồi Super Admin cuối cùng |
| 422 | `WEAK_PASSWORD` | Mật khẩu mới chưa đạt quy tắc |

## Migration và kiểm tra

```sh
npm run migrate
npm run typecheck
npm run lint
npm test
npm run test:integration -- tests/integration/staff.test.ts tests/integration/auth.test.ts
```

Migration `0004_staff_credentials.sql` thêm `must_change_password`, `auth_version` và index tìm nhân sự.
Phải chạy migration trước khi khởi động API mới. Cờ mặc định false để giữ tương thích tài khoản cũ.
STF-05 ở đây được hỗ trợ bằng API list/filter; màn Flutter chưa được triển khai trong thay đổi backend này.
