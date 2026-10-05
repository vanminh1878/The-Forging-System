import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_backdrop.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../providers/auth_controller.dart';

/// Shown while the stored session is being restored on cold start.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(authControllerProvider.select((s) => s.restoreError));
    return Scaffold(
      body: HvpBackdrop(
        glow: 0.7,
        slashes: false,
        child: Column(
          children: <Widget>[
            const HvpLogoHeader(),
            Expanded(
              child: error != null
                  ? ErrorState(
                      title: 'Không thể khôi phục phiên',
                      message: error,
                      onRetry: () => ref.read(authControllerProvider.notifier).restore(),
                    )
                  : const Center(
                      child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
