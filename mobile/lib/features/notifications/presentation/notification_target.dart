import '../../../app/route_paths.dart';

/// Where opening a notification leads: a route, and whether it is a shell tab
/// (reached with `go`) or a pushed screen (reached with `push`, so back returns to the inbox).
class NotificationTarget {
  const NotificationTarget(this.path, {this.isTab = false});

  final String path;
  final bool isTab;
}

/// The screen an event is about, or null when it has none (welcome, broadcasts, unknown events):
/// opening those only reads them.
NotificationTarget? notificationTarget(String eventType) {
  if (eventType.startsWith('RANK')) return const NotificationTarget(StudentPaths.fighterRecord);
  if (eventType.startsWith('STREAK')) return const NotificationTarget(StudentPaths.streak);
  if (eventType.startsWith('INACTIVE')) return const NotificationTarget(StudentPaths.streak);
  if (eventType.startsWith('ARMORY')) return const NotificationTarget(StudentPaths.armory, isTab: true);
  if (eventType.startsWith('MEMBERSHIP') || eventType.startsWith('RENEWAL')) {
    return const NotificationTarget(StudentPaths.membership);
  }
  if (const <String>{
    'CHALLENGE_JOINED',
    'CHALLENGE_JOIN_APPROVED',
    'CHALLENGE_COMPLETED',
    'CHALLENGE_REWARDED',
  }.contains(eventType)) {
    return const NotificationTarget(StudentPaths.currentChallenges);
  }
  if (eventType.startsWith('CHALLENGE')) {
    return const NotificationTarget(StudentPaths.challenges);
  }
  switch (eventType) {
    case 'SESSION_COMPLETED':
    case 'NEAR_RANK':
    case 'COMEBACK_BONUS':
    case 'DP_ADJUSTED':
    case 'BELOW_THRESHOLD':
    case 'ACADEMY_FAILED':
      return const NotificationTarget(StudentPaths.fighterRecord);
    case 'BOOK_COMPLETED':
      return const NotificationTarget(StudentPaths.courses);
    case 'EXAM':
    case 'ABSENT':
      return const NotificationTarget(StudentPaths.schedule, isTab: true);
    default:
      return null;
  }
}
