class ChallengeReview {
  const ChallengeReview({
    required this.participationId,
    required this.challengeTitle,
    required this.memberFullName,
    required this.memberCode,
    required this.progressValue,
    required this.target,
    required this.status,
    required this.evidenceUrl,
  });

  final String participationId;
  final String challengeTitle;
  final String memberFullName;
  final String memberCode;
  final int progressValue;
  final int target;
  final String status;
  final String? evidenceUrl;
}

class ChallengeReviewPage {
  const ChallengeReviewPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
  final List<ChallengeReview> items;
  final int page;
  final int totalPages;
  final int total;
}

abstract interface class ChallengeReviewRepository {
  Future<ChallengeReviewPage> list({String? status, String? evidence, String? query, int page = 1});
  Future<void> approveJoin(String participationId);
  Future<void> approve(String participationId);
}
