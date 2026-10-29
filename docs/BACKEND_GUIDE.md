# Hướng dẫn Backend

## 1. Chạy & lệnh thường dùng
Xem `backend/README.md`. Tóm tắt: `npm run dev`, `npm run typecheck`, `npm run lint`, `npm test`, `npm run test:integration`.

## 2. Cấu trúc thư mục
```
backend/
  db/migrations/          SQL forward-only (0001 = schema v3.0, 0002 = bổ sung nền tảng). KHÔNG sửa file đã merge.
  scripts/                migrate.ts, seed.ts, seed-demo.ts
  src/
    config/env.ts         biến môi trường (zod)
    db/                   database (tenantTx, afterCommit), sql helpers, migrator
    common/               errors, http (handler, pagination), middlewares, events (EventBus), utils (clock, time, jwt…)
    shared/               roles, ports.ts (interface giữa module), events.ts (payload của domain event)
    modules/<module>/     routes -> service -> repository (+ rules thuần)
    jobs/scheduler.ts     nơi đăng ký cron cho batch job
    seeds/                dữ liệu tham chiếu + demo
    container.ts          composition root (DI thủ công)
  tests/{unit,integration,helpers}
```

## 3. Module đã có (nền tảng)
`auth`, `members`, `points` (sổ cái), `ranks` (engine hạng + Rank Trial), `notifications`, `settings`, `audit`, `uploads`. Đọc `ranks/` và `points/` làm mẫu chuẩn.

## 4. Thêm một module mới (công thức 6 bước)
1. **Migration mới** `db/migrations/00NN_<ten>.sql` nếu cần bảng/index (bảng mới PHẢI có `tenant_id` + RLS policy `tenant_isolation`; xem 0002). Không sửa migration cũ. Role `hvp_app` tự có quyền nhờ `ALTER DEFAULT PRIVILEGES` của 0002.
2. **Thư mục** `src/modules/<name>/` với 4 file dưới đây (rules thuần → repository → service → routes).
3. **Đăng ký** trong `src/container.ts` tại các anchor: import (`[imports]`), khai báo kiểu nếu cần để test truy cập (`[services]`), khởi tạo + gắn event listener (`[modules]`), push router (`[routers]`).
4. **Cấu hình**: tham số nghiệp vụ → thêm vào `settings/settings.catalog.ts`; đọc bằng `settings.getNumber('key')`.
5. **Liên module**: gọi sang module khác qua *port* (`shared/ports.ts` hoặc `*Port` của module đó), phản ứng sự kiện qua `eventBus.on(DomainEvents.X, …)`. Thêm tên event vào `DomainEvents` và payload vào `shared/events.ts`.
6. **Test** (xem `docs/TESTING_GUIDE.md`): unit cho rules, integration cho luồng chính + từ chối quyền.

### Mã khung (đã kiểm tra biên dịch)
**`src/modules/<name>/<name>.rules.ts`**

```ts
/** Pure business rules: no I/O, trivially unit-testable. */
export function canCancel(status: string): boolean {
  return status === 'OPEN';
}
```

**`src/modules/<name>/<name>.repository.ts`**

```ts
import { db } from '../../db/database';
import { sql } from '../../db/sql';

export interface <Name>Row {
  id: string;
  title: string;
  status: string;
}

/** SQL only. Every statement runs in the request's tenant transaction (row level security). */
export class <Name>Repository {
  list(limit: number, offset: number): Promise<<Name>Row[]> {
    return sql.many<<Name>Row>(`SELECT id, title, status FROM <name>s ORDER BY created_at DESC LIMIT $1 OFFSET $2`, [limit, offset]);
  }

  findById(id: string): Promise<<Name>Row | null> {
    return sql.one<<Name>Row>(`SELECT id, title, status FROM <name>s WHERE id = $1`, [id]);
  }

  insert(title: string): Promise<<Name>Row | null> {
    return sql.one<<Name>Row>(`INSERT INTO <name>s (tenant_id, title) VALUES ($1, $2) RETURNING id, title, status`, [db.currentTenantId(), title]);
  }
}
```

**`src/modules/<name>/<name>.service.ts`**

```ts
import { notFound, unprocessable } from '../../common/errors/app-error';
import { AuditService } from '../audit/audit.service';
import type { NotifierPort } from '../notifications/notification.service';
import { canCancel } from './<name>.rules';
import { <Name>Repository } from './<name>.repository';

/** Business rules and orchestration. Depends on ports, never on other modules' repositories. */
export class <Name>Service {
  constructor(
    private readonly repo: <Name>Repository,
    private readonly audit: AuditService,
    private readonly notifier: NotifierPort,
  ) {}

  list(limit: number, offset: number) {
    return this.repo.list(limit, offset);
  }

  async create(title: string, by: string) {
    const row = await this.repo.insert(title);
    await this.audit.record({ actorId: by, action: '<NAME>_CREATED', entityType: '<NAME>', entityId: row!.id, after: { title }, reason: 'Tạo mới' });
    return row!;
  }

  async assertCancellable(id: string) {
    const row = await this.repo.findById(id);
    if (!row) throw notFound('<Name>');
    if (!canCancel(row.status)) throw unprocessable('Mục này không thể huỷ.', '<NAME>_NOT_CANCELLABLE');
    return row;
  }
}
```

