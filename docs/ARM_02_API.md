# ARM-02 — Học viên đổi quà: chi nhánh nhận, giữ Marks, trừ kho

**Nhánh:** `feature/ARM-02-Armory-Redemption`, dựa trên ARM-04. Chưa commit/push tự động.
**Phạm vi:** POST tạo yêu cầu đổi 1 phần quà mỗi lần; không gộp API Admin GFT, catalog ARM-01, lịch sử/hủy đơn hoặc giao quà vào task này.
**Schema:** backend v3, dùng `redemptions`, `rewards.stock`, `inventory_movements`, `audit_logs` và số dư member. Không cần migration mới.

## 1. API

```http
POST /api/v1/armory/redemptions
Authorization: Bearer <MEMBER_ACCESS_TOKEN>
X-Tenant-Code: hvp
Content-Type: application/json
```

```json
{
  "rewardId": "<UUID phần quà>",
  "pickupBranchId": "<UUID chi nhánh nhận>"
}
```

- Chỉ role MEMBER; memberId lấy từ token, không nhận từ body.
- Chỉ cần hai UUID quà và chi nhánh, chuẩn hóa lowercase. Không nhận quantity, Marks cost, status hoặc requestedAt từ client.
- Một đơn = một sản phẩm. Chi nhánh nhận có thể khác home branch của học viên nhưng phải cùng tenant và đang hoạt động.
- Backend tự sinh mã request nội bộ nếu client không gửi mã. Mỗi POST không kèm key là một lần đổi mới.
- `idempotencyKey` là field tùy chọn cho client cần retry cùng thao tác; không bắt người dùng nhập. Nếu có thì phải là UUID và giữ nguyên khi retry. Key được namespace theo tenant + member.

## 2. Response

Lần đầu: **201 Created**. Retry cùng key và cùng reward/branch: **200 OK**, duplicate=true.

```json
{
  "data": {
    "redemption": {
      "id": "<UUID đơn>",
      "redemptionCode": "ARM-<UUID>",
      "rewardId": "<UUID quà>",
      "pickupBranchId": "<UUID chi nhánh nhận>",
      "marksCost": 120,
      "status": "PENDING_PICKUP",
      "requestedAt": "<thời gian server>"
    },
    "wallet": {
      "marksBalance": 300,
      "marksHeld": 120,
      "marksAvailable": 180
    },
    "duplicate": false
  }
}
```

Retry trả lại snapshot giá/status của đơn đã tạo; không lấy giá hiện tại để tính lại đơn.
Wallet trong response là ví tại thời điểm request được xử lý, không phải snapshot ví cố định từ request đầu.
Dùng lại key nhưng đổi reward hoặc pickup branch trả 409 IDEMPOTENCY_CONFLICT.

## 3. Quy tắc nghiệp vụ

1. Khóa member trước, xác nhận tài khoản user ACTIVE; lấy đơn cũ theo key sau khi lấy lock.
2. Nếu đây là request mới, chặn member INACTIVE. Theo schema runtime v3, member FROZEN vẫn được đổi quà.
3. Kiểm tra chi nhánh nhận active và cùng tenant; giữ share lock trong transaction.
4. Khóa reward row, kiểm tra active, stock, thời gian mở bán theo server (start inclusive, end exclusive), rank và giới hạn đổi.
5. Giới hạn mỗi học viên tính các đơn PENDING_PICKUP + DELIVERED; đơn CANCELLED/REJECTED/EXPIRED không chiếm quota.
6. MONTH/YEAR dùng timezone APP_TIMEZONE, không dùng ngày giờ client. LIFETIME không giới hạn khoảng ngày.
7. Sau khi giữ member lock, đọc ví bằng một SQL statement mới để không dùng snapshot hold cũ sau khi chờ lock.
8. `marksHeld = SUM(marks_cost)` của các đơn PENDING_PICKUP; `marksAvailable = marksBalance - marksHeld`.
9. Nếu đủ Marks khả dụng, tạo đơn snapshot giá Marks, giảm stock đúng 1, ghi inventory OUT và audit REDEMPTION_CREATED trong cùng transaction.
10. Giữ Marks **không trừ marksBalance và không tạo point_transactions**. Khi giao quà mới ghi debit qua ARM-04.

Không thể tạo đơn mới bằng cách dùng Marks đã giữ cho đơn khác; member lock serialize các yêu cầu cùng ví.
Reward lock bảo vệ món hàng cuối khi hai học viên đổi đồng thời. Audit/inventory lỗi rollback cả đơn, hold và stock.
Replay đơn cũ không bị các thay đổi giá/active/stock hiện tại làm phát sinh đơn mới hay trừ kho lần nữa.

## 4. Ranh giới với ARM-04 và các task khác

