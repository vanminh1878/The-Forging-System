# CHL-02 & GFT-01 — Đặc tả API và kế hoạch triển khai

**Trạng thái:** đề xuất trước triển khai, chưa phải API đã hoạt động.  
**Phạm vi:** Phase 1 / W1, ngày 12/10–18/10.  
**Ngày lập:** 17/10/2026.

## 1. Task và phạm vi

| Task | Yêu cầu | Kết quả dự kiến |
|---|---|---|
| CHL-02 | API bật/tắt thử thách | Admin mở/đóng Challenge; kiểm tra vòng đời, thời hạn, audit và tenant |
| GFT-01 | API Admin tạo/sửa quà và tầng | Admin tạo/cập nhật reward, reward tier; API đọc danh sách/chi tiết phục vụ form quản trị |

Không mở rộng CHL-02 thành toàn bộ Challenge CRUD. API tạo Challenge thuộc task khác; kiểm thử CHL-02 dùng fixture Challenge trong database test.

Luồng tham gia Challenge, nộp minh chứng, Coach xác nhận, phát DP/Marks thuộc các task tiếp theo. Bật Challenge không có nghĩa là hoàn thành Challenge và không tự phát thưởng.

GFT-01 không bao gồm tạo đơn đổi quà, xác nhận giao quà, hoàn Marks hoặc màn Flutter. Dữ liệu quà/tầng cần được cung cấp cho những luồng đó khi triển khai sau.

## 2. Nhánh và hiện trạng workspace

- Nhánh checkout tại thời điểm khảo sát: `main`, tracking `origin/main`.
- Có nhánh local `feat/STF-01-staff-apis`, commit `1422554`, chứa API phân quyền/nhân sự.
- Sau `git fetch origin`, remote chưa có `refs/heads/feat/STF-01-staff-apis`; cần xác nhận nhánh target trước bước sửa backend.
- Có thay đổi local và file chưa track. Không reset, xóa, stash hoặc chuyển nhánh tự động trong bước lập tài liệu này.
- Tài liệu được tạo trong working tree hiện tại; khi triển khai, dùng nhánh task đã xác nhận, có nền code phân quyền phù hợp.

## 3. Nguồn và khác biệt schema

### 3.1 Nguồn yêu cầu

- `SPEC.md`: HV-19..24, ADM-05, ADM-06, ADM-11.
- `SRS.docx`: nghiệp vụ Challenge, Armory, cấu hình và audit; luồng Coach xác nhận Challenge đã được người dùng làm rõ trong phiên làm việc.
- `HVP_Database_Design.md`, `hvp_schema.sql`: thiết kế tham khảo bản draft.
- `backend/db/migrations/0001_initial_schema.sql`: schema v3 thực tế của backend.
- `docs/FEATURE_MAP.md`, source `shared/roles.ts`, `db/database.ts`, `common/http/handler.ts`: ranh giới module, RLS và transaction.

### 3.2 Định hướng triển khai theo schema runtime

| Nội dung | DB draft bên ngoài repo | Backend v3 đang dùng |
|---|---|---|
| Tính giá quà | Cost VNĐ, coefficient, published Marks | Nhập `marks_cost` trực tiếp |
| Kho | `stock_on_hand`, `stock_reserved` | Một cột `stock` |
| Tầng quà | Catalogue theo code | PK `(tenant_id, code)` |
| Challenge | Điều kiện/tham số tổng quát | `context`, `target`, `reward_dp`, `reward_marks` |
| Coach xác nhận Challenge | Mô tả cũ khác trạng thái | Participation `AWAITING_COACH` → `REWARDED` |

Kế hoạch này đề xuất dùng schema v3 hiện hành. Không thêm lại cost/coefficient/reserved stock từ bản draft vào GFT-01. Nếu cần khôi phục các field đó thì phải chốt lại phạm vi và có migration riêng trước khi code.

## 4. Quy ước chung

- Base URL: `/api/v1`.
- Headers: `Authorization: Bearer <token>`, `X-Tenant-Code: hvp`.
- Quyền: `ADMIN`, `SUPER_ADMIN` qua `RoleGroup.ADMINS`; Coach/Lễ tân/Học viên không được ghi các API quản trị này.
- Response thành công: `{ "data": ... }`; list thêm `meta`.
- Phân trang theo code hiện có: `page`, `limit` (mặc định 20, tối đa 100), không dùng `pageSize`.
- Date-time ISO-8601 có timezone; thời điểm đánh giá lấy từ server/`clock`.
- Validate Zod ở route, nghiệp vụ trong service, SQL trong repository.
- Mỗi mutation và audit chạy cùng `handle()` / `db.tenantTx()`; lỗi phải rollback cả hai.
- Không hard-delete business row hoặc sửa/xóa audit.
- ID không thuộc tenant hiện tại xử lý như không tồn tại, không tiết lộ dữ liệu tenant khác.

