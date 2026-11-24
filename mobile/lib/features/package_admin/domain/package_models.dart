import '../../membership/domain/membership_models.dart';

/// Fields of the create/edit package form (PKG-01). Null limits mean
/// unlimited / not set.
class PackageDraft {
  const PackageDraft({
    required this.code,
    required this.name,
    required this.isTrial,
    required this.isActive,
    this.durationDays,
    this.totalSessions,
    this.sessionsPerWeek,
    this.priceVnd,
    this.description,
    this.sortOrder = 0,
  });

  factory PackageDraft.of(PackageType p) => PackageDraft(
        code: p.code,
        name: p.name,
        durationDays: p.durationDays,
        totalSessions: p.totalSessions,
        sessionsPerWeek: p.sessionsPerWeek,
        isTrial: p.isTrial,
        priceVnd: p.priceVnd,
        description: p.description,
        isActive: p.isActive,
        sortOrder: p.sortOrder,
      );

  final String code;
  final String name;
  final int? durationDays;
  final int? totalSessions;
  final int? sessionsPerWeek;
  final bool isTrial;
  final int? priceVnd;
  final String? description;
  final bool isActive;
  final int sortOrder;

  /// Request body of `POST /admin/package-types`.
  Map<String, Object?> toJson() => <String, Object?>{
        'code': code.trim(),
        'name': name.trim(),
        'durationDays': durationDays,
        'totalSessions': totalSessions,
        'sessionsPerWeek': sessionsPerWeek,
        'isTrial': isTrial,
        'priceVnd': priceVnd,
        'description':
            description?.trim().isEmpty ?? true ? null : description!.trim(),
        'isActive': isActive,
        'sortOrder': sortOrder,
      };

  /// Only the fields that differ from [before], for
  /// `PATCH /admin/package-types/:id`. Empty when nothing changed.
  Map<String, Object?> changesFrom(PackageDraft before) {
    final now = toJson();
    final old = before.toJson();
    return <String, Object?>{
      for (final key in now.keys)
        if (now[key] != old[key]) key: now[key],
    };
  }
}
