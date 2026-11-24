# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

HVP The Forging System: membership + gamification for a boxing gym chain (packages, check-in, discipline points "DP", HVP Marks, ranks, streaks, challenges, Armory rewards). Monorepo: `backend/` (Node 20 / TypeScript / Express / PostgreSQL 16, multi-tenant with RLS), `mobile/` (Flutter / Riverpod / go_router / Dio), `docker/`, `docs/`.

**Language convention:** code, comments, identifiers in English; user-facing text (error messages, UI strings) and docs in Vietnamese.

The `docs/` folder holds the detailed guides (ARCHITECTURE, BACKEND_GUIDE, MOBILE_GUIDE, TESTING_GUIDE, DEPLOY_DIGITALOCEAN). Read the relevant one before larger changes.

**Mandatory:** before editing any file, read and follow @docs/WORKFLOW_CODE_CHUAN.md (the plan must get the user's "OK" before any code is written).

## Commands

```bash
docker compose up --build                          # postgres + api (auto migrate + reference seed), API on :4000
SEED_DEMO=true docker compose up -d --build api    # + demo accounts, password hvp12345 (admin 0900000001, student 0911000001…)
docker compose up -d postgres                      # just the DB (creates hvp_app role + hvp_test DB)

# backend/
npm run dev | build | typecheck | lint | format
npm run migrate && npm run seed && npm run seed:demo
npm test                                           # unit (no DB)
npm run test:integration                           # needs Postgres; uses DB hvp_test
npx vitest run --project integration tests/integration/auth.test.ts   # single file
npx vitest run -t "restoration"                    # by test name

# mobile/
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1   # also TENANT_CODE (default hvp)
flutter test
flutter analyze
dart format lib test                               # CI fails on unformatted code
python3 tool/check_imports.py lib test             # missing/unused project imports
```

CI (`.github/workflows/ci.yml`): backend typecheck → lint → unit → integration; mobile `dart format --set-exit-if-changed` → analyze → test.

## Backend architecture

Request flow: middleware (`resolveTenant`, `requireAuth`, `requireRoles`, `validate` with zod) → `*.routes.ts` → `*.service.ts` (business rules, no req/res) → `*.repository.ts` (raw SQL via `db/sql.ts` helpers only) → Postgres. Pure logic lives in `*.rules.ts` / `rank.engine.ts` and is unit-tested. `ranks/` and `points/` are the reference modules.

- **Transactions + tenancy:** `handle()` (`common/http/handler.ts`) wraps each request in one `db.tenantTx` that sets `app.current_tenant_id`. The API connects as `hvp_app` (non-owner, no BYPASSRLS) so RLS always applies; migrations run as `hvp_owner`. Every new table needs `tenant_id` + a `tenant_isolation` RLS policy (see migration 0002). `db.afterCommit(fn)` for non-transactional side effects (push).
- **Composition root:** `src/container.ts` is the only place objects are constructed (manual DI). New modules register at the `// [imports|services|modules|routers:feature-modules]` anchors.
- **Cross-module:** never import another module's repository. Commands/queries go through ports (`shared/ports.ts`, `*Port` types); notifications through domain events (`common/events/event-bus.ts`, names in `DomainEvents`, payloads in `shared/events.ts`). Event handlers are awaited sequentially **inside the same transaction**, so they commit or roll back with the triggering action.
- **Points ledger:** only `PointsService` via `PointsPort.award` writes `point_transactions` (one row carries both `dp_amount` and `marks_amount`). POSTED rows are immutable; corrections are `REVERSAL` or `MANUAL_ADJUSTMENT` with reason + audit. DB triggers keep `members.dp_balance/marks_balance` in sync and block negative balances. Pass an `idempotencyKey` for retryable actions. Monthly caps apply only to certain sources (see `points.rules.ts`).
- **Ranks:** every DP change emits `POINTS_AWARDED` → `RankService.reevaluate` (promote/demote/restore, badges). Time-gate is time spent in the *current* rank (`member_rank_history.earned_at`); V→VI needs a coach Rank Trial, VI→VII an admin one (migration 0003).
- **Time:** never `new Date()`/`Date.now()` in business code — use `clock.now()` and `common/utils/time.ts` (`APP_TIMEZONE`, Mon–Sun weeks). Tests use `setClock(fixedClock(...))`.
- **Config:** business numbers (caps, thresholds, durations) go in `settings/settings.catalog.ts`, read via `settings.getNumber('key')`; admins override in `system_configs`. Don't hardcode.
- **Errors:** throw `badRequest/forbidden/notFound/conflict/unprocessable(message, 'CODE')` from `common/errors/app-error.ts` — Vietnamese message, stable UPPER_SNAKE code.
- Staff/admin actions → `audit.record(...)` with a reason. Append-only tables (`audit_logs`, `auth_logs`, `member_rank_history`, `streak_logs`, `batch_runs`, `inventory_movements`) are INSERT-only.
- **Migrations** (`db/migrations/00NN_*.sql`) are forward-only; never edit a merged one.
- Batch jobs: idempotent `runXxx(now = clock.now())` service methods run per tenant inside `db.tenantTx`, registered in `jobs/scheduler.ts` (gated by `ENABLE_SCHEDULER`).

### Integration tests
`global-setup` drops and re-migrates the test DB each run; each file calls `bootTestApp()` (resets data + reference seed), and files run in a single fork — so tests must not depend on other files' data. The test DB name **must end in `_test`** or the suite refuses to run. Helpers in `tests/helpers/test-app.ts`: `registerMember`, `createStaff` + `login`, `bearer`, `ctx.tx(...)` (run service code in a tenant tx), `ownerQuery` (bypasses RLS — fixtures/assertions only). Cover success, 401/403, 400 validation, idempotency, and edge thresholds via `setClock`.

## Mobile architecture

One app, four role shells (`student|coach|reception|admin`) selected from `user.appRole` after login; routes per role in `lib/app/routes/<role>_routes.dart`, path constants in `route_paths.dart`, redirect rules in `role_redirect.dart`. Most tabs are still `ComingSoonPage` placeholders.

Features are `lib/features/<name>/{domain,data,presentation}`; `fighter_record` is the reference feature (follow the 7-step recipe in `mobile/README.md`). Domain is pure Dart (entities, rules, abstract repository); data has `<name>_api.dart` over `ApiClient`, DTO mappers, repository impl; presentation exposes a `Provider<Repository>` that tests override.

Rules: colors/text styles only via `context.hvp` / `context.txt` (no hex in feature widgets); no business logic in widgets; Riverpod only, no code generation; no `dart:io` in shared code (app must run on web); every screen handles loading (`AsyncBody`), empty (`EmptyState`) and error states. Tests: repositories with `test/helpers/scripted_adapter.dart`, screens with `pumpHvp(..., overrides: [...])`; no golden tests.
