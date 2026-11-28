import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/color_utils.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_refresh.dart';
import '../../../core/widgets/hvp_toast.dart';
import '../../../core/widgets/icon_label.dart';
import '../domain/app_notification.dart';
import 'notification_providers.dart';
import 'notification_target.dart';

/// Shared inbox: newest first, unread ones stand out, tapping one reads it.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    super.key,
    this.enableTargets = true,
    this.enableIndividualRead = true,
  });

  /// Staff inbox events may not have a member-facing destination. They remain
  /// readable, but do not redirect a staff member into the student route tree.
  final bool enableTargets;

  /// Staff inboxes are shared per role, so only "read all" changes their
  /// shared read state. A tap must not pretend to read one item locally.
  final bool enableIndividualRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(notificationsProvider);
    final unread = inbox.valueOrNull?.unread ?? 0;
    final notifier = ref.read(notificationsProvider.notifier);
    // Every load, refresh and read leaves the exact unread count here: hand it to the bell without a request.
    ref.listen<AsyncValue<NotificationsState>>(notificationsProvider,
        (_, next) {
      final count = next.valueOrNull?.unread;
      if (count != null) ref.read(unreadCountProvider.notifier).setCount(count);
    });

    Future<void> readAll() async {
      if (!await notifier.markAllRead() && context.mounted) {
        HvpToast.show(context, 'Không đánh dấu đã đọc được. Vui lòng thử lại.',
            type: ToastType.error);
      }
    }

    return Scaffold(
      appBar: HvpAppBar(
        title: 'Thông báo',
        titleIcon: HvpIcons.bellFill,
        actions: <Widget>[
          if (unread > 0)
            TextButton.icon(
                onPressed: readAll,
                icon: const Icon(HvpIcons.checks, size: 18),
                label: const Text('Đọc tất cả')),
        ],
      ),
      body: AsyncBody<NotificationsState>(
        value: inbox,
        onRetry: () => ref.invalidate(notificationsProvider),
        builder: (context, state) => HvpRefresh(
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            await ref.read(notificationsProvider.future);
          },
          child: state.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const <Widget>[
                    EmptyState(
                      icon: HvpIcons.bell,
                      title: 'Chưa có thông báo',
                      message:
                          'Thông báo về buổi tập, hạng và chuỗi tập của bạn sẽ hiện ở đây.',
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                      16, 12, 16, HvpLayout.navClearance),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.items.length) {
                      return _LoadMoreFooter(
                          state: state, onMore: notifier.loadMore);
                    }
                    final item = state.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NotificationTile(
                        item: item,
                        onTap: () async {
                          final marked = enableIndividualRead
                              ? await notifier.markRead(item.id)
                              : true;
                          if (!context.mounted) return;
                          if (enableIndividualRead && !marked) {
                            HvpToast.show(context,
                                'Không đánh dấu đã đọc được. Vui lòng thử lại.',
                                type: ToastType.error);
                          }
                          if (!enableTargets) return;
                          // The learner came for the screen: go there even when marking it read failed.
                          final target = notificationTarget(item.eventType);
                          if (target == null) return;
                          if (target.isTab) {
                            context.go(target.path);
                          } else {
                            await context.push<void>(target.path);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return HvpCard(
      accent: item.isRead ? null : c.gold,
      onTap: onTap,
      semanticLabel: '${item.isRead ? '' : 'Chưa đọc. '}${item.title}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isRead ? c.surfaceHigh : c.goldSoft),
            child: Icon(notificationIcon(item.eventType),
                size: 20, color: item.isRead ? c.textMuted : c.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: t.titleS.copyWith(
                      color: item.isRead ? c.textSecondary : c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(item.body, style: t.bodySmall),
                const SizedBox(height: 6),
                IconLabel(
                    icon: HvpIcons.clock,
                    iconSize: 13,
                    label: formatRelative(item.createdAt),
                    style: t.caption),
              ],
            ),
          ),
          if (!item.isRead)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Container(
                key: const ValueKey<String>('unread-dot'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: c.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.gold.fade(0.5))),
              ),
            ),
        ],
      ),
    );
  }
}

/// The icon of an event; anything unknown (including admin broadcasts) gets the bell.
IconData notificationIcon(String eventType) {
  if (eventType.startsWith('RANK')) return HvpIcons.trophy;
  if (eventType.startsWith('STREAK')) return HvpIcons.fire;
  if (eventType.startsWith('CHALLENGE')) return HvpIcons.flag;
  if (eventType.startsWith('ARMORY') || eventType.startsWith('REDEEM')) {
    return HvpIcons.gift;
  }
  if (eventType.startsWith('MEMBERSHIP') ||
      eventType.startsWith('RENEW') ||
      eventType.startsWith('PACKAGE')) {
    return HvpIcons.ticket;
  }
  switch (eventType) {
    case 'SESSION_COMPLETED':
    case 'NEAR_RANK':
      return HvpIcons.checks;
    default:
      return HvpIcons.bell;
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onMore});

  final NotificationsState state;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final failed = state.loadMoreError != null;
    return Column(
      children: <Widget>[
        if (failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(state.loadMoreError!,
                style: context.txt.bodySmall, textAlign: TextAlign.center),
          ),
        HvpButton.secondary(
          label: failed ? 'Thử lại' : 'Xem thêm',
          icon: failed ? HvpIcons.retry : HvpIcons.caretDown,
          small: true,
          loading: state.loadingMore,
          onPressed: onMore,
        ),
      ],
    );
  }
}
