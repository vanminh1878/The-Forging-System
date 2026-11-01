import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../domain/schedule_dates.dart';
import '../domain/schedule_query.dart';

/// Raw endpoint calls.
class ScheduleApi {
  ScheduleApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> schedule(ScheduleQuery q) => _api.get(
        '/me/schedule',
        query: <String, dynamic>{
          'view': q.view.wire,
          'date': toIsoDate(dateOnly(q.anchorDate)),
          if (q.branchId != null) 'branchId': q.branchId,
          if (q.status != null) 'status': q.status!.wire,
        },
      );
}
