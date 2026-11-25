import '../../../../core/widgets/status_chip.dart';

String streakResultLabel(String result) => switch (result) {
      'INCREASED' => 'Tăng chuỗi',
      'FROZEN' => 'Đã dùng Freeze',
      'RESET' => 'Chuỗi đặt lại',
      'SKIPPED' => 'Chưa bắt đầu',
      _ => result,
    };

ChipTone streakResultTone(String result) => switch (result) {
      'INCREASED' => ChipTone.success,
      'FROZEN' => ChipTone.gold,
      'RESET' => ChipTone.danger,
      _ => ChipTone.neutral,
    };
