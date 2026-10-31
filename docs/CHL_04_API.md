# CHL-04 - API tham gia thu thach

## Pham vi

CHL-04 bo sung API cho hoc vien tham gia mot Challenge dang mo. API phu thuoc CHL-03 (danh sach Challenge dang mo) va chi cho phep tham gia Challenge `OPEN`, con trong thoi gian tham gia.

Join khong phat DP/Marks, khong tang progress va khong tao evidence. Cac buoc do thuoc CHL-05/CHL-06/CHL-07.

## Endpoint

Base URL `/api/v1`; yeu cau Bearer token va tenant (`X-Tenant-Code`, mac dinh `hvp`).

Chi `MEMBER` duoc truy cap.

| Method | Path | Muc dich |
|---|---|---|
| POST | `/me/challenges/:challengeId/join` | Tham gia Challenge |
| POST | `/challenges/:challengeId/join` | Alias |

### Request

```http
POST /api/v1/me/challenges/<challenge-uuid>/join
Authorization: Bearer <token>
X-Tenant-Code: hvp
```

Khong co request body.

### Dieu kien nghiep vu

- Challenge phai ton tai trong tenant hien tai.
- `status = OPEN`.
- Thoi gian hien tai nam trong `[startsAt, endsAt)` (`startsAt <= now < endsAt`).
- Member chua tham gia Challenge nay.

Neu da tham gia, tra `409 CHALLENGE_ALREADY_JOINED`.

### Response 201

```json
{
  "data": {
    "id": "<participation-uuid>",
    "challengeId": "<challenge-uuid>",
    "memberId": "<member-user-uuid>",
    "status": "JOINED",
    "progressValue": 0,
    "evidenceUrl": null,
    "evidenceAt": null,
    "joinedAt": "<timestamp>",
    "completedAt": null,
    "confirmedBy": null,
    "confirmedAt": null,
    "isLimited": false,
    "rewardedAt": null,
    "updatedAt": "<timestamp>"
  }
}
```

### Ma loi

| HTTP | Code | Tinh huong |
|---|---|---|
| 400 | VALIDATION_ERROR | `challengeId` khong phai UUID |
| 401 | UNAUTHORIZED / TOKEN_INVALID | Thieu/sai token |
| 403 | FORBIDDEN | Khong phai MEMBER |
| 404 | NOT_FOUND | Challenge khong ton tai hoac thuoc tenant khac |
| 409 | CHALLENGE_NOT_OPEN | Challenge chua mo hoac da dong |
| 409 | CHALLENGE_CLOSED | Challenge chua bat dau hoac da het han |
| 409 | CHALLENGE_ALREADY_JOINED | Member da tham gia Challenge nay |

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

- Row `challenge_participations` duoc tao voi `status = JOINED`, `progress_value = 0`.
- Rang buoc unique `(challenge_id, member_id)` ngan tham gia trung.
- Join duoc ghi audit `CHALLENGE_JOINED`.
