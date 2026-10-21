# GFT-01 — Admin tạo/sửa quà và tầng Armory

Nhánh triển khai: `feature/GFT-01-Armory-Gift`. Một task/commit riêng.
Theo schema backend v3: giá nhập trực tiếp bằng `marks_cost`, tồn kho theo `stock`; không có cost VNĐ/coefficient/reserved stock của DB draft cũ.
Không cần migration mới. Module Admin tách thành `admin-armory.*`, độc lập với module catalog học viên ARM-01.

## API

Base URL `/api/v1`. Headers `Authorization: Bearer <ADMIN_TOKEN>`, `X-Tenant-Code: hvp`.
Chỉ `ADMIN` hoặc `SUPER_ADMIN` truy cập cả read và write.

| Method | Path | Chức năng |
|---|---|---|
| GET | `/admin/armory/tiers` | Tầng theo sortOrder rồi code |
| GET | `/admin/armory/tiers/:tierCode` | Chi tiết tầng |
| POST | `/admin/armory/tiers` | Tạo tầng |
| PATCH | `/admin/armory/tiers/:tierCode` | Sửa tầng |
| GET | `/admin/armory/rewards` | Tìm/lọc/phân trang catalog Admin |
| GET | `/admin/armory/rewards/:rewardId` | Chi tiết quà để mở popup |
| POST | `/admin/armory/rewards` | Tạo quà |
| PATCH | `/admin/armory/rewards/:rewardId` | Sửa metadata, giá Marks, tồn kho, trạng thái |

Không hard-delete. Dừng quà bằng `isActive=false`. Tầng chưa có trạng thái active trong schema nên task không thêm API đóng/xóa tầng.

## Tầng quà

POST body:

```json
{
  "code": "CLUB_GEAR",
  "name": "Club Gear",
  "minMarks": 100,
  "maxMarks": 500,
  "sortOrder": 5
}
```

- Code trim/uppercase, 2–50 ký tự A-Z/0-9/_, duy nhất trong tenant và bất biến sau tạo.
- name 2–100 ký tự, minMarks >=0, maxMarks null hoặc >= minMarks, đều integer int32.
- sortOrder integer 0–32767, mặc định 0. maxMarks mặc định null.
- PATCH chỉ gửi field sửa và `reason` bắt buộc 3–500 ký tự.
- Partial patch kiểm tra min/max sau merge với dữ liệu hiện tại.
- Khoảng Marks tầng là metadata nhóm quà; không ép giá mọi quà vào khoảng hoặc ép các tầng không giao nhau khi nghiệp vụ chưa chốt quy tắc đó.

## Phần quà

POST body:

```json
{
  "sku": "HVP-WRAPS-01",
  "name": "Băng quấn tay HVP",
  "description": "Băng quấn dùng trong tập luyện",
  "imageUrl": null,
  "tierCode": "CLUB_GEAR",
  "marksCost": 220,
  "stock": 10,
  "perMemberLimit": 1,
  "limitPeriod": "MONTH",
  "minRankId": null,
  "pickupDays": 7,
  "saleStartsAt": null,
  "saleEndsAt": null,
  "isActive": true
}
```

| Field | Quy tắc |
|---|---|
| sku | Bắt buộc, uppercase/trim, 2–80 ký tự A-Z/0-9/./_/-; không sửa SKU qua PATCH |
| name | Bắt buộc, trim, 2–150 ký tự |
| marksCost | Bắt buộc, integer 1–2147483647 |
| stock | Integer 0–2147483647, mặc định 0; đây là giá trị tồn đích, không phải delta |
| description | Null hoặc tối đa 2000 ký tự, mặc định null |
| imageUrl | Null hoặc URL HTTP(S), tối đa 2000 ký tự |
| tierCode | Null hoặc code tầng trong cùng tenant |
| perMemberLimit / limitPeriod | Cả hai null, hoặc số nguyên dương + MONTH/YEAR/LIFETIME |
| minRankId | Null hoặc UUID hạng trong cùng tenant |
| pickupDays | Null hoặc integer 1–32767 |
| saleStartsAt / saleEndsAt | Null hoặc ISO-8601 có timezone; nếu cùng có giá trị thì start < end |
| isActive | Boolean thật, mặc định true |

