import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../notification_providers.dart';

/// How often the number is re-read while the app is open: new notifications arrive any time.
const Duration bellRefreshEvery = Duration(seconds: 60);

/// App bar bell for every signed-in actor: a badge with the unread count,
/// opening that role's inbox.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({
    super.key,
    this.inboxPath = StudentPaths.notifications,
    this.inboxIsTab = false,
  });

  final String inboxPath;
  final bool inboxIsTab;

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  void _refresh() => ref.read(unreadCountProvider.notifier).refresh();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(bellRefreshEvery, (_) => _refresh());
    _lifecycle = AppLifecycleListener(
        onResume: _refresh); // back to the app: look again at once
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (widget.inboxIsTab) {
      context.go(widget.inboxPath);
      return;
    }
    await context.push<void>(widget.inboxPath);
    if (mounted) _refresh(); // read some (or got new ones) while there
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final count = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final label = count > 99 ? '99+' : '$count';
    return Semantics(
      label: count > 0 ? 'Thông báo, $count chưa đọc' : 'Thông báo',
      button: true,
      excludeSemantics: true,
      child: IconButton(
        tooltip: 'Thông báo',
        onPressed: _open,
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(label),
          backgroundColor: c.red,
          textColor: c.onRed,
          child: Icon(count > 0 ? HvpIcons.bellRinging : HvpIcons.bell,
              color: c.gold),
        ),
      ),
    );
  }
}
