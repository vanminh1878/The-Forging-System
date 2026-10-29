# Lịch học viên (`schedule`)

Vai trò xem [README](README.md). Cả hai endpoint chỉ dành cho **M** (`MEMBER`); coach/lễ tân/admin gọi sẽ nhận 403, chưa đăng nhập nhận 401.

Buổi nào hiện (mọi chi nhánh): buổi của lớp mà học viên đang ghi danh (enrollment không bị huỷ và ngày địa phương của buổi nằm trong `[startDate, endDate]`, `endDate = null` là không giới hạn), cộng buổi mà học viên có dòng điểm danh (thêm lẻ hoặc đã check-in). Buổi bị huỷ vẫn hiện, với `status = CANCELLED`.

Item lịch:

```json
{
  "sessionId": "7a1c...",
  "classId": "0b8f6a52-...",
  "title": "Boxing tối",
  "sessionType": "GROUP",
  "isExam": false,
  "startsAt": "2026-03-04T11:30:00.000Z",
  "endsAt": "2026-03-04T12:30:00.000Z",
  "date": "2026-03-04",
  "isToday": true,
  "branch": { "id": "6f1c...", "name": "HVP Boxing - The Corner" },
  "coach": { "id": "a1c0...", "fullName": "Nguyễn Văn A" },
  "status": "UPCOMING",
  "checkinAt": null,
  "completionPercent": null
}
```

- `date`, `isToday` theo ngày địa phương (`APP_TIMEZONE`). `classId` là `null` với buổi không thuộc lớp (PT, sự kiện).
- `checkinAt`, `completionPercent` chỉ có giá trị khi học viên có dòng điểm danh.

## Trạng thái (`status`)

Thứ tự ưu tiên: (1) buổi `CANCELLED`; (2) có điểm danh thì lấy trạng thái điểm danh; (3) không có điểm danh và đã kết thúc (`endsAt` < bây giờ) thì `ABSENT`; (4) còn lại `UPCOMING`.

| `status`         | Nhãn hiển thị      |
| ---------------- | ------------------ |
| `UPCOMING`       | Sắp tới            |
| `AWAITING_COACH` | Chờ coach xác nhận |
| `CONFIRMED_PASS` | Đạt                |
| `CONFIRMED_FAIL` | Chưa đạt           |
| `ABSENT`         | Vắng mặt           |
| `CANCELLED`      | Đã huỷ             |

## GET `/me/schedule`

| Query      | Kiểu                    | Mặc định | Ghi chú                                        |
| ---------- | ----------------------- | -------- | ---------------------------------------------- |
| `view`     | `week`\|`month`         | `week`   | Tuần Thứ 2 → Chủ nhật; tháng theo lịch         |
| `date`     | `YYYY-MM-DD`            | hôm nay  | Ngày bất kỳ trong tuần/tháng cần xem           |
| `branchId` | uuid                    |          | Không tồn tại thì trả mảng rỗng, không báo lỗi |
| `status`   | một giá trị ở bảng trên |          | Lọc theo trạng thái đã suy ra                  |

```json
{
  "data": [
    {
      "sessionId": "7a1c...",
      "title": "Boxing tối",
      "status": "UPCOMING",
      "...": "..."
    }
  ],
  "meta": { "view": "week", "from": "2026-03-02", "to": "2026-03-08" }
}
```

Sắp xếp theo `startsAt`. Không phân trang (một tuần/tháng).

| HTTP | code               | message                                                            |
| ---- | ------------------ | ------------------------------------------------------------------ |
| 400  | `VALIDATION_ERROR` | Dữ liệu không hợp lệ (`date` sai, `view`/`status` ngoài danh sách) |
| 401  | `UNAUTHORIZED`     | Yêu cầu đăng nhập                                                  |
| 403  | `FORBIDDEN`        | Không đủ quyền (không phải học viên)                               |

## GET `/me/sessions/:sessionId`

Chi tiết một buổi trên lịch của học viên (màn CLS-13). Trả item ở trên cộng:

```json
{
  "lessonPlan": { "id": "9b2e...", "title": "JAB (1)" },
  "notes": "Mang băng tay"
}
```

`lessonPlan` là `null` nếu buổi chưa gắn giáo án; `notes` có thể `null`.

| HTTP | code               | message                                                     |
| ---- | ------------------ | ----------------------------------------------------------- |
| 400  | `VALIDATION_ERROR` | `sessionId` không phải uuid                                 |
| 404  | `NOT_FOUND`        | Buổi tập not found (không có hoặc không thuộc học viên này) |

## Ghi chú FE

- Màn Lịch: mặc định tuần hiện tại; nút trước/sau gửi `date` = ngày bất kỳ của tuần/tháng kế; chuyển tuần/tháng bằng `view`. Dùng `meta.from`/`meta.to` làm tiêu đề.
- Nhóm theo `date`, đánh dấu ngày `isToday`. Hiển thị giờ từ `startsAt` theo giờ máy (đổi sang UTC+7). Chip trạng thái theo bảng nhãn ở trên; `CANCELLED` làm mờ và gạch tên.
- Trạng thái: loading, rỗng ("Chưa có buổi tập trong khoảng này"), lỗi (thử lại). Lớp "open"/Workshop chưa có cờ trong DB nên chưa hiện.
- Học viên mới ghi danh lớp sẽ thấy các buổi đã sinh sẵn của lớp từ ngày bắt đầu ghi danh; lịch dài hơn 28 ngày phụ thuộc cài đặt `classes.session_horizon_days`.
- Mở chi tiết bằng `sessionId`; 404 thì toast "Buổi tập không còn trên lịch của bạn" và quay lại.

# API Coach (CLS-05)