PATCH có ít nhất một field sửa + reason. Field nullable được xóa bằng null; field khác không nhận null.
Start/end và limit/period được validate sau merge, không chỉ trên patch rời.
Không nhận `tenantId`, actor hoặc fields ngoài contract từ body.

List hỗ trợ `q` (tên/SKU literal), `tierCode`, `isActive=true|false`, `page`, `limit` (1–100, mặc định 20).
Mặc định gồm cả quà active/inactive và ngoài thời gian mở bán để Admin quản lý; không áp filter catalog học viên.
Sort `createdAt DESC, id DESC`. Tiers/rewards trả camelCase, không trả tenantId.
POST trả 201 `{data:object}`, GET/PATCH trả 200; list reward thêm `meta:{page,limit,total,totalPages}`.

## Audit và kho

- Tạo/sửa ghi REWARD_TIER_CREATED, REWARD_TIER_UPDATED, REWARD_CREATED, REWARD_UPDATED.
- Mutation, audit và inventory movement cùng transaction. Audit lỗi rollback cả stock và movement.
- Tạo quà với stock >0 ghi IN; sửa tồn ghi IN/OUT theo chênh lệch từ row đã khóa. Không ghi movement quantity=0.
- No-op không update timestamp, không tạo audit/movement trùng.
- Khóa row khi sửa quà/tầng; concurrent stock edits được audit theo đúng before/after đã lock.
- Không sửa đơn đổi quà, Marks, ledger hoặc snapshot marks_cost của đơn đã tạo khi đổi giá catalog.

## Lỗi

| HTTP | Code | Trường hợp |
|---|---|---|
| 400 | VALIDATION_ERROR | Field/enum/UUID/số sai, patch trống hoặc thiếu reason |
| 400 | INVALID_TIER_RANGE | maxMarks nhỏ hơn minMarks |
| 400 | INVALID_REWARD_LIMIT / INVALID_REWARD_DATES | Pair hoặc khoảng thời gian không hợp lệ |
| 400 | INVALID_REWARD_TIER / INVALID_REWARD_RANK | Tham chiếu không có trong tenant |
| 401/403 | UNAUTHORIZED / TOKEN_INVALID / FORBIDDEN | Thiếu token hoặc sai role |
| 404 | NOT_FOUND | Object không tồn tại hoặc thuộc tenant khác |
| 409 | TIER_CODE_TAKEN / REWARD_SKU_TAKEN / DUPLICATE | Trùng code/SKU (kể cả race được DB chặn) |

## cURL CMD

```cmd
set "TOKEN=ADMIN_ACCESS_TOKEN"
curl -X POST "http://localhost:4000/api/v1/admin/armory/tiers" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"code\":\"CLUB_GEAR\",\"name\":\"Club Gear\",\"minMarks\":100,\"maxMarks\":500,\"sortOrder\":5}"
curl -X POST "http://localhost:4000/api/v1/admin/armory/rewards" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"sku\":\"HVP-WRAPS-01\",\"name\":\"Bang quan tay HVP\",\"tierCode\":\"CLUB_GEAR\",\"marksCost\":220,\"stock\":10}"
set "REWARD_ID=UUID_TU_RESPONSE"
curl -X PATCH "http://localhost:4000/api/v1/admin/armory/rewards/%REWARD_ID%" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"stock\":15,\"marksCost\":200,\"reason\":\"Nhap them hang va cap nhat gia\"}"
curl -X PATCH "http://localhost:4000/api/v1/admin/armory/tiers/CLUB_GEAR" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"name\":\"Club Gear Updated\",\"reason\":\"Doi ten tang\"}"
curl "http://localhost:4000/api/v1/admin/armory/rewards?isActive=false&page=1&limit=20" -H "Authorization: Bearer %TOKEN%"
curl "http://localhost:4000/api/v1/admin/armory/tiers" -H "Authorization: Bearer %TOKEN%"
```

## Kiểm tra

26 unit tests, 10 integration tests pass trên PostgreSQL tách biệt; lint/build pass.
Typecheck backend và tests liên quan chạy riêng khi workspace còn các test nhân sự chưa track import module staff không có trên nhánh GFT.

```sh
npm run build
npm run lint
npx vitest run --project unit tests/unit/admin-armory.test.ts
npm run test:integration -- tests/integration/admin-armory.test.ts
```
