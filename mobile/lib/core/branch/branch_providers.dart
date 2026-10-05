import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network_providers.dart';
import '../utils/json_utils.dart';
import 'branch.dart';

/// Active branches. Requires a signed-in user (the endpoint is authenticated).
final branchesProvider = FutureProvider.autoDispose<List<Branch>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/branches');
  return res.dataList.map((e) => Branch.fromJson(asMap(e))).toList(growable: false);
});
