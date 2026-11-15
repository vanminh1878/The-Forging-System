/// A class of a package from `GET /package-types/:id/classes`, as offered in
/// the "choose a class" step.
class PackageClassOption {
  const PackageClassOption({
    required this.id,
    required this.name,
    required this.branchName,
    required this.weekdays,
    required this.startTime,
    required this.durationMinutes,
    this.coachName,
    this.capacity,
    this.seatsLeft,
    this.enrolled = false,
  });

  final String id;
  final String name;
  final String branchName;
  final String? coachName;

  /// ISO weekdays, 1 = Monday ... 7 = Sunday.
  final List<int> weekdays;

  /// `HH:mm`.
  final String startTime;
  final int durationMinutes;

  /// Null = no limit.
  final int? capacity;

  /// Null = unlimited seats.
  final int? seatsLeft;

  /// The learner already holds a seat here (renewing the same class).
  final bool enrolled;

  bool get isFull => seatsLeft != null && seatsLeft! <= 0;

  /// A full class stays pickable for a learner who already has a seat in it.
  bool get isSelectable => !isFull || enrolled;
}
