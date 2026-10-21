# CFG-10 — API Audit Log với bộ lọc

```http
GET /api/v1/admin/audit-logs
```

Chỉ ADMIN/SUPER_ADMIN trong tenant hiện tại; giữ response `{data:[...],meta:{page,limit,total,totalPages}}`.

| Query | Ý nghĩa |
|---|---|
| action | Exact match action code, ví dụ CONFIG_CHANGE |
| entityType | Exact match, ví dụ SYSTEM_CONFIG / MEMBER / USER |
| entityId | Text ID; nhận UUID hoặc key như points.dp_monthly_cap |
| actorId | UUID của người thực hiện |
| actorType | USER hoặc SYSTEM |
| from / to | ISO-8601 có timezone, khoảng inclusive; from <= to |
| q | Search literal, không phân biệt hoa thường, trên action/entity type/entity ID/reason/tên actor |
| page / limit | Mặc định 1/20, limit 1–100 |

Các bộ lọc kết hợp bằng AND. q tìm bằng OR trên các trường text bên trong điều kiện search.
Chuỗi %, _ không trở thành wildcard. Không cho query field không thuộc contract; query sai trả 400 VALIDATION_ERROR.
Sort `createdAt DESC, id DESC`, kể cả log có ID mới nhưng timestamp cũ. Count và list dùng cùng filter/join.
Trả id, action, entityType, entityId, beforeData, afterData, reason, actorType, actorId, actorName, createdAt.
SYSTEM có actorId/actorName null. Không trả tenantId hoặc dữ liệu ngoài tenant. Join actor ràng buộc cùng tenant.
API chỉ đọc, không có sửa/xóa audit; append-only vẫn do database bảo vệ.

## cURL CMD

```cmd
curl "http://localhost:4000/api/v1/admin/audit-logs?action=CONFIG_CHANGE&entityType=SYSTEM_CONFIG&page=1&limit=20" -H "Authorization: Bearer %TOKEN%" -H "X-Tenant-Code: hvp"
curl "http://localhost:4000/api/v1/admin/audit-logs?actorId=UUID_NHAN_SU&actorType=USER" -H "Authorization: Bearer %TOKEN%"
curl -G "http://localhost:4000/api/v1/admin/audit-logs" -H "Authorization: Bearer %TOKEN%" --data-urlencode "from=2026-10-01T00:00:00+07:00" --data-urlencode "to=2026-10-31T23:59:59+07:00"
```

Migration `0006_audit_filter_indexes.sql` bổ sung index actor/action + thời gian. Chạy `npm run migrate` hoặc rebuild/restart API Docker để entrypoint tự migrate.
Tests: unit/integration `audit.test.ts`, gồm filter kết hợp, date range, actor, SYSTEM, search, pagination, RBAC, RLS và trace thay đổi settings.

Đã kiểm tra CFG-10: 15 unit tests và 7 integration tests pass. Chạy chung CFG-01/CFG-10: 68 unit tests và 13 integration tests pass trên PostgreSQL test riêng; lint/build pass.
Trên nhánh `feature/CFG-01-Audit`, typecheck backend và test liên quan pass khi loại các test nhân sự chưa track còn sót từ task khác (module staff không có trên base của nhánh này).