## 5. CHL-02 — Bật/tắt Challenge

### 5.1 Endpoint dự kiến

```http
PATCH /api/v1/admin/challenges/:challengeId/status
```

```json
{
  "enabled": true,
  "reason": "Mở thử thách tháng 10"
}
```

- `challengeId`: UUID hợp lệ.
- `enabled`: boolean bắt buộc, không nhận chuỗi `"true"`.
- `reason`: bắt buộc, trim, 3–500 ký tự.
- Không dùng toggle mù: request chỉ rõ trạng thái đích để tránh click lặp làm đảo trạng thái ngoài ý muốn.

### 5.2 State machine đề xuất

Schema không có `is_active` cho Challenge. Ánh xạ `enabled` vào `status` hiện có:

| Trạng thái hiện tại | enabled=true | enabled=false |
|---|---|---|
| DRAFT | OPEN nếu cấu hình/thời hạn hợp lệ | Giữ DRAFT, không publish |
| OPEN | Giữ OPEN | CLOSED |
| CLOSED | OPEN nếu chưa hết hạn | Giữ CLOSED |
| CANCELLED | Chặn 409 | Giữ CANCELLED |

Quy ước `CLOSED` ở endpoint này là ngừng mở cho tham gia; được phép mở lại trước deadline. `CANCELLED` là kết thúc không thể mở lại bằng CHL-02. Đây là quyết định thiết kế đề xuất, cần giữ nhất quán ở các task Challenge sau.

### 5.3 Validation và tác động

- Khóa row Challenge trước khi đọc trạng thái và cập nhật (`FOR UPDATE`).
- Khi bật: `starts_at < ends_at`, `target > 0`, phần thưởng không âm, `ends_at > serverNow`.
- Cho phép publish trước `starts_at`. `OPEN` là đã publish; quyền tham gia sau này vẫn phải kiểm tra `starts_at <= now < ends_at`.
- Tắt không tự đổi participation đã có, không xóa minh chứng, không đảo giao dịch thưởng.
- Chính sách hoàn tất/xác nhận participation khi Challenge đã đóng phải được xử lý ở task Coach confirmation; CHL-02 không tự quyết định kết quả học viên.
- Request cùng trạng thái trả 200/no-op, không ghi thêm audit thay đổi.
- Khi có thay đổi: cập nhật `status`, `updated_at`, ghi `CHALLENGE_ENABLED` hoặc `CHALLENGE_DISABLED` với actor, before/after và reason.

### 5.4 Response mẫu

```json
{
  "data": {
    "id": "<challenge-uuid>",
    "title": "Tay đấm bền bỉ",
    "status": "OPEN",
    "enabled": true,
    "startsAt": "2026-10-01T00:00:00+07:00",
    "endsAt": "2026-11-01T00:00:00+07:00",
    "updatedAt": "<server timestamp>"
  }
}
```

`enabled` là field API suy ra từ `status === OPEN`, không phải cột mới.

## 6. GFT-01 — Quà và tầng Armory

### 6.1 Endpoints dự kiến

| Method | Path | Chức năng |
|---|---|---|
| GET | `/admin/armory/tiers` | Danh sách tầng theo `sortOrder`, `code` |
| GET | `/admin/armory/tiers/:tierCode` | Chi tiết tầng |
| POST | `/admin/armory/tiers` | Tạo tầng |
| PATCH | `/admin/armory/tiers/:tierCode` | Sửa tầng |
| GET | `/admin/armory/rewards` | List quà, search, filter, phân trang |
| GET | `/admin/armory/rewards/:rewardId` | Chi tiết quà cho popup sửa |
| POST | `/admin/armory/rewards` | Tạo quà |
| PATCH | `/admin/armory/rewards/:rewardId` | Sửa quà / giá Marks / tồn / trạng thái |

Không có DELETE trong task này. Dừng quà qua `isActive=false`. Schema tầng chưa có `is_active`, nên không thêm API vô hiệu hóa tầng trong GFT-01.

