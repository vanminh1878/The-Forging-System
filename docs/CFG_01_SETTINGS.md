# CFG-01 — Settings: đọc, sửa và validation

## APIs

Base `/api/v1`, Bearer token + `X-Tenant-Code`; chỉ ADMIN/SUPER_ADMIN.

| Method | Path | Nội dung |
|---|---|---|
| GET | `/admin/settings?group=POINTS&q=cap` | Catalog kèm override/default, lọc group và key/description |
| GET | `/admin/settings/:key` | Một setting, gồm value, type, min/max, isDefault, updatedAt/updatedBy |
| PUT | `/admin/settings/:key` | Đổi value theo định nghĩa catalog, trả 204 |

```json
{ "value": 1300, "reason": "Điều chỉnh hạn mức tháng" }
```

`reason` tùy chọn để tương thích client chỉ gửi value; nếu gửi thì 3–500 ký tự.
Không nhận field ngoài value/reason; không tạo key tùy ý ngoài catalog.

## Validation

- INT: số nguyên hữu hạn int32, min/max theo catalog. Cap 0 vẫn hợp lệ (ngừng phát từ nguồn có cap).
- DECIMAL: số hữu hạn, min/max; không coercion chuỗi thành số.
- BOOL: boolean thật, không nhận chuỗi false/true.
- TEXT/TIME: kiểm tra đúng kiểu; TIME HH:mm hoặc HH:mm:ss.
- JSON: cấu trúc JSON hợp lệ. `streak.milestones` phải là object {tuần nguyên dương: DP nguyên không âm}; không nhận array hoặc value âm.
- `security.password_min_length` tối đa 72, phù hợp bcrypt/password API.
- GET unknown key: 404 NOT_FOUND; PUT unknown key: 400 UNKNOWN_CONFIG_KEY.
- Sai giá trị: 400 INVALID_CONFIG_VALUE; sai request: 400 VALIDATION_ERROR.

## Sửa lỗi rà soát

- Bỏ cache gắn với PoolClient: pool tái sử dụng connection giữa request/tenant, không được giữ snapshot cấu hình trên connection.
- Read lấy giá trị theo key trong tenant transaction; list lấy catalog một lần và merge override.
- Migration `0005_settings_audit.sql`: ghi CONFIG_CHANGE cho override đầu tiên và update; không audit trùng trong upsert.
- Update cùng value là no-op, không đổi timestamp hoặc tạo audit mới.
- Reason truyền qua transaction-local PostgreSQL setting để trigger ghi cùng audit; không lưu GUC session lâu dài.
- Audit, value và actor được commit/rollback trong cùng transaction. Không thêm bảng version vì schema v3 dùng audit_logs.

## cURL CMD

```cmd
curl "http://localhost:4000/api/v1/admin/settings?group=STREAK" -H "Authorization: Bearer %TOKEN%"
curl "http://localhost:4000/api/v1/admin/settings/points.dp_monthly_cap" -H "Authorization: Bearer %TOKEN%"
curl -X PUT "http://localhost:4000/api/v1/admin/settings/points.dp_monthly_cap" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"value\":1300,\"reason\":\"Dieu chinh han muc\"}"
```

Chạy `npm run migrate` trước khi dùng phiên bản mới. Tests: `settings.test.ts` trong unit/integration.
