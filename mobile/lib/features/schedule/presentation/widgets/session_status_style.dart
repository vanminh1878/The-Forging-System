import 'package:flutter/material.dart';

import '../../../../core/design/hvp_colors.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/schedule_models.dart';

/// Chip tone for each session status (also the colour of its calendar dot).
ChipTone sessionStatusTone(SessionStatus status) {
  switch (status) {
    case SessionStatus.upcoming:
    case SessionStatus.absent:
    case SessionStatus.cancelled:
      return ChipTone.neutral;
    case SessionStatus.awaitingCoach:
      return ChipTone.warning;
    case SessionStatus.confirmedPass:
      return ChipTone.success;
    case SessionStatus.confirmedFail:
      return ChipTone.danger;
  }
}

Color sessionStatusColor(HvpColors c, SessionStatus status) =>
    StatusChip.foreground(c, sessionStatusTone(status));

/// Status pill using the shared mapping.
class SessionStatusChip extends StatelessWidget {
  const SessionStatusChip({super.key, required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: status.label, tone: sessionStatusTone(status));
}
