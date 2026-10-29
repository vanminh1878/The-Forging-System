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

## MEM-03 — Yêu cầu gia hạn

Duyệt / huỷ yêu cầu là MEM-04 / MEM-06 (W2), chưa có trong nhánh này.

Đối tượng `renewalRequest` dùng chung cho các endpoint dưới đây:

```json
{
  "id": "0d9e...",
  "status": "PENDING",
  "note": "Tuần sau tôi qua đóng tiền",
  "reason": null,
  "createdAt": "2026-10-24T05:00:00.000Z",
  "handledAt": null,
  "member": { "id": "a1b2...", "fullName": "Nguyễn Văn A", "phone": "0911000001", "memberCode": "HVP000123" },
  "desiredPackage": { "id": "6f1c...", "name": "BOOK II — Foundation 2", "priceVnd": 9800000 },
  "currentMembership": { "id": "b2c1...", "packageName": "BOOK I — Foundation", "endDate": "2026-11-30" }
}
```

`status`: `PENDING` / `COMPLETED` / `CANCELLED`. `currentMembership` = `null` nếu học viên không có gói ACTIVE lúc gửi. `reason` là lý do huỷ (có khi MEM-06 xong).

### `POST /me/renewal-requests`  (vai trò: MEMBER)

| Trường body | Kiểu | Bắt buộc | Giới hạn |
|---|---|---|---|
| `packageTypeId` | uuid | có | Gói phải đang bán (`GET /package-types`) |
| `note` | string | không | tối đa 500 ký tự, tự cắt khoảng trắng đầu/cuối |

- **Response 201:** `{ "data": <renewalRequest> }` với `status = "PENDING"`.
- **Lỗi:**

| HTTP | code | message |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Dữ liệu không hợp lệ |
| 401 | `UNAUTHORIZED` | Chưa đăng nhập |
| 403 | `FORBIDDEN` | Không phải học viên |
| 403 | `ACCOUNT_INACTIVE` | Tài khoản đang ngừng hoạt động. Vui lòng liên hệ lễ tân để kích hoạt lại. |
| 422 | `PACKAGE_NOT_AVAILABLE` | Gói tập này hiện không còn được bán. |
| 409 | `RENEWAL_PENDING_EXISTS` | Bạn đã có một yêu cầu gia hạn đang chờ xử lý. Lễ tân sẽ xử lý sớm. |

- **Quy tắc:**
  - Mỗi học viên chỉ có tối đa 1 yêu cầu `PENDING`; gửi đồng thời nhiều lần chỉ tạo 1 yêu cầu, các lần còn lại nhận 409.
  - Tài khoản `FROZEN` vẫn được gửi; `INACTIVE` bị chặn.
  - Lưu `currentMembership` = gói ACTIVE tại thời điểm gửi (nếu có).
  - Học viên nhận thông báo `RENEWAL_SENT` ("Đã gửi yêu cầu gia hạn"); lễ tân nhận thông báo nội bộ `RENEWAL_REQUEST`. Ghi audit `RENEWAL_REQUESTED`.
- **Ghi chú FE:**
  - Sau 201: toast "Đã gửi yêu cầu gia hạn. Lễ tân sẽ liên hệ với bạn sớm." rồi tải lại `GET /me/membership` (`pendingRenewal` có giá trị -> khoá nút Gia hạn).
  - 409: hiển thị đúng `error.message`, đồng thời tải lại `GET /me/membership`.
  - 422: toast lỗi và tải lại danh sách gói. 403 `ACCOUNT_INACTIVE`: hiển thị `error.message` kèm gợi ý liên hệ lễ tân.

### `GET /me/renewal-requests`  (vai trò: MEMBER)

- **Query:** `page` (mặc định 1), `limit` (1..100, mặc định 20).
- **Response 200:** `{ "data": [<renewalRequest>...], "meta": { "page": 1, "limit": 20, "total": 2, "totalPages": 1 } }`, mới nhất trước.
- **Lỗi:** 400 `VALIDATION_ERROR`, 401 `UNAUTHORIZED`, 403 `FORBIDDEN`.
- **Ghi chú FE:** màn "Lịch sử gia hạn". Trống: "Bạn chưa gửi yêu cầu gia hạn nào". Nhãn trạng thái: PENDING "Chờ xử lý", COMPLETED "Đã gia hạn", CANCELLED "Đã huỷ" (hiển thị `reason` nếu có).

### `GET /renewal-requests`  (vai trò: RECEPTIONIST, ADMIN, SUPER_ADMIN)

Hộp thư yêu cầu gia hạn cho lễ tân (MEM-12).

| Query | Kiểu | Mô tả |
|---|---|---|
| `status` | `PENDING` / `COMPLETED` / `CANCELLED` | Lọc trạng thái (không truyền = tất cả) |
| `q` | string, tối đa 100 | Tìm theo tên, số điện thoại hoặc mã học viên (không phân biệt hoa thường) |
| `page`, `limit` | int | Mặc định 1 / 20, `limit` tối đa 100 |

- **Response 200:** `{ "data": [<renewalRequest>...], "meta": { "page", "limit", "total", "totalPages" } }`, mới nhất trước.
- **Lỗi:** 400 `VALIDATION_ERROR` (ví dụ `status` sai), 401 `UNAUTHORIZED`, 403 `FORBIDDEN` (HLV/học viên).
- **Ghi chú FE:** tab mặc định `status=PENDING` kèm ô tìm kiếm; mỗi dòng hiển thị tên + mã học viên, gói muốn gia hạn + giá, gói hiện tại + ngày hết hạn, ghi chú, thời điểm gửi. Trống: "Chưa có yêu cầu gia hạn nào". Nút Duyệt/Huỷ sẽ có ở MEM-04/MEM-06.

