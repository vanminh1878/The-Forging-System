import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../data/audit_log_repository.dart';
import '../domain/audit_log.dart';

final auditLogRepositoryProvider = Provider<AuditLogRepository>(
    (ref) => AuditLogRepositoryImpl(ref.watch(apiClientProvider)));

final auditLogListProvider =
    FutureProvider.autoDispose.family<AuditLogPage, AuditLogFilter>(
  (ref, filter) => ref.watch(auditLogRepositoryProvider).list(
        query: filter.query,
        action: filter.action,
        entityType: filter.entityType,
        entityId: filter.entityId,
        from: filter.from,
        to: filter.to,
        page: filter.page,
      ),
);

class AuditLogFilter {
  const AuditLogFilter(
      {this.query = '',
      this.action = '',
      this.entityType = '',
      this.entityId = '',
      this.from,
      this.to,
      this.page = 1});

  final String query;
  final String action;
  final String entityType;
  final String entityId;
  final DateTime? from;
  final DateTime? to;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is AuditLogFilter &&
      query == other.query &&
      action == other.action &&
      entityType == other.entityType &&
      entityId == other.entityId &&
      from == other.from &&
      to == other.to &&
      page == other.page;

  @override
  int get hashCode =>
      Object.hash(query, action, entityType, entityId, from, to, page);
}
