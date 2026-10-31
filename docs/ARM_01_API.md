# ARM-01 — API danh sách quà theo tầng (Học viên)

Commit riêng cho ARM-01; ARM-04 ledger/giữ Marks được triển khai ở commit tiếp theo.
Không cần migration: dùng bảng `reward_tiers`, `rewards`, `ranks` của schema runtime v3.

## Endpoints

Base URL `/api/v1`. Bearer token, tenant header `X-Tenant-Code` (mặc định hvp).
Chỉ role `MEMBER`; đây là catalog học viên, không phải API quản trị quà.

| Method | Path | Nội dung |
|---|---|---|
| GET | `/armory/tiers` | Tầng quà theo sortOrder rồi code |
| GET | `/armory/rewards` | List quà theo tầng, search và phân trang |

```http
GET /api/v1/armory/rewards?tierCode=FIELD_SUPPLIES&q=HVP&page=1&limit=20
```

- `tierCode`, `q` tùy chọn; page >=1, limit 1–100 (mặc định 20).
- Search literal theo tên/SKU, không phân biệt hoa thường; %, _ không biến thành wildcard.
- Chỉ trả quà active trong thời gian mở bán, lấy thời gian từ server.
- `saleStartsAt` inclusive, `saleEndsAt` exclusive; null không giới hạn mốc đó.
- Quà hết stock vẫn hiển thị với `inStock=false` để UI mô tả trạng thái.
- Trả minRankId/minRankOrder/minRankName, giới hạn đổi, thời gian nhận và giá Marks; không tự khẳng định đủ điều kiện đổi chỉ dựa trên catalog.
- Quà chưa gán tầng nằm cuối danh sách; tầng không có quà vẫn được trả bởi `/tiers`.
- Tầng không tồn tại trong filter trả list rỗng, không làm lộ catalogue tenant khác.
- Không thay stock, ví, ledger hoặc đơn đổi quà khi đọc catalog.

Response tiers `{data:[{code,name,minMarks,maxMarks,sortOrder}]}`.
Response rewards `{data:[{id,sku,name,description,imageUrl,tierCode,tierName,marksCost,stock,inStock,perMemberLimit,limitPeriod,minRankId,minRankOrder,minRankName,pickupDays,saleStartsAt,saleEndsAt}],meta:{page,limit,total,totalPages}}`.

## cURL CMD

```cmd
set "TOKEN=MEMBER_ACCESS_TOKEN"
curl "http://localhost:4000/api/v1/armory/tiers" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
curl "http://localhost:4000/api/v1/armory/rewards?tierCode=FIELD_SUPPLIES&page=1&limit=20" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
```

Lỗi: 400 VALIDATION_ERROR, 401 UNAUTHORIZED/TOKEN_INVALID, 403 FORBIDDEN.
Kiểm thử: validation/filter, thứ tự tầng, thời gian mở bán, quà hết stock, pagination, RBAC và RLS đa tenant.
