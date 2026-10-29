# Lớp học (`classes`)

Vai trò xem [README](README.md). Mọi endpoint yêu cầu đăng nhập; đường dẫn đều bắt đầu bằng `/admin/classes`.

Object lớp học (`ClassRow`):

```json
{
  "id": "0b8f6a52-1d0e-4c0b-9a55-0b6f3a2f6c11",
  "branchId": "6f1c0a52-8d0e-4c0b-9a55-0b6f3a2f6c11",
  "name": "Boxing sáng",
  "sessionTypeCode": "GROUP",
  "courseId": null,
  "defaultCoachId": "a1c0a52-8d0e-4c0b-9a55-0b6f3a2f6c22",
  "weekdays": [1, 3, 5],
  "startTime": "06:30",
  "durationMinutes": 60,
  "capacity": 20,
  "isActive": true
}
```

- `weekdays`: ISO, 1 = Thứ Hai ... 7 = Chủ Nhật. `startTime`: `HH:mm` (giờ địa phương). `capacity = null` nghĩa là không giới hạn sĩ số.
- `sessionTypeCode`: `GROUP`, `PT`, `ACADEMY`, `WORKSHOP`, `SPARRING`.

## GET `/admin/classes`

Danh sách lớp (màn CLS-06). Quyền: **S** (mọi staff).

| Query             | Kiểu            | Mặc định | Ghi chú            |
| ----------------- | --------------- | -------- | ------------------ |
| `branchId`        | uuid            |          | Lọc theo chi nhánh |
| `sessionTypeCode` | string          |          | Lọc theo loại buổi |
| `isActive`        | `true`\|`false` |          | Không gửi = cả hai |
| `page`, `limit`   | int             | 1, 20    | `limit` 1–100      |

```json
{
  "data": [
    {
      "id": "0b8f6a52-...",
      "name": "Boxing sáng",
      "weekdays": [1, 3, 5],
      "startTime": "06:30",
      "capacity": 20,
      "isActive": true,
      "enrolledCount": 12
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 1, "totalPages": 1 }
}
```

Mỗi phần tử là `ClassRow` kèm `enrolledCount` (số học viên đang học). Sắp xếp theo `name`, `startTime`.

| HTTP | code               | message                   |
| ---- | ------------------ | ------------------------- |
| 400  | `VALIDATION_ERROR` | Dữ liệu không hợp lệ      |
| 401  | `UNAUTHORIZED`     | Yêu cầu đăng nhập         |
| 403  | `FORBIDDEN`        | Không đủ quyền (học viên) |

## GET `/admin/classes/:id`

Chi tiết lớp và danh sách học viên. Quyền: **S**.

```json
{
  "data": {
    "id": "0b8f6a52-...",
    "name": "Boxing sáng",
    "weekdays": [1, 3, 5],
    "startTime": "06:30",
    "durationMinutes": 60,
    "capacity": 20,
    "isActive": true,
    "enrolledCount": 1,
    "roster": [
      {
        "enrollmentId": "e1f6a52-...",
        "memberId": "c3d6a52-...",
        "memberCode": "HVP-000123",
        "fullName": "Nguyễn Văn A",
        "membershipId": null,
        "startDate": "2026-10-24",
        "endDate": null
      }
    ]
  }
}
```

`roster` chỉ gồm enrollment đang `ACTIVE`, sắp theo tên.

| HTTP | code        | message           |
| ---- | ----------- | ----------------- |
| 404  | `NOT_FOUND` | Lớp học not found |

## POST `/admin/classes`

Tạo lớp. Quyền: **A**. Trả 201 với `ClassRow`.

| Field             | Kiểu       | Bắt buộc | Giới hạn / mặc định                                                   |
| ----------------- | ---------- | -------- | --------------------------------------------------------------------- |
| `branchId`        | uuid       | có       | Chi nhánh phải đang hoạt động                                         |
| `name`            | string     | có       | 1–120 ký tự                                                           |
| `sessionTypeCode` | string     | có       | Phải tồn tại (và đang bật)                                            |
| `courseId`        | uuid\|null | không    | Mặc định `null`; phải tồn tại                                         |
| `defaultCoachId`  | uuid\|null | không    | Mặc định `null`; user phải có role COACH/HEAD_COACH/ADMIN/SUPER_ADMIN |
| `weekdays`        | int[]      | có       | Mỗi phần tử 1–7, không trùng, ít nhất 1                               |
| `startTime`       | string     | có       | `HH:mm` (00:00–23:59)                                                 |
| `durationMinutes` | int        | có       | 1–1440                                                                |
| `capacity`        | int\|null  | không    | 1–1000; mặc định `null` (không giới hạn)                              |
| `isActive`        | boolean    | không    | Mặc định `true`                                                       |

