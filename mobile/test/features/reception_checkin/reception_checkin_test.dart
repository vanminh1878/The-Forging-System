import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hvp_forging/app/route_paths.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/design/hvp_text_styles.dart';
import 'package:hvp_forging/core/design/hvp_theme.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/core/widgets/entrance.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/checkin/data/checkin_repository_impl.dart';
import 'package:hvp_forging/features/checkin/domain/checkin_outcome.dart';
import 'package:hvp_forging/features/checkin/domain/checkin_repository.dart';
import 'package:hvp_forging/features/checkin/domain/checkin_session.dart';
import 'package:hvp_forging/features/checkin/presentation/checkin_providers.dart';
import 'package:hvp_forging/features/reception_checkin/data/member_search_repository_impl.dart';
import 'package:hvp_forging/features/reception_checkin/domain/member_hit.dart';
import 'package:hvp_forging/features/reception_checkin/presentation/member_today_screen.dart';
import 'package:hvp_forging/features/reception_checkin/presentation/reception_checkin_tab.dart';
import 'package:hvp_forging/features/reception_checkin/presentation/reception_providers.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

const _lan = MemberHit(
  id: 'm1',
  memberCode: 'HVP-AB12CD',
  fullName: 'Nguyễn Thị Lan',
  phone: '0912345678',
  status: 'ACTIVE',
  packageName: 'BOOK I',
);
const _frozen = MemberHit(
    id: 'm2', memberCode: 'HVP-ZZ99', fullName: 'Lan Anh', status: 'FROZEN');

CheckinSession _session(String id, String title,
        {CheckinState state = CheckinState.open, String? message}) =>
    CheckinSession(
      sessionId: id,
      title: title,
      sessionType: 'GROUP',
      isExam: false,
      startsAt: DateTime.utc(2026, 11, 2, 11),
      endsAt: DateTime.utc(2026, 11, 2, 12),
      branchId: 'q1',
      branchName: 'HVP The Corner',
      coachName: 'Minh',
      state: state,
      canCheckin: state == CheckinState.open,
      message: message,
      opensAt: DateTime.utc(2026, 11, 2, 10),
      closesAt: DateTime.utc(2026, 11, 2, 12),
    );

class FakeSearch implements MemberSearchRepository {
  FakeSearch(this.result);
  MemberSearchResult result;
  final List<String> queries = <String>[];

  @override
  Future<MemberSearchResult> search(String query) async {
    queries.add(query);
    return result;
  }
}

class FakeToday implements CheckinRepository {
  FakeToday(this.data);
  TodayCheckin data;
  final List<String> asked = <String>[];

  @override
  Future<TodayCheckin> today() async => data;

  @override
  Future<TodayCheckin> todayFor(String memberId) async {
    asked.add(memberId);
    return data;
  }

  @override
  Future<CheckinOutcome> submit(
          {String? payload, String? shortCode, String? sessionId}) =>
      throw UnimplementedError();

  @override
  Future<CheckedIn> checkInFor(
          {required String memberId,
          required String sessionId,
          required String evidenceUrl}) =>
      throw UnimplementedError('the list screens never check anyone in');
}

TodayCheckin _day(List<CheckinSession> sessions,
        {CheckinEligibility? eligibility}) =>
    TodayCheckin(
        date: '2026-11-02',
        eligibility: eligibility ?? const CheckinEligibility(canCheckin: true),
        sessions: sessions);

