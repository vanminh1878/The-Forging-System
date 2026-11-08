# CHL — Challenge APIs và tiến độ tự động

Base URL: `/api/v1`. Các API member yêu cầu Bearer token, tenant header và role `MEMBER`.

## Workflow Challenge — cấu hình theo từng Challenge

`challengeType` (`DAILY`, `WEEKLY`, `MONTHLY`, `EVENT`) chỉ mô tả chu kỳ, **không quyết định workflow**. Không được áp một state machine toàn cục cho mọi Challenge.

Mỗi Challenge phải khai báo hai cấu hình workflow độc lập:

```text
joinApproval: AUTO | COACH
completionMethod: ATTENDANCE | EVIDENCE
```

| Cấu hình | Luồng bắt buộc |
|---|---|
| `AUTO` + `ATTENDANCE` | Member join → `JOINED` → attendance hợp lệ tăng `progressValue` → đạt `target` thành `AWAITING_COACH` → nộp evidence (nếu Challenge yêu cầu) → Coach duyệt reward → `REWARDED`. |
| `COACH` + `EVIDENCE` | Member đăng ký → `PENDING_COACH` → Coach duyệt tham gia → `JOINED` → member **Yêu cầu hoàn thành** và upload evidence → `AWAITING_COACH` → Coach xác nhận/phát thưởng → `REWARDED`. |
| `AUTO` + `EVIDENCE` | Member join → `JOINED` → member Yêu cầu hoàn thành + evidence → `AWAITING_COACH` → Coach xác nhận/phát thưởng. |
| `COACH` + `ATTENDANCE` | Member đăng ký → `PENDING_COACH` → Coach duyệt tham gia → attendance hợp lệ tăng tiến độ theo `target` → flow review/reward. |

`PENDING_COACH` chỉ xuất hiện khi `joinApproval=COACH`. `AWAITING_COACH` luôn nghĩa là đang chờ Coach xác nhận **hoàn thành/reward**, không được dùng để diễn tả chờ duyệt đăng ký.

### Bắt buộc khi bổ sung workflow mới

Mọi API/UI/migration Challenge phải nhận và tôn trọng `joinApproval` cùng `completionMethod`. Definition of Done phải có test cho từng tổ hợp workflow được hỗ trợ; không được test một flow rồi suy diễn là áp dụng cho toàn bộ Challenge.

## CHL-01: Quản trị Challenge

Chỉ `ADMIN` / `SUPER_ADMIN`.

| Method | Path | Mục đích |
|---|---|---|
| POST | `/admin/challenges` | Tạo Challenge ở `DRAFT` |
| PATCH | `/admin/challenges/:challengeId` | Sửa Challenge, yêu cầu `reason` |
| GET | `/admin/challenges` | Danh sách/search/filter/phân trang |
| GET | `/admin/challenges/:challengeId` | Chi tiết Challenge |
| PATCH | `/admin/challenges/:challengeId/status` | Mở/đóng Challenge, yêu cầu `enabled` và `reason` |

Challenge dùng `code`, `title`, `description`, `challengeType`, `context`, `target`, `rewardDp`, `rewardMarks`, `startsAt`, `endsAt`, `joinApproval` và `completionMethod`. `status`, actor và tenant luôn do server quản lý. Khi đã có participation, không thể sửa điều kiện, workflow, phần thưởng hoặc thời hạn; chỉ được sửa metadata. Các mutation ghi audit `CHALLENGE_CREATED` / `CHALLENGE_UPDATED`.

## CHL-02: Mở/đóng Challenge

```http
PATCH /api/v1/admin/challenges/:challengeId/status
```

```json
{ "enabled": true, "reason": "Mở thử thách tháng 10" }
```

`enabled=true` chuyển `DRAFT` hoặc `CLOSED` sang `OPEN` khi Challenge hợp lệ và chưa hết hạn; `enabled=false` chuyển `OPEN` sang `CLOSED`. `CANCELLED` không thể mở lại. `enabled` là field suy ra từ `status === OPEN`, không có cột riêng. Mutation ghi audit `CHALLENGE_ENABLED` / `CHALLENGE_DISABLED`.

## CHL-03: Danh sách Challenge đang mở

| Method | Path |
|---|---|
| GET | `/me/challenges` |
| GET | `/me/challenges/open` |
| GET | `/challenges` |
| GET | `/challenges/open` |

Query tùy chọn: `period` hoặc `challengeType` (`DAILY`, `WEEKLY`, `MONTHLY`, `EVENT`), `context` (`SESSION`, `WORKSHOP`, `EXAM`), `q`, `page` và `limit` (mặc định 20, tối đa 100).

Chỉ trả Challenge `OPEN`, chưa hết hạn; sắp xếp `endsAt ASC, id DESC`. Mỗi row bao gồm Challenge cùng `participationId`, `participationStatus`, `progressValue`, `joinedAt` và `evidenceUrl` nếu member đã tham gia. Response list dùng `{ data, meta }` với `page`, `limit`, `total`, `totalPages`.

