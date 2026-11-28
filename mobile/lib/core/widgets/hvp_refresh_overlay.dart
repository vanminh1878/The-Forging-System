import 'dart:async';

import 'package:flutter/material.dart';

import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import 'hvp_button.dart';

/// The "Làm mới" button of a list, disabled while a refresh is running.
class HvpRefreshButton extends StatelessWidget {
  const HvpRefreshButton({
    super.key,
    required this.refreshing,
    required this.onPressed,
  });

  final bool refreshing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => HvpButton.secondary(
        label: 'Làm mới',
        icon: HvpIcons.retry,
        small: true,
        onPressed: refreshing ? null : onPressed,
      );
}

/// Covers a list with an animated curtain while it reloads, and blocks taps on
/// the stale rows. It stays for at least [minVisible] so a fast reload is still
/// seen to happen instead of flickering.
class HvpRefreshOverlay extends StatefulWidget {
  const HvpRefreshOverlay({
    super.key,
    required this.refreshing,
    required this.child,
    this.label = 'Đang làm mới…',
  });

  final bool refreshing;
  final Widget child;
  final String label;

  static const Duration minVisible = Duration(milliseconds: 700);

  @override
  State<HvpRefreshOverlay> createState() => _HvpRefreshOverlayState();
}

class _HvpRefreshOverlayState extends State<HvpRefreshOverlay> {
  Timer? _hold;
  bool _visible = false;
  bool _held = false;

  @override
  void initState() {
    super.initState();
    if (widget.refreshing) _show();
  }

  @override
  void didUpdateWidget(HvpRefreshOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshing && !oldWidget.refreshing) {
      _show();
    } else if (!widget.refreshing && _held) {
      _visible = false;
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _show() {
    _hold?.cancel();
    _visible = true;
    _held = false;
    _hold = Timer(HvpRefreshOverlay.minVisible, () {
      _held = true;
      if (mounted && !widget.refreshing) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          widget.child,
          if (_visible) Positioned.fill(child: _Curtain(label: widget.label)),
        ],
      );
}

class _Curtain extends StatefulWidget {
  const _Curtain({required this.label});

  final String label;

  @override
  State<_Curtain> createState() => _CurtainState();
}

class _CurtainState extends State<_Curtain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _punch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _punch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return AbsorbPointer(
      child: Semantics(
        liveRegion: true,
        label: widget.label,
        excludeSemantics: true,
        child: ColoredBox(
          color: c.bg.fade(0.84),
          child: Center(
            // Scales down instead of overflowing when the list area is short.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          CircularProgressIndicator(
                            strokeWidth: 4,
                            color: c.gold,
                            backgroundColor: c.goldSoft,
                          ),
                          Center(
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.85, end: 1.2)
                                  .animate(CurvedAnimation(
                                      parent: _punch, curve: Curves.easeIn)),
                              child:
                                  Icon(HvpIcons.glove, size: 36, color: c.gold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(widget.label, style: t.titleS),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
