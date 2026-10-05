import '../../../core/network/api_client.dart';
import '../domain/points_models.dart';

/// Raw endpoint calls. Returns the unwrapped envelope; mapping to domain
/// entities happens in `dto/`.
class FighterRecordApi {
  FighterRecordApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> rank() => _api.get('/me/rank');

  Future<ApiEnvelope> ranks() => _api.get('/ranks');

  Future<ApiEnvelope> badges() => _api.get('/me/badges');

  Future<ApiEnvelope> history() => _api.get('/me/rank-history');

  Future<ApiEnvelope> transactions({required int page, required int limit, PointSource? source}) =>
      _api.get(
        '/me/points/transactions',
        query: <String, dynamic>{
          'page': page,
          'limit': limit,
          if (source != null) 'source': source.wire,
        },
      );

  Future<ApiEnvelope> monthly() => _api.get('/me/points/monthly');

  Future<ApiEnvelope> requestTrial() => _api.post('/me/rank-trials');
}
