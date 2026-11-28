class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actorType,
    required this.createdAt,
    this.actorId,
    this.actorName,
    this.reason,
    this.beforeData,
    this.afterData,
  });

  final int id;
  final String action;
  final String entityType;
  final String entityId;
  final String actorType;
  final String? actorId;
  final String? actorName;
  final String? reason;
  final Object? beforeData;
  final Object? afterData;
  final DateTime createdAt;
}

class AuditLogPage {
  const AuditLogPage(
      {required this.items,
      required this.page,
      required this.totalPages,
      required this.total});

  final List<AuditLogEntry> items;
  final int page;
  final int totalPages;
  final int total;
}

abstract interface class AuditLogRepository {
  Future<AuditLogPage> list({
    String? query,
    String? action,
    String? entityType,
    String? entityId,
    DateTime? from,
    DateTime? to,
    int page,
  });
}
