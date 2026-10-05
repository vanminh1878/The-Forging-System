# Hướng dẫn viết & chạy test

## 1. Hai loại test backend

| | Unit | Integration |
|---|---|---|
| Thư mục | `backend/tests/unit/` | `backend/tests/integration/` |
| Cần DB? | Không | Có (PostgreSQL thật, DB `hvp_test`) |
| Kiểm tra gì | Hàm thuần: `*.rules.ts`, `*.engine.ts`, utils thời gian | Luồng HTTP đầy đủ: route → service → SQL → trigger/RLS |
| Lệnh | `npm test` | `npm run test:integration` |
| Tốc độ | mili-giây | vài giây |

Quy tắc chọn: **luật nghiệp vụ → tách thành hàm thuần + unit test**; **luồng ghép nhiều lớp / ràng buộc DB / phân quyền → integration**.

## 2. Chuẩn bị môi trường test

- **Docker**: `docker compose up -d postgres` (script khởi tạo tự tạo role `hvp_app` và DB `hvp_test`).
- **Không Docker**: tạo role/DB theo `backend/README.md`.
- Biến môi trường (có mặc định cho máy dev): `TEST_DATABASE_URL` (role `hvp_app`), `TEST_DATABASE_MIGRATE_URL` (role `hvp_owner`). Tên DB **bắt buộc kết thúc bằng `_test`** — nếu không test từ chối chạy (bảo vệ DB dev).
- Mỗi lần chạy integration, `global-setup` xoá schema `public` của DB test và migrate lại từ đầu; mỗi file test gọi `bootTestApp()` để xoá sạch dữ liệu và seed lại dữ liệu tham chiếu. Vì vậy **file test không được phụ thuộc dữ liệu của file khác**.

Chạy:
```bash
cd backend
npm test                                   # unit
npm run test:integration                   # integration
npx vitest run --project integration tests/integration/auth.test.ts   # một file
npx vitest run -t "restoration"            # theo tên test
npm run test:coverage
docker compose --profile test run --rm api-tests    # tất cả, trong Docker
```

## 3. Viết unit test

```ts
import { describe, expect, it } from 'vitest';
import { applyMonthlyCap } from '../../src/modules/points/points.rules';

describe('applyMonthlyCap', () => {
  it('trims to the remaining room', () => {
    const r = applyMonthlyCap({ source: 'CHALLENGE', dp: 200, marks: 10, usedDpThisMonth: 1100, usedMarksThisMonth: 0, dpCap: 1200, marksCap: 150 });
    expect(r).toEqual({ dp: 100, marks: 10, capped: true });
  });
});
```
Mẹo: test biên (đúng ngưỡng, ngưỡng ± 1), trường hợp rỗng, và mọi nhánh lỗi. Đặt tên test theo hành vi ("trims…", "refuses…").

## 4. Viết integration test

Công cụ có sẵn trong `tests/helpers/test-app.ts`:

| Helper | Dùng để |
|---|---|
| `bootTestApp()` | dựng app thật + reset dữ liệu + seed tham chiếu → `ctx` (`ctx.api` = supertest, `ctx.services`, `ctx.tx`) |
| `registerMember(ctx.api)` | tạo học viên qua API, trả `{ token, userId, phone }` |
| `createStaff({ role, fullName, phone })` + `login(ctx.api, phone)` | tạo/đăng nhập COACH, HEAD_COACH, RECEPTIONIST, ADMIN |
| `bearer(token)` | header `Authorization` |
| `ctx.tx(() => …)` | chạy service trong transaction tenant (như một request) |
| `ownerQuery(sql, params)` | sắp đặt/kiểm tra dữ liệu bằng quyền owner (bỏ qua RLS) — **chỉ dùng cho fixture** |
| `setClock(fixedClock(date))` / `resetClock()` | "du hành thời gian" (cạnh `clock.now()`) |

Mẫu:
```ts
describe('my feature', () => {
  let ctx: TestContext;
  beforeAll(async () => { ctx = await bootTestApp(); });
  afterEach(() => resetClock());

  it('lets a coach confirm and posts points exactly once', async () => {
    const member = await registerMember(ctx.api);
    const coach = await createStaff({ role: 'COACH', fullName: 'Coach', phone: nextPhone() });
    const { token } = await login(ctx.api, coach.phone);

    const res = await ctx.api.post('/api/v1/...').set(bearer(token)).send({ ... });
    expect(res.status).toBe(201);
    // verify via API and, when needed, the ledger:
    const rows = await ownerQuery('SELECT count(*)::int AS n FROM point_transactions WHERE member_id = $1', [member.userId]);
    expect(rows[0].n).toBe(1);
  });
});
```

Checklist cho mỗi tính năng:
1. Luồng thành công (trạng thái HTTP + dữ liệu trả về).
2. **Phân quyền**: vai trò sai → 403; chưa đăng nhập → 401.
3. **Validate**: thiếu/ sai field → 400.
4. **Idempotency**: gọi lại cùng thao tác không cộng/ trừ hai lần.
5. **Quy tắc biên** (cap, ngưỡng, hết hạn, hết kho…) dùng `setClock` thay vì `sleep`.
6. **Đồng thời** nếu có tranh chấp (vd. 2 yêu cầu đổi món cuối cùng): `Promise.all([...])`, khẳng định chỉ một thành công.
7. Ràng buộc DB quan trọng (số dư không âm, bảng append-only) bằng `ownerQuery`.

Nguyên tắc: test **xác định** (không `setTimeout`, không phụ thuộc thứ tự), kiểm tra **kết quả nghiệp vụ** thay vì chi tiết cài đặt, mỗi test một ý.

## 5. Test mobile (Flutter)

```bash
cd mobile
flutter test
flutter analyze
```
- Domain/DTO: unit test thuần Dart.
- Repository: dùng `test/helpers/scripted_adapter.dart` (Dio adapter giả, trả JSON theo kịch bản) — không gọi mạng.
- Màn hình: `pumpHvp(tester, widget, overrides: [repositoryProvider.overrideWithValue(fake)])`; mẫu tại `test/features/fighter_record/`.
- Không dùng golden test.
- Kiểm tra cú pháp/import không cần SDK: `python3 tool/check_syntax.py lib test`, `python3 tool/check_imports.py lib test`.

## 6. CI
`.github/workflows/ci.yml` chạy trên mỗi PR: backend (typecheck, lint, unit, integration với service Postgres) và mobile (format, analyze, test).
