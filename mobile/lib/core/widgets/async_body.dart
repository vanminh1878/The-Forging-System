import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_state.dart';
import 'shimmer_box.dart';

/// Standard loading / error / data switch for [AsyncValue].
///
/// While refreshing with previous data present, the data stays on screen.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (data) => builder(context, data),
      loading: () => loading ?? const ShimmerList(),
      error: (error, _) => ErrorState.fromError(error, onRetry: onRetry),
    );
  }
}
