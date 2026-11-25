import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/streak.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import 'helpers/streak_ui_helpers.dart';
import 'streak_providers.dart';

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(streakSummaryProvider);
    ref.listen<AsyncValue<StreakSummary>>(streakSummaryProvider, (_, next) {
      final value = next.valueOrNull;
      if (value != null) _showMilestone(context, ref, value);
    });
    return Scaffold(
      appBar: const HvpAppBar(title: 'Chuỗi tập'),
      body: AsyncBody<StreakSummary>(
        value: summary,
        onRetry: () => ref.invalidate(streakSummaryProvider),
        builder: (_, value) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(streakSummaryProvider);
            await ref.read(streakSummaryProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              _Hero(summary: value),
              const SizedBox(height: 12),
              _Progress(summary: value),
              const SizedBox(height: 12),
              _FreezeInfo(count: value.availableFreezes),
              const SizedBox(height: 20),
              Text('LỊCH SỬ CHỐT TUẦN', style: context.txt.titleS),
              const SizedBox(height: 8),
              if (value.logs.isEmpty)
                const SizedBox(
                  height: 180,
                  child: EmptyState(icon: HvpIcons.history, title: 'Chưa có tuần nào được chốt'),
                )
              else
                for (final log in value.logs) Padding(padding: const EdgeInsets.only(bottom: 8), child: _LogCard(log: log)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMilestone(BuildContext context, WidgetRef ref, StreakSummary summary) async {
    final logs = summary.logs.where((log) => log.result == 'INCREASED').toList(growable: false);
    if (logs.isEmpty) return;
    final log = logs.first;
    final dp = summary.milestones[log.streakAfter];
    final userId = ref.read(currentUserIdProvider);
    if (dp == null || userId == null || !context.mounted) return;
    final key = 'streak_milestone:$userId:${log.weekStart.toIso8601String().substring(0, 10)}:${log.streakAfter}';
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(HvpIcons.trophy),
        title: Text('MỐC ${log.streakAfter} TUẦN!'),
        content: Text('Bạn nhận được $dp DP nhờ duy trì chuỗi tập.'),
        actions: <Widget>[TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('TIẾP TỤC'))],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary});
  final StreakSummary summary;

  @override
  Widget build(BuildContext context) => HvpCard(
        highlighted: true,
        child: Row(children: <Widget>[
          Icon(HvpIcons.fire, size: 42, color: context.hvp.gold),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('CHUỖI HIỆN TẠI', style: context.txt.caption),
            Text('${summary.currentStreakWeeks} tuần', style: context.txt.titleL),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
            Text('Kỷ lục', style: context.txt.caption),
            Text('${summary.longestStreakWeeks} tuần', style: context.txt.titleS),
          ]),
        ]),
      );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.summary});
  final StreakSummary summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.targetSessions == 0 ? 0.0 : (summary.sessionsThisWeek / summary.targetSessions).clamp(0, 1).toDouble();
    return HvpCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('TIẾN ĐỘ TUẦN NÀY', style: context.txt.titleS),
      const SizedBox(height: 8),
      Text('${summary.sessionsThisWeek}/${summary.targetSessions} buổi đã xác nhận', style: context.txt.bodySmall),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: progress, minHeight: 8),
      const SizedBox(height: 8),
      Text('Tuần bắt đầu ${formatDate(summary.currentWeekStart)}.', style: context.txt.caption),
    ]));
  }
}

class _FreezeInfo extends StatelessWidget {
  const _FreezeInfo({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => HvpCard(
        child: Row(children: <Widget>[
          Icon(HvpIcons.snowflake, color: context.hvp.info),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('STREAK FREEZE', style: context.txt.titleS),
            Text(count > 0 ? 'Còn $count Freeze, tự dùng khi thiếu buổi chốt tuần.' : 'Chưa có Freeze khả dụng.', style: context.txt.bodySmall),
          ])),
        ]),
      );
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});
  final StreakLog log;

  @override
  Widget build(BuildContext context) => HvpCard(child: Row(children: <Widget>[
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('Tuần ${formatDate(log.weekStart)}', style: context.txt.titleS),
      Text('${log.sessionsCount}/${log.targetSessions} buổi xác nhận · ${log.streakBefore} → ${log.streakAfter} tuần', style: context.txt.bodySmall),
    ])),
    StatusChip(label: streakResultLabel(log.result), tone: streakResultTone(log.result)),
  ]));
}