## CHL-04: Tham gia Challenge

| Method | Path |
|---|---|
| POST | `/me/challenges/:challengeId/join` |
| POST | `/challenges/:challengeId/join` |

Không có request body. Challenge phải tồn tại, `OPEN`, trong thời gian `[startsAt, endsAt)` và member chưa tham gia. Thành công trả `201` participation có `status: PENDING_COACH` khi `joinApproval=COACH`, hoặc `JOINED` khi `joinApproval=AUTO`; `progressValue: 0`. Join được audit `CHALLENGE_JOINED`; notification recipient phụ thuộc workflow (Coach cần được báo khi có registration chờ duyệt). Không phát DP/Marks.

| HTTP | Code | Tình huống |
|---|---|---|
| 400 | `VALIDATION_ERROR` | `challengeId` không phải UUID |
| 409 | `CHALLENGE_NOT_OPEN` | Challenge chưa mở/đã đóng |
| 409 | `CHALLENGE_CLOSED` | Chưa bắt đầu hoặc đã hết hạn |
| 409 | `CHALLENGE_ALREADY_JOINED` | Member đã tham gia |

## CHL-05: Duyệt tham gia

```http
POST /api/v1/staff/challenges/participations/:participationId/approve-join
```

Endpoint này chỉ hợp lệ khi `joinApproval=COACH`. Coach/Head Coach/Admin chỉ duyệt participation `PENDING_COACH`. Thành công chuyển `PENDING_COACH → JOINED`, ghi audit `CHALLENGE_JOIN_APPROVED` và gửi `CHALLENGE_JOIN_APPROVED` tới học viên. Khi đó học viên mới có CTA/tiến độ tương ứng với `completionMethod`.

Với `completionMethod=ATTENDANCE`, attendance là điều kiện tăng tiến độ và phải emit `ATTENDANCE_CONFIRMED`. Với `completionMethod=EVIDENCE`, attendance không được chặn CTA **Yêu cầu hoàn thành**.

## CHL-06: Nộp bằng chứng và Coach duyệt

| Method | Path | Quyền |
|---|---|---|
| POST | `/me/challenges/:challengeId/evidence` | MEMBER |
| GET | `/staff/challenges/participations` | COACH, HEAD_COACH, ADMIN, SUPER_ADMIN |
| POST | `/staff/challenges/participations/:participationId/approve` | COACH, HEAD_COACH, ADMIN, SUPER_ADMIN |

Nộp bằng chứng:

```json
{ "evidenceUrl": "http://localhost:4000/files/challenges/proof.jpg" }
```

- Chỉ participation của chính member, đang `JOINED`, mới được gửi yêu cầu hoàn thành kèm evidence khi `completionMethod=EVIDENCE` (hoặc khi flow attendance yêu cầu bằng chứng bổ sung).
- URL phải là file đã tải qua hệ thống, dưới `${PUBLIC_BASE_URL}/files/`.
- Gửi evidence chuyển `JOINED → AWAITING_COACH`. Coach chỉ duyệt participation `AWAITING_COACH` đã có bằng chứng. Duyệt lặp trả `duplicate: true`.
- Duyệt chuyển `AWAITING_COACH → REWARDED`, ghi Coach/thời điểm và phát reward snapshot `rewardDp`/`rewardMarks` qua ledger với idempotency key theo participation.
- Khi member đã đạt `challenge.monthly_reward_limit` trong tháng, participation vẫn `REWARDED` nhưng `isLimited=true` và không phát DP/Marks.
- Audit: `CHALLENGE_EVIDENCE_SUBMITTED`, `CHALLENGE_APPROVED` hoặc `CHALLENGE_APPROVED_LIMITED`.
- Ngay sau khi evidence được lưu, backend ghi notification role `COACH` với event `CHALLENGE_EVIDENCE`; Coach duyệt tại tab Challenge.
- Khi Coach duyệt, member nhận notification `CHALLENGE_REWARDED`, kể cả khi đã chạm giới hạn thưởng tháng.

Hàng chờ duyệt của Coach:

```http
GET /api/v1/staff/challenges/participations?status=AWAITING_COACH&evidence=SUBMITTED&page=1&limit=100
```

- Query tùy chọn: `status` (`JOINED`, `AWAITING_COACH`, `REWARDED`, `EXPIRED`), `evidence` (`SUBMITTED`, `PENDING`), `q` (tên/mã học viên hoặc tên Challenge), `page`, `limit`.
- Kết quả sắp `AWAITING_COACH` trước, sau đó theo `completedAt` tăng dần. Mỗi row có `id` (participationId), `challengeTitle`, `challengeType`, `target`, `memberCode`, `memberFullName`, `progressValue`, `evidenceUrl`, `status`.

UI:

