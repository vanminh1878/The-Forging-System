# ARM-04 — Marks âm và giữ Marks

Commit riêng sau ARM-01. Dùng schema runtime v3, không thêm bảng/cột hold hoặc migration.

## Ví học viên

```http
GET /api/v1/me/armory/wallet
Authorization: Bearer <MEMBER_TOKEN>
```

Response `{data:{memberId,status,marksBalance,marksHeld,marksAvailable,canRedeem}}`.

- `marksBalance`: số dư từ ledger (cache do trigger cập nhật).
- `marksHeld`: SUM(marks_cost) của các đơn PENDING_PICKUP.
- `marksAvailable = marksBalance - marksHeld`.
- Theo schema v3, FROZEN vẫn được đổi quà; INACTIVE không được tạo đơn mới (`canRedeem=false`).
- Đổi status đơn sang CANCELLED/REJECTED/EXPIRED tự giải phóng hold vì không còn thuộc SUM. Không phát sinh debit/refund ledger vì hold chưa trừ tiền.
- Đọc bảng nền có RLS thay vì view owner-rights để không lộ ví tenant khác.

## Port cho module tạo đơn (ARM-02 tiếp theo)

`MarksWalletPort.assertMarksAvailable(memberId, amount)` khóa member, đọc tổng hold và kiểm tra số dư khả dụng.
Module tạo đơn phải gọi trước khi insert PENDING_PICKUP và giữ nguyên tenant transaction tới khi lưu đơn:

```ts
await db.tenantTx(tenantId, async () => {
  await points.assertMarksAvailable(memberId, marksCost);
  // Validate reward/stock/pickup branch, insert PENDING_PICKUP order, audit.
  // The order itself persists the hold, not assertMarksAvailable().
});
```

Không có endpoint công khai để giữ một số Marks tùy ý. Hold phải gắn với đơn đổi quà, để có nguồn truy vết.
ARM-04 cung cấp hạ tầng check/lock/read; tạo/hủy/giao đơn là task Armory tương ứng.
Mọi writer tạo đơn phải lấy lock member trước insert; nếu không, không thể bảo đảm concurrent hold.

## Mở rộng award()

```ts
await points.award({
  memberId,
  source: 'ARMORY_REDEEM',
  dp: 0,
  marks: -order.marksCost,
  redemptionId: order.id,
  note: 'Giao quà tại quầy',
  by: receptionistId,
});
```

- Debit đổi quà dùng ARMORY_REDEEM; DP luôn 0, yêu cầu redemptionId và snapshot marksCost khớp debit. Nguồn thưởng thông thường không được gửi điểm âm.
- Giữ tương thích transfer gộp tài khoản đang dùng MANUAL_ADJUSTMENT âm qua award(): bắt buộc actor/reason, kiểm tra số dư và hold. Đây là correction nội bộ, không phải redeem DP.
- Trừ Marks không áp monthly cap và không làm giảm usage các nguồn thưởng có cap.
- Đơn phải thuộc member/tenant, có status PENDING_PICKUP hoặc DELIVERED.
- Khi kiểm tra số dư, loại hold của chính đơn đang trả nhưng giữ nguyên bảo vệ Marks của các đơn khác.
- Lock theo thứ tự member → redemption. Module giao quà phải dùng cùng thứ tự để tránh deadlock.
- Debit và chuyển đơn sang DELIVERED phải ở **cùng transaction**. award() chỉ ghi ledger, không giao quà/chuyển status/đổi stock.
- Caller có thể đổi status trước hoặc sau award() trong transaction đó. Không commit một debit mới rồi để đơn PENDING_PICKUP.
- Tự sinh idempotency key khi debit không truyền key. Retry cùng đơn (kể cả key khác) trả debit cũ, không trừ hai lần; không cho tái dùng key cho member/source khác.
- Kiểm tra lại idempotency sau khi lấy lock để retry đồng thời vẫn trả transaction cũ dù số dư đã thay đổi.
- Ghi `ARMORY_MARKS_DEBITED` cùng transaction; audit lỗi rollback cả ledger/balance.
- manualAdjust() và reverse() cũng không được làm giảm Marks xuống dưới tổng hold đang có.
- Không mở API public award() cho học viên tự truyền số Marks âm.

## Lỗi

- 400 INVALID_POINT_AMOUNT / INVALID_AWARD: số không nguyên, nguồn không cho âm, DP debit khác 0 hoặc thiếu redemptionId.
- 400 REDEMPTION_AMOUNT_MISMATCH: debit không bằng snapshot đơn.
- 403 MEMBER_INACTIVE: không cho giữ thêm Marks/tạo đơn mới.
- 404 NOT_FOUND: member/đơn không tồn tại trong tenant hoặc đơn không thuộc member.
- 409 REDEMPTION_NOT_PAYABLE: đơn đã hủy/từ chối/hết hạn.
- 409 IDEMPOTENCY_CONFLICT: dùng lại key cho giao dịch khác.
- 422 INSUFFICIENT_AVAILABLE_MARKS: không đủ Marks sau khi bảo vệ hold khác.

## Kiểm thử

```sh
npx vitest run --project unit tests/unit/armory-wallet.test.ts tests/unit/points.rules.test.ts
npm run test:integration -- tests/integration/armory-wallet.test.ts tests/integration/points-ranks.test.ts
```

Đã kiểm tra: 18 unit tests mới cho wallet/debit, 2 unit tests catalog và 7 tests point rules pass.
Integration trên PostgreSQL 18.4 tách biệt: 10 wallet/debit tests, 4 catalog tests và 10 points/ranks regression tests pass.
Build/lint và typecheck code/test liên quan pass. Full workspace typecheck vẫn có các test nhân sự chưa track import module không thuộc nhánh Armory.

```cmd
curl "http://localhost:4000/api/v1/me/armory/wallet" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
```
