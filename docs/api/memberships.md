# API Gói tập (memberships)

Quy ước chung (base URL, `X-Tenant-Code`, Bearer, envelope, phân trang, vai trò): xem [README](./README.md).

## MEM-01 — Danh sách loại gói

### `GET /package-types`

- **Vai trò:** mọi tài khoản đã đăng nhập (học viên cần xem giá trong modal gia hạn).
- **Query:**

| Tham số | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `includeInactive` | `"true"` / `"false"` | không | Chỉ ADMIN / SUPER_ADMIN có tác dụng: lấy cả gói đã ngừng bán. Vai trò khác bị bỏ qua (luôn chỉ gói đang bán). |

- **Response 200:**

```json
{
  "data": [
    {
      "id": "6f1c0a52-3b0e-4e0c-9d1d-0f6d2f3a9b11",
      "code": "BOOK_1",
      "name": "BOOK I — Foundation",
      "durationDays": 84,
      "totalSessions": 36,
      "sessionsPerWeek": 3,
      "isTrial": false,
      "priceVnd": 8900000,
      "description": null
    }
  ]
}
```

Khi ADMIN gọi với `includeInactive=true`, mỗi phần tử có thêm `isActive: boolean`.

`durationDays` / `totalSessions` / `sessionsPerWeek` / `priceVnd` có thể `null` (không giới hạn ngày / không giới hạn buổi / chưa có giá).

- **Lỗi:**

| HTTP | code | message |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Dữ liệu không hợp lệ (ví dụ `includeInactive` khác `true`/`false`) |
| 401 | `UNAUTHORIZED` | Chưa đăng nhập |

- **Quy tắc:** sắp xếp theo `sort_order` (BOOK I..V, HSSV, Group Training...). Chỉ trả gói `is_active`.
- **Ghi chú FE:**
  - Dùng cho modal "Gia hạn": hiển thị `name`, `priceVnd` (định dạng `8.900.000đ`), thời hạn (`durationDays` ngày) và số buổi (`totalSessions` hoặc "Không giới hạn buổi").
  - `isTrial = true`: gắn nhãn "Gói trải nghiệm".
  - Danh sách rỗng: hiển thị trạng thái trống "Hiện chưa có gói nào đang bán".