### 6.2 Tạo tầng

```json
{
  "code": "TRAINING_GEAR",
  "name": "Training Gear",
  "minMarks": 200,
  "maxMarks": 400,
  "sortOrder": 2
}
```

- `code`: mã uppercase `[A-Z0-9_]`, 2–50 ký tự, duy nhất trong tenant và bất biến sau tạo.
- `name`: trim, 2–100 ký tự.
- `minMarks`: integer >= 0.
- `maxMarks`: null hoặc integer >= minMarks; null biểu diễn không giới hạn trên.
- `sortOrder`: integer >= 0, trong giới hạn smallint của DB (<=32767).
- PATCH nhận field thay đổi và `reason` 3–500 ký tự; kiểm tra cặp min/max trên dữ liệu sau merge.
- Chưa áp ràng buộc bắt buộc giá quà phải nằm trong khoảng tầng: schema hiện tại không enforce và dữ liệu demo cần được đối chiếu trước khi thêm chính sách này.
- Không ép các tầng phải phủ liên tục hoặc không trùng khoảng khi SRS chưa chốt quy tắc đó.

### 6.3 Tạo quà

```json
{
  "sku": "HVP-WRAPS-01",
  "name": "Băng quấn tay HVP",
  "description": "Băng quấn tay dùng cho tập luyện",
  "imageUrl": null,
  "tierCode": "TRAINING_GEAR",
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
| sku | Bắt buộc, trim, 2–80 ký tự, duy nhất trong tenant; đề xuất bất biến sau tạo |
| name | Bắt buộc, trim, 2–150 ký tự |
| description | Tùy chọn/null, tối đa 2.000 ký tự |
| imageUrl | Tùy chọn/null, URL HTTP(S) hợp lệ |
| tierCode | Tùy chọn/null; nếu có phải thuộc tenant hiện tại |
| marksCost | Integer > 0 |
| stock | Integer >= 0, mặc định 0 |
| perMemberLimit | Null hoặc integer > 0 |
| limitPeriod | MONTH / YEAR / LIFETIME hoặc null; phải đi cùng perMemberLimit |
| minRankId | UUID hoặc null; phải tồn tại trong tenant hiện tại |
| pickupDays | Null hoặc integer > 0, <=32767 |
| saleStartsAt / saleEndsAt | ISO time hoặc null; nếu có cả hai thì start < end |
| isActive | Boolean, mặc định true |

PATCH chỉ nhận field cho phép sửa và `reason` bắt buộc. Field nullable có thể được xóa bằng null. Không cho body trống hoặc chỉ có reason.

### 6.4 Tồn kho và concurrency

- Kho là dữ liệu chung theo tenant, không tách stock theo chi nhánh nhận hàng.
- Sửa tồn trong GFT-01 dùng giá trị đích `stock`; khóa reward row trước khi tính delta để tránh lost update.
- Audit lưu before/after. Delta khác 0 ghi `inventory_movements` cùng transaction:
  - Delta dương → `IN`, quantity = delta.
  - Delta âm → `OUT`, quantity = abs(delta).
- Tạo quà với stock > 0 cũng ghi movement nhập kho ban đầu.
- Không trừ/cộng Marks hoặc sửa trạng thái redemption khi cập nhật quà.
- Đơn đổi quà đã có giữ `marks_cost` snapshot của đơn; thay giá catalog không sửa lịch sử.

### 6.5 List quà

```http
GET /api/v1/admin/armory/rewards?q=HVP&tierCode=TRAINING_GEAR&isActive=true&page=1&limit=20
```

- Search theo tên hoặc SKU, không phân biệt hoa/thường.
- `isActive` phải parse đúng `true`/`false`; không dùng coercion khiến chuỗi `false` thành true.
- Trả field camelCase theo schema runtime, thêm tên tầng để render list nếu cần.
- Mặc định bao gồm cả active/inactive cho màn Admin; chỉ filter khi query truyền vào.
- Response 200 `{data:[...],meta:{page,limit,total,totalPages}}`.
- POST quà/tầng trả 201 `{data:...}`; PATCH trả 200 `{data:...}`.

## 7. Audit và lỗi

Actions dự kiến:

- `CHALLENGE_ENABLED`, `CHALLENGE_DISABLED`.
- `REWARD_TIER_CREATED`, `REWARD_TIER_UPDATED`.
- `REWARD_CREATED`, `REWARD_UPDATED`; inventory movement khi có đổi stock.

Mỗi audit có actor, entityType, entityId, before/after, reason, server timestamp. Tầng dùng `code` làm định danh nghiệp vụ, tương thích `audit_logs.entity_id` kiểu text của backend hiện hành.

| HTTP | Code dự kiến | Trường hợp |
|---|---|---|
| 400 | VALIDATION_ERROR / BAD_REQUEST | UUID, field, ngày, boolean hoặc khoảng số không hợp lệ |
| 401 | UNAUTHORIZED / TOKEN_INVALID | Chưa đăng nhập hoặc token không hợp lệ |
| 403 | FORBIDDEN | Không có quyền quản trị |
| 404 | NOT_FOUND | Không có object trong tenant |
| 409 | CHALLENGE_CANCELLED | Bật lại Challenge đã cancel |
| 409 | CHALLENGE_EXPIRED | Bật Challenge đã hết hạn |
| 409 | DUPLICATE / SKU_TAKEN / TIER_CODE_TAKEN | Trùng SKU hoặc tier code |
| 400 | INVALID_TIER / INVALID_RANK | Tham chiếu không hợp lệ hoặc thuộc tenant khác |

## 8. Cấu trúc code dự kiến

```text
backend/src/modules/challenges/
  challenge.routes.ts
  challenge.service.ts
  challenge.repository.ts
  challenge.validation.ts

