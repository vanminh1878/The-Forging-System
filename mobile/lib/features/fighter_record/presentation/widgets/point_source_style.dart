import 'package:flutter/widgets.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../domain/points_models.dart';

/// Icon of each ledger source.
IconData iconOfSource(PointSource source) {
  switch (source) {
    case PointSource.opening:
      return HvpIcons.sparkle;
    case PointSource.session:
      return HvpIcons.barbell;
    case PointSource.attitude:
      return HvpIcons.star;
    case PointSource.academy:
      return HvpIcons.book;
    case PointSource.streakMilestone:
      return HvpIcons.fire;
    case PointSource.challenge:
      return HvpIcons.flag;
    case PointSource.rankTrial:
      return HvpIcons.trophy;
    case PointSource.earlyRenewal:
      return HvpIcons.ticket;
    case PointSource.comeback:
      return HvpIcons.rocket;
    case PointSource.armoryRedeem:
      return HvpIcons.gift;
    case PointSource.manualAdjustment:
      return HvpIcons.wrench;
    case PointSource.reversal:
      return HvpIcons.retry;
    case PointSource.other:
      return HvpIcons.coins;
  }
}
