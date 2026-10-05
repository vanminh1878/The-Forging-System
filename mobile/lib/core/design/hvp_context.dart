import 'package:flutter/material.dart';

import 'hvp_colors.dart';
import 'hvp_text_styles.dart';

extension HvpThemeContext on BuildContext {
  HvpColors get hvp => Theme.of(this).extension<HvpColors>() ?? HvpColors.dark;
  HvpTextStyles get txt => Theme.of(this).extension<HvpTextStyles>() ?? HvpTextStyles(HvpColors.dark);
}
