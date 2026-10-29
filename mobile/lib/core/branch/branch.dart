import '../utils/json_utils.dart';

/// Branch directory entry (`GET /branches`). The optional fields are what the
/// admin list uses; `qrVersion` is only sent to staff.
class Branch {
  const Branch({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    this.openingHours,
    this.isActive = true,
    this.qrVersion,
  });

  factory Branch.fromJson(JsonMap j) => Branch(
        id: str(j, 'id'),
        code: str(j, 'code'),
        name: str(j, 'name'),
        address: strOrNull(j, 'address'),
        openingHours: strOrNull(j, 'openingHours'),
        isActive: boolOf(j, 'isActive', true),
        qrVersion: strOrNull(j, 'qrVersion'),
      );

  final String id;
  final String code;
  final String name;
  final String? address;
  final String? openingHours;
  final bool isActive;
  final String? qrVersion;

  /// "address · openingHours", skipping whichever part is missing.
  String get addressLine => <String?>[address, openingHours]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' · ');
}
