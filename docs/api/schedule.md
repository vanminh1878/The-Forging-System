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
