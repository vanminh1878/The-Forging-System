class OpenChallenge {
  const OpenChallenge({
    required this.id,
    required this.code,
    required this.title,
    required this.challengeType,
    required this.context,
    required this.target,
    required this.rewardDp,
    required this.rewardMarks,
    required this.endsAt,
    this.description,
    this.participationId,
    this.participationStatus,
    this.progressValue,
  });

  final String id;
  final String code;
  final String title;
  final String? description;
  final String challengeType;
  final String context;
  final int target;
  final int rewardDp;
  final int rewardMarks;
  final DateTime endsAt;
  final String? participationId;
  final String? participationStatus;
  final int? progressValue;
}

class OpenChallengePage {
  const OpenChallengePage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<OpenChallenge> items;
  final int page;
  final int totalPages;
  final int total;
}

abstract interface class OpenChallengeRepository {
  Future<OpenChallengePage> list({String? challengeType, int page = 1});
  Future<void> join(String challengeId);
}
