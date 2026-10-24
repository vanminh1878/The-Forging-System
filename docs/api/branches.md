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

## Quản trị chi nhánh (chỉ admin: `ADMIN`, `SUPER_ADMIN`)

Học viên/staff khác gọi các endpoint này nhận 403 `FORBIDDEN`.

### POST `/admin/branches`: tạo chi nhánh

| Field | Kiểu | Bắt buộc | Giới hạn |
|---|---|---|---|
| `code` | string | có | tự chuyển IN HOA; `A-Z 0-9 _ -`, 2–20 ký tự; duy nhất |
| `name` | string | có | 2–100 |
| `address` | string\|null | không | ≤ 255 |
| `openingHours` | string\|null | không | ≤ 100, văn bản tự do, ví dụ `06:00 – 21:30` |
| `latitude` / `longitude` | number\|null | không | -90..90 / -180..180 |
| `geofenceRadiusM` | int | không | 10–5000, mặc định 100 |

Trả **201** với `data` là chi nhánh vừa tạo (cùng shape như `GET /branches/:id`, kèm `qrVersion: null`).

| HTTP | code | message |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Dữ liệu không hợp lệ |
| 403 | `FORBIDDEN` | Không đủ quyền |
| 409 | `BRANCH_CODE_TAKEN` | Mã chi nhánh đã tồn tại |

### PATCH `/admin/branches/:branchId`: sửa một phần

Body: các field như trên, tất cả tuỳ chọn; gửi `null` để xoá `address`, `openingHours`, `latitude`, `longitude`. Có thể đổi `code` nhưng không được trùng chi nhánh khác. Trả 200 với chi nhánh sau khi sửa.

| HTTP | code | message |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Dữ liệu không hợp lệ |
| 404 | `NOT_FOUND` | Chi nhánh not found |
| 409 | `BRANCH_CODE_TAKEN` | Mã chi nhánh đã tồn tại |

### POST `/admin/branches/:branchId/status`: bật/tắt hoạt động

Body: `{ "isActive": false, "reason": "Đóng cửa sửa chữa" }`. `reason` bắt buộc, 3–500 ký tự. Trả 200 với chi nhánh sau khi đổi. Nếu trạng thái không đổi thì không làm gì (vẫn 200, không ghi audit).

| HTTP | code | message |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Thiếu lý do hoặc `isActive` sai kiểu |
| 404 | `NOT_FOUND` | Chi nhánh not found |

### Quy tắc nghiệp vụ

- Mọi thao tác ghi đều được lưu audit: `BRANCH_CREATED`, `BRANCH_UPDATED` (trước/sau), `BRANCH_ACTIVATED`, `BRANCH_DEACTIVATED` (kèm lý do).
- Chi nhánh ngừng hoạt động biến mất khỏi `GET /branches` của học viên và staff (chỉ admin thấy với `includeInactive=true`). Dữ liệu cũ (học viên, lớp) giữ nguyên, không bị xoá.

### Ghi chú FE (admin)

- Form tạo/sửa: hiển thị `code` tự in hoa; lỗi `BRANCH_CODE_TAKEN` hiện ngay dưới ô Mã. Toast: "Đã tạo chi nhánh", "Đã lưu thay đổi".
- Nút bật/tắt mở hộp thoại bắt nhập lý do (≥ 3 ký tự); toast "Đã ngừng hoạt động chi nhánh" / "Đã kích hoạt lại chi nhánh".

## QR check-in của chi nhánh

`qrVersion` là chuỗi số tăng dần; chưa từng đặt thì coi là `"1"` (mọi API đều trả `"1"`, không trả `null`).

### GET `/branches/:branchId/qr`

Quyền: lễ tân + admin (FD). Học viên/coach → 403.

```json
{ "data": { "branchId": "6f1c0a52-8d0e-4c0b-9a55-0b6f3a2f6c11", "code": "Q1", "qrVersion": "3", "payload": "HVP|Q1|3" } }
```

`payload` = `HVP|<mã chi nhánh>|<qrVersion>`, chuỗi để in/hiển thị mã QR tĩnh (màn lễ tân, in bảng QR).

| HTTP | code | message |
|---|---|---|
| 403 | `FORBIDDEN` | Không đủ quyền |
| 404 | `NOT_FOUND` | Chi nhánh not found |

### POST `/admin/branches/:branchId/qr/rotate`

Quyền: admin (A). Body (tuỳ chọn): `{ "reason": "Mất bảng QR" }` (3–500 ký tự; mặc định "Cập nhật QR check-in"). Tăng `qrVersion` thêm 1 (đặt `qr_prefix` mặc định `HVP-<code>` nếu đang trống), ghi audit `BRANCH_QR_UPDATED`. Trả 200 cùng shape như GET `/qr` với version mới.

| HTTP | code | message |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Lý do quá ngắn/dài |
| 403 | `FORBIDDEN` | Không đủ quyền |
| 404 | `NOT_FOUND` | Chi nhánh not found |

### Hợp đồng cho CHK-01 (check-in)

- Mã check-in xoay vòng được **suy ra** từ `chi nhánh + qrVersion + cửa sổ thời gian`, cửa sổ dài `checkin.code_ttl_seconds` giây (ví dụ `HMAC(secret, branchId|qrVersion|floor(now/ttl))`).
- Vì `qrVersion` nằm trong đầu vào, **tăng `qrVersion` làm vô hiệu mọi mã đã phát hành** (kể cả QR in cũ), không cần lưu danh sách mã.
- CHK-01 phải đọc version đúng quy tắc: cột `branches.qr_version`, thiếu → `"1"`.

### Ghi chú FE

- Màn admin: nút "Làm mới mã QR" mở hộp thoại cảnh báo "Mã QR đã in sẽ không còn dùng được" + ô lý do tuỳ chọn; sau khi thành công toast "Đã cập nhật QR check-in" và hiển thị "Mã QR: phiên bản {qrVersion}".
- Màn lễ tân: dùng `payload` để vẽ mã QR; tải lại khi admin vừa làm mới.

## Ghi chú FE

- Danh sách chọn chi nhánh (đăng ký, đặt lớp…): gọi `GET /branches`, hiển thị `name` + `address`, và `openingHours` nếu có.
- Màn quản trị chi nhánh (admin): gọi với `includeInactive=true`, đánh dấu chi nhánh `isActive=false` bằng chip "Ngừng hoạt động"; hiển thị "Mã QR: phiên bản {qrVersion}".
- Trạng thái màn hình: loading, rỗng ("Chưa có chi nhánh"), lỗi (nút thử lại).
