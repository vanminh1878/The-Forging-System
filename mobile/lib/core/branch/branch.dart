import '../utils/json_utils.dart';

/// Branch directory entry (`GET /branches`).
class Branch {
  const Branch({required this.id, required this.code, required this.name, this.address});

  factory Branch.fromJson(JsonMap j) => Branch(
        id: str(j, 'id'),
        code: str(j, 'code'),
        name: str(j, 'name'),
        address: strOrNull(j, 'address'),
      );

  final String id;
  final String code;
  final String name;
  final String? address;
}
