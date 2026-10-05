/// Defensive JSON helpers: the backend sends ints as numbers (or numeric
/// strings for Postgres bigint) and dates as ISO-8601 strings.
typedef JsonMap = Map<String, dynamic>;

JsonMap asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> asList(Object? value) => value is List ? value : const <dynamic>[];

String str(JsonMap j, String key, [String fallback = '']) {
  final v = j[key];
  return v is String ? v : (v == null ? fallback : v.toString());
}

String? strOrNull(JsonMap j, String key) {
  final v = j[key];
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  return v.toString();
}

int intOf(JsonMap j, String key, [int fallback = 0]) {
  final v = j[key];
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round() ?? fallback;
  return fallback;
}

double doubleOf(JsonMap j, String key, [double fallback = 0]) {
  final v = j[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

bool boolOf(JsonMap j, String key, [bool fallback = false]) {
  final v = j[key];
  if (v is bool) return v;
  if (v is String) return v == 'true';
  return fallback;
}

/// Parses an ISO-8601 instant or `YYYY-MM-DD` date. Returns null when absent.
DateTime? dateOrNull(JsonMap j, String key) {
  final v = j[key];
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

List<String> stringList(Object? value) =>
    asList(value).map((e) => e.toString()).toList(growable: false);
