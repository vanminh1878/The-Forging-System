# CFG-02 - API admin cau hinh hang

## Pham vi

CFG-02 bo sung API quan tri cau hinh hang (rank): thoi gian toi thieu o hang hien tai (`minActiveMonths`) va vai tro duoc phep cham Rank Trial (`approvalRole`: COACH, HEAD_COACH, ADMIN).

API chi cap nhat cac truong cau hinh nay trong bang `ranks`. Khong thay doi DP threshold, course gate, badge hoac rules tu dong.

## Endpoint

Base URL `/api/v1`; yeu cau Bearer token va tenant (`X-Tenant-Code`, mac dinh `hvp`).

Chi `ADMIN` / `SUPER_ADMIN` duoc truy cap.

| Method | Path | Muc dich |
|---|---|---|
| GET | `/admin/ranks` | Danh sach cau hinh hang |
| GET | `/admin/ranks/:rankId` | Chi tiet mot hang |
| PATCH | `/admin/ranks/:rankId` | Cap nhat thoi gian o hang va nguoi chamm trial |

### Request PATCH

```http
PATCH /api/v1/admin/ranks/<rank-uuid>
Authorization: Bearer <token>
X-Tenant-Code: hvp
Content-Type: application/json

{
  "minActiveMonths": 3,
  "approvalRole": "HEAD_COACH",
  "reason": "Dieu chinh thoi gian o hang va nguoi chamm trial"
}
```

| Field | Quy tac |
|---|---|
| `minActiveMonths` | Tuy chon, integer 0..120 |
| `approvalRole` | Tuy chon, `COACH`, `HEAD_COACH`, `ADMIN` hoac `null` |
| `reason` | Bat buoc, trim, 3..500 ky tu |
| Body | Khong duoc rong; chi nhan cac field tren |

### Response 200

Tra ve `RankDef` gom `id`, `rankOrder`, `code`, `nameEn`, `nameVi`, `dpThreshold`, `minActiveMonths`, `requiresTrial`, `approvalRole`, `isHonorary`, `requiredCourseIds`.

### Ma loi

| HTTP | Code | Tinh huong |
|---|---|---|
| 400 | VALIDATION_ERROR | UUID sai, body rong, field khong hop le |
| 401 | UNAUTHORIZED / TOKEN_INVALID | Thieu/sai token |
| 403 | FORBIDDEN | Khong phai Admin |
| 404 | NOT_FOUND | Rank khong ton tai hoac thuoc tenant khac |

## Kiem tra

```sh
npm run typecheck
npm run lint
npm run build
npm test
```

## Ghi chu

- Cap nhat duoc ghi audit `RANK_CONFIG_UPDATED` voi before/after va reason.
- Thay doi `minActiveMonths` anh huong cac danh gia rank sau nay.
- Thay doi `approvalRole` anh huong queue va quyen chamm Rank Trial.
