import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/state/submit_notifier.dart';
import '../data/admin_settings_repository.dart';
import '../data/rank_configuration_repository.dart';
import '../domain/admin_setting.dart';
import '../domain/rank_configuration.dart';

final adminSettingsRepositoryProvider = Provider<AdminSettingsRepository>(
    (ref) => AdminSettingsRepositoryImpl(ref.watch(apiClientProvider)));
final adminSettingsProvider = FutureProvider.autoDispose<List<AdminSetting>>(
    (ref) => ref.watch(adminSettingsRepositoryProvider).list());
final adminSettingsSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
final rankConfigurationRepositoryProvider =
    Provider<RankConfigurationRepository>(
        (ref) => RankConfigurationRepository(ref.watch(apiClientProvider)));
final rankConfigurationsProvider =
    FutureProvider.autoDispose<List<RankConfiguration>>(
        (ref) => ref.watch(rankConfigurationRepositoryProvider).list());
