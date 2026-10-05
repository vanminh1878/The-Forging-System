import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/rank_models.dart';
import '../providers/fighter_record_providers.dart';

/// Call to action under the checklist; depends on [RankProgress.status].
class TrialPanel extends ConsumerWidget {
  const TrialPanel({super.key, required this.progress});

  final RankProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = progress.next;
    switch (progress.status) {
      case RankStatus.maxRank:
        return const SizedBox.shrink();
      case RankStatus.rankReady:
        return const InlineBanner(
          tone: ChipTone.success,
          icon: HvpIcons.checkCircle,
          title: 'Đủ điều kiện',
          message: 'Hệ thống sẽ tự động nâng hạng cho bạn.',
        );
      case RankStatus.trialPending:
        return const InlineBanner(
          tone: ChipTone.warning,
          icon: HvpIcons.hourglass,
          title: 'Đang chờ chấm',
          message: 'Yêu cầu Rank Trial của bạn đang chờ huấn luyện viên chấm.',
        );
      case RankStatus.inProgress:
        return Text(
          'Hoàn thành các điều kiện trên để ${next == null ? 'tiếp tục' : 'tiến tới ${next.displayName}'}.',
          style: context.txt.bodySmall,
          textAlign: TextAlign.center,
        );
      case RankStatus.trialRequired:
        final submitting = ref.watch(trialRequestProvider.select((s) => s.submitting));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Bạn đã đủ DP, thời gian và khóa học. Bước cuối cùng là Rank Trial với huấn luyện viên.',
              style: context.txt.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            HvpButton.primary(
              label: 'Yêu cầu Rank Trial',
              icon: HvpIcons.trophy,
              expand: true,
              loading: submitting,
              onPressed: () => _request(context, ref),
            ),
          ],
        );
    }
  }

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final target = progress.next?.displayName ?? 'hạng tiếp theo';
    final confirmed = await showConfirmSheet(
      context,
      title: 'Yêu cầu Rank Trial',
      message: 'Gửi yêu cầu Rank Trial lên $target? Huấn luyện viên sẽ liên hệ để chấm trực tiếp.',
      confirmLabel: 'Gửi yêu cầu',
    );
    if (!confirmed || !context.mounted) return;
    final sent = await ref.read(trialRequestProvider.notifier).run(
          () => ref.read(fighterRecordRepositoryProvider).requestRankTrial(),
        );
    if (!context.mounted) return;
    if (sent) {
      HvpToast.success(context, 'Đã gửi yêu cầu Rank Trial.');
    } else {
      final message = ref.read(trialRequestProvider).error ?? 'Không gửi được yêu cầu. Vui lòng thử lại.';
      HvpToast.error(context, message);
    }
    // Reload either way: a rejected request usually means the state changed.
    ref.invalidate(rankProgressProvider);
  }
}
