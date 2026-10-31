# Challenge APIs — CHL-01 / CHL-02

## Plan theo task và commit

| Task | Phạm vi | Commit dự kiến | Trạng thái |
|---|---|---|---|
| CHL-01 | Admin tạo/sửa Challenge, list/detail phục vụ form, validation, tenant/RBAC, audit và tests | `feat: CHL-01 admin challenge creation and editing` | Đã triển khai và kiểm thử |
| CHL-02 | Bật/tắt Challenge qua endpoint trạng thái riêng, validation vòng đời, audit và tests | `feat: CHL-02 challenge activation and deactivation` | Đã triển khai và kiểm thử; chưa commit |

Triển khai và kiểm thử từng task riêng. Chỉ commit/push khi người dùng yêu cầu rõ ràng; không tự stage hoặc commit khi được yêu cầu proceed implementation.
Working tree hiện có các thay đổi từ task nhân sự và tài liệu khác; không đưa chúng vào task Challenge.

## Nguồn và kiến trúc

- Nghiệp vụ: `SPEC.md` (HV-19..21, ADM-05/11), SRS về vòng đời Challenge.
- Schema thực tế: `backend/db/migrations/0001_initial_schema.sql`, bảng `challenges` và `challenge_participations`.
- Quy ước: Express router → service → repository; Zod; `handle()` mở tenant transaction; PostgreSQL RLS; `AuditService`.
- Schema hiện dùng `context`, `target`, `reward_dp`, `reward_marks`. CHL-01 không thêm field của DB draft cũ hoặc phần thưởng quà hiện vật.
- Không cần migration mới cho CHL-01: các cột đã có. Không sửa migration đã chạy.

## CHL-01 — API

Base URL `/api/v1`; yêu cầu Bearer token và tenant (header `X-Tenant-Code`, mặc định `hvp`).
Chỉ `ADMIN` / `SUPER_ADMIN` được truy cập.

| Method | Path | Mục đích |
|---|---|---|
| POST | `/admin/challenges` | Tạo Challenge, luôn ở trạng thái DRAFT |
| PATCH | `/admin/challenges/:challengeId` | Sửa field cho phép, yêu cầu reason |
| GET | `/admin/challenges` | List/search/filter/pagination cho màn Admin |
| GET | `/admin/challenges/:challengeId` | Đọc thông tin để mở form chỉnh sửa |

### Tạo Challenge

```json
{
  "code": "CONSISTENCY_OCT_2026",
  "title": "Tay đấm bền bỉ",
  "description": "Hoàn thành điều kiện thử thách và được Coach xác nhận.",
  "challengeType": "MONTHLY",
  "context": "SESSION",
  "target": 3,
  "rewardDp": 100,
  "rewardMarks": 40,
  "startsAt": "2026-10-01T00:00:00+07:00",
  "endsAt": "2026-11-01T00:00:00+07:00"
}
```

| Field | Quy tắc |
|---|---|
| code | Tùy chọn/null; trim, uppercase, 2–64 ký tự A-Z/0-9/_/-, duy nhất trong tenant |
| title | Bắt buộc, trim, 2–150 ký tự |
| description | Tùy chọn/null, tối đa 2.000 ký tự |
| challengeType | DAILY / WEEKLY / MONTHLY / EVENT |
| context | SESSION / WORKSHOP / EXAM, mặc định SESSION |
| target | Integer 1..2147483647, mặc định 1 |
| rewardDp / rewardMarks | Integer 0..2147483647, mặc định 0 |
| startsAt / endsAt | Date-time ISO-8601 có timezone, startsAt < endsAt |

Không nhận `status`, `enabled`, `createdBy`, `tenantId` từ body. Actor và tenant lấy từ request context.
Cho phép lưu draft có thời hạn trong quá khứ để quản trị dữ liệu; việc mở một Challenge hết hạn sẽ được CHL-02 chặn.

Response POST 201, PATCH/GET 200: `{ "data": <ChallengeView> }`.
ChallengeView gồm id, code, title, description, challengeType, context, target, rewardDp, rewardMarks,
startsAt, endsAt, status, createdBy, createdAt, updatedAt. Không trả tenantId.

### Sửa Challenge

```json
{
  "title": "Tay đấm bền bỉ — cập nhật",
  "target": 4,
  "rewardDp": 120,
  "reason": "Điều chỉnh mục tiêu trước khi nhận đăng ký"
}
```

- PATCH có ít nhất một field thay đổi và reason trim 3–500 ký tự.
- Nullable fields có thể xóa bằng null; field khác không nhận null.
- Kiểm tra start/end trên dữ liệu sau merge, không chỉ payload patch.
- Khóa row trước khi đọc/sửa. Challenge CANCELLED không được sửa bằng CHL-01.
- Khi đã có participation: không đổi challengeType, context, target, rewardDp, rewardMarks, startsAt, endsAt.
  Vẫn cho sửa title/description/code. Thay giá trị field về đúng giá trị cũ là no-op hợp lệ.
