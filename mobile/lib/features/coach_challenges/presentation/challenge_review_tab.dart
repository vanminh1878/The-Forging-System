import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/inline_banner.dart';
import '../domain/challenge_review.dart';
import 'challenge_review_providers.dart';

/// Coach "Challenge" tab: review evidence the learner submitted and release the reward.
class ChallengeReviewTab extends ConsumerStatefulWidget {
  const ChallengeReviewTab({super.key});

  @override
  ConsumerState<ChallengeReviewTab> createState() => _ChallengeReviewTabState();
}

class _ChallengeReviewTabState extends ConsumerState<ChallengeReviewTab> {
  String _query = '';
  String? _status;
  String? _evidence;
  int _page = 1;

  ({String? status, String? evidence, String query, int page}) get _filter => (
    status: _status, evidence: _evidence, query: _query, page: _page,
  );

  void _setStatus(String? value) => setState(() { _status = value; _page = 1; });
  void _setEvidence(String? value) => setState(() { _evidence = value; _page = 1; });

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    final queue = ref.watch(challengeReviewQueueProvider(filter));
    final action = ref.watch(challengeReviewActionProvider);
    return Material(
      color: Colors.transparent,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Duyệt Challenge', style: context.txt.titleL),
              const SizedBox(height: 4),
              Text(
                'Tìm, lọc participation; duyệt bằng chứng hợp lệ để phát thưởng.',
                style: context.txt.bodySmall,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Tìm học viên, mã học viên hoặc Challenge',
              prefixIcon: Icon(HvpIcons.search),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => setState(() { _query = value.trim(); _page = 1; }),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: <Widget>[
              _chip(null, 'Tất cả'),
              _chip('PENDING_COACH', 'Chờ duyệt tham gia'),
              _chip('JOINED', 'Đã tham gia'),
              _chip('AWAITING_COACH', 'Chờ duyệt'),
              _chip('REWARDED', 'Đã thưởng'),
              _chip('EXPIRED', 'Hết hạn'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: <Widget>[
            Text('Bằng chứng:', style: context.txt.bodySmall),
            const SizedBox(width: 8),
            DropdownButton<String?>(
              value: _evidence,
              items: const <DropdownMenuItem<String?>>[
                DropdownMenuItem(value: null, child: Text('Tất cả')),
                DropdownMenuItem(value: 'SUBMITTED', child: Text('Đã nộp')),
                DropdownMenuItem(value: 'PENDING', child: Text('Chưa nộp')),
              ],
              onChanged: _setEvidence,
            ),
          ]),
        ),
        if (action.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InlineBanner(message: action.error!),
          ),
        Expanded(
          child: AsyncBody<ChallengeReviewPage>(
            value: queue,
            onRetry: () => ref.invalidate(challengeReviewQueueProvider(filter)),
            builder: (context, result) {
              if (result.items.isEmpty) {
                return const EmptyState(
                  icon: HvpIcons.flag,
                  title: 'Không có participation phù hợp',
                  message: 'Thử đổi bộ lọc hoặc tìm kiếm khác.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(challengeReviewQueueProvider(filter));
                  await ref.read(challengeReviewQueueProvider(filter).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, HvpLayout.navClearance),
                  children: <Widget>[
                    Text('${result.total} participation · Trang ${result.page}/${result.totalPages}', style: context.txt.caption),
                    const SizedBox(height: 8),
                    for (final item in result.items) ...<Widget>[
                      _ReviewCard(item: item, submitting: action.submitting, filter: filter),
                      const SizedBox(height: 12),
                    ],
                    if (result.totalPages > 1) Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        TextButton.icon(onPressed: result.page > 1 ? () => setState(() => _page = result.page - 1) : null, icon: const Icon(HvpIcons.caretLeft), label: const Text('Trang trước')),
                        TextButton.icon(onPressed: result.page < result.totalPages ? () => setState(() => _page = result.page + 1) : null, icon: const Icon(HvpIcons.caretRight), label: const Text('Trang sau')),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
      ),
    );
  }

  Widget _chip(String? value, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(label: Text(label), selected: _status == value, onSelected: (_) => _setStatus(value)),
  );
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.item, required this.submitting, required this.filter});

  final ChallengeReview item;
  final bool submitting;
  final ({String? status, String? evidence, String query, int page}) filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = item.evidenceUrl;
    return HvpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(item.challengeTitle, style: context.txt.titleS),
          const SizedBox(height: 4),
          Text('${item.memberFullName} · ${item.memberCode}', style: context.txt.bodySmall),
          const SizedBox(height: 8),
           Text('Tiến độ: ${item.progressValue} / ${item.target}', style: context.txt.bodySmall),
           const SizedBox(height: 4),
           Text('Trạng thái: ${_statusLabel(item.status)}', style: context.txt.bodySmall),
          if (url != null) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  alignment: Alignment.center,
                  color: context.hvp.surfaceHighest,
                  child: Text('Không tải được ảnh minh chứng', style: context.txt.bodySmall),
                ),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            Text('Học viên chưa nộp ảnh minh chứng.', style: context.txt.bodySmall),
          ],
          const SizedBox(height: 14),
          if (item.status == 'PENDING_COACH') HvpButton.gold(
              label: 'Duyệt tham gia',
              small: true,
              loading: submitting,
              onPressed: submitting ? null : () => _approveJoin(context, ref),
            ),
          if (item.status == 'AWAITING_COACH') HvpButton.gold(
              label: 'Duyệt và phát thưởng',
              small: true,
              loading: submitting,
              onPressed: submitting || url == null ? null : () => _approve(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Duyệt bài nộp',
      message:
          'Xác nhận bài nộp của ${item.memberFullName}? Phần thưởng Challenge sẽ được phát.',
      confirmLabel: 'Duyệt bài nộp',
    );
    if (!confirmed) return;
    final ok = await ref.read(challengeReviewActionProvider.notifier).run(
          () => ref.read(challengeReviewRepositoryProvider).approve(item.participationId),
        );
    if (ok) ref.invalidate(challengeReviewQueueProvider(filter));
  }

  Future<void> _approveJoin(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Duyệt tham gia Challenge',
      message: 'Cho phép ${item.memberFullName} thực hiện thử thách này?',
      confirmLabel: 'Duyệt tham gia',
    );
    if (!confirmed) return;
    final ok = await ref.read(challengeReviewActionProvider.notifier).run(
      () => ref.read(challengeReviewRepositoryProvider).approveJoin(item.participationId),
    );
    if (ok) ref.invalidate(challengeReviewQueueProvider(filter));
  }

  String _statusLabel(String status) => switch (status) {
    'PENDING_COACH' => 'Chờ duyệt tham gia',
    'JOINED' => 'Đã tham gia',
    'AWAITING_COACH' => 'Chờ duyệt',
    'REWARDED' => 'Đã thưởng',
    'EXPIRED' => 'Hết hạn',
    _ => status,
  };
}
