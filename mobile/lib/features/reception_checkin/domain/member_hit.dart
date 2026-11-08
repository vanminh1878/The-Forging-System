/// A learner found at the front desk by name, phone or member code.
class MemberHit {
  const MemberHit({
    required this.id,
    required this.memberCode,
    required this.fullName,
    required this.status,
    this.phone,
    this.avatarUrl,
    this.rankName,
    this.packageName,
    this.packageEndDate,
  });

  final String id;
  final String memberCode;
  final String fullName;
  final String? phone;
  final String? avatarUrl;

  /// `ACTIVE`, `FROZEN` or `INACTIVE`.
  final String status;
  final String? rankName;

  /// The package running now, if any.
  final String? packageName;

  /// When that package ends, a calendar date `YYYY-MM-DD`; null for no expiry.
  final String? packageEndDate;
}

class MemberSearchResult {
  const MemberSearchResult({required this.items, required this.total});

  final List<MemberHit> items;

  /// Everyone matching, which can be more than [items] (the first page only).
  final int total;

  bool get hasMoreThanShown => total > items.length;
}

abstract interface class MemberSearchRepository {
  /// Learners matching [query] in name, phone, email or member code, by name.
  /// An empty [query] matches everyone.
  Future<MemberSearchResult> search(String query);
}
