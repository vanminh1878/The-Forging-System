import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hvp_forging/app/route_paths.dart';
import 'package:hvp_forging/core/design/hvp_text_styles.dart';
import 'package:hvp_forging/core/design/hvp_theme.dart';
import 'package:hvp_forging/core/widgets/entrance.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/design/hvp_icons.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/notifications/data/notification_repository_impl.dart';
import 'package:hvp_forging/features/notifications/domain/app_notification.dart';
import 'package:hvp_forging/features/notifications/presentation/notification_providers.dart';
import 'package:hvp_forging/features/notifications/presentation/notification_target.dart';
import 'package:hvp_forging/features/notifications/presentation/notifications_screen.dart';
import 'package:hvp_forging/features/notifications/presentation/widgets/notification_bell.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

AppNotification _n(String id, {bool read = false, String event = 'BROADCAST', String? title}) => AppNotification(
      id: id,
      eventType: event,
      title: title ?? 'Thông báo $id',
      body: 'Nội dung $id',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: read,
    );

class FakeNotifications implements NotificationRepository {
  FakeNotifications(this.pages, {this.unread = 0});

  final List<List<AppNotification>> pages;
  int unread;
  bool failWrites = false;
  final List<int> pageCalls = <int>[];
  final List<String> reads = <String>[];
  int readAllCalls = 0;

  @override
  Future<NotificationPage> list({required int page, required int limit}) async {
    pageCalls.add(page);
    final items = page <= pages.length ? pages[page - 1] : const <AppNotification>[];
    return NotificationPage(items: items, unread: unread, total: pages.fold<int>(0, (sum, p) => sum + p.length), hasMore: page < pages.length);
  }

  int unreadCalls = 0;
  bool failUnreadCount = false;

  @override
  Future<int> unreadCount() async {
    unreadCalls++;
    if (failUnreadCount) throw const ApiException(code: ApiErrorCodes.network, message: 'Không có kết nối mạng.');
    return unread;
  }

  @override
  Future<void> markRead(String id) async {
    if (failWrites) throw const ApiException(code: ApiErrorCodes.network, message: 'Không có kết nối mạng.');
    reads.add(id);
    if (unread > 0) unread--;
  }

  @override
  Future<void> markAllRead() async {
    if (failWrites) throw const ApiException(code: ApiErrorCodes.network, message: 'Không có kết nối mạng.');
    readAllCalls++;
    unread = 0;
  }
}

Future<void> _pump(WidgetTester tester, FakeNotifications repo) async {
  await pumpHvp(tester, const NotificationsScreen(), overrides: [
    currentUserIdProvider.overrideWithValue('member'),
    notificationRepositoryProvider.overrideWithValue(repo),
  ]);
  await tester.pumpAndSettle();
}

int _dots(WidgetTester tester) => find.byKey(const ValueKey<String>('unread-dot')).evaluate().length;

