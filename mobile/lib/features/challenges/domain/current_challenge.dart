class CurrentChallenge {
  const CurrentChallenge({
    required this.id,
    required this.participationId,
    required this.title,
    required this.challengeType,
    required this.target,
    required this.rewardDp,
    required this.rewardMarks,
    required this.endsAt,
    required this.participationStatus,
    required this.progressValue,
    this.description,
    this.evidenceUrl,
    this.rejectionReason,
    this.completionMethod = 'EVIDENCE',
  });

  final String id;
  final String participationId;
  final String title;
  final String? description;
  final String challengeType;
  final int target;
  final int rewardDp;
  final int rewardMarks;
  final DateTime endsAt;
  final String participationStatus;
  final int progressValue;
  final String? evidenceUrl;
  final String? rejectionReason;
  final String completionMethod;

  double get progress =>
      target == 0 ? 0 : (progressValue / target).clamp(0, 1).toDouble();
}

abstract interface class CurrentChallengeRepository {
  Future<List<CurrentChallenge>> list();
  Future<void> submitEvidence(String challengeId, String evidenceUrl);
}
