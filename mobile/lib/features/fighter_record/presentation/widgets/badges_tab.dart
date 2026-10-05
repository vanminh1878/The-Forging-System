import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_layout.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../domain/rank_rules.dart';
import '../providers/fighter_record_providers.dart';
import 'badge_detail_sheet.dart';
import 'badge_tile.dart';
import 'history_tile.dart';

/// Tab "Huy hiệu": the 7 medallions plus the rank timeline.
class BadgesTab extends ConsumerWidget {
  const BadgesTab({super.key});

  static const double _gap = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(badgeBoardProvider);
    return AsyncBody<BadgeBoard>(
      value: board,
      onRetry: () => ref.invalidate(badgeBoardProvider),
      loading: const ShimmerList(itemCount: 3, itemHeight: 160),
      builder: (context, data) => HvpRefresh(
        onRefresh: () async {
          ref.invalidate(badgeBoardProvider);
          await ref.read(badgeBoardProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            _grid(context, data).entrance(0),
            SectionHeader(
              title: 'Lịch sử huy hiệu',
              subtitle: data.history.isEmpty ? null : '${data.history.length} mốc gần nhất',
            ),
            _timeline(data).entrance(1),
          ],
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, BadgeBoard data) {
    return HvpCard(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = (box.maxWidth - 2 * _gap) / 3;
          return Wrap(
            spacing: _gap,
            runSpacing: _gap,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final slot in data.slots)
                SizedBox(
                  width: width,
                  child: BadgeTile(slot: slot, onTap: () => showBadgeDetail(context, slot)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _timeline(BadgeBoard data) {
    if (data.history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Chưa có lịch sử huy hiệu.')),
      );
    }
    final last = data.history.length - 1;
    return Padding(
      padding: HvpLayout.screenPadding.copyWith(left: 4, right: 4),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < data.history.length; i++)
            HistoryTile(
              entry: data.history[i],
              rankName: data.ranksById[data.history[i].toRankId]?.displayName ?? 'hạng',
              isLast: i == last,
            ),
        ],
      ),
    );
  }
}
