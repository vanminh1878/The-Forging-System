import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../core/widgets/hvp_pagination_bar.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/inline_banner.dart';
import '../domain/open_challenge.dart';
import 'open_challenge_providers.dart';
import 'helpers/challenge_ui_helpers.dart';
import 'widgets/challenge_summary_header.dart';

class OpenChallengesScreen extends ConsumerStatefulWidget {
  const OpenChallengesScreen({super.key});

  @override
  ConsumerState<OpenChallengesScreen> createState() =>
      _OpenChallengesScreenState();
}

class _OpenChallengesScreenState extends ConsumerState<OpenChallengesScreen> {
  String? _type;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final query = (type: _type, page: _page);
    final challenges = ref.watch(openChallengesProvider(query));
    final joining = ref.watch(joinChallengeActionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thử thách'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Thử thách của tôi',
            icon: const Icon(HvpIcons.flag),
            onPressed: () => context.push(StudentPaths.currentChallenges),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('THỬ THÁCH', style: context.txt.titleL),
                const SizedBox(height: 4),
                Text(
                  'Hoàn thành mục tiêu và nhận phần thưởng.',
                  style: context.txt.bodySmall,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _filter(null, 'Tất cả'),
                      _filter('DAILY', 'Hằng ngày'),
                      _filter('WEEKLY', 'Hằng tuần'),
                      _filter('MONTHLY', 'Hằng tháng'),
                      _filter('EVENT', 'Sự kiện'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody<OpenChallengePage>(
              value: challenges,
              onRetry: () => ref.invalidate(openChallengesProvider(query)),
              builder: (_, result) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(openChallengesProvider(query));
                  await ref.read(openChallengesProvider(query).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: <Widget>[
                    Text(
                      '${result.total} thử thách · Trang ${result.page}/${result.totalPages}',
                      style: context.txt.caption,
                    ),
                    const SizedBox(height: 12),
                    if (result.items.isEmpty)
                      const EmptyState(
                        icon: HvpIcons.flag,
                        title: 'Chưa có thử thách',
                        message:
                            'Hiện không có thử thách đang mở trong nhóm này.',
                      ),
                    if (joining.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InlineBanner(message: joining.error!),
                      ),
                    for (final challenge in result.items) ...<Widget>[
                      _ChallengeCard(
                        challenge: challenge,
                        submitting: joining.submitting,
                        onOpenProgress: () =>
                            context.push(StudentPaths.currentChallenges),
                        onJoin: () async {
                          final ok = await ref
                              .read(joinChallengeActionProvider.notifier)
                              .run(() => ref
                                  .read(openChallengeRepositoryProvider)
                                  .join(challenge.id));
                          if (ok) {
                            ref.invalidate(openChallengesProvider(query));
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    HvpPaginationBar(
                      page: result.page,
                      totalPages: result.totalPages,
                      onPageChanged: (p) => setState(() => _page = p),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filter(String? type, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _type == type,
          onSelected: (_) => setState(() {
            _type = type;
            _page = 1;
          }),
        ),
      );
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.submitting,
    required this.onJoin,
    required this.onOpenProgress,
  });
  final OpenChallenge challenge;
  final bool submitting;
  final VoidCallback onJoin;
  final VoidCallback onOpenProgress;

  @override
  Widget build(BuildContext context) => HvpCard(
        semanticLabel: 'Thử thách ${challenge.title}',
        accent: challenge.participationId == null ? null : context.hvp.emerald,
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: <Widget>[
                IconLabel(
                  icon: HvpIcons.flag,
                  label: 'Mục tiêu: ${formatInt(challenge.target)}',
                ),
                IconLabel(
                  icon: HvpIcons.star,
                  label: '+${formatInt(challenge.rewardDp)} DP',
                ),
                IconLabel(
                  icon: HvpIcons.coins,
                  label: '+${formatInt(challenge.rewardMarks)} Marks',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Kết thúc: ${formatDateTime(challenge.endsAt)}',
              style: context.txt.caption,
            ),
            if (challenge.participationId == null) ...<Widget>[
              const SizedBox(height: 14),
              HvpButton.gold(
                label: 'Tham gia thử thách',
                icon: HvpIcons.plus,
                small: true,
                loading: submitting,
                onPressed:
                    submitting ? null : () => _confirmJoin(context, onJoin),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 14),
              HvpButton.secondary(
                label: challenge.participationStatus == 'JOINED' &&
                        challenge.completionMethod == 'EVIDENCE'
                    ? 'Nộp bằng chứng hoàn thành'
                    : 'Xem tiến độ thử thách',
                small: true,
                onPressed: onOpenProgress,
              ),
            ],
          ],
        ),
      );

  Future<void> _confirmJoin(BuildContext context, VoidCallback onJoin) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Tham gia thử thách',
      message: 'Xác nhận tham gia thử thách này?',
      confirmLabel: 'Tham gia',
    );
    if (confirmed) onJoin();
  }
}
