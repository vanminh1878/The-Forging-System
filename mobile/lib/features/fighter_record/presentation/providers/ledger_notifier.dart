import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/points_models.dart';
import 'fighter_record_providers.dart';

/// Loaded pages of the ledger.
class LedgerState {
  const LedgerState({
    required this.items,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<PointTransaction> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;

  LedgerState copyWith({
    List<PointTransaction>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    String? loadMoreError,
    bool clearError = false,
  }) =>
      LedgerState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
      );
}

/// Paginated "Sổ điểm". Rebuilds (page 1) when the filter or the user changes.
class LedgerNotifier extends AutoDisposeAsyncNotifier<LedgerState> {
  static const int pageSize = 20;

  @override
  Future<LedgerState> build() async {
    ref.watch(currentUserIdProvider);
    final source = ref.watch(ledgerFilterProvider);
    final page = await ref
        .read(fighterRecordRepositoryProvider)
        .getTransactions(page: 1, limit: pageSize, source: source);
    return LedgerState(items: page.items, page: page.page, hasMore: page.hasMore);
  }

  /// Appends the next page. Errors are kept in [LedgerState.loadMoreError] so
  /// the loaded rows stay on screen.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    final source = ref.read(ledgerFilterProvider);
    state = AsyncData<LedgerState>(current.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await ref.read(fighterRecordRepositoryProvider).getTransactions(
            page: current.page + 1,
            limit: pageSize,
            source: source,
          );
      // The filter changed while loading: this notifier was rebuilt, drop the stale page.
      if (ref.read(ledgerFilterProvider) != source) return;
      state = AsyncData<LedgerState>(
        LedgerState(
          items: <PointTransaction>[...current.items, ...page.items],
          page: page.page,
          hasMore: page.hasMore,
        ),
      );
    } catch (e) {
      if (ref.read(ledgerFilterProvider) != source) return;
      state = AsyncData<LedgerState>(current.copyWith(loadingMore: false, loadMoreError: errorMessage(e)));
    }
  }
}

final ledgerProvider = AsyncNotifierProvider.autoDispose<LedgerNotifier, LedgerState>(LedgerNotifier.new);
