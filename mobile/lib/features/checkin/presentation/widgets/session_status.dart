import 'package:flutter/widgets.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/checkin_session.dart';

/// What the chip of a session says about its check-in.
String checkinStatusLabel(CheckinSession s) {
  switch (s.state) {
    case CheckinState.open:
      return 'Đang mở check-in';
    case CheckinState.notYetOpen:
      return 'Mở lúc ${formatTime(s.opensAt)}';
    case CheckinState.closed:
      return 'Đã đóng check-in';
    case CheckinState.checkedIn:
      return s.checkedInAt == null ? 'Đã check-in' : 'Đã check-in ${formatTime(s.checkedInAt!)}';
    case CheckinState.overlapsCheckedIn:
      return 'Trùng giờ';
    case CheckinState.blocked:
      return 'Chưa thể check-in';
  }
}

ChipTone checkinStatusTone(CheckinState state) {
  switch (state) {
    case CheckinState.open:
      return ChipTone.success;
    case CheckinState.checkedIn:
      return ChipTone.gold;
    case CheckinState.notYetOpen:
      return ChipTone.info;
    case CheckinState.closed:
    case CheckinState.overlapsCheckedIn:
      return ChipTone.warning;
    case CheckinState.blocked:
      return ChipTone.danger;
  }
}

IconData checkinStatusIcon(CheckinState state) {
  switch (state) {
    case CheckinState.open:
      return HvpIcons.scan;
    case CheckinState.checkedIn:
      return HvpIcons.checkCircle;
    case CheckinState.notYetOpen:
      return HvpIcons.clock;
    case CheckinState.closed:
      return HvpIcons.lock;
    case CheckinState.overlapsCheckedIn:
      return HvpIcons.warning;
    case CheckinState.blocked:
      return HvpIcons.block;
  }
}
