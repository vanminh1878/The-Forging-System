import 'package:flutter/material.dart' show IconData, Icons;

/// Every icon used by the app, in one place (built-in Material icons: no extra package, always
/// compatible with the installed Flutter SDK). To change an icon app-wide, edit it here only.
abstract final class HvpIcons {
  // Navigation
  static const IconData home = Icons.home_outlined;
  static const IconData homeFill = Icons.home_rounded;
  static const IconData calendar = Icons.calendar_month_outlined;
  static const IconData calendarFill = Icons.calendar_month;
  static const IconData scan = Icons.qr_code_scanner;
  static const IconData scanFill = Icons.qr_code_scanner;
  static const IconData armory = Icons.local_mall_outlined;
  static const IconData armoryFill = Icons.local_mall;
  static const IconData user = Icons.person_outline;
  static const IconData userFill = Icons.person;
  static const IconData users = Icons.groups_outlined;
  static const IconData usersFill = Icons.groups;
  static const IconData chart = Icons.bar_chart;
  static const IconData chartFill = Icons.bar_chart;
  static const IconData book = Icons.school_outlined;
  static const IconData bookFill = Icons.school;
  static const IconData flag = Icons.flag_outlined;
  static const IconData flagFill = Icons.flag;
  static const IconData history = Icons.history;
  static const IconData historyFill = Icons.history;
  static const IconData ticket = Icons.confirmation_number_outlined;
  static const IconData ticketFill = Icons.confirmation_number;
  static const IconData gift = Icons.card_giftcard_outlined;
  static const IconData giftFill = Icons.card_giftcard;
  static const IconData package = Icons.inventory_2_outlined;
  static const IconData packageFill = Icons.inventory_2;
  static const IconData megaphone = Icons.campaign_outlined;
  static const IconData megaphoneFill = Icons.campaign;
  static const IconData gear = Icons.settings_outlined;
  static const IconData gearFill = Icons.settings;

  // Brand / gamification
  static const IconData glove = Icons.sports_mma;
  static const IconData gloveBold = Icons.sports_mma;
  static const IconData fire = Icons.local_fire_department;
  static const IconData fireBold = Icons.local_fire_department_outlined;
  static const IconData trophy = Icons.emoji_events;
  static const IconData trophyBold = Icons.emoji_events_outlined;
  static const IconData medal = Icons.military_tech;
  static const IconData lightning = Icons.bolt;
  static const IconData crown = Icons.workspace_premium;
  static const IconData hammer = Icons.hardware;
  static const IconData shield = Icons.shield;
  static const IconData shieldCheck = Icons.verified_user;
  static const IconData question = Icons.help;
  static const IconData star = Icons.star;
  static const IconData coins = Icons.monetization_on;
  static const IconData sparkle = Icons.auto_awesome;

  // Actions & status
  static const IconData bell = Icons.notifications_none;
  static const IconData bellFill = Icons.notifications;
  static const IconData bellRinging = Icons.notifications_active;
  static const IconData check = Icons.check;
  static const IconData checks = Icons.done_all;
  static const IconData checkCircle = Icons.check_circle;
  static const IconData close = Icons.close;
  static const IconData xCircle = Icons.cancel;
  static const IconData warning = Icons.warning_rounded;
  static const IconData info = Icons.info;
  static const IconData lock = Icons.lock;
  static const IconData lockOpen = Icons.lock_open;
  static const IconData hourglass = Icons.hourglass_bottom;
  static const IconData camera = Icons.photo_camera;
  static const IconData image = Icons.image;
  static const IconData pencil = Icons.edit;
  static const IconData plus = Icons.add;
  static const IconData trash = Icons.delete_outline;
  static const IconData retry = Icons.refresh;
  static const IconData caretRight = Icons.chevron_right;
  static const IconData caretLeft = Icons.chevron_left;
  static const IconData caretDown = Icons.expand_more;
  static const IconData arrowRight = Icons.arrow_forward;
  static const IconData signOut = Icons.logout;
  static const IconData eye = Icons.visibility;
  static const IconData eyeSlash = Icons.visibility_off;
  static const IconData phone = Icons.phone;
  static const IconData mail = Icons.mail_outline;
  static const IconData key = Icons.key;
  static const IconData lockKey = Icons.lock_outline;
  static const IconData mapPin = Icons.place;
  static const IconData cake = Icons.cake;
  static const IconData idCard = Icons.badge;
  static const IconData moon = Icons.dark_mode;
  static const IconData sun = Icons.light_mode;
  static const IconData deviceMobile = Icons.smartphone;
  static const IconData tray = Icons.inbox;
  static const IconData list = Icons.format_list_bulleted;
  static const IconData snowflake = Icons.ac_unit;
  static const IconData rocket = Icons.rocket_launch;
  static const IconData wrench = Icons.build;
  static const IconData receipt = Icons.receipt_long;
  static const IconData barbell = Icons.fitness_center;

  /// One icon per rank order (1..7).
  static IconData rank(int order) {
    switch (order) {
      case 1:
        return question;
      case 2:
        return lightning;
      case 3:
        return shieldCheck;
      case 4:
        return hammer;
      case 5:
        return glove;
      case 6:
        return shield;
      default:
        return crown;
    }
  }
}