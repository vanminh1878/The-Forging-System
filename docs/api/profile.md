# Hồ sơ cá nhân (AUTH-11)

Base URL `/api/v1`. Header `X-Tenant-Code`, `Authorization: Bearer <token>`. Chỉ role **MEMBER** (học viên) gọi được; staff nhận 403.

## GET /me/profile

Trả hồ sơ của học viên đang đăng nhập.

```json
{
  "data": {
    "userId": "6b1f…", "memberCode": "HVP-AB12CD", "fullName": "Nguyễn Văn A",
    "email": "a@example.com", "phone": "0912345678",
    "avatarUrl": "https://api.hvp.vn/files/hvp/avatars/6b1f…/2026-10/x.jpg",
    "dateOfBirth": "1990-05-01", "gender": "MALE",
    "homeBranchId": "c0a8…", "homeBranchName": "HVP Boxing - The Corner",
    "joinedAt": "2026-10-01T03:00:00.000Z", "status": "ACTIVE", "statusReason": null,
    "currentRankId": "…", "dpBalance": 620, "marksBalance": 4,
    "currentStreakWeeks": 2, "longestStreakWeeks": 5, "lastActivityAt": "2026-10-20T10:00:00.000Z"
  }
}
```

(Còn các trường nội bộ khác như `statusChangedBy`, `peakRankId`, `duplicateOfMemberId` - FE bỏ qua.)

## PATCH /me/profile

Cập nhật một phần. Quy tắc chung: **bỏ qua trường = giữ nguyên; gửi `null` = xóa giá trị**. Trả về hồ sơ mới (cùng dạng GET).

| Trường | Kiểu | Ràng buộc |
|---|---|---|
| fullName | string | 2-100 ký tự, không được null |
| avatarUrl | string \| null | phải là URL do `POST /uploads?purpose=avatar` trả về |
| email | string \| null | email hợp lệ, duy nhất |
| phone | string \| null | 9-16 ký tự, SĐT VN hợp lệ, duy nhất |
| dateOfBirth | `YYYY-MM-DD` \| null | |
| gender | `MALE` \| `FEMALE` \| `OTHER` \| null | |
| homeBranchId | uuid \| null | chi nhánh đang hoạt động (lấy từ `GET /branches`) |

Quy tắc:
- Đổi email/SĐT: kiểm tra trùng với tài khoản khác; gửi lại đúng giá trị cũ thì không tính là đổi.
- Không được xóa cả email lẫn SĐT (phải còn ít nhất một).
- Đổi email -> `email_verified_at` bị reset; đổi SĐT -> `phone_verified_at` bị reset (cần xác minh lại).
- Mỗi lần cập nhật ghi audit `PROFILE_UPDATED` (trước/sau).

### Luồng đổi ảnh đại diện
1. `POST /uploads?purpose=avatar` (multipart, field `file`; JPG/PNG/WEBP/HEIC, tối đa 8MB) -> `201 { "data": { "url": "…" } }`.
2. `PATCH /me/profile { "avatarUrl": "<url>" }`.
3. Xóa ảnh: `PATCH /me/profile { "avatarUrl": null }`.

### Lỗi

| HTTP | code | Message |
|---|---|---|
| 400 | VALIDATION_ERROR | Invalid request data (kèm `details[]` theo trường) |
| 400 | (không code) | Số điện thoại không hợp lệ. / Email không hợp lệ. |
| 400 | CONTACT_REQUIRED | Cần giữ lại ít nhất số điện thoại hoặc email. |
| 400 | INVALID_AVATAR_URL | Ảnh đại diện không hợp lệ. Vui lòng tải ảnh lên trước rồi chọn lại. |
| 400 | INVALID_BRANCH | Chi nhánh không tồn tại hoặc đã ngừng hoạt động. |
| 400 | INVALID_REFERENCE | Dữ liệu tham chiếu không tồn tại. (FK vi phạm, phòng hờ) |
| 401 | - | Chưa đăng nhập / token hết hạn |
| 403 | - | Không phải học viên |
| 409 | PHONE_TAKEN | Số điện thoại này đã được đăng ký. Mỗi người chỉ có 1 tài khoản dùng chung mọi chi nhánh. |
| 409 | EMAIL_TAKEN | Email này đã được đăng ký. Vui lòng dùng email khác hoặc đăng nhập. |
| 404 | NOT_FOUND | Không có hồ sơ học viên |

## Ghi chú FE (tab Hồ sơ)
- **Hiển thị:** ảnh đại diện, họ tên, mã học viên (`memberCode`), email, SĐT, ngày sinh, giới tính, chi nhánh (`homeBranchName`), ngày tham gia, trạng thái, rank/DP/marks, streak.
- **Cho sửa:** họ tên, ảnh, email, SĐT, ngày sinh, giới tính, chi nhánh. Không sửa được mã học viên, trạng thái, điểm.
- Chỉ gửi các trường người dùng thực sự đổi. Ô ngày sinh/giới tính/email để trống và đã có giá trị cũ -> gửi `null`.
- Toast thành công: "Đã cập nhật hồ sơ." Lỗi: hiển thị `error.message` của server; `PHONE_TAKEN`/`EMAIL_TAKEN` hiện ngay dưới ô tương ứng.
- Sau khi đổi email/SĐT, hiển thị nhãn "Chưa xác minh" (backend đã reset).
- Danh sách chi nhánh để chọn: `GET /branches`.

## Câu hỏi mở
- **Đổi SĐT có cần OTP xác minh không?** Khách hàng chưa quy định, hiện KHÔNG yêu cầu OTP; SĐT mới chỉ bị đánh dấu chưa xác minh. Cần hỏi lại khách hàng.
