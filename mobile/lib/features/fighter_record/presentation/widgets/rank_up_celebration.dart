import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/confetti_burst.dart';
import '../../domain/rank_models.dart';
import '../../domain/rank_rules.dart';
import '../providers/fighter_record_providers.dart';

/// Fires confetti + a strong haptic when a reload shows a higher rank than
/// before. Place it in a `Stack` above the tabs; it ignores touches and
/// renders nothing while idle.
class RankUpCelebration extends ConsumerStatefulWidget {
  const RankUpCelebration({super.key});

  @override
  ConsumerState<RankUpCelebration> createState() => _RankUpCelebrationState();
}

class _RankUpCelebrationState extends ConsumerState<RankUpCelebration> {
  late final ConfettiController _controller = ConfettiController(duration: const Duration(seconds: 2));
  Timer? _hideTimer;
  bool _active = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _celebrate() {
    Haptics.heavy();
    setState(() => _active = true);
    // Start after the confetti widget is mounted so it picks the state change up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.play();
    });
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _active = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<RankProgress>>(rankProgressProvider, (previous, next) {
      final after = next.valueOrNull;
      if (after != null && isRankUp(previous?.valueOrNull, after)) _celebrate();
    });
    if (!_active) return const SizedBox.shrink();
    return IgnorePointer(child: ConfettiBurst(controller: _controller));
  }
}
