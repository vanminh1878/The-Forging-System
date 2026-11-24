class AdminChallenge {
  const AdminChallenge({
    required this.id,
    required this.title,
    required this.challengeType,
    required this.context,
    required this.target,
    required this.rewardDp,
    required this.rewardMarks,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.joinApproval = 'COACH',
    this.completionMethod = 'EVIDENCE',
    this.code,
    this.description,
  });

  final String id;
  final String? code;
  final String title;
  final String? description;
  final String challengeType;
  final String context;
  final int target;
  final int rewardDp;
  final int rewardMarks;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final String joinApproval;
  final String completionMethod;
}

class AdminChallengePage {
  const AdminChallengePage(
      {required this.items,
      required this.page,
      required this.totalPages,
      required this.total});
  final List<AdminChallenge> items;
  final int page;
  final int totalPages;
  final int total;
}

class ChallengeInput {
  const ChallengeInput({
    required this.title,
    required this.challengeType,
    required this.context,
    required this.target,
    required this.rewardDp,
    required this.rewardMarks,
    required this.startsAt,
    required this.endsAt,
    this.joinApproval = 'COACH',
    this.completionMethod = 'EVIDENCE',
    this.code,
    this.description,
  });

  final String? code;
  final String title;
  final String? description;
  final String challengeType;
  final String context;
  final int target;
  final int rewardDp;
  final int rewardMarks;
  final DateTime startsAt;
  final DateTime endsAt;
  final String joinApproval;
  final String completionMethod;
}

abstract interface class AdminChallengeRepository {
  Future<AdminChallengePage> list(
      {String? query,
      String? status,
      String? challengeType,
      String? context,
      int page = 1});
  Future<AdminChallenge> detail(String id);
  Future<void> create(ChallengeInput input);
  Future<void> update(String id, ChallengeInput input, String reason);
  Future<void> setEnabled(String id,
      {required bool enabled, required String reason});
}
