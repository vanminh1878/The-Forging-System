# Batch job (`batch`)

Vai trò xem [README](README.md). Tất cả endpoint chỉ dành cho **A** (`ADMIN`, `SUPER_ADMIN`). Job tự chạy theo cron (múi giờ `APP_TIMEZONE`) cho từng tenant; admin cũng có thể chạy tay.

Mỗi lần chạy ghi đúng 1 dòng `batch_runs` (chỉ thêm, không sửa/xoá), kèm audit `BATCH_RUN` (entityType `BATCH`).

Object lần chạy (`BatchRun`):

```json
{
  "id": "5d0c...",
  "batchKey": "sessions",
  "name": "Sinh buổi tập từ lịch lớp",
  "status": "SUCCESS",
  "resultLines": ["Lớp Boxing sáng: +12 buổi"],
  "runBy": "a1c0...",
  "startedAt": "2026-03-02T10:00:00.000Z",
  "runAt": "2026-03-02T10:00:01.000Z"
}
```

- `status`: `SUCCESS` (Thành công), `FAILED` (Thất bại: `resultLines` chứa dòng "Lỗi: ..."; mọi thay đổi của job được hoàn tác), `SKIPPED` (Bỏ qua: job đang chạy ở tiến trình khác).
- `runBy = null` nghĩa là hệ thống chạy theo lịch.

## GET `/admin/batch-jobs`

Danh sách job đã đăng ký.

```json
{
  "data": [
    {
      "key": "sessions",
      "name": "Sinh buổi tập từ lịch lớp",
      "cron": "10 0 * * *",
      "lastRun": {
        "status": "SUCCESS",
        "runAt": "2026-03-02T10:00:01.000Z",
        "lines": ["Không có buổi mới cần sinh."]
      }
    }
  ]
}
```

`lastRun = null` nếu job chưa từng chạy.

## POST `/admin/batch-jobs/:key/run`

Chạy ngay cho tenant hiện tại (`runBy` = admin gọi). Không có body. Trả 200 với `BatchRun` vừa ghi. Job lỗi **không** trả lỗi HTTP: kết quả là `status = "FAILED"`.

| HTTP | code           | message                                            |
| ---- | -------------- | -------------------------------------------------- |
| 401  | `UNAUTHORIZED` | Yêu cầu đăng nhập                                  |
| 403  | `FORBIDDEN`    | Không đủ quyền                                     |
| 404  | `NOT_FOUND`    | Batch job not found (key không có trong danh sách) |

## GET `/admin/batch-runs`

Lịch sử chạy, mới nhất trước.

| Query           | Kiểu                           | Mặc định | Ghi chú          |
| --------------- | ------------------------------ | -------- | ---------------- |
| `key`           | string                         |          | Lọc theo job     |
| `status`        | `SUCCESS`\|`FAILED`\|`SKIPPED` |          | Lọc theo kết quả |
| `page`, `limit` | int                            | 1, 20    | `limit` 1–100    |

Trả `data: BatchRun[]`, `meta = { page, limit, total, totalPages }`. Sai `status` → 400 `VALIDATION_ERROR`.

## Ghi chú FE

- Màn "Tác vụ nền" (admin): bảng job với tên, lịch cron, kết quả lần gần nhất (chip: Thành công / Thất bại / Bỏ qua) và nút "Chạy ngay". Sau khi bấm: hiện loading, rồi toast theo `status` ("Đã chạy xong" / "Job thất bại, xem chi tiết" / "Job đang chạy ở nơi khác").
- `resultLines` hiển thị nguyên văn, mỗi phần tử một dòng.
- Lễ tân và coach không thấy màn này (403).