| HTTP | code                     | message                                         |
| ---- | ------------------------ | ----------------------------------------------- |
| 400  | `VALIDATION_ERROR`       | Dữ liệu không hợp lệ (xem `details`)            |
| 400  | `SESSION_TYPE_NOT_FOUND` | Loại buổi tập không tồn tại                     |
| 400  | `COURSE_NOT_FOUND`       | Khoá học không tồn tại                          |
| 400  | `COACH_INVALID`          | Người dùng được chọn không phải huấn luyện viên |
| 403  | `FORBIDDEN`              | Không đủ quyền                                  |
| 422  | `BRANCH_INACTIVE`        | Chi nhánh không tồn tại hoặc đã ngừng hoạt động |

Ghi audit `CLASS_CREATED`.

## PATCH `/admin/classes/:id`

Sửa lớp. Quyền: **A**. Body là các field như trên, **tất cả tuỳ chọn** nhưng phải gửi ít nhất 1 field (cho phép gửi `null` cho `courseId`, `defaultCoachId`, `capacity` để xoá). Trả 200 với `ClassRow` mới.

- Chỉ kiểm tra lại chi nhánh / loại buổi / khoá học / HLV khi giá trị **thay đổi**; lớp thuộc chi nhánh đã ngừng hoạt động vẫn sửa tên, giờ... được.
- Giảm `capacity` xuống thấp hơn sĩ số hiện tại không bị chặn; chỉ ảnh hưởng lần ghi danh sau.
- Tắt lớp bằng `isActive: false` (không xoá). Lớp tắt không nhận ghi danh mới.

Lỗi như POST, thêm `404 NOT_FOUND` (Lớp học not found). Ghi audit `CLASS_UPDATED` (before/after).

## POST `/admin/classes/:id/enrollments`

Ghi danh học viên vào lớp. Quyền: **FD** (lễ tân + admin). Trả 201.

| Field          | Kiểu               | Bắt buộc | Ghi chú                           |
| -------------- | ------------------ | -------- | --------------------------------- |
| `memberId`     | uuid               | có       | `user_id` của học viên            |
| `startDate`    | `YYYY-MM-DD`       | không    | Mặc định hôm nay                  |
| `endDate`      | `YYYY-MM-DD`\|null | không    | Không được trước `startDate`      |
| `membershipId` | uuid\|null         | không    | Phải là gói của chính học viên đó |

```json
{ "data": { "enrollmentId": "e1f6a52-..." } }
```

| HTTP | code                   | message                                |
| ---- | ---------------------- | -------------------------------------- |
| 400  | `VALIDATION_ERROR`     | Dữ liệu không hợp lệ                   |
| 400  | `BAD_REQUEST`          | Ngày kết thúc phải sau ngày bắt đầu    |
| 400  | `MEMBERSHIP_NOT_FOUND` | Gói tập không thuộc học viên này       |
| 403  | `FORBIDDEN`            | Không đủ quyền                         |
| 404  | `NOT_FOUND`            | Lớp học not found / Học viên not found |
| 409  | `ALREADY_ENROLLED`     | Học viên đã có trong lớp này           |
| 409  | `CLASS_FULL`           | Lớp đã đủ sĩ số                        |
| 422  | `MEMBER_INACTIVE`      | Tài khoản học viên không còn hoạt động |
| 422  | `CLASS_INACTIVE`       | Lớp học đã ngừng hoạt động             |

- `MEMBER_INACTIVE`: học viên `INACTIVE` hoặc tài khoản đã bị gộp (trùng). Học viên `FROZEN` vẫn ghi danh được.
- `CLASS_FULL` chỉ áp dụng khi lớp có `capacity`; đếm các enrollment `ACTIVE`.
- Học viên đã rời lớp (ENDED) có thể ghi danh lại.
- Ghi audit `ROSTER_UPDATED`.

## DELETE `/admin/classes/:id/enrollments/:memberId`

Cho học viên rời lớp. Quyền: **FD**. Không xoá cứng: enrollment chuyển `ENDED`, `endDate` = hôm nay.

Body tuỳ chọn: `{ "reason": "string 1-500" }`. Trả 200 `{ "data": { "ended": true } }`.

| HTTP | code        | message                                                   |
| ---- | ----------- | --------------------------------------------------------- |
| 403  | `FORBIDDEN` | Không đủ quyền                                            |
| 404  | `NOT_FOUND` | Học viên trong lớp not found (không có enrollment ACTIVE) |

Ghi audit `ROSTER_UPDATED` kèm `reason`.

## Sinh buổi tập từ lịch lớp (CLS-02)

Từ `weekdays`, `startTime`, `durationMinutes`, `defaultCoachId` của lớp, hệ thống tạo các buổi (`sessions`) từ **hôm nay** tới **hôm nay + `classes.session_horizon_days`** ngày (mặc định 28, cấu hình 7–90 trong cài đặt hệ thống).