- Member: thẻ Challenge chưa tham gia có nút **Tham gia thử thách**; sau Coach duyệt tham gia (`JOINED`), thẻ hiện **Yêu cầu hoàn thành** để upload evidence. Nộp evidence chuyển sang `AWAITING_COACH`.
- Coach: tab **Challenge** tại `/coach/challenge` hỗ trợ tìm kiếm, lọc status/evidence, phân trang; có **Duyệt tham gia** cho `PENDING_COACH` và **Duyệt và phát thưởng** cho `AWAITING_COACH` có evidence.

Mã nguồn:

- `mobile/lib/features/challenges/presentation/current_challenges_screen.dart`
- `mobile/lib/features/coach_challenges/domain/challenge_review.dart`
- `mobile/lib/features/coach_challenges/data/challenge_review_repository.dart`
- `mobile/lib/features/coach_challenges/presentation/challenge_review_tab.dart`

## Kiểm tra

```sh
npm run typecheck
npm run lint
npm run build
npm test
```

## CHL-09: Danh sách thử thách học viên

Màn **Thử thách** tại `/student/challenges` hiển thị Challenge đang mở qua `GET /api/v1/me/challenges`.

- Lọc tất cả, hằng ngày, hằng tuần, hằng tháng và sự kiện.
- Hiển thị mục tiêu, phần thưởng DP/Marks, thời điểm kết thúc và trạng thái tham gia.
- Hỗ trợ pull-to-refresh, retry và phân trang.
- Card chưa tham gia hiện CTA **Tham gia thử thách** gọi CHL-04; sau thành công danh sách được refresh.

Mã nguồn:

- `mobile/lib/features/challenges/domain/open_challenge.dart`
- `mobile/lib/features/challenges/data/open_challenge_repository.dart`
- `mobile/lib/features/challenges/presentation/open_challenge_providers.dart`
- `mobile/lib/features/challenges/presentation/open_challenges_screen.dart`

## CHL-10: Thẻ thử thách hiện tại

Màn **Thử thách** tại `/student/challenges` hiển thị các Challenge đã tham gia, lấy từ `GET /api/v1/me/challenges` với `participationId`.

- Hiển thị loại/trạng thái, tiến độ `progressValue / target`, hạn kết thúc và phần thưởng DP/Marks.
- Challenge `PENDING_COACH` hiển thị chờ Coach duyệt; Challenge `JOINED` có nút **Yêu cầu hoàn thành** (CHL-06); `AWAITING_COACH` hiển thị chờ Coach xác nhận hoàn thành.
- Có trạng thái rỗng, retry và kéo để làm mới.
- Chỉ theo dõi tiến độ; tham gia thuộc CHL-04 và tăng progress thuộc CHL-05.

Mã nguồn:

- `mobile/lib/features/challenges/domain/current_challenge.dart`
- `mobile/lib/features/challenges/data/current_challenge_repository.dart`
- `mobile/lib/features/challenges/presentation/current_challenge_providers.dart`
- `mobile/lib/features/challenges/presentation/current_challenges_screen.dart`

## Notification contract và Definition of Done

Mọi mutation Challenge mới hoặc thay đổi phải cập nhật cùng lúc backend event, recipient, mobile route và test. Không được chỉ thêm event constant hoặc UI mà không có trigger thật.

| Action | Audit | Notification | Recipient | Khi mở notification |
|---|---|---|---|---|
| Member đăng ký | `CHALLENGE_JOINED` | `CHALLENGE_JOINED` | Member thực hiện đăng ký; inbox role Coach | `/student/challenges/current`; Coach queue |
| Coach duyệt tham gia | `CHALLENGE_JOIN_APPROVED` | `CHALLENGE_JOIN_APPROVED` | Member | `/student/challenges/current` |
| Member yêu cầu hoàn thành/evidence | `CHALLENGE_EVIDENCE_SUBMITTED` | `CHALLENGE_EVIDENCE` | Inbox role `COACH` | Queue `/coach/challenge`; mobile staff inbox/push chưa có |
| Coach duyệt reward | `CHALLENGE_APPROVED` / `_LIMITED` | `CHALLENGE_REWARDED` | Member | `/student/challenges/current` |
| Admin mở/đóng Challenge | `CHALLENGE_ENABLED` / `_DISABLED` | Chưa gửi | Không áp dụng | Không áp dụng |

Thông báo mở/đóng Challenge **không được tự ý broadcast**: cần product decision về audience (toàn bộ member, theo branch, hay chỉ participant) và backend query/notification primitive tương ứng. Khi được chốt, implementation phải bổ sung một hàng trong bảng trên, route mobile và test recipient/deduplication.

`GET /staff/notifications` và `POST /staff/notifications/read-all` đã tồn tại ở backend, nhưng mobile hiện chưa có staff inbox/bell hoặc push delivery theo role. Đây là phạm vi bắt buộc phải hoàn thiện trước khi coi `CHALLENGE_EVIDENCE` là notification hiển thị chủ động cho Coach; hiện event vẫn được lưu đúng role và queue Challenge đã là nơi xử lý tương ứng.