- Cập nhật không thay trạng thái, không sửa participation, không tăng progress và không phát điểm.
- Tạo/sửa ghi `CHALLENGE_CREATED` / `CHALLENGE_UPDATED`, actor và before/after trong cùng transaction.
- Request không làm thay đổi giá trị không ghi audit trùng.

### List/search

```http
GET /api/v1/admin/challenges?q=boxing&status=DRAFT&challengeType=MONTHLY&context=SESSION&page=1&limit=20
```

`q` tìm literal theo title/code; filter tùy chọn. `limit` 1–100, mặc định 20.
Sort `createdAt DESC, id DESC`.
Response `{ data: [...], meta: { page, limit, total, totalPages } }`.

### Mã lỗi

| HTTP | Code | Tình huống |
|---|---|---|
| 400 | VALIDATION_ERROR | Field sai/thiếu, field không cho phép, patch trống |
| 400 | INVALID_CHALLENGE_DATES | startsAt >= endsAt sau merge |
| 401 | UNAUTHORIZED / TOKEN_INVALID | Thiếu/sai token |
| 403 | FORBIDDEN | Không phải Admin |
| 404 | NOT_FOUND | Không có Challenge trong tenant |
| 409 | CHALLENGE_CODE_TAKEN / DUPLICATE | Code trùng trong tenant |
| 409 | CHALLENGE_CANCELLED | Challenge đã cancel |
| 409 | CHALLENGE_RULES_LOCKED | Sửa điều kiện/phần thưởng/thời gian sau khi có người tham gia |

## CHL-02 — API bật/tắt thử thách

```http
PATCH /api/v1/admin/challenges/:challengeId/status
```

```json
{
  "enabled": true,
  "reason": "Mở thử thách tháng 10"
}
```

- Quyền: `ADMIN` / `SUPER_ADMIN`, cùng tenant của Challenge.
- `enabled` bắt buộc là boolean, không nhận chuỗi `"true"`/`"false"` hay số 0/1.
- `reason` bắt buộc, trim, 3–500 ký tự. Không nhận các field khác trong body.
- Không toggle mù: request xác định trạng thái đích nên retry không đảo trạng thái ngoài ý muốn.

### Chuyển trạng thái

| Trạng thái hiện tại | enabled=true | enabled=false |
|---|---|---|
| DRAFT | OPEN nếu hợp lệ | Giữ DRAFT |
| OPEN | Giữ OPEN nếu còn hợp lệ | CLOSED |
| CLOSED | OPEN nếu hợp lệ | Giữ CLOSED |
| CANCELLED | 409 CHALLENGE_CANCELLED | Giữ CANCELLED |

- Khi bật, kiểm tra `startsAt < endsAt`, `endsAt > serverNow`, `target >= 1` và DP/Marks integer không âm.
- Deadline bằng thời điểm server cũng đã được xem là hết hạn; trả 409 `CHALLENGE_EXPIRED`.
- Có thể publish trước `startsAt`. OPEN là trạng thái publish; task tham gia sau này vẫn phải kiểm tra khung thời gian để cho phép join.
- Request bật OPEN đã hết hạn vẫn bị chặn, không trả thành công vì là no-op.
- Khi tắt, không yêu cầu cấu hình activation còn hợp lệ; Admin vẫn đóng được một OPEN đã hết hạn.
- No-op không đổi `updatedAt`, không ghi audit thay đổi trùng.
- Khóa row trước khi xử lý để serialize request đồng thời; update trạng thái và audit cùng transaction.
- Audit `CHALLENGE_ENABLED` / `CHALLENGE_DISABLED`, ghi actor, before/after và reason.
- Không sửa participation, không đặt hoàn thành, không tăng progress hoặc phát/đảo điểm thưởng.
- Không cần migration mới; `enabled` suy ra từ `status === OPEN`, không lưu thêm cột.

### Response 200

```json
{
  "data": {
    "id": "<challengeId>",
    "title": "Tay đấm bền bỉ",
    "status": "OPEN",
    "enabled": true,
    "startsAt": "2026-09-30T17:00:00.000Z",
    "endsAt": "2026-10-31T17:00:00.000Z",
    "rewardDp": 100,
    "rewardMarks": 40,
    "updatedAt": "<server timestamp>"
  }
}
```

Response thực tế gồm toàn bộ `ChallengeView` như GET/detail và thêm `enabled`.

### Mã lỗi CHL-02

