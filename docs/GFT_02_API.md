# GFT-02 — Nhập/xuất kho và lịch sử

Base URL `/api/v1`. Chỉ Lễ tân, Admin, Super Admin; Bearer token và `X-Tenant-Code`.
Kho `rewards.stock` là kho chung theo tenant, không phân kho theo chi nhánh.

## Nhập/xuất

```http
POST /staff/armory/inventory/movements
```

```json
{ "rewardId": "<UUID_QUA>", "movementType": "IN", "quantity": 5, "reason": "Nhập hàng" }
```

`movementType`: IN hoặc OUT; `quantity`: integer dương; `reason`: 3–500 ký tự. Actor/tenant lấy từ token.
Response 201 `{data:{movement,stockBefore,stockAfter}}`. Reward được khóa khi tính stock; không xuất âm hoặc vượt int32.
Thay đổi stock, inventory movement và audit cùng transaction. Không tự tạo/cập nhật đơn redemption hay ledger Marks.

## Lịch sử

```http
GET /staff/armory/inventory/movements?rewardId=<uuid>&movementType=IN&actorId=<uuid>&page=1&limit=20
```

Tất cả filter tùy chọn; thêm `from`, `to` ISO-8601 có timezone (inclusive), `page`, `limit` 1–100.
Response `{data:[...],meta:{page,limit,total,totalPages}}`, sắp xếp `createdAt DESC,id DESC`.
Bao gồm movement từ các luồng khác có ghi vào `inventory_movements`, kể cả movement gắn `redemptionId`.
Chỉ trả dữ liệu tenant hiện tại. 400 validation, 401/403 token/role, 404 quà không thuộc tenant, 409 INSUFFICIENT_STOCK/STOCK_LIMIT_EXCEEDED.

## CMD cURL

```cmd
set "TOKEN=STAFF_ACCESS_TOKEN"
set "REWARD_ID=UUID_PHAN_QUA"
curl -X POST "http://localhost:4000/api/v1/staff/armory/inventory/movements" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"rewardId\":\"%REWARD_ID%\",\"movementType\":\"IN\",\"quantity\":5,\"reason\":\"Nhap hang\"}"
curl -X POST "http://localhost:4000/api/v1/staff/armory/inventory/movements" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"rewardId\":\"%REWARD_ID%\",\"movementType\":\"OUT\",\"quantity\":2,\"reason\":\"Xuat kho\"}"
curl "http://localhost:4000/api/v1/staff/armory/inventory/movements?rewardId=%REWARD_ID%&page=1&limit=20" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
```

GFT-02 không yêu cầu migration mới. Mỗi POST là một thao tác kho mới; không tự retry nếu chưa biết kết quả request trước.
