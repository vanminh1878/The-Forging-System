import '../../membership/domain/membership_models.dart';

/// A renewal request in the front desk inbox (`GET /renewal-requests`).
class RenewalRequest {
  const RenewalRequest({
    required this.id,
    required this.status,
    required this.memberName,
    required this.packageName,
    this.memberPhone,
    this.memberCode = '',
    this.priceVnd,
    this.note,
    this.reason,
    this.createdAt,
    this.currentPackageName,
    this.currentEndDate,
    this.packageTypeId = '',
    this.classInfo,
  });

  final String id;

  /// `PENDING`, `COMPLETED` or `CANCELLED`.
  final String status;
  final String memberName;
  final String? memberPhone;
  final String memberCode;
  final String packageName;

  /// The package the learner asked for (to list its classes on approval).
  final String packageTypeId;
  final int? priceVnd;

  /// The class the learner chose; null when the package has no classes.
  final RenewalClass? classInfo;
  final String? note;

  /// Why it was cancelled.
  final String? reason;
  final DateTime? createdAt;
  final String? currentPackageName;

  /// Calendar date `YYYY-MM-DD`.
  final String? currentEndDate;

  bool get isPending => status == 'PENDING';
}

class RenewalPage {
  const RenewalPage(
      {required this.items, required this.page, required this.hasMore});

  final List<RenewalRequest> items;
  final int page;
  final bool hasMore;
}

/// Statuses the inbox can be filtered by, with their Vietnamese labels.
const Map<String, String> renewalStatusLabels = <String, String>{
  'PENDING': 'Chờ xử lý',
  'COMPLETED': 'Đã gia hạn',
  'CANCELLED': 'Đã huỷ',
};