| HTTP | Code | Trường hợp |
|---|---|---|
| 400 | VALIDATION_ERROR | Sai UUID/boolean, thiếu reason hoặc field ngoài contract |
| 400 | INVALID_CHALLENGE_DATES | Khoảng thời gian không hợp lệ |
| 400 | INVALID_CHALLENGE_CONFIG | Cấu hình cũ có target/phần thưởng sai |
| 401/403 | UNAUTHORIZED / TOKEN_INVALID / FORBIDDEN | Chưa đăng nhập hoặc không có quyền |
| 404 | NOT_FOUND | Challenge không tồn tại hoặc thuộc tenant khác |
| 409 | CHALLENGE_CANCELLED | Bật Challenge đã hủy |
| 409 | CHALLENGE_EXPIRED | Bật Challenge đã hết hạn |

## Checklist kiểm thử CHL-01

- Tạo draft có actor/timestamp đúng; default values; nullable fields.
- Patch từng field, partial date merge, no-op và audit before/after.
- Validate enum, số âm/thập phân/quá int32, dates, code, field cấm và payload trống.
- Code trùng tenant bị chặn; tenant khác được dùng cùng code.
- List search literal %, _, pagination/filter.
- Admin/Super Admin được phép; Coach/Head Coach/Lễ tân/Member bị từ chối.
- ID tenant khác trả 404, list không lộ tenant khác; rollback ghi dữ liệu khi audit lỗi.
- Field điều kiện/phần thưởng bị khóa khi có participation; metadata vẫn sửa được.
- `typecheck`, `lint`, `build`, unit tests và integration tests trên database `_test`.

## Chạy kiểm tra

```sh
npm run typecheck
npm run lint
npm run build
npx vitest run --project unit tests/unit/challenges.test.ts
npm run test:integration -- tests/integration/challenges.test.ts
npx vitest run --project unit tests/unit/challenge-status.test.ts
npm run test:integration -- tests/integration/challenge-status.test.ts
```

Kết quả kiểm tra CHL-01: 22 unit tests và 8 integration tests pass; lint/build pass.
Kết quả kiểm tra CHL-02: 24 unit tests và 7 integration tests pass; cả hai task chạy chung đạt 46 unit tests / 15 integration tests. Lint/build pass.
Integration được chạy trên PostgreSQL 18.4 tạm thời ở port 55439, database `hvp_test`, có runtime role không sở hữu bảng để kiểm tra RLS.
Docker Engine hiện không chạy; PostgreSQL 5432 local không chấp nhận credential test mặc định.
Full `npm run typecheck` ở working tree hiện tại bị lỗi từ test nhân sự chưa track còn sót lại từ task trước
(`tests/unit/staff.test.ts` import module staff chưa có). Kiểm tra TypeScript cho phần code và test tương ứng của Challenge thực hiện riêng, không sửa các file task nhân sự.

## cURL — CMD Windows

Đặt token Admin sau khi đăng nhập:

```cmd
set "TOKEN=ADMIN_ACCESS_TOKEN"
```

Tạo draft:

```cmd
curl -X POST "http://localhost:4000/api/v1/admin/challenges" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"code\":\"CONSISTENCY_OCT_2026\",\"title\":\"Tay dam ben bi\",\"challengeType\":\"MONTHLY\",\"context\":\"SESSION\",\"target\":3,\"rewardDp\":100,\"rewardMarks\":40,\"startsAt\":\"2026-10-01T00:00:00+07:00\",\"endsAt\":\"2026-11-01T00:00:00+07:00\"}"
```

Đặt id từ response rồi sửa:

```cmd
set "CHALLENGE_ID=UUID_TU_RESPONSE"
curl -X PATCH "http://localhost:4000/api/v1/admin/challenges/%CHALLENGE_ID%" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"title\":\"Tay dam ben bi - cap nhat\",\"rewardDp\":120,\"reason\":\"Dieu chinh draft truoc khi nhan dang ky\"}"
```

Danh sách và chi tiết:

```cmd
curl "http://localhost:4000/api/v1/admin/challenges?status=DRAFT&page=1&limit=20" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
curl "http://localhost:4000/api/v1/admin/challenges/%CHALLENGE_ID%" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
```

Bật thử thách (CHL-02):

```cmd
curl -X PATCH "http://localhost:4000/api/v1/admin/challenges/%CHALLENGE_ID%/status" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"enabled\":true,\"reason\":\"Mo thu thach thang 10\"}"
```

Tắt thử thách:

```cmd
curl -X PATCH "http://localhost:4000/api/v1/admin/challenges/%CHALLENGE_ID%/status" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"enabled\":false,\"reason\":\"Tam dong thu thach\"}"
```

Deploy Docker sau khi merge task: `docker compose up --build -d api`. CHL-01/02 không yêu cầu migration mới.
