# Chi nhánh (`branches`)

Vai trò xem [README](README.md). Mọi endpoint yêu cầu đăng nhập.

## GET `/branches`

Danh sách chi nhánh. Quyền: mọi user đăng nhập.

| Query | Kiểu | Mặc định | Ghi chú |
|---|---|---|---|
| `includeInactive` | `true`\|`false` | `false` | Chỉ **admin** (A) có hiệu lực; vai trò khác gửi `true` vẫn chỉ nhận chi nhánh đang hoạt động. Giá trị khác → 400 |

```json
{
  "data": [
    {
      "id": "6f1c0a52-8d0e-4c0b-9a55-0b6f3a2f6c11",
      "code": "Q1",
      "name": "HVP Boxing - The Corner",
      "address": "12 Nguyễn Huệ, Q1",
      "openingHours": "06:00 – 21:30",
      "latitude": 10.7769,
      "longitude": 106.7009,
      "geofenceRadiusM": 100,
      "isActive": true,
      "qrVersion": "1"
    }
  ]
}
```

- Sắp xếp theo `name`. `address`, `openingHours`, `latitude`, `longitude` có thể `null`.
- `qrVersion` **chỉ có với staff** (S); học viên không nhận field này.

| HTTP | code | message |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Dữ liệu không hợp lệ |
| 401 | `UNAUTHORIZED` | Yêu cầu đăng nhập |

## GET `/branches/:branchId`

Chi tiết một chi nhánh. Quyền: mọi user đăng nhập. Response `data` là một object như phần tử ở trên.

| HTTP | code | message |
|---|---|---|
| 400 | `VALIDATION_ERROR` | `branchId` không phải UUID |
| 404 | `NOT_FOUND` | Chi nhánh not found |

- Học viên gọi chi nhánh đã ngừng hoạt động nhận **404** (như không tồn tại). Staff vẫn xem được.

## Ghi chú FE

- Danh sách chọn chi nhánh (đăng ký, đặt lớp…): gọi `GET /branches`, hiển thị `name` + `address`, và `openingHours` nếu có.
- Màn quản trị chi nhánh (admin): gọi với `includeInactive=true`, đánh dấu chi nhánh `isActive=false` bằng chip "Ngừng hoạt động"; hiển thị "Mã QR: phiên bản {qrVersion}".
- Trạng thái màn hình: loading, rỗng ("Chưa có chi nhánh"), lỗi (nút thử lại).
