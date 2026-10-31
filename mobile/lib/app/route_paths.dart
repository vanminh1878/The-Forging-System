import '../features/auth/domain/auth_user.dart';

/// Every route path of the app. Role paths live here (not in the route files)
/// so any file can link to a screen without importing another feature.
abstract final class AppPaths {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String changePassword = '/change-password';

  /// Screens reachable without a session.
  static const List<String> public = <String>[login, register, forgotPassword];

  /// First tab of each role; where a signed-in user lands.
  static String homeOf(AppRole role) {
    switch (role) {
      case AppRole.student:
        return StudentPaths.home;
      case AppRole.coach:
        return CoachPaths.today;
      case AppRole.reception:
        return ReceptionPaths.checkin;
      case AppRole.admin:
        return AdminPaths.dashboard;
    }
  }
}

abstract final class StudentPaths {
  // Tabs
  static const String home = '/student/home';
  static const String schedule = '/student/schedule';
  static const String checkin = '/student/checkin';
  static const String armory = '/student/armory';
  static const String profile = '/student/profile';

  // Pushed screens
  static const String fighterRecord = '/student/fighter-record';
  static const String streak = '/student/streak';
  static const String challenges = '/student/challenges';
  static const String notifications = '/student/notifications';
  static const String membership = '/student/membership';
  static const String workLog = '/student/work-log';
  static const String lessonPattern = '/student/lessons/:id';
  static String lesson(String id) => '/student/lessons/$id';
}

abstract final class CoachPaths {
  static const String today = '/coach/today';
  static const String classes = '/coach/classes';
  static const String challenge = '/coach/challenge';
  static const String rankTrial = '/coach/rank-trial';
  static const String history = '/coach/history';
}

abstract final class ReceptionPaths {
  static const String checkin = '/reception/checkin';
  static const String memberships = '/reception/memberships';
  static const String stock = '/reception/stock';
  static const String handover = '/reception/handover';
}

abstract final class AdminPaths {
  static const String dashboard = '/admin/dashboard';
  static const String members = '/admin/members';
  static const String training = '/admin/training';
  static const String challenges = '/admin/challenges';
  static const String notifications = '/admin/notifications';
  static const String settings = '/admin/settings';

  // Pushed screens
  static const String branches = '/admin/settings/branches';
}
