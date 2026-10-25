# ARM-03 — Lịch sử đổi quà và trạng thái (Học viên)

**Nhánh:** `feature/ARM-03-redemption-history`. Phụ thuộc ARM-02.  
**Phạm vi:** chỉ đọc danh sách lịch sử và trạng thái đơn của member đang đăng nhập. Không thay đổi lifecycle, stock, Marks, hoặc Admin/Lễ tân API.

## API

Base `/api/v1`; yêu cầu Bearer token và tenant. Chỉ role MEMBER.

| Method | Path | Chức năng |
|---|---|---|
| GET | `/me/armory/redemptions` | Lịch sử đổi quà, filter trạng thái, phân trang |
| GET | `/me/armory/redemptions/:redemptionId` | Chi tiết và trạng thái mới nhất của một đơn |

Không nhận memberId từ URL/query/body. Cả list và detail luôn lấy member ID từ token; ID đơn của member khác trả 404 để không lộ đơn tồn tại.

### Lịch sử

```http
GET /api/v1/me/armory/redemptions?status=PENDING_PICKUP&page=1&limit=20
```

Filter `status` tùy chọn: `PENDING_PICKUP`, `DELIVERED`, `REJECTED`, `CANCELLED`, `EXPIRED`.
Pagination theo API chung: page mặc định 1, limit mặc định 20/tối đa 100.
Sort `requestedAt DESC, id DESC`.

Response:

```json
{
  "data": [{
    "id": "<uuid>",
    "redemptionCode": "ARM-...",
    "rewardId": "<uuid>",
    "pickupBranchId": "<uuid>",
    "marksCost": 120,
    "status": "PENDING_PICKUP",
    "requestedAt": "<server timestamp>",
    "decidedAt": null,
    "reason": null,
    "rewardSku": "HVP-WRAPS-01",
    "rewardName": "Băng quấn tay HVP",
    "rewardImageUrl": null,
    "pickupBranchName": "HVP Boxing - Quận 7"
  }],
  "meta": { "page": 1, "limit": 20, "total": 1, "totalPages": 1 }
}
```

Giá Marks trả từ `redemptions.marks_cost` snapshot; tên/SKU/ảnh quà và tên chi nhánh join từ record cùng tenant.
Trạng thái phản ánh lifecycle mới nhất tại thời điểm query. `decidedAt`/`reason` null khi đơn còn pending.

### Chi tiết

```http
GET /api/v1/me/armory/redemptions/<redemptionId>
```

Response 200 `{ "data": <một record như phần tử lịch sử> }`; không có envelope pagination.

## cURL CMD Windows

```cmd
set "TOKEN=MEMBER_ACCESS_TOKEN"
curl "http://localhost:4000/api/v1/me/armory/redemptions?page=1&limit=20" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
curl "http://localhost:4000/api/v1/me/armory/redemptions?status=PENDING_PICKUP&page=1&limit=20" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
set "REDEMPTION_ID=UUID_DON_TU_RESPONSE"
curl "http://localhost:4000/api/v1/me/armory/redemptions/%REDEMPTION_ID%" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
```

## Bảo mật và test

- Staff và request chưa đăng nhập bị từ chối.
- Query status enum, page/limit được validate; không nhận query không định nghĩa.
- RLS được áp dụng qua tenant transaction; detail của người khác trả 404.
- Không có side-effect: không sửa đơn, ledger, stock hoặc Marks.

Tests: `backend/tests/integration/redemption-history.test.ts` bao phủ ownership, status, filter, pagination, reward/branch labels, RBAC và RLS.
