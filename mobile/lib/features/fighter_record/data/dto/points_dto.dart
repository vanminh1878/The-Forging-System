import '../../../../core/network/api_client.dart';
import '../../../../core/utils/json_utils.dart';
import '../../domain/points_models.dart';

/// JSON -> domain mappers for the point ledger.

PointTransaction pointTransactionFromJson(JsonMap j) => PointTransaction(
      id: str(j, 'id'),
      source: PointSource.parse(strOrNull(j, 'source')),
      dpAmount: intOf(j, 'dpAmount'),
      marksAmount: intOf(j, 'marksAmount'),
      isCapped: boolOf(j, 'isCapped'),
      occurredAt: dateOrNull(j, 'occurredAt'),
      note: strOrNull(j, 'note'),
    );

/// A list response: items in `data`, pagination in `meta`.
PointsPage pointsPageFromEnvelope(ApiEnvelope envelope) {
  final meta = PageMeta.fromJson(envelope.meta);
  return PointsPage(
    items: envelope.dataList.map((e) => pointTransactionFromJson(asMap(e))).toList(growable: false),
    page: meta.page,
    totalPages: meta.totalPages,
    total: meta.total,
  );
}

MonthlyPointStatus monthlyStatusFromJson(JsonMap j) => MonthlyPointStatus(
      dpUsed: intOf(j, 'dpUsed'),
      dpCap: intOf(j, 'dpCap'),
      marksUsed: intOf(j, 'marksUsed'),
      marksCap: intOf(j, 'marksCap'),
    );