backend/src/modules/armory/
  armory.routes.ts
  armory.service.ts
  armory.repository.ts
  armory.validation.ts

backend/tests/integration/
  challenges.test.ts
  armory.test.ts
```

Wire ở `src/container.ts` theo pattern hiện có; dùng `AuditService`, `clock`, `sql`, `handle`, `requireAuth`, `requireRoles`.

Không dự kiến migration chỉ để bật/tắt Challenge hoặc tạo/sửa quà/tầng vì các cột đã có. Chỉ thêm migration nếu phát hiện ràng buộc thiếu cần thiết khi kiểm thử; không sửa migration đã áp dụng.

## 9. Acceptance tests trước khi hoàn tất

### CHL-02

1. Admin bật DRAFT → OPEN; tắt OPEN → CLOSED; mở lại CLOSED trước deadline.
2. Bật trước startsAt được phép publish nhưng không tự tham gia/phát thưởng.
3. Challenge hết hạn hoặc cancel không bật lại được.
4. Request lặp cùng trạng thái không đảo trạng thái hoặc tạo audit thay đổi trùng.
5. Không sửa participation, progress hoặc ledger khi bật/tắt.
6. Thiếu reason/sai boolean/sai UUID trả 400.
7. Coach, Lễ tân, Học viên trả 403; tenant khác trả 404.
8. Audit và status rollback cùng nhau khi transaction lỗi.

### GFT-01

1. Tạo/sửa/list/detail tầng; trùng code bị chặn; validate min/max sau patch.
2. Tạo/sửa/list/detail quà; giá Marks >0, stock không âm, SKU duy nhất.
3. Validate rank/tier trong tenant; không chấp nhận foreign ID khác tenant.
4. List filter isActive=false đúng; search và pagination đúng tổng.
5. Sửa stock ghi delta movement và audit trong cùng transaction; không có movement quantity=0.
6. Đổi giá catalog không sửa marks_cost snapshot của đơn cũ.
7. Dừng quà bằng isActive=false, không hard-delete lịch sử.
8. Các role không phải Admin bị chặn ghi; API không lộ dữ liệu tenant khác.

### Lệnh kiểm tra

```sh
npm run typecheck
npm run lint
npm run build
npm test
npm run test:integration -- tests/integration/challenges.test.ts tests/integration/armory.test.ts
```

Integration tests dùng database tên kết thúc `_test`, không dùng database demo/production. Hoàn tất tài liệu API thực tế và cURL sau khi implementation/test pass.

## 10. Trình tự tiếp theo

1. Xác nhận nhánh target và cách giữ các thay đổi local hiện có.
2. Chốt semantics CHL-02: enabled → OPEN/CLOSED, cho phép mở lại CLOSED trước deadline.
3. Triển khai CHL-02 và tests.
4. Triển khai GFT-01 cho tầng, quà, tồn kho và tests.
5. Chạy kiểm tra, cập nhật tài liệu API thực tế; chỉ commit/push khi được yêu cầu.
