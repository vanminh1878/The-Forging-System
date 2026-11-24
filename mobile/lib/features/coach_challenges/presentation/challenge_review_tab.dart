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
import '../../../core/widgets/hvp_pagination_bar.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../../challenges/presentation/helpers/challenge_ui_helpers.dart';
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
        status: _status,
        evidence: _evidence,
        query: _query,
        page: _page,
      );

  void _setStatus(String? value) => setState(() {
        _status = value;
        _page = 1;
      });
  void _setEvidence(String? value) => setState(() {
        _evidence = value;
        _page = 1;
      });

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
            child: HvpTextField(
              label: 'Tìm kiếm',
              hint: 'Tìm học viên, mã học viên hoặc Challenge',
              prefixIcon: HvpIcons.search,
              onSubmitted: (value) => setState(() {
                _query = value.trim();
                _page = 1;
              }),
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
            child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text('Bằng chứng:', style: context.txt.bodySmall),
                  DropdownButton<String?>(
                    value: _evidence,
                    items: const <DropdownMenuItem<String?>>[
                      DropdownMenuItem(value: null, child: Text('Tất cả')),
                      DropdownMenuItem(
                          value: 'SUBMITTED', child: Text('Đã nộp')),
                      DropdownMenuItem(
                          value: 'PENDING', child: Text('Chưa nộp')),
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
              onRetry: () =>
                  ref.invalidate(challengeReviewQueueProvider(filter)),
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
                    padding: const EdgeInsets.fromLTRB(
                        16, 4, 16, HvpLayout.navClearance),
                    children: <Widget>[
                      Text(
                          '${result.total} participation · Trang ${result.page}/${result.totalPages}',
                          style: context.txt.caption),
                      const SizedBox(height: 8),
                      for (final item in result.items) ...<Widget>[
                        _ReviewCard(
                            item: item,
                            submitting: action.submitting,
                            filter: filter),
                        const SizedBox(height: 12),
                      ],
                      HvpPaginationBar(
                        page: result.page,
                        totalPages: result.totalPages,
                        onPageChanged: (p) => setState(() => _page = p),
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
        child: ChoiceChip(
            label: Text(label),
            selected: _status == value,
            onSelected: (_) => _setStatus(value)),
      );
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard(
      {required this.item, required this.submitting, required this.filter});

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
          Text('${item.memberFullName} · ${item.memberCode}',
              style: context.txt.bodySmall),
          const SizedBox(height: 8),
          // ---- Progress row with visual bar ----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('TIẾN ĐỘ', style: context.txt.caption),
              Text('${item.progressValue} / ${item.target}',
                  style: context.txt.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: item.target == 0
                  ? 0
                  : (item.progressValue / item.target).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: context.hvp.surfaceHighest,
              color: context.hvp.gold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: <Widget>[
            StatusChip(
              label: participationStatusLabel(item.status),
              tone: participationStatusTone(item.status),
            ),
            IconLabel(
              icon: HvpIcons.flag,
              label: completionMethodLabel(item.completionMethod),
            ),
          ]),
          if (url != null) ...<Widget>[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showFullImage(context, url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  url,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) =>
                      progress == null
                          ? child
                          : SizedBox(
                              height: 180,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            ),
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    alignment: Alignment.center,
                    color: context.hvp.surfaceHighest,
                    child: Text('Không tải được ảnh minh chứng',
                        style: context.txt.bodySmall),
                  ),
                ),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            Text(
                item.completionMethod == 'ATTENDANCE'
                    ? 'Hoàn thành được xác minh bằng điểm danh.'
                    : 'Học viên chưa nộp ảnh minh chứng.',
                style: context.txt.bodySmall),
          ],
          const SizedBox(height: 14),
          if (item.status == 'PENDING_COACH')
            HvpButton.gold(
              label: 'Duyệt tham gia',
              small: true,
              loading: submitting,
              onPressed: submitting ? null : () => _approveJoin(context, ref),
            ),
          if (item.status == 'AWAITING_COACH')
            HvpButton.gold(
              label: 'Duyệt và phát thưởng',
              small: true,
              loading: submitting,
              onPressed: submitting ? null : () => _approve(context, ref),
            ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Stack(
          children: <Widget>[
            InteractiveViewer(
              child: Center(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton.filled(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final isAttendance = item.completionMethod == 'ATTENDANCE';
    final confirmed = await showConfirmSheet(
      context,
      title: isAttendance
          ? 'Duyệt hoàn thành Challenge'
          : 'Duyệt bài nộp',
      message: isAttendance
          ? 'Xác nhận ${item.memberFullName} đã hoàn thành thử thách bằng điểm danh? Phần thưởng sẽ được phát.'
          : 'Xác nhận bài nộp của ${item.memberFullName}? Phần thưởng Challenge sẽ được phát.',
      confirmLabel: isAttendance ? 'Duyệt hoàn thành' : 'Duyệt bài nộp',
    );
    if (!confirmed) return;
    final ok = await ref.read(challengeReviewActionProvider.notifier).run(
          () => ref
              .read(challengeReviewRepositoryProvider)
              .approve(item.participationId),
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
          () => ref
              .read(challengeReviewRepositoryProvider)
              .approveJoin(item.participationId),
        );
    if (ok) ref.invalidate(challengeReviewQueueProvider(filter));
  }
}
