import '../domain/schedule_models.dart';
import '../domain/schedule_query.dart';
import '../domain/schedule_repository.dart';
import 'dto/schedule_dto.dart';
import 'schedule_api.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl(this._api);

  final ScheduleApi _api;

  @override
  Future<ScheduleResult> getSchedule(ScheduleQuery query) async =>
      scheduleResultFromEnvelope(await _api.schedule(query));
}