/// The reception tab with the member screen and the check-in hook behind it, like the reception shell.
Future<void> _pump(WidgetTester tester,
    {required FakeSearch search, required FakeToday today}) async {
  HvpFonts.useGoogleFonts = false;
  hvpEntranceEnabled = false;
  usePhoneSurface(tester);
  final router = GoRouter(routes: <RouteBase>[
    GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: ReceptionCheckinTab())),
    GoRoute(
      path: ReceptionPaths.memberTodayPattern,
      builder: (_, state) => MemberTodayScreen(
        memberId: state.pathParameters['memberId']!,
        member: state.extra is MemberHit ? state.extra! as MemberHit : null,
      ),
    ),
    GoRoute(
      path: ReceptionPaths.assistedCheckinPattern,
      builder: (_, state) => Scaffold(
          body: Text(
              'ASSISTED:${state.pathParameters['memberId']}:${state.pathParameters['sessionId']}')),
    ),
    GoRoute(
        path: ReceptionPaths.branchQr,
        builder: (_, __) => const Scaffold(body: Text('BRANCH-QR'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('desk'),
      memberSearchRepositoryProvider.overrideWithValue(search),
      checkinRepositoryProvider.overrideWithValue(today),
    ],
    child: MaterialApp.router(
        theme: HvpTheme.light(),
        darkTheme: HvpTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 400)); // past the debounce
  await tester.pumpAndSettle();
}

void main() {
  test(
      'CHK-10 repositories search the members and read a member\'s sessions of today',
      () async {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'desk-token', refreshToken: 'refresh')),
    );
    final adapter = ScriptedAdapter((request) {
      if (request.path == '/members') {
        return okEnvelope(<dynamic>[
          <String, dynamic>{
            'userId': 'm1',
            'memberCode': 'HVP-AB12CD',
            'fullName': 'Nguyễn Thị Lan',
            'phone': '0912345678',
            'avatarUrl': null,
            'status': 'ACTIVE',
            'rankName': 'THE UNKNOWN',
            'packageName': 'BOOK I',
          },
        ], meta: <String, dynamic>{
          'page': 1,
          'limit': 20,
          'total': '45',
          'totalPages': 3
        });
      }
      return okEnvelope(<String, dynamic>{
        'date': '2026-11-02',
        'eligibility': <String, dynamic>{'canCheckin': true},
        'sessions': <dynamic>[],
      });
    });
    dio.httpClientAdapter = adapter;
    final api = ApiClient(dio);

    final found = await MemberSearchRepositoryImpl(api).search('lan');
    expect(adapter.requests.last.path, '/members');
    expect(adapter.requests.last.queryParameters,
        <String, dynamic>{'q': 'lan', 'page': 1, 'limit': 20});
    expect(found.total, 45); // the server may send the count as text
    expect(found.hasMoreThanShown, isTrue);
    expect(
        found.items.single,
        isA<MemberHit>()
            .having((m) => m.id, 'id', 'm1')
            .having((m) => m.packageName, 'package', 'BOOK I'));
    expect(found.items.single.avatarUrl, isNull);

    await MemberSearchRepositoryImpl(api).search('');
    expect(adapter.requests.last.queryParameters,
        <String, dynamic>{'page': 1, 'limit': 20});

    final today = await CheckinRepositoryImpl(api).todayFor('m1');
    expect(adapter.requests.last.path, '/members/m1/checkin/sessions');
    expect(today.date, '2026-11-02');
  });

  testWidgets('lists the learners on open, before anything is typed',
      (tester) async {
    final search = FakeSearch(
        const MemberSearchResult(items: <MemberHit>[_lan], total: 1));
    await _pump(tester,
        search: search, today: FakeToday(_day(const <CheckinSession>[])));

    expect(search.queries, <String>['']);
    expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
  });

  testWidgets('an empty academy is not reported as a failed search',
      (tester) async {
    final search =
        FakeSearch(const MemberSearchResult(items: <MemberHit>[], total: 0));
    await _pump(tester,
        search: search, today: FakeToday(_day(const <CheckinSession>[])));

    expect(find.text('CHƯA CÓ HỌC VIÊN'), findsOneWidget);
    expect(find.text('KHÔNG TÌM THẤY HỌC VIÊN'), findsNothing);
  });

  testWidgets('shows the learners found with their status and package',
      (tester) async {
    final search = FakeSearch(
        const MemberSearchResult(items: <MemberHit>[_lan, _frozen], total: 2));
    await _pump(tester,
        search: search, today: FakeToday(_day(const <CheckinSession>[])));
    await _type(tester, 'Lan');

    expect(search.queries, <String>['', 'Lan']);
    expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
    expect(find.text('0912345678 · HVP-AB12CD'), findsOneWidget);
    expect(find.text('HOẠT ĐỘNG'), findsOneWidget);
    expect(find.text('BOOK I'), findsOneWidget);
    expect(find.text('ĐÓNG BĂNG'), findsOneWidget);
    expect(find.text('CHƯA CÓ GÓI'), findsOneWidget);
    expect(find.text('2 học viên'), findsOneWidget);
  });

  testWidgets(
      'says when there are more matches than shown, and when there are none',
      (tester) async {
    final search = FakeSearch(
        const MemberSearchResult(items: <MemberHit>[_lan], total: 45));
    await _pump(tester,
        search: search, today: FakeToday(_day(const <CheckinSession>[])));
    await _type(tester, 'Nguy');
    expect(find.text('Hiển thị 1 trên 45 học viên. Gõ thêm để thu hẹp.'),
        findsOneWidget);

    search.result = const MemberSearchResult(items: <MemberHit>[], total: 0);
    await _type(tester, 'Nguyễn Văn Zzz');
    expect(find.text('KHÔNG TÌM THẤY HỌC VIÊN'), findsOneWidget);
  });

  testWidgets(
      'opens the learner and lists their sessions, offering check-in only for open ones',
      (tester) async {
    final search = FakeSearch(
        const MemberSearchResult(items: <MemberHit>[_lan], total: 1));
    final today = FakeToday(_day(<CheckinSession>[
      _session('s1', 'Evening class'),
      _session('s2', 'Late class',
          state: CheckinState.closed,
          message: 'Buổi tập đã kết thúc, không thể check-in.'),
    ]));
    await _pump(tester, search: search, today: today);
    await _type(tester, 'Lan');
    await tester.tap(find.text('Nguyễn Thị Lan'));
    await tester.pumpAndSettle();

    expect(today.asked, <String>['m1']);
    expect(
        find.text('Nguyễn Thị Lan'), findsOneWidget); // the member card on top
    expect(find.text('Evening class'), findsOneWidget);
    expect(find.text('ĐANG MỞ CHECK-IN'), findsOneWidget);
    expect(find.text('ĐÃ ĐÓNG CHECK-IN'), findsOneWidget);
    expect(
        find.text('Buổi tập đã kết thúc, không thể check-in.'), findsOneWidget);
    expect(
        find.text('CHECK-IN HỘ'), findsOneWidget); // not for the closed session
  });

  testWidgets(
      'the check-in button goes on to the check-in with this learner and session',
      (tester) async {
    final search = FakeSearch(
        const MemberSearchResult(items: <MemberHit>[_lan], total: 1));
    await _pump(tester,
        search: search,
        today:
            FakeToday(_day(<CheckinSession>[_session('s1', 'Evening class')])));
    await _type(tester, 'Lan');
    await tester.tap(find.text('Nguyễn Thị Lan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHECK-IN HỘ'));
    await tester.pumpAndSettle();
    expect(find.text('ASSISTED:m1:s1'), findsOneWidget);
  });

  testWidgets('explains why a learner cannot check in at all', (tester) async {
    final search = FakeSearch(
        const MemberSearchResult(items: <MemberHit>[_frozen], total: 1));
    final today = FakeToday(_day(
      <CheckinSession>[
        _session('s1', 'Evening class',
            state: CheckinState.blocked, message: 'Tài khoản đang đóng băng.')
      ],
      eligibility: const CheckinEligibility(
          canCheckin: false,
          code: 'ACCOUNT_RESTRICTED',
          message: 'Tài khoản đang đóng băng.'),
    ));
    await _pump(tester, search: search, today: today);
    await _type(tester, 'Lan');
    await tester.tap(find.text('Lan Anh'));
    await tester.pumpAndSettle();

    expect(find.text('Tài khoản đang đóng băng.'),
        findsNWidgets(2)); // the banner and the session
    expect(find.text('CHECK-IN HỘ'), findsNothing);
  });

  testWidgets('says so when the learner has no session today', (tester) async {
    final search = FakeSearch(
        const MemberSearchResult(items: <MemberHit>[_lan], total: 1));
    await _pump(tester,
        search: search, today: FakeToday(_day(const <CheckinSession>[])));
    await _type(tester, 'Lan');
    await tester.tap(find.text('Nguyễn Thị Lan'));
    await tester.pumpAndSettle();
    expect(find.text('KHÔNG CÓ BUỔI NÀO HÔM NAY'), findsOneWidget);
  });

  testWidgets('has a way to the branch QR screen for the tablet at the desk',
      (tester) async {
    await _pump(tester,
        search: FakeSearch(
            const MemberSearchResult(items: <MemberHit>[], total: 0)),
        today: FakeToday(_day(const <CheckinSession>[])));
    await tester.tap(find.text('HIỂN THỊ MÃ QR QUẦY'));
    await tester.pumpAndSettle();
    expect(find.text('BRANCH-QR'), findsOneWidget);
  });
}