**`src/modules/<name>/<name>.routes.ts`**

```ts
import { Router } from 'express';
import { z } from 'zod';
import { authOf, created, handle, ok } from '../../common/http/handler';
import { pageMeta, paginationQuery, toPage } from '../../common/http/pagination';
import { requireAuth, requireRoles } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { RoleGroup } from '../../shared/roles';
import { <Name>Service } from './<name>.service';

const createBody = z.object({ title: z.string().trim().min(2).max(120) });

export function <name>Routes(service: <Name>Service): Router {
  const r = Router();
  r.use(requireAuth);
  r.get('/<name>s', requireRoles(...RoleGroup.STAFF), validate({ query: paginationQuery }), handle(async (req) => {
    const page = toPage(req.query as unknown as z.infer<typeof paginationQuery>);
    return ok(await service.list(page.limit, page.offset), pageMeta(page, 0));
  }));
  r.post('/<name>s', requireRoles(...RoleGroup.ADMINS), validate({ body: createBody }), handle(async (req) =>
    created(await service.create(req.body.title, authOf(req).userId)),
  ));
  return r;
}
```


Đăng ký trong `container.ts`:
```ts
const <name> = new <Name>Service(new <Name>Repository(), audit, notifications);
// ...
const routers: Router[] = [ /* … */ <name>Routes(<name>), ];
```

## 5. Quy tắc bắt buộc
1. Routes: luôn `requireAuth` + `requireRoles(...)` rõ ràng + `validate({ params, query, body })` bằng zod.
2. Service không biết `req/res`; repository không chứa luật nghiệp vụ; SQL chỉ nằm ở repository.
3. Chỉ ghi sổ cái qua `PointsPort.award` (kèm `idempotencyKey` cho thao tác có thể bị gọi lại). Không `INSERT INTO point_transactions` ở nơi khác.
4. Không `new Date()`/`Date.now()` trong nghiệp vụ → `clock.now()`.
5. Không hardcode con số nghiệp vụ → settings.
6. Hành động của staff/admin → `audit.record(...)` (kèm lý do).
7. Lỗi nghiệp vụ → `badRequest/forbidden/notFound/conflict/unprocessable(message, 'CODE')`: message tiếng Việt cho người dùng, `CODE` UPPER_SNAKE ổn định cho app.
8. Cập nhật cache tính toán dựa trên sự kiện, không gọi chéo module.
9. Bảng append-only (`audit_logs`, `inventory_movements`, `auth_logs`, `member_rank_history`, `streak_logs`, `batch_runs`) chỉ INSERT.

## 6. Batch job (SYS-xx)
`src/jobs/scheduler.ts` hiện là khung rỗng. Mỗi job nên là một phương thức idempotent của service (`runXxx(now = clock.now())`), chạy theo từng tenant:
```ts
for (const tenantId of await lookupActiveTenantIds()) {
  await db.tenantTx(tenantId, () => service.runXxx(clock.now()));
}
```
Đăng ký bằng `node-cron` trong `startScheduler`, ghi kết quả vào `batch_runs`. Bật/tắt bằng `ENABLE_SCHEDULER`.

## 7. Môi trường & bảo mật
- `.env` không commit; secret JWT tối thiểu 32 ký tự.
- Token truy cập ngắn hạn (15 phút) + refresh token xoay vòng dùng một lần.
- Upload ảnh (minh chứng, avatar) qua `POST /uploads?purpose=` rồi lưu URL; thay `LocalDiskStorage` bằng S3/MinIO bằng cách implement `StorageService`.
- Push: `PUSH_PROVIDER=console|fcm`; OTP: `OTP_PROVIDER=console` (cần nhà cung cấp SMS khi lên production).

## 8. Swagger UI (tài liệu API tự sinh)
- Chạy dev rồi mở http://localhost:4000/api/docs (JSON: `/api/docs.json`). Tắt khi `NODE_ENV=production`.
- Bấm **Authorize**, dán access token lấy từ `POST /auth/login`; header `X-Tenant-Code` tùy chọn (bỏ trống = tenant mặc định).
- Tài liệu sinh từ zod trong `validate()` và vai trò trong `requireRoles()` (xem `common/http/openapi.ts`), nên route mới tự xuất hiện, không cần khai báo thêm.
- Cấu trúc response chi tiết và quy tắc nghiệp vụ: tài liệu API trong `docs/`.
