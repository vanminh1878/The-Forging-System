# CFG-03 - Luu phien ban cau hinh va hoan tac

## Pham vi

CFG-03 bo sung API xem lich su thay doi cau hinh va hoan tac ve mot phien ban truoc. Vi khong co bang version rieng, cac phien ban duoc luu trong `audit_logs` voi `entity_type = SYSTEM_CONFIG`, `entity_id = key`.

## Endpoint

Base URL `/api/v1`; yeu cau Bearer token va tenant. Chi `ADMIN` / `SUPER_ADMIN`.

| Method | Path | Muc dich |
|---|---|---|
| GET | `/admin/settings/:key/history` | Lich su thay doi cau hinh |
| GET | `/admin/settings/:key/versions` | Alias |
| POST | `/admin/settings/:key/rollback` | Hoan tac ve phien ban da chon |

### GET history

```http
GET /api/v1/admin/settings/points.dp_monthly_cap/history
```

Tra ve danh sach audit log moi nhat truoc, gom `id`, `action`, `beforeData`, `afterData`, `reason`, `actorId`, `createdAt`.

### POST rollback

```http
POST /api/v1/admin/settings/points.dp_monthly_cap/rollback
Content-Type: application/json

{
  "auditLogId": 123,
  "reason": "Hoan tac cau hinh theo yeu cau van hanh"
}
```

Body chap nhan `auditLogId`, `versionId` hoac `auditId` (bat buoc mot trong ba), va `reason`.

Rollback doc gia tri `afterData` cua phien ban da chon; neu khong co thi dung `beforeData`, sau do goi lai `PUT /admin/settings/:key` de tao audit log moi.

### Ma loi

| HTTP | Code | Tinh huong |
|---|---|---|
| 400 | VALIDATION_ERROR | Thieu phien ban hoac reason khong hop le |
| 401 | UNAUTHORIZED / TOKEN_INVALID | Thieu/sai token |
| 403 | FORBIDDEN | Khong phai Admin |
| 404 | NOT_FOUND | Config hoac phien ban khong ton tai |

## Kiem tra

```sh
npm run typecheck
npm run lint
npm run build
npm test
```
