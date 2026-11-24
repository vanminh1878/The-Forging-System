import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/app_notification.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this.api, {this.isStaff = false});

  final ApiClient api;
  final bool isStaff;

  String get _basePath =>
      isStaff ? '/staff/notifications' : '/me/notifications';

  @override
  Future<NotificationPage> list({required int page, required int limit}) async {
    final response = await api.get(
      _basePath,
      query: isStaff ? null : <String, dynamic>{'page': page, 'limit': limit},
    );
    final items =
        response.dataList.map((e) => _item(asMap(e))).toList(growable: false);
    final meta = PageMeta.fromJson(response.meta, fallbackLimit: limit);
    return NotificationPage(
      items: items,
      unread: intOf(response.meta ?? const <String, dynamic>{}, 'unread'),
      total: meta.total,
      hasMore: meta.hasMore,
    );
  }

  @override
  Future<int> unreadCount() async {
    if (!isStaff) {
      return intOf(
          (await api.get('$_basePath/unread-count')).dataMap, 'unread');
    }
    return intOf(
        (await api.get(_basePath)).meta ?? const <String, dynamic>{}, 'unread');
  }

  @override
  Future<void> markRead(String id) async {
    if (!isStaff) {
      await api.post('$_basePath/$id/read');
    }
  }

  @override
  Future<void> markAllRead() async {
    await api.post('$_basePath/read-all');
  }

  AppNotification _item(JsonMap j) => AppNotification(
        id: str(j, 'id'),
        eventType: str(j, 'eventType'),
        title: str(j, 'title'),
        body: str(j, 'body'),
        createdAt: dateOrNull(j, 'createdAt') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        isRead: boolOf(j, 'isRead', strOrNull(j, 'readAt') != null),
        payload: asMap(j['payload']),
      );
}