void main() {
  test('NTF-02 repository reads the inbox, the unread count, the total and whether another page follows', () async {
    final dio = createApiDio(
      config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(accessToken: 'member-token', refreshToken: 'refresh')),
    );
    Map<String, dynamic> raw(String id, bool read) => <String, dynamic>{
          'id': id,
          'eventType': 'RANK_EARNED',
          'title': 'RANK EARNED',
          'body': 'Bạn đã lên hạng',
          'payload': <String, dynamic>{'rank': 'THE INITIATED'},
          'createdAt': '2026-11-02T10:00:00.000Z',
          'isRead': read,
        };
    final adapter = ScriptedAdapter((request) {
      if (request.method == 'POST') return okEnvelope(null);
      final page = request.queryParameters['page'] as int;
      return okEnvelope(<dynamic>[raw('a', false), raw('b', true)],
          meta: <String, dynamic>{'page': page, 'limit': 2, 'total': 5, 'totalPages': 3, 'unread': 4});
    });
    dio.httpClientAdapter = adapter;
    final repo = NotificationRepositoryImpl(ApiClient(dio));

    final first = await repo.list(page: 1, limit: 2);
    expect(adapter.requests.last.path, '/me/notifications');
    expect(adapter.requests.last.queryParameters, <String, dynamic>{'page': 1, 'limit': 2});
    expect(first.unread, 4);
    expect(first.total, 5);
    expect(first.hasMore, isTrue); // page 1 of 3
    expect(first.items.map((n) => n.isRead), <bool>[false, true]);
    expect(first.items.first.payload['rank'], 'THE INITIATED');
    expect(first.items.first.createdAt, DateTime.utc(2026, 11, 2, 10));

    expect((await repo.list(page: 3, limit: 2)).hasMore, isFalse); // the last page of 3

    await repo.markRead('a');
    expect(adapter.requests.last.path, '/me/notifications/a/read');
    await repo.markAllRead();
    expect(adapter.requests.last.path, '/me/notifications/read-all');
  });

  test('every event has an icon and unknown ones fall back to the bell', () {
    expect(notificationIcon('RANK_EARNED'), HvpIcons.trophy);
    expect(notificationIcon('RANK_LOST'), HvpIcons.trophy);
    expect(notificationIcon('STREAK_WARNING'), HvpIcons.fire);
    expect(notificationIcon('SESSION_COMPLETED'), HvpIcons.checks);
    expect(notificationIcon('BROADCAST'), HvpIcons.bell);
    expect(notificationIcon('SOMETHING_NEW'), HvpIcons.bell);
  });

  testWidgets('lists the notifications and marks the unread ones', (tester) async {
    final repo = FakeNotifications(<List<AppNotification>>[
      <AppNotification>[_n('1'), _n('2', read: true), _n('3')],
    ], unread: 2);
    await _pump(tester, repo);
    expect(find.text('Thông báo 1'), findsOneWidget);
    expect(find.text('Nội dung 2'), findsOneWidget);
    expect(_dots(tester), 2);
    expect(find.text('Đọc tất cả'), findsOneWidget);
  });

  testWidgets('tapping a notification reads it, and reading the last one hides "Đọc tất cả"', (tester) async {
    final repo = FakeNotifications(<List<AppNotification>>[
      <AppNotification>[_n('1'), _n('2')],
    ], unread: 2);
    await _pump(tester, repo);

    await tester.tap(find.text('Thông báo 1'));
    await tester.pumpAndSettle();
    expect(repo.reads, <String>['1']);
    expect(_dots(tester), 1);
    expect(find.text('Đọc tất cả'), findsOneWidget);

    await tester.tap(find.text('Thông báo 1')); // already read: nothing more to send
    await tester.pumpAndSettle();
    expect(repo.reads, <String>['1']);

    await tester.tap(find.text('Thông báo 2'));
    await tester.pumpAndSettle();
    expect(_dots(tester), 0);
    expect(find.text('Đọc tất cả'), findsNothing);
  });

  testWidgets('"Đọc tất cả" reads everything at once', (tester) async {
    final repo = FakeNotifications(<List<AppNotification>>[
      <AppNotification>[_n('1'), _n('2'), _n('3', read: true)],
    ], unread: 2);
    await _pump(tester, repo);
    await tester.tap(find.text('Đọc tất cả'));
    await tester.pumpAndSettle();
    expect(repo.readAllCalls, 1);
    expect(_dots(tester), 0);
    expect(find.text('Đọc tất cả'), findsNothing);
  });

  testWidgets('puts the notification back to unread and says so when the server refuses', (tester) async {
    final repo = FakeNotifications(<List<AppNotification>>[
      <AppNotification>[_n('1')],
    ], unread: 1)
      ..failWrites = true;
    await _pump(tester, repo);
    await tester.tap(find.text('Thông báo 1'));
    await tester.pumpAndSettle();
    expect(_dots(tester), 1);
    expect(find.text('Đọc tất cả'), findsOneWidget);
    expect(find.text('Không đánh dấu đã đọc được. Vui lòng thử lại.'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4)); // let the toast go
    await tester.tap(find.text('Đọc tất cả'));
    await tester.pumpAndSettle();
    expect(_dots(tester), 1);
    expect(find.text('Không đánh dấu đã đọc được. Vui lòng thử lại.'), findsOneWidget);
  });

  testWidgets('loads the next page on "Xem thêm" and stops when a page comes back short', (tester) async {
    final first = <AppNotification>[for (var i = 1; i <= 20; i++) _n('a$i', read: true, title: 'Cũ $i')];
    final second = <AppNotification>[_n('b1', read: true, title: 'Cũ 21'), _n('a20', read: true, title: 'Trùng')];
    final repo = FakeNotifications(<List<AppNotification>>[first, second]);
    await _pump(tester, repo);

    // The list builds rows lazily: the footer only exists once scrolled to.
    await tester.scrollUntilVisible(find.text('XEM THÊM'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('XEM THÊM'));
    await tester.pumpAndSettle();
    expect(repo.pageCalls, <int>[1, 2]);
    await tester.scrollUntilVisible(find.text('Cũ 21'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Cũ 21'), findsOneWidget);
    expect(find.text('Trùng'), findsNothing); // already on screen from page 1
    expect(find.text('XEM THÊM'), findsNothing);
  });

  testWidgets('says so when there is nothing yet', (tester) async {
    await _pump(tester, FakeNotifications(<List<AppNotification>>[<AppNotification>[]]));
    expect(find.text('CHƯA CÓ THÔNG BÁO'), findsOneWidget);
    expect(find.text('Đọc tất cả'), findsNothing);
  });

  group('NTF-04 opening a notification', () {
    test('maps each event to the screen it is about, and leaves the generic ones without a target', () {
      NotificationTarget? t(String e) => notificationTarget(e);
      expect(t('RANK_EARNED')?.path, StudentPaths.fighterRecord);
      expect(t('RANK_TRIAL_FAILED')?.path, StudentPaths.fighterRecord);
      expect(t('SESSION_COMPLETED')?.path, StudentPaths.fighterRecord);
      expect(t('STREAK_WARNING')?.path, StudentPaths.streak);
      expect(t('INACTIVE_7D')?.path, StudentPaths.streak);
      expect(t('CHALLENGE')?.path, StudentPaths.challenges);
      expect(t('CHALLENGE_JOINED')?.path, StudentPaths.currentChallenges);
      expect(t('CHALLENGE_JOIN_APPROVED')?.path, StudentPaths.currentChallenges);
      expect(t('CHALLENGE_COMPLETED')?.path, StudentPaths.currentChallenges);
      expect(t('CHALLENGE_REWARDED')?.path, StudentPaths.currentChallenges);
      expect(t('RENEWAL_COMPLETED')?.path, StudentPaths.membership);
      expect(t('MEMBERSHIP_EXPIRE')?.path, StudentPaths.membership);
      expect(t('BOOK_COMPLETED')?.path, StudentPaths.courses);
      expect(t('ARMORY_READY')?.path, StudentPaths.armory);
      expect(t('ARMORY_READY')?.isTab, isTrue);
      expect(t('EXAM')?.path, StudentPaths.schedule);
      expect(t('RANK_EARNED')?.isTab, isFalse);
      expect(t('WELCOME'), isNull);
      expect(t('BROADCAST'), isNull);
      expect(t('SOMETHING_NEW'), isNull);
    });

    Future<GoRouter> pumpInbox(WidgetTester tester, FakeNotifications repo) async {
      HvpFonts.useGoogleFonts = false;
      hvpEntranceEnabled = false;
      usePhoneSurface(tester);
      Widget page(String text) => Scaffold(appBar: AppBar(), body: Text(text));
      final router = GoRouter(initialLocation: StudentPaths.notifications, routes: <RouteBase>[
        GoRoute(path: StudentPaths.notifications, builder: (_, __) => const NotificationsScreen()),
        GoRoute(path: StudentPaths.fighterRecord, builder: (_, __) => page('FIGHTER RECORD')),
        GoRoute(path: StudentPaths.armory, builder: (_, __) => page('ARMORY')),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('member'),
          notificationRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(theme: HvpTheme.light(), darkTheme: HvpTheme.dark(), themeMode: ThemeMode.dark, routerConfig: router),
      ));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('reads the notification and opens its screen, and back returns to the inbox', (tester) async {
      final repo = FakeNotifications(<List<AppNotification>>[
        <AppNotification>[_n('1', event: 'RANK_EARNED')],
      ], unread: 1);
      await pumpInbox(tester, repo);
      await tester.tap(find.text('Thông báo 1'));
      await tester.pumpAndSettle();
      expect(repo.reads, <String>['1']);
      expect(find.text('FIGHTER RECORD'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Thông báo 1'), findsOneWidget);
      expect(_dots(tester), 0);
    });

    testWidgets('opens a tab destination with go', (tester) async {
      final repo = FakeNotifications(<List<AppNotification>>[
        <AppNotification>[_n('1', event: 'ARMORY_READY')],
      ], unread: 1);
      final router = await pumpInbox(tester, repo);
      await tester.tap(find.text('Thông báo 1'));
      await tester.pumpAndSettle();
      expect(find.text('ARMORY'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, StudentPaths.armory);
    });

    testWidgets('stays on the inbox for a notification with no screen', (tester) async {
      final repo = FakeNotifications(<List<AppNotification>>[
        <AppNotification>[_n('1', event: 'BROADCAST')],
      ], unread: 1);
      await pumpInbox(tester, repo);
      await tester.tap(find.text('Thông báo 1'));
      await tester.pumpAndSettle();
      expect(repo.reads, <String>['1']);
      expect(find.text('Thông báo 1'), findsOneWidget);
    });

    testWidgets('still opens the screen when marking it read fails, and says so', (tester) async {
      final repo = FakeNotifications(<List<AppNotification>>[
        <AppNotification>[_n('1', event: 'RANK_EARNED')],
      ], unread: 1)
        ..failWrites = true;
      await pumpInbox(tester, repo);
      await tester.tap(find.text('Thông báo 1'));
      await tester.pumpAndSettle();
      expect(find.text('FIGHTER RECORD'), findsOneWidget);
      expect(find.text('Không đánh dấu đã đọc được. Vui lòng thử lại.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 4)); // let the toast go
    });
  });

  group('NTF-03 bell', () {
    /// A home page with the bell in its app bar, and the inbox one tap away, like the student shell.
    Future<void> pumpBell(WidgetTester tester, FakeNotifications repo, {String? userId = 'member'}) async {
      HvpFonts.useGoogleFonts = false;
      hvpEntranceEnabled = false;
      usePhoneSurface(tester);
      final router = GoRouter(routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(appBar: AppBar(actions: const <Widget>[NotificationBell()]), body: const Text('HOME')),
        ),
        GoRoute(path: StudentPaths.notifications, builder: (_, __) => const NotificationsScreen()),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(userId),
          notificationRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(theme: HvpTheme.light(), darkTheme: HvpTheme.dark(), themeMode: ThemeMode.dark, routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    FakeNotifications server({int unread = 3}) => FakeNotifications(<List<AppNotification>>[
          <AppNotification>[for (var i = 1; i <= unread; i++) _n('$i')],
        ], unread: unread);

    test('the repository reads the unread count', () async {
      final dio = createApiDio(
        config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
        tokens: MemoryTokenStore(const StoredTokens(accessToken: 'member-token', refreshToken: 'refresh')),
      );
      final adapter = ScriptedAdapter((request) => okEnvelope(<String, dynamic>{'unread': 7}));
      dio.httpClientAdapter = adapter;
      expect(await NotificationRepositoryImpl(ApiClient(dio)).unreadCount(), 7);
      expect(adapter.requests.last.path, '/me/notifications/unread-count');
    });

    testWidgets('shows how many are unread', (tester) async {
      await pumpBell(tester, server(unread: 3));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows no badge when there is nothing unread', (tester) async {
      await pumpBell(tester, server(unread: 0));
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });

    testWidgets('caps a long count at 99+', (tester) async {
      await pumpBell(tester, FakeNotifications(<List<AppNotification>>[<AppNotification>[]], unread: 250));
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('opens the inbox, and the number follows what was read there', (tester) async {
      final repo = server(unread: 3);
      await pumpBell(tester, repo);

      await tester.tap(find.byType(NotificationBell));
      await tester.pumpAndSettle();
      expect(find.text('Thông báo 1'), findsOneWidget);

      await tester.tap(find.text('Thông báo 1'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('clears the badge after reading everything', (tester) async {
      final repo = server(unread: 3);
      await pumpBell(tester, repo);
      await tester.tap(find.byType(NotificationBell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đọc tất cả'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });

    testWidgets('looks again every minute and picks up new notifications', (tester) async {
      final repo = server(unread: 1);
      await pumpBell(tester, repo);
      expect(find.text('1'), findsOneWidget);
      final before = repo.unreadCalls;

      repo.unread = 4; // something arrived on the server
      await tester.pump(bellRefreshEvery);
      await tester.pumpAndSettle();
      expect(repo.unreadCalls, greaterThan(before));
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('keeps the last number when a refresh fails', (tester) async {
      final repo = server(unread: 2);
      await pumpBell(tester, repo);
      repo.failUnreadCount = true;
      await tester.pump(bellRefreshEvery);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('does not ask the server while nobody is signed in', (tester) async {
      final repo = server(unread: 5);
      await pumpBell(tester, repo, userId: null);
      expect(repo.unreadCalls, 0);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });
  });
}
