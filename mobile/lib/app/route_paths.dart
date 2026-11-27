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
  static const String armoryRedemptions = '/student/armory/redemptions';
  static const String armoryRedemptionPattern =
      '/student/armory/redemptions/:redemptionId';
  static String armoryRedemption(String id) =>
      '/student/armory/redemptions/$id';
  static const String profile = '/student/profile';

  // Pushed screens
  static const String checkinScan = '/student/checkin/scan';

  /// The scanner, optionally told which session the learner picked (`?sessionId=`).
  static String checkinScanFor(String? sessionId) => sessionId == null
      ? checkinScan
      : '$checkinScan?sessionId=${Uri.encodeQueryComponent(sessionId)}';
  static const String fighterRecord = '/student/fighter-record';
  static const String streak = '/student/streak';
  static const String challenges = '/student/challenges';
  static const String currentChallenges = '/student/challenges/current';
  static const String notifications = '/student/notifications';
  static const String membership = '/student/membership';
  static const String workLog = '/student/work-log';
  static const String sessionPattern = '/student/sessions/:id';
  static String session(String id) => '/student/sessions/$id';
  static const String courses = '/student/courses';
  static const String coursePattern = '/student/courses/:courseId';
  static String course(String id) => '/student/courses/$id';
  static const String courseLessonPattern =
      '/student/courses/:courseId/lessons/:lessonNo';
  static String courseLesson(String courseId, int lessonNo) =>
      '/student/courses/$courseId/lessons/$lessonNo';
  static const String lessonPattern = '/student/lessons/:id';
  static String lesson(String id) => '/student/lessons/$id';
}

abstract final class CoachPaths {
  static const String today = '/coach/today';
  static const String classes = '/coach/classes';
  static const String challenge = '/coach/challenge';
  static const String rankTrial = '/coach/rank-trial';
  static const String history = '/coach/history';
  static const String notifications = '/coach/notifications';

  // Pushed screens
  static const String classDetailPattern = '/coach/classes/:id';
  static String classDetail(String id) => '/coach/classes/$id';
}

abstract final class ReceptionPaths {
  static const String checkin = '/reception/checkin';

  // Pushed screens
  static const String branchQr = '/reception/checkin/qr';
  static const String memberTodayPattern =
      '/reception/checkin/member/:memberId';
  static String memberToday(String memberId) =>
      '/reception/checkin/member/$memberId';
  static const String assistedCheckinPattern =
      '/reception/checkin/member/:memberId/session/:sessionId';
  static String assistedCheckin(String memberId, String sessionId) =>
      '/reception/checkin/member/$memberId/session/$sessionId';

  static const String memberships = '/reception/memberships';
  static const String membershipMemberPattern =
      '/reception/memberships/member/:memberId';
  static String membershipMember(String memberId) =>
      '/reception/memberships/member/$memberId';
  static const String stock = '/reception/stock';
  static const String handover = '/reception/handover';
  static const String classes = '/reception/classes';
  static const String classDetailPattern = '/reception/classes/:id';
  static String classDetail(String id) => '/reception/classes/$id';
  static const String profile = '/reception/profile';
  static const String notifications = '/reception/notifications';
}

abstract final class AdminPaths {
  static const String dashboard = '/admin/dashboard';
  static const String members = '/admin/members';
  static const String training = '/admin/training';
  static const String challenges = '/admin/challenges';
  static const String notifications = '/admin/notifications';
  static const String settings = '/admin/settings';
  static const String classDetailPattern = '/admin/training/classes/:id';
  static String classDetail(String id) => '/admin/training/classes/$id';

  // Pushed screens
  static const String branches = '/admin/settings/branches';
  static const String armory = '/admin/settings/armory';
  static const String renewalRequests = '/admin/settings/renewal-requests';
  static const String auditLogs = '/admin/settings/audit-logs';
  static const String configHistory = '/admin/settings/history';
  static const String pointsAdjustment = '/admin/points/adjustments';
  static const String armoryRewards = '/admin/settings/armory/rewards';
  static String armoryRewardsForTier(String tierCode) =>
      '$armoryRewards?tierCode=${Uri.encodeQueryComponent(tierCode)}';
  static const String armoryTierCreate = '/admin/settings/armory/tiers/create';
  static const String armoryRewardCreate =
      '/admin/settings/armory/rewards/create';
  static const String challengeCreate = '/admin/challenges/create';
  static const String challengeEditPattern =
      '/admin/challenges/:challengeId/edit';
  static String challengeEdit(String challengeId) =>
      '/admin/challenges/$challengeId/edit';
}
