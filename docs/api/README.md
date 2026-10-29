# API cho Frontend (`docs/api/`)

Tài liệu theo từng tính năng để FE dựng màn hình mà không cần đọc code backend. Tài liệu nền tảng chung (auth, điểm, hạng…): [`../API_FOUNDATION.md`](../API_FOUNDATION.md).

## Quy ước chung

- **Base URL:** `/api/v1` (dev: `http://localhost:4000/api/v1`).
- **Tenant:** header `X-Tenant-Code` (tuỳ chọn, mặc định `hvp`).
- **Xác thực:** `Authorization: Bearer <accessToken>` (lấy từ `/auth/login`). Thiếu/hết hạn → 401.
- **Thành công:** `{ "data": ..., "meta"?: ... }`. Trả 204 thì không có body.
- **Lỗi:** `{ "error": { "code": "UPPER_SNAKE", "message": "tiếng Việt", "details"?: ... } }`. FE `switch` theo `code`, hiển thị `message`.
  - Lỗi validate (400) có `code = "VALIDATION_ERROR"` (hoặc `BAD_REQUEST`), `details` là danh sách field sai.
  - 401 chưa đăng nhập, 403 không đủ quyền, 404 không tồn tại, 409 xung đột (trùng), 422 vi phạm quy tắc nghiệp vụ.
- **Phân trang:** `?page=1&limit=20` (`page` ≥ 1, `limit` 1–100, mặc định 20). `meta = { page, limit, total, totalPages }`.
- **Thời gian:** ISO-8601 UTC; ngày lịch `YYYY-MM-DD`. JSON dùng camelCase.

## Ký hiệu vai trò

| Ký hiệu | Role code | Ghi chú |
|---|---|---|
| M | `MEMBER` | Học viên |
| Coach | `COACH`, `HEAD_COACH` | Huấn luyện viên |
| FD | `RECEPTIONIST`, `ADMIN`, `SUPER_ADMIN` | Lễ tân + admin |
| S | `COACH`, `HEAD_COACH`, `RECEPTIONIST`, `ADMIN`, `SUPER_ADMIN` | Mọi staff |
| A | `ADMIN`, `SUPER_ADMIN` | Quản trị |

## Mục lục

- [`batch.md`](batch.md): batch job / scheduler (danh sách, chạy tay, lịch sử)
- [`branches.md`](branches.md): chi nhánh (danh sách, chi tiết, quản trị, QR check-in)
- `classes.md`: lớp học
- `memberships.md`: gói tập
- `profile.md`: hồ sơ cá nhân
