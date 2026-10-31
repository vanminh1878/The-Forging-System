# ARM-05 — Máy trạng thái yêu cầu đổi quà

Nhánh `feature/ARM-05-redemption-status` dựa trên ARM-02 và ARM-04. Schema runtime v3 không có `READY`.

`PENDING_PICKUP` có thể chuyển sang `DELIVERED`, `REJECTED`, `CANCELLED` hoặc `EXPIRED`. Trạng thái cuối không chuyển sang trạng thái khác. Retry cùng trạng thái trả `duplicate: true`; trạng thái cuối khác trả 409.

## API

Member hủy đơn của mình:

```http
POST /api/v1/me/armory/redemptions/:redemptionId/cancel
```

Body `{}` hoặc `{"reason":"Không thể nhận"}`. Lễ tân tại chi nhánh nhận, Admin hoặc Super Admin quyết định:

```http
POST /api/v1/staff/armory/redemptions/:redemptionId/decision
```

Body `{"status":"DELIVERED"}` hoặc `{"status":"REJECTED","reason":"Hàng lỗi"}`. Giao có thể kèm `deliveryEvidenceUrl` HTTP(S).
Các API yêu cầu Bearer token; chi nhánh của Lễ tân phải khớp chi nhánh nhận. Member không thể hủy đơn của người khác.

Giao gọi `award()` ARM-04 trừ đúng Marks snapshot; cập nhật status và audit cùng transaction. Stock đã trừ ở ARM-02, không trừ lại.
Hủy/từ chối/hết hạn chuyển status, giải phóng Marks giữ, hoàn stock 1 và ghi inventory IN/audit cùng transaction; không tạo ledger hoàn vì chưa debit.
Thứ tự khóa member → redemption → reward phù hợp ARM-02/ARM-04, và mọi thao tác giữ trong tenant transaction của `handle()`.

`RedemptionService.expire(id, reason)` là hook nội bộ cho scheduler. **Task này chưa đăng ký job/tự động tính deadline**; caller phải kiểm tra deadline trước khi gọi.
Không có endpoint công khai để tùy ý đặt EXPIRED. Không có migration mới.

## cURL CMD

```cmd
set "MEMBER_TOKEN=TOKEN_HOC_VIEN"
set "RECEPTION_TOKEN=TOKEN_LE_TAN"
set "REDEMPTION_ID=UUID_DON"
curl -X POST "http://localhost:4000/api/v1/me/armory/redemptions/%REDEMPTION_ID%/cancel" -H "Authorization: Bearer %MEMBER_TOKEN%" -H "Content-Type: application/json" -d "{\"reason\":\"Khong the den nhan\"}"
curl -X POST "http://localhost:4000/api/v1/staff/armory/redemptions/%REDEMPTION_ID%/decision" -H "Authorization: Bearer %RECEPTION_TOKEN%" -H "Content-Type: application/json" -d "{\"status\":\"DELIVERED\"}"
curl -X POST "http://localhost:4000/api/v1/staff/armory/redemptions/%REDEMPTION_ID%/decision" -H "Authorization: Bearer %RECEPTION_TOKEN%" -H "Content-Type: application/json" -d "{\"status\":\"REJECTED\",\"reason\":\"Hang loi\"}"
```

Mỗi lệnh chuyển trạng thái cần dùng đơn PENDING riêng để thử; không thể giao một đơn đã hủy/từ chối.
