# CHL-03 - API thu thach dang mo theo Daily/Weekly/Monthly

## Pham vi

CHL-03 bo sung API cho hoc vien xem danh sach Challenge dang mo theo Daily/Weekly/Monthly. API phu thuoc CHL-01 (schema va CRUD Challenge) va chi tra ve Challenge co `status = OPEN`, chua het han.

Khong tao/sua/xoa Challenge, khong thay doi participation, progress hoac ledger.

## Nguon va kien truc

- Nghiep vu: `SPEC.md` (HV-19..21), SRS phan vong doi Challenge.
- Schema: `backend/db/migrations/0001_initial_schema.sql`, bang `challenges` va `challenge_participations`.
- Quy uoc: Express router -> service -> repository; Zod; `handle()` mo tenant transaction; PostgreSQL RLS; response `{ data, meta }`.

## Endpoint

Base URL `/api/v1`; yeu cau Bearer token va tenant (`X-Tenant-Code`, mac dinh `hvp`).

Chi `MEMBER` duoc truy cap.

| Method | Path | Muc dich |
|---|---|---|
| GET | `/me/challenges` | Danh sach Challenge dang mo |
| GET | `/me/challenges/open` | Alias |
| GET | `/challenges` | Alias |
| GET | `/challenges/open` | Alias |

### Query

```http
GET /api/v1/me/challenges?period=DAILY&page=1&limit=20
```

| Param | Quy tac |
|---|---|
| `period` / `challengeType` | Tuy chon, `DAILY`, `WEEKLY`, `MONTHLY` hoac `EVENT` |
| `context` | Tuy chon, `SESSION`, `WORKSHOP` hoac `EXAM` |
| `q` | Tuy chon, tim literal theo title/code, toi da 100 ky tu |
| `page` | Mac dinh 1 |
| `limit` | Mac dinh 20, toi da 100 |

### Dieu kien tra ve

- `status = OPEN`
- `ends_at > server now`
- Loc theo `challengeType` neu truyen `period` hoac `challengeType`
- Loc theo `context` neu truyen
- Tim kiem `q` theo title/code (literal, khong wildcard)
- Sort `ends_at ASC, id DESC`
- Pagination `{ page, limit, total, totalPages }`

### Response 200

```json
{
  "data": [
    {
      "id": "<challenge-uuid>",
      "code": "DAILY_CHECKIN",
      "title": "Thu thach hang ngay",
      "description": null,
      "challengeType": "DAILY",
      "context": "SESSION",
      "target": 1,
      "rewardDp": 10,
      "rewardMarks": 5,
      "startsAt": "2026-10-01T00:00:00.000Z",
      "endsAt": "2026-10-02T00:00:00.000Z",
      "status": "OPEN",
      "createdBy": "<user-uuid>",
      "createdAt": "<timestamp>",
      "updatedAt": "<timestamp>",
      "participationId": null,
      "participationStatus": null,
      "progressValue": null,
      "joinedAt": null
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "totalPages": 1
  }
}
```

Neu member da tham gia, cac field `participation*` duoc dien tu `challenge_participations`.

### Ma loi

| HTTP | Code | Tinh huong |
|---|---|---|
| 400 | VALIDATION_ERROR | Sai query, sai enum, page/limit khong hop le |
| 401 | UNAUTHORIZED / TOKEN_INVALID | Thieu/sai token |
| 403 | FORBIDDEN | Khong phai MEMBER |

## Kiem tra

```sh
npm run typecheck
npm run lint
npm run build
npm test
```

Integration test can DB `hvp_test`:

```sh
npm run test:integration -- tests/integration/challenges.test.ts
```

## Ghi chu

- `enabled` duoc suy ra tu `status === OPEN`, khong co cot rieng.
- API nay khong phat diem, khong tao participation va khong cap nhat progress.
- Join Challenge thuoc CHL-04; cap nhat progress tu dong thuoc CHL-05.
