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

## cURL test API — CMD Windows

Các lệnh dưới dành cho **Command Prompt (CMD)**. Token Admin và token nhân sự dùng hai biến riêng.
Các ví dụ tạo/cập nhật dùng tài khoản test; nếu SĐT/email đã có, đổi thông tin để tránh lỗi 409.

### 1. Migration và chạy backend

Chạy tại thư mục backend, sử dụng kết nối trong `.env`, không cần Docker:

```cmd
cd /d "E:\Hoc\Boxing\HVPForgingSystem\backend"
npm run migrate
npm run dev
```

Giữ terminal này chạy, mở CMD thứ hai để test:

```cmd
curl "http://localhost:4000/health"
```

### 2. Đăng nhập Admin và đặt biến

Tài khoản demo đã kiểm tra đăng nhập thành công trên DB hiện tại:

```cmd
curl -X POST "http://localhost:4000/api/v1/auth/login" -H "Content-Type: application/json" -H "X-Tenant-Code: hvp" -d "{\"identifier\":\"0900000001\",\"password\":\"hvp12345\"}"
```

Copy `data.accessToken` từ response, thay placeholder rồi chạy:

```cmd
set "TOKEN=ACCESS_TOKEN_ADMIN"
set "BRANCH_ID=d9740649-d99f-4a7c-a5bb-184e12f21aa2"
```

`BRANCH_ID` trên là chi nhánh Quận 7 của DB `localhost:5439/hvp` đã xác minh trong phiên kiểm tra.
Đây không phải ID mặc định cố định: khi dùng DB khác hoặc seed lại, thay bằng UUID chi nhánh thực tế.

### 3. STF-01 — Danh sách, tìm kiếm và bộ lọc

```cmd
curl "http://localhost:4000/api/v1/admin/staff?page=1&limit=20" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
```

Lọc kết hợp tên, vai trò, trạng thái và chi nhánh:

```cmd
curl "http://localhost:4000/api/v1/admin/staff?q=Test&role=COACH&status=ACTIVE&branchId=%BRANCH_ID%&page=1&limit=20" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
```

Kết quả thành công: 200 với `data` và `meta`. Không có kết quả phù hợp vẫn trả 200 với danh sách rỗng.

### 4. STF-02 — Tạo nhân sự

```cmd
curl -X POST "http://localhost:4000/api/v1/admin/staff" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"fullName\":\"Coach Test STF\",\"phone\":\"0909000021\",\"email\":\"coach.stf.test@example.com\",\"role\":\"COACH\",\"branchId\":\"%BRANCH_ID%\"}"
```

Thành công: 201. Copy `data.staff.id` và `data.temporaryPassword`, thay placeholder:

```cmd
set "STAFF_ID=ID_NHAN_SU_VUA_TAO"
set "TEMP_PASSWORD=MAT_KHAU_TAM_TU_RESPONSE"
```

Xem chi tiết tài khoản vừa tạo:

```cmd
curl "http://localhost:4000/api/v1/admin/staff/%STAFF_ID%" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
```

### 5. STF-03 — Đổi vai trò hoặc chi nhánh

```cmd
curl -X PATCH "http://localhost:4000/api/v1/admin/staff/%STAFF_ID%" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"role\":\"RECEPTIONIST\",\"branchId\":\"%BRANCH_ID%\",\"reason\":\"Dieu chuyen nhan su\"}"
```

Thành công: 200. Có thể chỉ gửi role hoặc branchId, luôn kèm reason.

### 6. STF-03 — Vô hiệu hóa và kích hoạt lại

Vô hiệu hóa tài khoản test:

```cmd
curl -X POST "http://localhost:4000/api/v1/admin/staff/%STAFF_ID%/status" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"status\":\"DISABLED\",\"reason\":\"Nhan su tam nghi\"}"
```

Kích hoạt lại trước khi test đăng nhập:

```cmd
curl -X POST "http://localhost:4000/api/v1/admin/staff/%STAFF_ID%/status" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"status\":\"ACTIVE\",\"reason\":\"Nhan su quay lai\"}"
```

### 7. STF-03 — Reset mật khẩu

```cmd
curl -X POST "http://localhost:4000/api/v1/admin/staff/%STAFF_ID%/reset-password" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"reason\":\"Nhan su quen mat khau\"}"
```

Thành công: 200 với mật khẩu tạm mới. **Thay `%TEMP_PASSWORD%` bằng `data.temporaryPassword` mới**, không dùng mật khẩu từ lúc tạo tài khoản:

```cmd
set "TEMP_PASSWORD=MAT_KHAU_TAM_MOI_TU_RESPONSE_RESET"
```

### 8. STF-04 — Đăng nhập bằng mật khẩu tạm

```cmd
curl -X POST "http://localhost:4000/api/v1/auth/login" -H "Content-Type: application/json" -H "X-Tenant-Code: hvp" -d "{\"identifier\":\"0909000021\",\"password\":\"%TEMP_PASSWORD%\"}"
```

Nếu đã đổi SĐT test ở bước tạo tài khoản, thay identifier tương ứng ở đây và bước đăng nhập cuối.
Copy access token của nhân sự, không ghi đè biến `%TOKEN%` của Admin:

```cmd
set "STAFF_TOKEN=ACCESS_TOKEN_NHAN_SU"
curl "http://localhost:4000/api/v1/auth/me" -H "Authorization: Bearer %STAFF_TOKEN%" -H "X-Tenant-Code: hvp"
```

Response có `mustChangePassword=true`. Có thể kiểm tra API nghiệp vụ đang bị chặn:

```cmd
curl "http://localhost:4000/api/v1/members" -H "Authorization: Bearer %STAFF_TOKEN%" -H "X-Tenant-Code: hvp"
```

Kỳ vọng 403 `PASSWORD_CHANGE_REQUIRED` cho tới khi đổi mật khẩu.

### 9. STF-04 — Đổi mật khẩu lần đầu

```cmd
curl -i -X POST "http://localhost:4000/api/v1/auth/password/change" -H "Authorization: Bearer %STAFF_TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"currentPassword\":\"%TEMP_PASSWORD%\",\"password\":\"NewStaffPass123\",\"passwordConfirm\":\"NewStaffPass123\"}"
```

Thành công: **204 No Content**. Token cũ bị thu hồi; đăng nhập lại bằng mật khẩu mới:

```cmd
curl -X POST "http://localhost:4000/api/v1/auth/login" -H "Content-Type: application/json" -H "X-Tenant-Code: hvp" -d "{\"identifier\":\"0909000021\",\"password\":\"NewStaffPass123\"}"
```

Response lúc này có `mustChangePassword=false`. Nếu tiếp tục gọi API, thay `%STAFF_TOKEN%` bằng access token mới.

### 10. Khi chuyển nhánh

Chạy `npm run migrate` tại backend sau khi checkout nhánh cần test, rồi khởi động lại backend để nạp code của nhánh đó.
Migration là forward-only, chỉ áp dụng file chưa chạy; checkout nhánh khác không tự rollback cấu trúc DB.
