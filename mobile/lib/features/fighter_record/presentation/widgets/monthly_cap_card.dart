import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/points_models.dart';

/// Usage of the monthly DP and Marks caps.
class MonthlyCapCard extends StatelessWidget {
  const MonthlyCapCard({super.key, required this.status});

  final MonthlyPointStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return HvpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('HẠN MỨC THÁNG NÀY', style: t.label)),
              if (status.dpCapReached || status.marksCapReached)
                const StatusChip(label: 'Đã chạm trần', tone: ChipTone.warning),
            ],
          ),
          const SizedBox(height: 14),
          _CapRow(
            label: 'DP',
            used: status.dpUsed,
            cap: status.dpCap,
            fraction: status.dpFraction,
            color: status.dpCapReached ? c.amber : c.gold,
          ),
          const SizedBox(height: 12),
          _CapRow(
            label: 'Marks',
            used: status.marksUsed,
            cap: status.marksCap,
            fraction: status.marksFraction,
            color: status.marksCapReached ? c.amber : c.emerald,
          ),
        ],
      ),
    );
  }
}

class _CapRow extends StatelessWidget {
  const _CapRow({
    required this.label,
    required this.used,
    required this.cap,
    required this.fraction,
    required this.color,
  });

  final String label;
  final int used;
  final int cap;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return Semantics(
      label: '$label: đã dùng ${formatInt(used)} trên ${formatInt(cap)} trong tháng',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(label, style: t.titleS),
                const Spacer(),
                Text('${formatInt(used)} / ${formatInt(cap)}', style: t.mono),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                color: color,
                backgroundColor: c.surfaceHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
