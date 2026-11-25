import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/evidence_photo_picker.dart';
import '../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../domain/current_challenge.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import 'current_challenge_providers.dart';
import 'helpers/challenge_ui_helpers.dart';
import 'widgets/challenge_summary_header.dart';

class CurrentChallengesScreen extends ConsumerStatefulWidget {
  const CurrentChallengesScreen({super.key});

  @override
  ConsumerState<CurrentChallengesScreen> createState() =>
      _CurrentChallengesScreenState();
}

class _CurrentChallengesScreenState
    extends ConsumerState<CurrentChallengesScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<List<CurrentChallenge>>>(
        currentChallengesProvider, (_, next) {
      final items = next.valueOrNull;
      if (items != null) _showReward(items);
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _showReward(List<CurrentChallenge> items) async {
    final rewarded = items
        .where((item) => item.participationStatus == 'REWARDED')
        .toList(growable: false);
    final userId = ref.read(currentUserIdProvider);
    if (rewarded.isEmpty || userId == null || !mounted) return;
    final item = rewarded.first;
    final prefs = ref.read(sharedPreferencesProvider);
    final key = 'challenge_reward:$userId:${item.participationId}';
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    if (!mounted) return;
    Haptics.medium();
    _confetti.play();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(HvpIcons.trophy),
        title: const Text('THỬ THÁCH HOÀN THÀNH!'),
        content: Text(
            'Bạn nhận ${formatInt(item.rewardDp)} DP và ${formatInt(item.rewardMarks)} Marks.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('TIẾP TỤC'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challenges = ref.watch(currentChallengesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thử thách của tôi')),
      body: Stack(children: <Widget>[
        AsyncBody<List<CurrentChallenge>>(
          value: challenges,
          onRetry: () => ref.invalidate(currentChallengesProvider),
          builder: (_, items) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentChallengesProvider);
              await ref.read(currentChallengesProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: <Widget>[
                Text('THỬ THÁCH CỦA TÔI', style: context.txt.titleL),
                const SizedBox(height: 4),
                Text('Theo dõi mục tiêu, thời hạn và phần thưởng của bạn.',
                    style: context.txt.bodySmall),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  EmptyState(
                    icon: HvpIcons.flag,
                    title: 'Chưa tham gia thử thách',
                    message:
                        'Khi tham gia thử thách đang mở, tiến độ sẽ xuất hiện tại đây.',
                    actionLabel: 'Khám phá thử thách',
                    onAction: () => context.push(StudentPaths.challenges),
                  ),
                for (final challenge in items) ...<Widget>[
                  CurrentChallengeCard(
                    challenge: challenge,
                    onSubmitEvidence: () =>
                        _showEvidenceSheet(context, ref, challenge),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        IgnorePointer(child: ConfettiBurst(controller: _confetti))
      ]),
    );
  }
}

Future<void> _showEvidenceSheet(
    BuildContext context, WidgetRef ref, CurrentChallenge challenge) async {
  ref.read(challengeEvidenceActionProvider.notifier).reset();
  await showHvpSheet<void>(
    context,
    title: 'Yêu cầu hoàn thành',
    builder: (_) => _EvidenceSheet(challenge: challenge),
  );
}

class CurrentChallengeCard extends StatelessWidget {
  const CurrentChallengeCard(
      {super.key, required this.challenge, this.onSubmitEvidence});
  final CurrentChallenge challenge;
  final VoidCallback? onSubmitEvidence;

  @override
  Widget build(BuildContext context) {
    final isActive = challenge.participationStatus == 'JOINED';
    final isRewarded = challenge.participationStatus == 'REWARDED';
    return HvpCard(
      highlighted: isActive,
      accent: isRewarded ? context.hvp.emerald : null,
      semanticLabel: 'Tiến độ thử thách ${challenge.title}',
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ChallengeSummaryHeader(
              typeLabel: challengeTypeLabel(challenge.challengeType),
              statusLabel:
                  participationStatusLabel(challenge.participationStatus),
              statusTone:
                  participationStatusTone(challenge.participationStatus),
              title: challenge.title,
              description: challenge.description,
            ),
            if (challenge.completionMethod == 'ATTENDANCE') ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Tiến độ tự động tăng khi điểm danh buổi tập hợp lệ.',
                style: context.txt.caption,
              ),
            ],
            const SizedBox(height: 14),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('TIẾN ĐỘ', style: context.txt.caption),
                  Text(
                      '${formatInt(challenge.progressValue)} / ${formatInt(challenge.target)}',
                      style: context.txt.bodySmall),
                ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: challenge.progress,
                minHeight: 10,
                backgroundColor: context.hvp.surfaceHighest,
                color: context.hvp.gold,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 8, children: <Widget>[
              IconLabel(
                  icon: HvpIcons.calendar,
                  label: 'Hạn: ${formatDateTime(challenge.endsAt)}'),
              IconLabel(
                  icon: HvpIcons.star,
                  label: '+${formatInt(challenge.rewardDp)} DP'),
              IconLabel(
                  icon: HvpIcons.coins,
                  label: '+${formatInt(challenge.rewardMarks)} Marks'),
            ]),
            if (challenge.participationStatus == 'JOINED' &&
                challenge.completionMethod == 'EVIDENCE') ...<Widget>[
              const SizedBox(height: 14),
              HvpButton.primary(
                  label: 'Yêu cầu hoàn thành',
                  small: true,
                  onPressed: onSubmitEvidence),
            ],
            if (challenge.participationStatus == 'REJECTED') ...<Widget>[
              const SizedBox(height: 12),
              InlineBanner(
                  message: challenge.rejectionReason ??
                      'Bằng chứng cần được nộp lại.'),
              const SizedBox(height: 12),
              HvpButton.primary(
                  label: 'Nộp lại bằng chứng',
                  small: true,
                  onPressed: onSubmitEvidence),
            ],
          ]),
    );
  }
}

class _EvidenceSheet extends ConsumerStatefulWidget {
  const _EvidenceSheet({required this.challenge});
  final CurrentChallenge challenge;

  @override
  ConsumerState<_EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends ConsumerState<_EvidenceSheet> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _url = widget.challenge.evidenceUrl;
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(challengeEvidenceActionProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Text(widget.challenge.title, style: context.txt.titleS),
        const SizedBox(height: 16),
        EvidencePhotoPicker(
            initialUrl: widget.challenge.evidenceUrl,
            onChanged: (url) => setState(() => _url = url)),
        if (action.error != null) ...<Widget>[
          const SizedBox(height: 12),
          InlineBanner(message: action.error!),
        ],
        const SizedBox(height: 20),
        HvpButton.primary(
          label: 'Gửi yêu cầu hoàn thành',
          expand: true,
          loading: action.submitting,
          onPressed: _url == null || action.submitting
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  final ok = await ref
                      .read(challengeEvidenceActionProvider.notifier)
                      .run(
                        () => ref
                            .read(currentChallengeRepositoryProvider)
                            .submitEvidence(widget.challenge.id, _url!),
                      );
                  if (!mounted || !ok) return;
                  ref.invalidate(currentChallengesProvider);
                  navigator.pop();
                },
        ),
      ]),
    );
  }
}
