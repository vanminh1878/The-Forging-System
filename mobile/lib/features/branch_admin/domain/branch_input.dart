import '../../../core/branch/branch.dart';

/// What the admin branch form sends (`POST /admin/branches`, `PATCH /admin/branches/:id`).
class BranchInput {
  const BranchInput({
    this.code,
    required this.name,
    this.address,
    this.openingHours,
    this.latitude,
    this.longitude,
    this.geofenceRadiusM = 100,
  });

  /// Null on create: the server assigns the next sequential code (CN001, CN002...). Not sent on edit.
  final String? code;
  final String name;
  final String? address;
  final String? openingHours;
  final double? latitude;
  final double? longitude;
  final int geofenceRadiusM;
}

/// Field rules of docs/api/branches.md. Each returns an error message or null.
abstract final class BranchRules {
  static final RegExp _time = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$');
  static final RegExp _hours =
      RegExp(r'^\s*(\d{1,2}:\d{2})\s*[–-]\s*(\d{1,2}:\d{2})\s*$');

  static String? name(String? v) {
    final n = (v ?? '').trim().length;
    return n >= 2 && n <= 100 ? null : 'Tên chi nhánh gồm 2–100 ký tự.';
  }

  static String? address(String? v) =>
      (v ?? '').trim().length <= 255 ? null : 'Địa chỉ tối đa 255 ký tự.';

  static String? openingHours(String? v) =>
      (v ?? '').trim().length <= 100 ? null : 'Giờ mở cửa tối đa 100 ký tự.';

  /// "06:00 – 21:30" -> ("06:00", "21:30"); null when the text is not in that
  /// shape (old free text such as "6h đến 21h").
  static (String, String)? splitHours(String? v) {
    final m = _hours.firstMatch(v ?? '');
    if (m == null) return null;
    final open = _normTime(m.group(1)!);
    final close = _normTime(m.group(2)!);
    return open == null || close == null ? null : (open, close);
  }

  /// The text stored in `openingHours`.
  static String joinHours(String open, String close) =>
      '${_normTime(open) ?? open} – ${_normTime(close) ?? close}';

  /// Opening time: both times are optional, but one without the other is an error.
  static String? openingTime(String? open, String? close) {
    final o = (open ?? '').trim();
    final c = (close ?? '').trim();
    if (o.isEmpty) return c.isEmpty ? null : 'Nhập giờ mở cửa.';
    return _normTime(o) == null
        ? 'Giờ mở cửa theo dạng HH:mm, ví dụ 06:00.'
        : null;
  }

  /// Closing time: valid HH:mm and later than the opening time.
  static String? closingTime(String? open, String? close) {
    final o = (open ?? '').trim();
    final c = (close ?? '').trim();
    if (c.isEmpty) return o.isEmpty ? null : 'Nhập giờ đóng cửa.';
    final end = _minutes(c);
    if (end == null) return 'Giờ đóng cửa theo dạng HH:mm, ví dụ 21:30.';
    final start = _minutes(o);
    if (start != null && end <= start) {
      return 'Giờ đóng cửa phải sau giờ mở cửa.';
    }
    return null;
  }

  static String? radius(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return n != null && n >= 10 && n <= 5000
        ? null
        : 'Bán kính từ 10 đến 5000 m.';
  }

  static String? _normTime(String v) {
    final m = _time.firstMatch(v.trim());
    return m == null ? null : '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
  }

  static int? _minutes(String v) {
    final m = _time.firstMatch(v.trim());
    return m == null
        ? null
        : int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }
}

/// Pre-fills the form from an existing branch.
BranchInput inputOf(Branch b) => BranchInput(
      name: b.name,
      address: b.address,
      openingHours: b.openingHours,
      latitude: b.latitude,
      longitude: b.longitude,
      geofenceRadiusM: b.geofenceRadiusM,
    );