## MEM-04 — Lễ tân kích hoạt / gia hạn gói kèm ảnh thu phí

Ảnh minh chứng: tải lên bằng `POST /uploads?purpose=evidence`, lấy `url` trả về điền vào `paymentEvidenceUrl`.

### `POST /members/:memberId/memberships`  (vai trò: RECEPTIONIST, ADMIN, SUPER_ADMIN)

Kích hoạt thủ công gói cho học viên. Trả **201**.

| Trường body | Kiểu | Bắt buộc | Giới hạn |
|---|---|---|---|
| `packageTypeId` | uuid | có | Gói phải đang bán |
| `paymentEvidenceUrl` | string | có (kiểm tra ở server) | Phải bắt đầu bằng `${PUBLIC_BASE_URL}/files/` |
| `branchId` | uuid | không | Mặc định chi nhánh chính của học viên |
| `note` | string | không | Tối đa 500 ký tự |

### `POST /renewal-requests/:id/approve`  (vai trò: RECEPTIONIST, ADMIN, SUPER_ADMIN)

Duyệt yêu cầu gia hạn `PENDING`. Trả **200**.

| Trường body | Kiểu | Bắt buộc | Giới hạn |
|---|---|---|---|
| `paymentEvidenceUrl` | string | có | Như trên |
| `packageTypeId` | uuid | không | Mặc định `desiredPackage` của yêu cầu |
| `note` | string | không | Tối đa 500 ký tự, lưu vào `reason` của yêu cầu |

### Response (cả hai endpoint)

```json
{
  "data": {
    "membership": {
      "id": "b2c1...",
      "packageType": { "id": "6f1c...", "code": "BOOK_2", "name": "BOOK II — Foundation 2", "isTrial": false },
      "status": "SCHEDULED",
      "startDate": "2027-01-16",
      "endDate": "2027-04-09",
      "totalSessions": 36,
      "usedSessions": 0,
      "paymentEvidenceUrl": "http://localhost:4000/files/evidence/abc.jpg"
    },
    "mode": "SCHEDULED",
    "reactivated": false,
    "message": "Gia hạn sớm: gói mới xếp nối tiếp từ 16/01/2027."
  }
}
```

`mode`: `ACTIVATED` (gói mới ACTIVE từ hôm nay) hoặc `SCHEDULED` (xếp nối tiếp).

### Lỗi

| HTTP | code | message |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Dữ liệu không hợp lệ |
| 400 | `PAYMENT_EVIDENCE_REQUIRED` | Vui lòng tải ảnh minh chứng đã thu phí. |
| 400 | `INVALID_PAYMENT_EVIDENCE` | Ảnh minh chứng không hợp lệ. |
| 400 | `PACKAGE_REQUIRED` | Vui lòng chọn gói tập. (duyệt yêu cầu không có gói mong muốn và body không có `packageTypeId`) |
| 401 | `UNAUTHORIZED` | Chưa đăng nhập |
| 403 | `FORBIDDEN` | Không đủ quyền (HLV / học viên) |
| 404 | `NOT_FOUND` | Không tìm thấy học viên / gói tập / chi nhánh / yêu cầu gia hạn |
| 409 | `MEMBERSHIP_ALREADY_SCHEDULED` | Học viên đã có gói nối tiếp đang chờ kích hoạt. |
| 409 | `RENEWAL_ALREADY_HANDLED` | Yêu cầu này đã được xử lý. |
| 422 | `PACKAGE_INACTIVE` | Gói tập này đã ngừng bán. |

### Quy tắc nghiệp vụ

- Gói ACTIVE còn hiệu lực (còn ngày và còn buổi) và có ngày kết thúc: gói mới là `SCHEDULED`, `startDate = endDate + 1`. Nếu gói hiện tại không có ngày kết thúc, gói mới `SCHEDULED` bắt đầu từ hôm nay.
- Ngược lại (không có gói, hoặc gói ACTIVE đã hết hạn/hết buổi): gói cũ chuyển `EXPIRED`, gói mới `ACTIVE` từ hôm nay. Nếu học viên đang FROZEN/INACTIVE thì tài khoản được mở lại `ACTIVE` (`reactivated = true`).
- `endDate = startDate + durationDays - 1` (null nếu gói không giới hạn ngày). Giá thu = giá gói, `totalSessions` lấy snapshot từ gói.
- HVP Marks không bị đóng băng/mở băng khi đổi trạng thái.
- Duyệt yêu cầu: yêu cầu chuyển `COMPLETED`, lưu người xử lý, thời điểm, ảnh và gói kết quả.
- Học viên nhận thông báo `RENEWAL_COMPLETED` ("GIA HẠN THÀNH CÔNG"). Audit: `MEMBERSHIP_CREATED`, `MEMBERSHIP_EXPIRED` (gói cũ), `RENEWAL_COMPLETED`.
- `GET /members/:memberId/membership` (lễ tân) có thêm `paymentEvidenceUrl` trong `current` / `scheduled`; `GET /me/membership` thì không.

### Ghi chú FE

- Form: chọn gói, tải ảnh thu phí (bắt buộc, có preview), chi nhánh (tuỳ chọn), ghi chú. Nút "Xác nhận đã thu phí" bị khoá tới khi ảnh upload xong.
- Thành công: hiển thị `message` làm toast, tải lại `GET /members/:memberId/membership` và hộp thư yêu cầu.
- 409 `RENEWAL_ALREADY_HANDLED`: tải lại hộp thư. 409 `MEMBERSHIP_ALREADY_SCHEDULED`: hiển thị `error.message`. 422: tải lại danh sách gói.
- Chỉ lễ tân/admin thấy ảnh minh chứng; màn học viên không có field này.
