# STK-01–05 — Chuỗi tập và Streak Freeze

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

Response gồm streak hiện tại/cao nhất, tuần hiện tại, số buổi đã xác nhận, target tuần, Freeze còn dùng được và 12 `streak_logs` gần nhất.

## Job vận hành

- Scheduler: bật `ENABLE_SCHEDULER=true`.
- Admin có thể gọi batch job `streak-weekly-close` qua Batch Jobs để chạy bù; job giữ advisory lock theo tenant và log kết quả vào `batch_runs`.
