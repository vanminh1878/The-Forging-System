import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/audit_log.dart';

class AuditLogRepositoryImpl implements AuditLogRepository {
  AuditLogRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<AuditLogPage> list(
      {String? query,
      String? action,
      String? entityType,
      String? entityId,
      DateTime? from,
      DateTime? to,
      int page = 1}) async {
    final response =
        await _api.get('/admin/audit-logs', query: <String, dynamic>{
      'page': page,
      'limit': 20,
      if (query?.trim().isNotEmpty ?? false) 'q': query!.trim(),
      if (action?.trim().isNotEmpty ?? false) 'action': action!.trim(),
      if (entityType?.trim().isNotEmpty ?? false)
        'entityType': entityType!.trim(),
      if (entityId?.trim().isNotEmpty ?? false) 'entityId': entityId!.trim(),
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    });
    final meta = PageMeta.fromJson(response.meta);
    return AuditLogPage(
      items: response.dataList
          .map((item) => _fromJson(asMap(item)))
          .toList(growable: false),
      page: meta.page,
      totalPages: meta.totalPages,
      total: meta.total,
    );
  }

  AuditLogEntry _fromJson(JsonMap json) => AuditLogEntry(
        id: intOf(json, 'id'),
        action: str(json, 'action'),
        entityType: str(json, 'entityType'),
        entityId: str(json, 'entityId'),
        actorType: str(json, 'actorType', 'SYSTEM'),
        actorId: strOrNull(json, 'actorId'),
        actorName: strOrNull(json, 'actorName'),
        reason: strOrNull(json, 'reason'),
        beforeData: json['beforeData'],
        afterData: json['afterData'],
        createdAt: dateOrNull(json, 'createdAt') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
