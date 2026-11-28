import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/icon_label.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/membership_models.dart';
import '../../domain/membership_rules.dart';

class _Line extends StatelessWidget {
  const _Line(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: context.hvp.gold),
          const SizedBox(width: 8),
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
    final endingSoon = badge == CurrentPackageBadge.endingSoon;
    return HvpCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(HvpIcons.lesson, size: 22, color: c.gold),
              const SizedBox(width: 8),
              Expanded(child: Text(package.name, style: t.titleM)),
              if (package.isTrial) ...<Widget>[
                const StatusChip(
                    label: 'Gói thử',
                    tone: ChipTone.gold,
                    icon: HvpIcons.sparkle),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
          StatusChip(
            label: badge.label,
            icon: endingSoon ? HvpIcons.warning : HvpIcons.checkCircle,
            tone: endingSoon ? ChipTone.warning : ChipTone.success,
          ),
          const SizedBox(height: 4),
          _Line(
              HvpIcons.eventStart,
              'Bắt đầu',
              package.startDate == null
                  ? ''
                  : formatCalendarDate(package.startDate!)),
          _Line(
              HvpIcons.eventEnd,
              'Hết hạn',
              package.endDate == null
                  ? 'Không thời hạn'
                  : formatCalendarDate(package.endDate!)),
          if (days != null) _Line(HvpIcons.hourglass, 'Thời gian', days),
          const SizedBox(height: 12),
          IconLabel(
              icon: HvpIcons.barbell,
              iconSize: 18,
              label: sessionsLabel(package),
              style: t.body),
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
          const StatusChip(
              label: 'Gói sắp kích hoạt',
              tone: ChipTone.info,
              icon: HvpIcons.scheduled),
          const SizedBox(height: 8),
          IconLabel(
              icon: HvpIcons.lesson,
              iconSize: 18,
              label: package.name,
              style: t.titleS),
          const SizedBox(height: 6),
          IconLabel(
              icon: HvpIcons.dateRange,
              label: validityLabel(package),
              style: t.body),
          const SizedBox(height: 4),
          IconLabel(
              icon: HvpIcons.barbell,
              label: total == null ? 'Không giới hạn số buổi' : '$total buổi'),
          const SizedBox(height: 8),
          IconLabel(
              icon: HvpIcons.info,
              label:
                  'Gói này tự kích hoạt khi gói hiện tại hết hạn, thời hạn không bị mất.',
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
              const StatusChip(
                  label: 'Chờ duyệt',
                  tone: ChipTone.warning,
                  icon: HvpIcons.hourglass),
            ],
          ),
          const SizedBox(height: 6),
          IconLabel(
            icon: HvpIcons.send,
            label: sent == null
                ? renewal.packageName
                : '${renewal.packageName} · gửi ${formatDate(sent)}',
          ),
        ],
      ),
    );
  }
}

/// One row of the renewal history.
class RenewalRequestTile extends StatelessWidget {
  const RenewalRequestTile({super.key, required this.request});

  final RenewalRequest request;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final sent = request.createdAt;
    final reason = request.reason;
    return HvpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(request.packageName, style: t.titleS)),
              const SizedBox(width: 8),
              StatusChip(
                label: request.status.label,
                icon: switch (request.status) {
                  RenewalStatus.pending => HvpIcons.hourglass,
                  RenewalStatus.completed => HvpIcons.checkCircle,
                  RenewalStatus.cancelled => HvpIcons.xCircle,
                },
                tone: switch (request.status) {
                  RenewalStatus.pending => ChipTone.warning,
                  RenewalStatus.completed => ChipTone.success,
                  RenewalStatus.cancelled => ChipTone.danger,
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          IconLabel(
            icon: HvpIcons.money,
            label: [
              if (sent != null) 'Gửi ${formatDate(sent)}',
              priceLabel(request.priceVnd),
            ].join(' · '),
          ),
          if (reason != null) ...<Widget>[
            const SizedBox(height: 4),
            IconLabel(
                icon: HvpIcons.note,
                label: 'Lý do huỷ: $reason',
                style: t.body),
          ],
        ],
      ),
    );
  }
}
