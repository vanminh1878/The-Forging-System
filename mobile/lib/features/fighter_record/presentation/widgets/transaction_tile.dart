import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/points_models.dart';
import 'point_source_style.dart';

/// One ledger row: source icon, title, note/time and the signed DP / Marks.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

  final PointTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final tx = transaction;
    final at = tx.occurredAt;
    final note = tx.note;
    final amounts = <(String, Color)>[
      if (tx.dpAmount != 0) ('${formatSigned(tx.dpAmount)} DP', tx.dpAmount < 0 ? c.red : c.gold),
      if (tx.marksAmount != 0) ('${formatSigned(tx.marksAmount)} Marks', tx.marksAmount < 0 ? c.red : c.emerald),
    ];
    final spoken = amounts.map((a) => a.$1).join(', ');
    return HvpCard(
      cut: 8,
      padding: const EdgeInsets.all(12),
      semanticLabel: '${tx.source.label}, $spoken${at == null ? '' : ', ${formatDateTime(at)}'}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.goldSoft),
              child: Icon(iconOfSource(tx.source), size: 20, color: c.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(tx.source.label, style: t.body.copyWith(fontWeight: FontWeight.w600)),
                  if (note != null && note.isNotEmpty) Text(note, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (at != null) Text(formatDateTime(at), style: t.caption),
                  if (tx.isCapped) ...<Widget>[
                    const SizedBox(height: 6),
                    const StatusChip(label: 'Bị giới hạn theo tháng', tone: ChipTone.warning),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final line in amounts)
                  Text(line.$1, style: t.mono.copyWith(fontWeight: FontWeight.w700, color: line.$2)),
                if (amounts.isEmpty) Text('0', style: t.mono.copyWith(color: c.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
