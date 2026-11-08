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
import '../../../core/widgets/hvp_text_field.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/admin_challenge.dart';
import 'admin_challenge_providers.dart';

class AdminChallengesScreen extends ConsumerStatefulWidget {
  const AdminChallengesScreen({super.key});
  @override
  ConsumerState<AdminChallengesScreen> createState() => _AdminChallengesScreenState();
}

class _AdminChallengesScreenState extends ConsumerState<AdminChallengesScreen> {
  String _query = '';
  String? _status;
  int _page = 1;
  ({String query, String? status, int page}) get _filter => (query: _query, status: _status, page: _page);
  void _setStatus(String? status) => setState(() { _status = status; _page = 1; });
  Future<void> _create() async {
    await context.push(AdminPaths.challengeCreate);
    if (mounted) ref.invalidate(adminChallengeListProvider(_filter));
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    return Scaffold(body: Column(children: <Widget>[
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Row(children: <Widget>[
          Expanded(child: Text('Thử thách', style: context.txt.titleL)),
          HvpButton.gold(label: 'Tạo Challenge', icon: HvpIcons.plus, small: true, onPressed: _create),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: HvpTextField(
          label: 'Tìm Challenge', hint: 'Tên hoặc mã Challenge', prefixIcon: HvpIcons.search,
          onSubmitted: (value) => setState(() { _query = value.trim(); _page = 1; }),
        )),
        SizedBox(height: 56, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), children: <Widget>[
          _chip(null, 'Tất cả'), _chip('DRAFT', 'Nháp'), _chip('OPEN', 'Đang mở'), _chip('CLOSED', 'Đã đóng'), _chip('CANCELLED', 'Đã hủy'),
        ])),
        Expanded(child: AsyncBody<AdminChallengePage>(
          value: ref.watch(adminChallengeListProvider(filter)), onRetry: () => ref.invalidate(adminChallengeListProvider(filter)),
          builder: (_, data) => RefreshIndicator(
            onRefresh: () async { ref.invalidate(adminChallengeListProvider(filter)); await ref.read(adminChallengeListProvider(filter).future); },
            child: data.items.isEmpty ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: <Widget>[SizedBox(height: 360, child: EmptyState(icon: HvpIcons.flag, title: 'Chưa có Challenge', message: 'Tạo Challenge đầu tiên cho học viên.', actionLabel: 'Tạo Challenge', onAction: _create))])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: <Widget>[
                  Text('${data.total} Challenge · Trang ${data.page}/${data.totalPages}', style: context.txt.caption), const SizedBox(height: 8),
                  for (final item in data.items) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ChallengeCard(item: item, onTap: () async { await context.push(AdminPaths.challengeEdit(item.id)); ref.invalidate(adminChallengeListProvider(filter)); })),
                  if (data.totalPages > 1) Wrap(alignment: WrapAlignment.spaceBetween, children: <Widget>[
                    TextButton.icon(onPressed: data.page > 1 ? () => setState(() => _page = data.page - 1) : null, icon: const Icon(HvpIcons.caretLeft), label: const Text('Trang trước')),
                    TextButton.icon(onPressed: data.page < data.totalPages ? () => setState(() => _page = data.page + 1) : null, icon: const Icon(HvpIcons.caretRight), label: const Text('Trang sau')),
                  ]),
                ]),
          ),
        )),
      ]));
  }
  Widget _chip(String? value, String label) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label), selected: _status == value, onSelected: (_) => _setStatus(value)));
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.item, required this.onTap});
  final AdminChallenge item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => HvpCard(onTap: onTap, child: Row(children: <Widget>[
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(item.title, style: context.txt.titleS), const SizedBox(height: 3),
      Text('${item.code ?? 'Chưa có mã'} · ${item.challengeType} · ${item.context}', style: context.txt.bodySmall),
      Text('${formatDateTime(item.startsAt)} – ${formatDateTime(item.endsAt)}', style: context.txt.caption),
    ])),
    Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[_status(item.status), const SizedBox(height: 8), const Icon(HvpIcons.caretRight)]),
  ]));
  StatusChip _status(String status) => switch (status) {
    'OPEN' => const StatusChip(label: 'Đang mở', tone: ChipTone.success),
    'DRAFT' => const StatusChip(label: 'Nháp', tone: ChipTone.warning),
    'CLOSED' => const StatusChip(label: 'Đã đóng', tone: ChipTone.neutral),
    _ => const StatusChip(label: 'Đã hủy', tone: ChipTone.danger),
  };
}
