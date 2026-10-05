import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../design/hvp_context.dart';

/// Confetti cannon firing upward from the bottom centre of its parent.
/// Start/stop with the [controller].
class ConfettiBurst extends StatelessWidget {
  const ConfettiBurst({super.key, required this.controller});

  final ConfettiController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConfettiWidget(
        confettiController: controller,
        blastDirection: -math.pi / 2,
        emissionFrequency: 0.05,
        numberOfParticles: 24,
        maxBlastForce: 38,
        minBlastForce: 14,
        gravity: 0.25,
        shouldLoop: false,
        colors: <Color>[c.gold, c.goldBright, c.red, c.emerald, c.textPrimary],
      ),
    );
  }
}
