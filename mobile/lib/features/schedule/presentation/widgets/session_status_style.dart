import 'package:flutter/material.dart';

import '../../../../core/design/hvp_colors.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/schedule_models.dart';

/// Chip tone for each session status (also the colour of its calendar dot).
ChipTone sessionStatusTone(SessionStatus status) {
  switch (status) {
    case SessionStatus.upcoming:
      return ChipTone.info;
    case SessionStatus.cancelled:
      return ChipTone.neutral;
    case SessionStatus.awaitingCoach:
      return ChipTone.warning;
    case SessionStatus.confirmedPass:
      return ChipTone.success;
    case SessionStatus.confirmedFail:
    case SessionStatus.absent:
      return ChipTone.danger;
  }
}

IconData sessionStatusIcon(SessionStatus status) {
  switch (status) {
    case SessionStatus.upcoming:
      return HvpIcons.upcoming;
    case SessionStatus.awaitingCoach:
      return HvpIcons.hourglass;
    case SessionStatus.confirmedPass:
      return HvpIcons.checkCircle;
    case SessionStatus.confirmedFail:
      return HvpIcons.xCircle;
    case SessionStatus.absent:
      return HvpIcons.personOff;
    case SessionStatus.cancelled:
      return HvpIcons.block;
  }
}

Color sessionStatusColor(HvpColors c, SessionStatus status) =>
    StatusChip.foreground(c, sessionStatusTone(status));

/// Status pill using the shared mapping. "Vắng mặt" is filled so it does not
/// fade into the card.
class SessionStatusChip extends StatelessWidget {
  const SessionStatusChip({super.key, required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) => StatusChip(
        label: status.label,
        tone: sessionStatusTone(status),
        icon: sessionStatusIcon(status),
        solid: status == SessionStatus.absent,
      );
}
