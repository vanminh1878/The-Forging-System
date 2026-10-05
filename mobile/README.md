# HVP The Forging System - mobile app

One Flutter app, four role experiences (`student`, `coach`, `reception`, `admin`) chosen after login
from `user.appRole` returned by the API. UI text is Vietnamese; code, comments and identifiers are English.

This is the **base project**: foundation, auth, the four role shells (every tab is a `ComingSoonPage`
placeholder) and one complete reference feature, `fighter_record`. Business screens are added feature by feature.

## Setup

```bash
cd mobile
flutter create . --platforms=android,ios,web --org vn.hvp --project-name hvp_forging   # once
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

| `--dart-define` | Default | Notes |
|---|---|---|
| `API_BASE_URL` | `http://localhost:4000/api/v1` | Android emulator: `http://10.0.2.2:4000/api/v1` |
| `TENANT_CODE` | `hvp` | Sent as `X-Tenant-Code` |

## Test and check

```bash
flutter test
flutter analyze
python3 tool/check_syntax.py lib test     # parser-only check (pip install tree-sitter tree-sitter-dart)
python3 tool/check_imports.py lib test    # missing / unused project imports, no SDK needed
```

## Structure

```
lib/
  main.dart                      ProviderScope + SharedPreferences override
  app/
    hvp_app.dart                 MaterialApp.router, theme mode, vi_VN
    router.dart                  GoRouter composition + refresh on auth change
    role_redirect.dart           pure redirect rules (splash / login / role guard)
    route_paths.dart             every path constant (AppPaths, StudentPaths, ...)
    routes/<role>_routes.dart    tabs + pushed screens of one role   <- features register here
    shell/                       RoleShell (app bar + floating nav), account panel, theme switch
  core/
    config/ network/ storage/ error/ utils/ state/ branch/
    design/                      tokens (HvpColors, HvpTextStyles), theme, chamfer border, tape, rank palette
    widgets/                     HvpButton, HvpCard, RankBadge, DpGauge, AsyncBody, states, nav bar, ...
  features/
    auth/                        login, register, forgot password (PIN), session restore, logout
    fighter_record/              REFERENCE FEATURE (student)
test/                            mirrors lib/; fakes live in test/helpers and per-feature fixtures.dart
```

Rules: colours and text styles only from `context.hvp` / `context.txt` (no hex in feature widgets);
no business rules in widgets (put them in `domain/` and unit-test them); Riverpod only; no code generation;
no `dart:io` in shared code so the app runs on web.

## Add a feature (recipe, using `fighter_record` as the model)

1. **Folder** `lib/features/<name>/{domain,data,presentation}`.
2. **Domain** - pure Dart: entities (`rank_models.dart`), rules (`rank_rules.dart`), and an abstract repository
   (`fighter_record_repository.dart`). No Flutter, no JSON.
3. **Data** - `<name>_api.dart` (raw calls through `ApiClient`), `dto/*.dart` (JSON -> entity mappers using
   `json_utils`), `<name>_repository_impl.dart`. Read the backend `*.routes.ts` for the exact shapes.
4. **Presentation/providers** - one `Provider<Repository>` that tests override, then `FutureProvider.autoDispose`
   (or an `AsyncNotifier` for pagination, see `ledger_notifier.dart`) that also `ref.watch(currentUserIdProvider)`.
   Forms/actions use `SubmitNotifier` (`core/state`).
5. **Presentation/screens + widgets** - wrap async data in `AsyncBody` (shimmer / error + retry built in), use
   `EmptyState` for empty lists, `HvpRefresh` for pull-to-refresh, `.entrance(i)` for staggered entrances,
   files under ~250 lines.
6. **Register** - in `lib/app/routes/<role>_routes.dart` replace the tab's `ComingSoonPage` builder, or add a
   `GoRoute` for a pushed screen (constant in `route_paths.dart`). Other features' files stay untouched.
7. **Tests** - `test/features/<name>/`: domain rules, DTO parsing, repository (scripted Dio adapter in
   `test/helpers/scripted_adapter.dart`), and screens with `pumpHvp(..., overrides: [repositoryProvider.overrideWithValue(fake)])`.

## Notes

- Auth: access token + rotating refresh token in secure storage; one single-flight refresh on 401
  (`core/network/interceptors.dart`); a rejected refresh signs the user out.
- Push notifications are a no-op hook (`PushRegistrar` in `features/auth/domain`); wire FCM/APNs there later.
- `GET /me/rank` has no DP balance field; the gauge derives it from `dpRemaining` (see `estimateDp`).
