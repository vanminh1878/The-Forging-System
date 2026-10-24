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

## MEM-02 — Gói hiện tại, gói chờ và trạng thái

### `GET /me/membership`  (vai trò: MEMBER)
### `GET /members/:memberId/membership`  (vai trò: RECEPTIONIST, ADMIN, SUPER_ADMIN)

Hai endpoint trả cùng một payload. `:memberId` là UUID của học viên (= `users.id`).

- **Response 200:**

```json
{
  "data": {
    "memberStatus": "ACTIVE",
    "current": {
      "id": "b2c1...",
      "packageType": { "id": "6f1c...", "code": "BOOK_1", "name": "BOOK I — Foundation", "isTrial": false },
      "status": "ACTIVE",
      "startDate": "2026-09-01",
      "endDate": "2026-11-01",
      "totalSessions": 36,
      "usedSessions": 30,
      "sessionsRemaining": 6,
      "daysRemaining": 7,
      "endingSoon": true
    },
    "scheduled": null,
    "pendingRenewal": null,
    "renewNotice": "ENDING_SOON",
    "canRenewEarly": true
  }
}
```

| Trường | Ý nghĩa |
|---|---|
| `memberStatus` | `ACTIVE` / `FROZEN` / `INACTIVE` (trạng thái tài khoản). |
| `current` | Gói đang `ACTIVE`, hoặc `null`. `totalSessions`, `sessionsRemaining` = `null` nếu không giới hạn buổi; `endDate`, `daysRemaining` = `null` nếu không giới hạn ngày. `daysRemaining = 0` là ngày cuối cùng. |
| `scheduled` | Gói `SCHEDULED` nối tiếp (tối đa 1), cùng cấu trúc như `current` nhưng không có trường tính toán; hoặc `null`. |
| `pendingRenewal` | Yêu cầu gia hạn đang `PENDING`: `{id, packageTypeId, packageName, priceVnd, note, createdAt}`, hoặc `null`. |
| `renewNotice` | `NO_PACKAGE` / `ENDED` / `ENDING_SOON` / `OK` (xem bên dưới). |
| `canRenewEarly` | `true` khi gói hiện tại còn hiệu lực và chưa có gói `SCHEDULED`. |

- **Lỗi:**

| HTTP | code | message |
|---|---|---|
| 400 | `VALIDATION_ERROR` | `memberId` không phải UUID |
| 401 | `UNAUTHORIZED` | Chưa đăng nhập |
| 403 | `FORBIDDEN` | Sai vai trò (ví dụ HLV gọi endpoint của lễ tân, học viên gọi `/members/:id/membership`) |
| 404 | `NOT_FOUND` | Học viên không tồn tại |

- **Quy tắc:**
  - "Hôm nay" tính theo múi giờ hệ thống (`APP_TIMEZONE`, Asia/Ho_Chi_Minh).
  - Gói còn hiệu lực khi `daysRemaining` là `null` hoặc `>= 0` **và** `sessionsRemaining` là `null` hoặc `> 0`.
  - `endingSoon = daysRemaining <= membership.remind_days (mặc định 7) HOẶC sessionsRemaining <= membership.remind_sessions (mặc định 2)`.
  - `renewNotice`:
    - `NO_PACKAGE`: chưa từng có gói nào kết thúc và không có gói đang chạy.
    - `ENDED`: không có gói hiệu lực (đã hết hạn / hết buổi, kể cả khi job chốt gói chưa chạy).
    - `ENDING_SOON`: gói hiệu lực, `endingSoon` và chưa có gói `SCHEDULED`.
    - `OK`: còn lại (gồm cả trường hợp đã có gói nối tiếp).
- **Ghi chú FE:**
  - Thẻ gói trên Home học viên: `current` hiển thị tên gói, "Còn X ngày / Y buổi" (hiển thị "Không giới hạn" khi `null`); `scheduled` hiển thị dòng "Gói kế tiếp: ... bắt đầu ngày ...".
  - `renewNotice = ENDING_SOON`: banner nhắc gia hạn kèm nút "Gia hạn"; `ENDED`: banner "Gói tập đã kết thúc" + nút "Gia hạn"; `NO_PACKAGE`: "Bạn chưa có gói tập, liên hệ lễ tân"; `OK`: không banner.
  - Nút "Gia hạn" mở modal chọn gói (`GET /package-types`): chỉ bật khi `renewNotice` khác `OK` hoặc `canRenewEarly = true`, và khi `pendingRenewal = null`. Nếu `pendingRenewal` có giá trị hiển thị trạng thái "Đã gửi yêu cầu gia hạn - chờ lễ tân xử lý".
  - `memberStatus = FROZEN` / `INACTIVE`: hiển thị nhãn trạng thái tài khoản ("Đóng băng" / "Ngừng hoạt động").
  - Lễ tân/Admin dùng `GET /members/:memberId/membership` cho màn chi tiết học viên (trạng thái tải, lỗi 404 "Không tìm thấy học viên").
