# STF-07 - Admin sửa quyền nhân sự

## Phạm vi

Từ chi tiết một nhân sự trong màn **Nhân sự**, Admin có thể:

- sửa vai trò và chi nhánh;
- vô hiệu hoá tài khoản;
- nhập lý do bắt buộc cho mọi thay đổi.

## API sử dụng

| Thao tác | API |
|---|---|
| Cập nhật vai trò/chi nhánh | `PATCH /api/v1/admin/staff/:staffId` |
| Vô hiệu hoá | `POST /api/v1/admin/staff/:staffId/status` với `status: "DISABLED"` |

Ví dụ cập nhật:

```json
{ "role": "COACH", "branchId": "<branch-uuid>", "reason": "Điều chuyển nhân sự" }
```

Ví dụ vô hiệu hoá:

```json
{ "status": "DISABLED", "reason": "Nhân sự đã nghỉ việc" }
```

Backend STF-03 kiểm tra quyền quản lý Super Admin, branch còn hoạt động, Super Admin cuối cùng và thu hồi các phiên đăng nhập của nhân sự bị thay đổi.

## Hành vi UI

- Form hiển thị lỗi API bằng `InlineBanner`.
- Lý do cần ít nhất 3 ký tự.
- Sau thành công, danh sách nhân sự được invalidate để tải lại dữ liệu.
- Nút vô hiệu hoá không hiển thị cho nhân sự đã ở trạng thái `DISABLED`.

## Kiểm tra

```sh
cd mobile
flutter analyze
flutter test test/features/staff/staff_directory_screen_test.dart
```
