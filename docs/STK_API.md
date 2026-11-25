# STK-01–09 — Chuỗi tập, Freeze và cảnh báo

## Quy tắc

- Tuần tính **Thứ hai–Chủ nhật** theo `APP_TIMEZONE`; chỉ attendance `CONFIRMED_PASS` có session bắt đầu trong tuần được tính.
- Job `streak-weekly-close` chạy `00:05` mỗi Thứ hai, chốt tuần vừa kết thúc, idempotent theo `(member_id, week_start)` và ghi `streak_logs`.
- Đạt `streak.weekly_min_sessions` thì streak tăng. Thiếu buổi thì tự dùng Freeze còn hạn (nếu có và chưa vượt `streak.max_freeze_per_month`); nếu không có Freeze thì reset về 0.
- Khi streak đạt bội số `streak.freeze_every_weeks`, cấp một Freeze tháng đó; Freeze hết hạn đầu tháng kế tiếp. Mốc DP đọc từ JSON `streak.milestones` (mặc định tuần 4/8/12 là 20/40/80 DP), ghi ledger `STREAK_MILESTONE` idempotent.

## API

```http
GET /api/v1/me/streak
Authorization: Bearer <MEMBER_TOKEN>
```

Response gồm streak hiện tại/cao nhất, tuần hiện tại, số buổi đã xác nhận, target tuần, Freeze còn dùng được, các mốc thưởng `milestones` (`[{ week, dp }]`) được cấu hình từ `streak.milestones`, và 12 `streak_logs` gần nhất. Client dùng `milestones` để hiển thị popup phần thưởng một lần cho mỗi `(weekStart, milestone)` trên từng thiết bị.

## Job vận hành

- Scheduler: bật `ENABLE_SCHEDULER=true`.
- Admin có thể gọi batch job `streak-weekly-close` qua Batch Jobs để chạy bù; job giữ advisory lock theo tenant và log kết quả vào `batch_runs`.
- Job `streak` (tên hiển thị **Cảnh báo sắp mất chuỗi tập**) chạy `09:00` Thứ Bảy theo `APP_TIMEZONE` (`0 9 * * 6`). Job chỉ nhắc Member ACTIVE đang có streak nhưng chưa đạt `streak.weekly_min_sessions`; notification `STREAK_WARNING` được khử trùng lặp theo `streak-warning:<memberId>:<weekStart>`.
