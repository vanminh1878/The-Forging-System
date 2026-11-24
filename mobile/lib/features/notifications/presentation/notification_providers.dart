import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/network/network_providers.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/notification_repository_impl.dart';
import '../domain/app_notification.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  final role = ref.watch(currentUserProvider)?.appRole;
  return NotificationRepositoryImpl(
    ref.watch(apiClientProvider),
    isStaff: role != null && role != AppRole.student,
  );
});

/// Loaded pages of the inbox.
class NotificationsState {
  const NotificationsState({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.unread,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<AppNotification> items;
  final int page;
  final bool hasMore;
  final int unread;
  final bool loadingMore;
  final String? loadMoreError;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? page,
    bool? hasMore,
    int? unread,
    bool? loadingMore,
    String? loadMoreError,
    bool clearError = false,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        unread: unread ?? this.unread,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
      );
}

/// The paginated inbox. Marking as read is applied on screen at once and given back if the server refuses.
class NotificationsNotifier extends AutoDisposeAsyncNotifier<NotificationsState> {
  static const int pageSize = 20;

  @override
  Future<NotificationsState> build() async {
    ref.watch(currentUserIdProvider);
    final page = await ref.read(notificationRepositoryProvider).list(page: 1, limit: pageSize);
    return NotificationsState(items: page.items, page: 1, hasMore: page.hasMore, unread: page.unread);
  }

  /// Appends the next page. A failure is kept in the state so the rows already loaded stay on screen.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData<NotificationsState>(current.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await ref.read(notificationRepositoryProvider).list(page: current.page + 1, limit: pageSize);
      final seen = current.items.map((n) => n.id).toSet(); // new notifications shift the pages: skip repeats
      state = AsyncData<NotificationsState>(
        NotificationsState(
          items: <AppNotification>[...current.items, ...page.items.where((n) => !seen.contains(n.id))],
          page: current.page + 1,
          hasMore: page.hasMore,
          unread: page.unread,
        ),
      );
    } catch (e) {
      state = AsyncData<NotificationsState>(current.copyWith(loadingMore: false, loadMoreError: errorMessage(e)));
    }
  }

  /// Marks one notification read. Returns false (and undoes it) when the server refused.
  Future<bool> markRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return true;
    final target = current.items.where((n) => n.id == id);
    if (target.isEmpty || target.first.isRead) return true;
    state = AsyncData<NotificationsState>(
      current.copyWith(
        items: <AppNotification>[for (final n in current.items) n.id == id ? n.asRead() : n],
        unread: current.unread > 0 ? current.unread - 1 : 0,
      ),
    );
    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
      return true;
    } catch (_) {
      _restore(current);
      return false;
    }
  }

  /// Marks the whole inbox read. Returns false (and undoes it) when the server refused.
  Future<bool> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null || current.unread == 0) return true;
    state = AsyncData<NotificationsState>(
      current.copyWith(items: <AppNotification>[for (final n in current.items) n.isRead ? n : n.asRead()], unread: 0),
    );
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      return true;
    } catch (_) {
      _restore(current);
      return false;
    }
  }

  /// Puts back the state from before an action, unless something else (a refresh) replaced it meanwhile.
  void _restore(NotificationsState before) {
    if (state.valueOrNull != null) state = AsyncData<NotificationsState>(before);
  }
}

final notificationsProvider =
    AsyncNotifierProvider.autoDispose<NotificationsNotifier, NotificationsState>(NotificationsNotifier.new);

/// The number on the bell. It is kept up to date by polling and by the inbox screen, which knows the exact
/// count after every read; a failed refresh keeps the last number rather than hiding the badge.
class UnreadCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    if (ref.watch(currentUserIdProvider) == null) return 0; // signed out: nothing to count
    return ref.read(notificationRepositoryProvider).unreadCount();
  }

  void setCount(int count) => state = AsyncData<int>(count < 0 ? 0 : count);

  Future<void> refresh() async {
    if (ref.read(currentUserIdProvider) == null) return;
    try {
      state = AsyncData<int>(await ref.read(notificationRepositoryProvider).unreadCount());
    } catch (_) {
      // keep showing the last known count
    }
  }
}

final unreadCountProvider = AsyncNotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);