- Job `sessions` chạy hằng ngày 00:10 (giờ `APP_TIMEZONE`); admin chạy tay bằng `POST /admin/batch-jobs/sessions/run` (xem [batch.md](batch.md)). Chạy lặp lại không tạo buổi trùng (khoá duy nhất theo lớp + giờ bắt đầu, bỏ qua buổi đã huỷ).
- Buổi được tạo với `coach` = `defaultCoachId`, `branch`, loại buổi, sĩ số theo lớp, tiêu đề = tên lớp. Giờ lưu UTC: 18:30 giờ địa phương = `11:30Z`.
- Lớp **chưa có coach mặc định** bị bỏ qua (job ghi dòng "Lớp {tên} chưa có coach mặc định — bỏ qua."). Lớp ngừng hoạt động không sinh buổi.
- Giờ bắt đầu đã qua trong hôm nay không được tạo; buổi đã qua không bị đụng tới.
- Tạo lớp mới: sinh buổi ngay. Sửa lớp (đổi `weekdays`, `startTime`, `durationMinutes`, `defaultCoachId`, `isActive`): trong cùng giao dịch, các buổi tương lai `SCHEDULED` không còn khớp lịch mới sẽ **xoá** (chưa ai điểm danh) hoặc chuyển `CANCELLED` (đã có điểm danh; phát sự kiện `SESSION_CANCELLED`). Đổi coach mặc định thì coach của các buổi tương lai còn lại đổi theo. Sau đó sinh buổi còn thiếu. Ghi audit `CLASS_SESSIONS_SYNCED` (`generated`, `deleted`, `cancelled`, `recoached`).
- Ngày nghỉ lễ chưa có: muốn bỏ một buổi lẻ thì huỷ buổi đó (tính năng huỷ buổi làm ở task sau).

## GET `/admin/classes/:id/sessions`

Danh sách buổi của lớp (phục vụ lịch lớp CLS-06/09). Quyền: **S**.

| Query  | Kiểu         | Mặc định          | Ghi chú                     |
| ------ | ------------ | ----------------- | --------------------------- |
| `from` | `YYYY-MM-DD` | hôm nay           | Ngày địa phương, gồm cả ngày này |
| `to`   | `YYYY-MM-DD` | `from` + 28 ngày  | Gồm cả ngày này; tối đa cách `from` 92 ngày |

```json
{
  "data": [
    {
      "id": "7a1c...",
      "classId": "0b8f6a52-...",
      "title": "Boxing tối",
      "startsAt": "2026-03-02T11:30:00.000Z",
      "endsAt": "2026-03-02T12:30:00.000Z",
      "date": "2026-03-02",
      "status": "SCHEDULED",
      "isExam": false,
      "capacity": 15,
      "coach": { "id": "a1c0...", "fullName": "Coach A" },
      "attendeeCount": 0
    }
  ]
}
```

`status`: `SCHEDULED`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`. Sắp xếp theo `startsAt`. `attendeeCount` là số dòng điểm danh của buổi.

| HTTP | code               | message                                |
| ---- | ------------------ | -------------------------------------- |
| 400  | `VALIDATION_ERROR` | Dữ liệu không hợp lệ (ngày sai định dạng) |
| 400  | `INVALID_RANGE`    | Ngày kết thúc phải sau ngày bắt đầu    |
| 400  | `RANGE_TOO_LARGE`  | Khoảng thời gian tối đa 92 ngày        |
| 401  | `UNAUTHORIZED`     | Yêu cầu đăng nhập                      |
| 403  | `FORBIDDEN`        | Không đủ quyền (học viên)              |
| 404  | `NOT_FOUND`        | Lớp học not found                      |

## Ghi chú FE

- Màn danh sách lớp (CLS-06): bảng/thẻ với tên, thứ trong tuần (map 1..7 sang T2..CN), giờ `startTime` + `durationMinutes`, `enrolledCount/capacity` (hiện "∞" nếu `capacity = null`). Bộ lọc chi nhánh, loại buổi, trạng thái. Trạng thái: loading, rỗng ("Chưa có lớp học"), lỗi (thử lại).
- Form tạo/sửa chỉ hiện cho **admin**: chọn chi nhánh từ `GET /branches?includeInactive=false`, chọn nhiều thứ, giờ bắt đầu, thời lượng, sĩ số (tuỳ chọn), HLV (tuỳ chọn). Toast thành công: "Đã tạo lớp" / "Đã cập nhật lớp".
- Chi tiết lớp: hiện roster; nút "Thêm học viên" và "Cho rời lớp" chỉ hiện cho lễ tân và admin. Coach chỉ xem.
- Hiển thị theo `code`: `ALREADY_ENROLLED` ("Học viên đã có trong lớp"), `CLASS_FULL` ("Lớp đã đủ sĩ số"), `MEMBER_INACTIVE` ("Tài khoản học viên đã ngừng hoạt động"). Xác nhận trước khi cho rời lớp, có ô lý do tuỳ chọn.
- Buổi tập được hệ thống tự sinh từ lịch lớp (xem mục "Sinh buổi tập" bên dưới); FE không tạo buổi cho lớp. Sau khi admin sửa lịch/coach/trạng thái lớp, nên tải lại danh sách buổi.
