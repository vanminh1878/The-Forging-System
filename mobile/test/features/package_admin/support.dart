import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/package_admin/data/package_admin_api.dart';
import 'package:hvp_forging/features/package_admin/data/package_admin_repository_impl.dart';
import 'package:hvp_forging/features/package_admin/domain/package_admin_repository.dart';
import 'package:hvp_forging/features/package_admin/domain/package_models.dart';
import 'package:hvp_forging/features/package_admin/presentation/providers/package_admin_providers.dart';

import '../../helpers/scripted_adapter.dart';

({PackageAdminRepositoryImpl repo, ScriptedAdapter adapter}) buildPackageRepo(
    ResponseBody Function(RequestOptions) handler) {
  final dio = createApiDio(
    config: const AppConfig(
        apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
    tokens: MemoryTokenStore(
        const StoredTokens(accessToken: 'admin', refreshToken: 'r')),
  );
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (
    repo: PackageAdminRepositoryImpl(PackageAdminApi(ApiClient(dio))),
    adapter: adapter
  );
}

const packageJson = <String, dynamic>{
  'id': 'p1',
  'code': 'BOOK_1',
  'name': 'BOOK I',
  'durationDays': 84,
  'totalSessions': 36,
  'sessionsPerWeek': 3,
  'isTrial': false,
  'priceVnd': 8900000,
  'description': null,
  'isActive': true,
  'sortOrder': 1,
  'classCount': 2,
};

const bookOne = PackageType(
  id: 'p1',
  code: 'BOOK_1',
  name: 'BOOK I',
  durationDays: 84,
  totalSessions: 36,
  sessionsPerWeek: 3,
  priceVnd: 8900000,
  sortOrder: 1,
  classCount: 2,
);

const stopped = PackageType(
  id: 'p2',
  code: 'OLD',
  name: 'Gói cũ',
  isActive: false,
);

class FakePackageAdminRepository implements PackageAdminRepository {
  FakePackageAdminRepository(this.packages, {this.onWrite});

  List<PackageType> packages;

  /// Throw from here to make create/update fail.
  final void Function()? onWrite;
  int listCalls = 0;
  final List<PackageDraft> created = <PackageDraft>[];
  final List<({String id, Map<String, Object?> changes})> updated =
      <({String id, Map<String, Object?> changes})>[];

  @override
  Future<List<PackageType>> list() async {
    listCalls++;
    return packages;
  }

  @override
  Future<PackageType> create(PackageDraft draft) async {
    onWrite?.call();
    created.add(draft);
    return bookOne;
  }

  @override
  Future<PackageType> update(String id, Map<String, Object?> changes) async {
    onWrite?.call();
    updated.add((id: id, changes: changes));
    return bookOne;
  }
}

List<Override> packageOverrides(FakePackageAdminRepository fake) => <Override>[
      packageAdminRepositoryProvider.overrideWithValue(fake),
      currentUserIdProvider.overrideWithValue('admin1'),
    ];
