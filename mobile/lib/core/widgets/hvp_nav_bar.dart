import 'package:flutter/material.dart';

import '../design/chamfer_border.dart';
import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../utils/haptics.dart';

/// One destination of [HvpNavBar].
class HvpNavItem {
  const HvpNavItem({required this.label, required this.icon, required this.activeIcon});

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Floating bottom navigation with an optional raised centre button
/// (the student Check-in tab).
class HvpNavBar extends StatelessWidget {
  const HvpNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.raisedIndex,
  });

  final List<HvpNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Index of the item drawn as a raised circular button, if any.
  final int? raisedIndex;

  static const double _barHeight = 64;
  static const double _raise = 24;
  static const double _button = 62;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final hasRaised = raisedIndex != null;
    final totalHeight = _barHeight + (hasRaised ? _raise : 0);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottomInset),
      child: SizedBox(
        height: totalHeight,
        child: LayoutBuilder(
          builder: (context, box) {
            final slot = box.maxWidth / items.length;
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _barHeight,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: c.isDark ? c.surface : c.surfaceHigh,
                      shape: ChamferBorder(
                        cut: 14,
                        topLeft: true,
                        topRight: true,
                        bottomLeft: true,
                        bottomRight: true,
                        side: BorderSide(color: c.isDark ? c.borderStrong : c.border),
                      ),
                      shadows: <BoxShadow>[
                        BoxShadow(color: c.shadow.fade(c.isDark ? 0.6 : 0.2), blurRadius: 18, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavButton(
                              item: items[i],
                              selected: i == currentIndex,
                              raised: i == raisedIndex,
                              onTap: () => _select(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (hasRaised)
                  Positioned(
                    left: slot * raisedIndex! + (slot - _button) / 2,
                    top: 0,
                    child: _RaisedButton(
                      item: items[raisedIndex!],
                      selected: raisedIndex == currentIndex,
                      onTap: () => _select(raisedIndex!),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _select(int index) {
    Haptics.selection();
    onSelected(index);
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.raised, required this.onTap});

  final HvpNavItem item;
  final bool selected;
  final bool raised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final color = selected ? c.gold : c.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        containedInkWell: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
          child: Column(
            mainAxisAlignment: raised ? MainAxisAlignment.end : MainAxisAlignment.center,
            children: <Widget>[
              if (!raised) ...<Widget>[
                AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(selected ? item.activeIcon : item.icon, size: 24, color: color),
                ),
                const SizedBox(height: 3),
              ],
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: t.label.copyWith(color: color, fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 22 : 0,
                height: 3,
                decoration: BoxDecoration(gradient: c.goldGradient, borderRadius: BorderRadius.circular(1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaisedButton extends StatelessWidget {
  const _RaisedButton({required this.item, required this.selected, required this.onTap});

  final HvpNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: HvpNavBar._button,
          height: HvpNavBar._button,
          decoration: ShapeDecoration(
            gradient: c.goldGradient,
            shape: ChamferBorder(
              cut: 18,
              topLeft: true,
              topRight: true,
              bottomLeft: true,
              bottomRight: true,
              side: BorderSide(color: selected ? c.textPrimary : c.bg, width: 3),
            ),
            shadows: <BoxShadow>[BoxShadow(color: c.gold.fade(0.5), blurRadius: 18, offset: const Offset(0, 4))],
          ),
          child: Icon(item.activeIcon, size: 30, color: c.onGold),
        ),
      ),
    );
  }
}