Ba endpoint dành cho **C** (`COACH`) và **HC** (`HEAD_COACH`). Học viên, lễ tân và admin nhận 403, chưa đăng nhập nhận 401. Phạm vi luôn là buổi có `sessions.coach_id` là chính người gọi; trưởng coach cũng chỉ thấy buổi của mình.

## GET `/coach/classes`

Lớp đang hoạt động có `defaultCoachId` là mình, sắp theo tên.

```json
{
  "data": [
    {
      "id": "0b8f6a52-...",
      "name": "Boxing tối",
      "branch": { "id": "6f1c...", "name": "HVP Boxing - The Corner" },
      "sessionType": "GROUP",
      "weekdays": [1, 3, 5],
      "startTime": "18:30",
      "durationMinutes": 60,
      "enrolledCount": 12
    }
  ]
}
```

`weekdays` theo ISO (1 = Thứ 2 ... 7 = CN). `enrolledCount` là số ghi danh đang `ACTIVE`.

## GET `/coach/sessions`

| Query  | Kiểu                | Mặc định   | Ghi chú                                  |
| ------ | ------------------- | ---------- | ---------------------------------------- |
| `view` | `day` hoặc `week`   | `day`      | Tuần chạy Thứ 2 đến Chủ nhật             |
| `date` | `YYYY-MM-DD`        | hôm nay    | Ngày neo, theo múi giờ `APP_TIMEZONE`    |

```json
{
  "data": [
    {
      "sessionId": "7a1c...",
      "classId": "0b8f6a52-...",
      "className": "Boxing tối",
      "title": "Boxing tối",
      "sessionType": "GROUP",
      "isExam": false,
      "status": "SCHEDULED",
      "startsAt": "2026-03-04T11:30:00.000Z",
      "endsAt": "2026-03-04T12:30:00.000Z",
      "date": "2026-03-04",
      "isToday": true,
      "branch": { "id": "6f1c...", "name": "HVP Boxing - The Corner" },
      "lessonPlan": { "id": "c3d2...", "title": "JAB (1)" },
      "counts": { "registered": 12, "checkedIn": 8, "reviewed": 5 }
    }
  ],
  "meta": { "view": "day", "from": "2026-03-04", "to": "2026-03-04" }
}
```

- `status` là trạng thái buổi: `SCHEDULED`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`. `classId`, `className`, `lessonPlan` có thể `null`.
- `counts.registered`: số học viên trong danh sách của buổi. `checkedIn`: số dòng đã có `checkinAt`. `reviewed`: số dòng đã `CONFIRMED_PASS`, `CONFIRMED_FAIL` hoặc `ABSENT`.
- Lỗi: 400 `VALIDATION_ERROR` khi `view` hoặc `date` sai (kể cả ngày không có thật).

## GET `/coach/sessions/:id/roster`

| Query    | Giá trị                          | Mặc định |
| -------- | -------------------------------- | -------- |
| `filter` | `all`, `pending`, `reviewed`     | `all`    |

Danh sách = học viên có dòng điểm danh của buổi, cộng học viên có ghi danh lớp bao phủ ngày địa phương của buổi (cùng điều kiện với lịch học viên). Sắp theo tên.

```json
{
  "data": [
    {
      "memberId": "d41e...",
      "memberCode": "HVP-000123",
      "fullName": "Nguyễn Văn An",
      "avatarUrl": null,
      "rank": { "order": 2, "name": "THE INITIATE" },
      "otherBranch": false,
      "status": "AWAITING_COACH",
      "checkinAt": "2026-03-04T11:25:00.000Z",
      "completionPercent": null,
      "dpAwarded": 0,
      "coachNote": null,
      "academyResult": null
    }
  ],
  "meta": { "counts": { "all": 12, "pending": 7, "reviewed": 5 } }
}
```

- `status`: trạng thái điểm danh; học viên chưa có dòng điểm danh là `UPCOMING`. `pending` = `UPCOMING` hoặc `AWAITING_COACH`; `reviewed` = `CONFIRMED_PASS`, `CONFIRMED_FAIL`, `ABSENT`. `meta.counts` luôn tính trên toàn danh sách, không phụ thuộc `filter`.
- `otherBranch = true` khi chi nhánh nhà của học viên khác chi nhánh của buổi. `rank` là `null` nếu học viên chưa có hạng.

| HTTP | code               | message                                                 |
| ---- | ------------------ | ------------------------------------------------------- |
| 400  | `VALIDATION_ERROR` | `filter` hoặc `id` không hợp lệ                         |
| 401  | `UNAUTHORIZED`     | Yêu cầu đăng nhập                                       |
| 403  | `FORBIDDEN`        | Không đủ quyền (học viên, lễ tân, admin)                |
| 404  | `NOT_FOUND`        | Buổi tập not found (không tồn tại hoặc không phải của mình) |

## Ghi chú FE (Coach)

- Màn "Lịch dạy": tab Ngày / Tuần, nút lùi/tiến theo `meta.from` và `meta.to`; thẻ buổi hiện giờ, tên lớp (hoặc `title`), chi nhánh, nhãn "KIỂM TRA" khi `isExam`, và `checkedIn/registered`, `reviewed/registered`. Buổi `CANCELLED` làm mờ. Rỗng: "Không có buổi nào". Lỗi: nút thử lại.
- Màn danh sách học viên của buổi: tab Tất cả / Chưa xác nhận / Đã xác nhận lấy số từ `meta.counts`. Học viên có `otherBranch` hiện nhãn "Chi nhánh khác". Buổi của coach khác trả 404, hiện "Không tìm thấy buổi tập".
- Chỉ coach và trưởng coach dùng nhóm API này; admin xem lớp qua `/admin/classes`.
