import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/membership_models.dart';
import '../../domain/membership_rules.dart';

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: t.bodySmall)),
          Text(value, style: t.body),
        ],
      ),
    );
  }
}

/// The active package: dates, days left and session usage.
class CurrentPackageCard extends StatelessWidget {
  const CurrentPackageCard({super.key, required this.package});

  final MemberPackage package;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final badge = currentPackageBadge(package);
    final fraction = sessionsFraction(package);
    final days = daysRemainingLabel(package.daysRemaining);
    return HvpCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(package.name, style: t.titleM)),
              if (package.isTrial) ...<Widget>[
                const StatusChip(label: 'Gói thử', tone: ChipTone.gold),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
          StatusChip(
            label: badge.label,
            tone: badge == CurrentPackageBadge.endingSoon
                ? ChipTone.warning
                : ChipTone.success,
          ),
          const SizedBox(height: 8),
          _Line(
              'Bắt đầu',
              package.startDate == null
                  ? ''
                  : formatCalendarDate(package.startDate!)),
          _Line(
              'Hết hạn',
              package.endDate == null
                  ? 'Không thời hạn'
                  : formatCalendarDate(package.endDate!)),
          if (days != null) _Line('Thời gian', days),
          const SizedBox(height: 12),
          Text(sessionsLabel(package), style: t.body),
          if (fraction != null) ...<Widget>[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                color: c.gold,
                backgroundColor: c.surfaceHigh,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The queued package that activates when the current one ends.
class ScheduledPackageCard extends StatelessWidget {
  const ScheduledPackageCard({super.key, required this.package});

  final MemberPackage package;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final total = package.totalSessions;
    return HvpCard(
      accent: c.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const StatusChip(label: 'Gói nối tiếp', tone: ChipTone.info),
          const SizedBox(height: 8),
          Text(package.name, style: t.titleS),
          const SizedBox(height: 6),
          Text(validityLabel(package), style: t.body),
          Text(total == null ? 'Không giới hạn số buổi' : '$total buổi',
              style: t.bodySmall),
          const SizedBox(height: 8),
          Text('Gói nối tiếp tự kích hoạt khi gói hiện tại hết hạn.',
              style: t.caption),
        ],
      ),
    );
  }
}

/// Renewal request sent to the front desk (read-only).
class PendingRenewalCard extends StatelessWidget {
  const PendingRenewalCard({super.key, required this.renewal});

  final PendingRenewal renewal;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final sent = renewal.createdAt;
    return HvpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: Text('Đã gửi yêu cầu · chờ lễ tân xác nhận',
                      style: t.titleS)),
              const SizedBox(width: 8),
              const StatusChip(label: 'Chờ duyệt', tone: ChipTone.warning),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sent == null
                ? renewal.packageName
                : '${renewal.packageName} · gửi ${formatDate(sent)}',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