Nhánh này dựa trực tiếp trên ARM-04. ARM-02 gọi `MarksWalletPort.assertMarksAvailable()` để kiểm tra Marks khả dụng và `wallet()` để đọc ví; không tự triển khai lại phép tính hold. Bản ghi PENDING_PICKUP là nguồn hold được ARM-04 tính toán.

- Catalog học viên: test trên ARM-01; Admin tạo quà: test trên GFT-01.
- ARM-02 chỉ thêm POST `/armory/redemptions`; không thêm lại GET catalog hoặc GET wallet của task khác.
- Quà/chi nhánh đã có trong cùng database được dùng khi checkout ARM-02. Có thể lấy UUID từ response API các task tương ứng trước khi chuyển nhánh.
- Stock đã giảm ở bước tạo đơn. Task giao quà **không được giảm stock lần nữa**; task hủy/từ chối/hết hạn phải hoàn stock một lần và ghi movement IN.
- Inventory OUT tại đây là phân bổ hàng cho đơn đang chờ, có redemptionId và reason để truy vết.
- API đăng ký học viên mới không tự có Marks; dùng tài khoản đã có Marks hoặc chuẩn bị số dư qua công cụ quản trị hợp lệ trước khi test đổi quà.
- Task này không tự chuyển DELIVERED, không tự thưởng/bù Marks và không thêm API public để học viên tự nhập điểm.

## 5. Mã lỗi

| HTTP | Code | Tình huống |
|---|---|---|
| 400 | VALIDATION_ERROR | UUID thiếu/sai hoặc client gửi field ngoài contract |
| 400 | INVALID_PICKUP_BRANCH | Chi nhánh không tồn tại/cùng tenant không có/đã ngừng hoạt động |
| 401 | UNAUTHORIZED / TOKEN_INVALID | Thiếu/sai token |
| 403 | FORBIDDEN | Không phải MEMBER |
| 403 | ACCOUNT_DISABLED / MEMBER_INACTIVE | User bị khóa/vô hiệu hóa, hoặc member inactive tạo đơn mới |
| 403 | RANK_REQUIRED | Chưa đủ rank để đổi |
| 404 | NOT_FOUND | Member/reward không tồn tại trong tenant |
| 409 | IDEMPOTENCY_CONFLICT | Dùng lại key cho payload khác |
| 409 | REWARD_UNAVAILABLE | Quà không active/chưa mở bán/đã hết hạn |
| 409 | OUT_OF_STOCK | Hết hàng |
| 409 | REWARD_LIMIT_REACHED | Đạt quota đổi trong chu kỳ |
| 409 | INVALID_REWARD_RULES | Cấu hình reward trong DB không hợp lệ |
| 422 | INSUFFICIENT_AVAILABLE_MARKS | Không đủ Marks sau khi trừ phần đang giữ |

## 6. cURL CMD Windows

Dừng backend nhánh cũ trước khi checkout nhánh mới, sau đó:

```cmd
cd /d "E:\Hoc\Boxing\HVPForgingSystem"
git switch feature/ARM-02-Armory-Redemption
cd backend
npm run migrate
npm run dev
```

Mở CMD thứ hai. Đăng nhập học viên demo có sẵn Marks (nếu DB đã seed), hoặc thay bằng tài khoản của bạn:

```cmd
curl -X POST "http://localhost:4000/api/v1/auth/login" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"identifier\":\"0911000004\",\"password\":\"hvp12345\"}"
set "TOKEN=MEMBER_ACCESS_TOKEN"
set "REWARD_ID=UUID_QUA_DANG_MO_BAN"
set "BRANCH_ID=UUID_CHI_NHANH_NHAN_DANG_ACTIVE"
```

```cmd
curl -i -X POST "http://localhost:4000/api/v1/armory/redemptions" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp" -H "Content-Type: application/json" -d "{\"rewardId\":\"%REWARD_ID%\",\"pickupBranchId\":\"%BRANCH_ID%\"}"
```

Mỗi lần gọi lệnh đơn giản này là một yêu cầu đổi quà mới, vẫn chịu kiểm tra quota, stock và Marks khả dụng.

## 7. Kiểm thử

Đã chạy trên PostgreSQL test tách biệt: 43 unit tests và 21 integration tests của ARM-02/ARM-04 pass; typecheck, lint và build pass. ARM-02 không cần schema mới.
Các case chính: tạo đơn ở chi nhánh khác, đúng snapshot giá, retry đồng thời, tranh stock cuối,
hai quà tranh cùng số dư Marks, rank/thời hạn/quota theo timezone, RBAC/RLS và rollback audit.

```sh
npm run typecheck
npm run lint
npm run build
npx vitest run --project unit tests/unit/redemption.test.ts
npm run test:integration -- tests/integration/redemption.test.ts
```
