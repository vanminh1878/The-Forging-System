# ARM-03 — Lịch sử đổi quà và trạng thái

Nhánh `feature/ARM-03-redemption-history`, phụ thuộc ARM-02 và ARM-04. Không cần migration mới.

## API học viên

Base URL `/api/v1`; yêu cầu Bearer token MEMBER và tenant header.

| Method | Endpoint | Chức năng |
|---|---|---|
| GET | `/me/armory/redemptions` | Danh sách lịch sử của học viên hiện tại |
| GET | `/me/armory/redemptions/:redemptionId` | Chi tiết/trạng thái mới nhất của một đơn |

Danh sách hỗ trợ `status`, `page`, `limit` (1–100). Status hợp lệ theo schema runtime v3:
`PENDING_PICKUP`, `DELIVERED`, `REJECTED`, `CANCELLED`, `EXPIRED`. Không có `READY` trong schema này.
Sort `requestedAt DESC, id DESC`, response `{data:[...],meta:{page,limit,total,totalPages}}`.

Mỗi bản ghi gồm `id`, `redemptionCode`, `rewardId`, `rewardName`, `rewardSku`, `rewardImageUrl`,
`pickupBranchId`, `pickupBranchName`, `marksCost`, `status`, `requestedAt`, `decidedAt`, `reason`.
Giá Marks là snapshot của đơn; tên/ảnh quà và tên chi nhánh là dữ liệu hiện tại. Detail trả `{data:object}`.

Chỉ đọc đơn thuộc member ID trong token, và RLS theo tenant. Đơn của người khác/tenant khác trả 404.
Không thay đổi trạng thái, điểm hoặc stock. API chuyển trạng thái là task khác.

## cURL CMD

```cmd
set "TOKEN=MEMBER_ACCESS_TOKEN"
curl "http://localhost:4000/api/v1/me/armory/redemptions?page=1&limit=20" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
curl "http://localhost:4000/api/v1/me/armory/redemptions?status=PENDING_PICKUP&page=1&limit=20" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
set "REDEMPTION_ID=UUID_TU_RESPONSE"
curl "http://localhost:4000/api/v1/me/armory/redemptions/%REDEMPTION_ID%" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
```

Không truyền status nếu muốn xem tất cả. Sai UUID/filter trả 400; thiếu token 401; sai role 403; không tìm thấy đơn thuộc tài khoản 404.

## Kiểm thử

```sh
npm run typecheck
npm run lint
npm run build
npm run test:integration -- tests/integration/redemption-history.test.ts tests/integration/redemption.test.ts
```
