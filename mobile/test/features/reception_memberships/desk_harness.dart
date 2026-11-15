import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hvp_forging/app/route_paths.dart';
import 'package:hvp_forging/core/design/hvp_text_styles.dart';
import 'package:hvp_forging/core/design/hvp_theme.dart';
import 'package:hvp_forging/core/widgets/entrance.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/screens/member_detail_screen.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/screens/reception_memberships_tab.dart';
import '../../helpers/test_harness.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/reception_checkin/data/member_search_repository_impl.dart';
import 'package:hvp_forging/features/reception_checkin/presentation/reception_providers.dart';
import 'package:hvp_forging/features/membership/data/membership_api.dart';
import 'package:hvp_forging/features/membership/data/membership_repository_impl.dart';
import 'package:hvp_forging/features/membership/presentation/providers/membership_providers.dart';
import 'package:hvp_forging/features/reception_memberships/data/reception_memberships_api.dart';
import 'package:hvp_forging/features/reception_memberships/data/reception_memberships_repository_impl.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/reception_memberships_providers.dart';

import '../../helpers/scripted_adapter.dart';

typedef Reply = ResponseBody Function(RequestOptions request);

/// A scripted API for the desk screens: routes are keyed `METHOD /path`, so the real repositories run.
class Desk {
  Desk(this.routes, {AuthUser? user})
      : user = user ??
            const AuthUser(
                id: 'desk',
                fullName: 'Lễ tân',
                appRole: AppRole.reception,
                roles: <String>['RECEPTIONIST']) {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(
          const StoredTokens(accessToken: 'a', refreshToken: 'r')),
    );
    adapter = ScriptedAdapter((o) =>
        routes['${o.method} ${o.path}']?.call(o) ??
        errorEnvelope(404, 'NOT_FOUND', 'no route ${o.method} ${o.path}'));
    dio.httpClientAdapter = adapter;
    api = ApiClient(dio);
  }

  final Map<String, Reply> routes;
  final AuthUser user;
  late final ScriptedAdapter adapter;
  late final ApiClient api;

  List<Override> get overrides => <Override>[
        currentUserProvider.overrideWithValue(user),
        currentUserIdProvider.overrideWithValue(user.id),
        receptionMembershipsRepositoryProvider.overrideWithValue(
            ReceptionMembershipsRepositoryImpl(ReceptionMembershipsApi(api))),
        membershipRepositoryProvider
            .overrideWithValue(MembershipRepositoryImpl(MembershipApi(api))),
        memberSearchRepositoryProvider
            .overrideWithValue(MemberSearchRepositoryImpl(api)),
        evidencePhotoBuilderProvider.overrideWithValue(fakePhotoField),
      ];

  /// Requests received for `METHOD /path`.
  List<RequestOptions> calls(String key) =>
      adapter.requests.where((o) => '${o.method} ${o.path}' == key).toList();
}

const String kEvidenceUrl = 'http://test.local/files/evidence/e.jpg';

/// Stands in for the camera: a button that "uploads" [kEvidenceUrl].
Widget fakePhotoField(BuildContext context, ValueChanged<String?> onChanged) =>
    TextButton(
        onPressed: () => onChanged(kEvidenceUrl),
        child: const Text('CHỌN ẢNH'));

/// The "Gói tập" tab with the member detail pushed from it, like the reception shell.
Future<void> pumpDeskApp(WidgetTester tester, Desk desk) async {
  HvpFonts.useGoogleFonts = false;
  hvpEntranceEnabled = false;
  usePhoneSurface(tester);
  final router = GoRouter(routes: <RouteBase>[
    GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: ReceptionMembershipsTab())),
    GoRoute(
        path: ReceptionPaths.membershipMemberPattern,
        builder: (_, state) =>
            MemberDetailScreen(memberId: state.pathParameters['memberId']!)),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: desk.overrides,
    child: MaterialApp.router(
        theme: HvpTheme.light(),
        darkTheme: HvpTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: router),
  ));
  await tester.pumpAndSettle();
}
