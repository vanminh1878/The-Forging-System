import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/branch_admin/data/branch_admin_api.dart';
import 'package:hvp_forging/features/branch_admin/data/branch_admin_repository_impl.dart';
import 'package:hvp_forging/features/branch_admin/domain/branch_admin_repository.dart';
import 'package:hvp_forging/features/branch_admin/domain/branch_input.dart';

import '../../helpers/scripted_adapter.dart';

const AppConfig _config =
    AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp');

void main() {
  test('getBranches asks for inactive branches and maps the new fields',
      () async {
    final dio = createApiDio(
      config: _config,
      tokens: MemoryTokenStore(
          const StoredTokens(accessToken: 'a', refreshToken: 'r')),
    );
    final adapter = ScriptedAdapter((o) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'b1',
            'code': 'Q1',
            'name': 'The Corner',
            'address': '12 Nguyễn Huệ',
            'openingHours': '06:00 – 21:30',
            'latitude': 10.7769,
            'longitude': '106.7009',
            'geofenceRadiusM': 150,
            'isActive': true,
            'qrVersion': '1',
          },
          <String, dynamic>{
            'id': 'b2',
            'code': 'Q2',
            'name': 'Old',
            'address': null,
            'isActive': false
          },
        ]));
    dio.httpClientAdapter = adapter;
    final repo = BranchAdminRepositoryImpl(BranchAdminApi(ApiClient(dio)));

    final list = await repo.getBranches();

    final req = adapter.requests.single;
    expect(req.path, '/branches');
    expect(req.queryParameters['includeInactive'], true);
    expect(list.first.addressLine, '12 Nguyễn Huệ · 06:00 – 21:30');
    expect(list.first.qrVersion, '1');
    expect(list.first.latitude, 10.7769);
    expect(list.first.longitude, 106.7009);
    expect(list.first.geofenceRadiusM, 150);
    expect(list.last.latitude, isNull);
    expect(list.last.geofenceRadiusM, 100);
    expect(list.last.isActive, isFalse);
    expect(list.last.addressLine, '');
    expect(visibleBranches(list, showInactive: false).map((b) => b.id),
        <String>['b1']);
    expect(visibleBranches(list, showInactive: true), hasLength(2));
  });

  group('create and update', () {
    late ScriptedAdapter adapter;
    late BranchAdminRepositoryImpl repo;

    setUp(() {
      final dio = createApiDio(
        config: _config,
        tokens: MemoryTokenStore(
            const StoredTokens(accessToken: 'a', refreshToken: 'r')),
      );
      adapter = ScriptedAdapter((o) => o.method == 'POST'
          ? okEnvelope(
              <String, dynamic>{'id': 'b9', 'code': 'Q9', 'name': 'New'},
              status: 201)
          : okEnvelope(
              <String, dynamic>{'id': 'b9', 'code': 'Q9', 'name': 'Renamed'}));
      dio.httpClientAdapter = adapter;
      repo = BranchAdminRepositoryImpl(BranchAdminApi(ApiClient(dio)));
    });

    test('create leaves the code out so the server numbers the branch',
        () async {
      final b = await repo.create(
          const BranchInput(name: ' New ', address: '', latitude: 10.5));

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/admin/branches');
      expect(req.data, <String, dynamic>{
        'name': 'New',
        'address': null,
        'openingHours': null,
        'latitude': 10.5,
        'longitude': null,
        'geofenceRadiusM': 100,
      });
      expect(b.id, 'b9');
    });

    test('an explicit code is still sent', () async {
      await repo.create(const BranchInput(code: ' Q9 ', name: 'New'));
      expect(adapter.requests.single.data['code'], 'Q9');
    });

    test('update patches the branch id and clears empty fields', () async {
      final b = await repo.update('b9', const BranchInput(name: 'Renamed'));

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/admin/branches/b9');
      expect(req.data['address'], isNull);
      expect(req.data.containsKey('address'), isTrue);
      expect(req.data.containsKey('code'), isFalse);
      expect(b.name, 'Renamed');
    });
  });

  test('setActive posts isActive and the reason', () async {
    final dio = createApiDio(
      config: _config,
      tokens: MemoryTokenStore(
          const StoredTokens(accessToken: 'a', refreshToken: 'r')),
    );
    final adapter = ScriptedAdapter((o) => okEnvelope(<String, dynamic>{
          'id': 'b9',
          'code': 'Q9',
          'name': 'X',
          'isActive': false
        }));
    dio.httpClientAdapter = adapter;
    final repo = BranchAdminRepositoryImpl(BranchAdminApi(ApiClient(dio)));

    final b = await repo.setActive('b9', isActive: false, reason: 'Đóng cửa');

    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/admin/branches/b9/status');
    expect(
        req.data, <String, dynamic>{'isActive': false, 'reason': 'Đóng cửa'});
    expect(b.isActive, isFalse);
  });

  test('BranchRules follow the API limits', () {
    expect(BranchRules.name('A'), isNotNull);
    expect(BranchRules.name('AB'), isNull);
    expect(BranchRules.name('A' * 101), isNotNull);
    expect(BranchRules.address('x' * 255), isNull);
    expect(BranchRules.address('x' * 256), isNotNull);
    expect(BranchRules.radius('9'), isNotNull);
    expect(BranchRules.radius('10'), isNull);
    expect(BranchRules.radius('5000'), isNull);
    expect(BranchRules.radius('5001'), isNotNull);
    expect(BranchRules.radius(''), isNotNull);
    expect(BranchRules.radius('-5'), isNotNull);
  });

  test('opening hours: both times or none, closing after opening', () {
    expect(BranchRules.openingTime('', ''), isNull);
    expect(BranchRules.closingTime('', ''), isNull);
    expect(BranchRules.openingTime('', '21:30'), isNotNull);
    expect(BranchRules.closingTime('06:00', ''), isNotNull);
    expect(BranchRules.openingTime('24:00', '21:30'), isNotNull);
    expect(BranchRules.openingTime('06:60', '21:30'), isNotNull);
    expect(BranchRules.openingTime('ab:cd', '21:30'), isNotNull);
    expect(BranchRules.openingTime('6:00', '21:30'), isNull);
    expect(BranchRules.closingTime('06:00', '06:00'), isNotNull);
    expect(BranchRules.closingTime('06:00', '05:59'), isNotNull);
    expect(BranchRules.closingTime('06:00', '06:01'), isNull);
    expect(BranchRules.closingTime('06:00', '23:59'), isNull);
    expect(BranchRules.joinHours('6:00', '21:30'), '06:00 – 21:30');
    expect(BranchRules.splitHours('06:00 – 21:30'), ('06:00', '21:30'));
    expect(BranchRules.splitHours('6:00-21:30'), ('06:00', '21:30'));
    expect(BranchRules.splitHours('6h đến 21h'), isNull);
    expect(BranchRules.splitHours(null), isNull);
  });
}
