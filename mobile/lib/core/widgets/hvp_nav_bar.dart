import 'package:flutter/material.dart';

import '../design/chamfer_border.dart';
import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import '../utils/haptics.dart';

/// One destination of [HvpNavBar].
class HvpNavItem {
  const HvpNavItem(
      {required this.label, required this.icon, required this.activeIcon});

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Floating bottom navigation with an optional raised centre button
/// (the student Check-in tab).
///
/// When the destinations do not fit, the bar scrolls sideways and an arrow on
/// the faded edge says that there is more.
class HvpNavBar extends StatefulWidget {
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

  /// Narrowest slot that still shares the width: five destinations fit a 320dp
  /// phone. Below it the bar scrolls with the roomier [_scrollSlotWidth].
  static const double _minSlotWidth = 58;
  static const double _scrollSlotWidth = 72;
  static const double _hintWidth = 48;

  @override
  State<HvpNavBar> createState() => _HvpNavBarState();
}

class _HvpNavBarState extends State<HvpNavBar> {
  final ScrollController _scroll = ScrollController();
  bool _moreLeft = false;
  bool _moreRight = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateHints);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(HvpNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _updateHints() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final left = position.pixels > position.minScrollExtent + 1;
    final right = position.pixels < position.maxScrollExtent - 1;
    if (left != _moreLeft || right != _moreRight) {
      setState(() {
        _moreLeft = left;
        _moreRight = right;
      });
    }
  }

  /// Scrolls just enough to show the selected destination.
  void _revealSelected() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final content = position.maxScrollExtent + position.viewportDimension;
    final slot = content / widget.items.length;
    final start = slot * widget.currentIndex;
    var target = position.pixels;
    if (start < target) target = start;
    if (start + slot > target + position.viewportDimension) {
      target = start + slot - position.viewportDimension;
    }
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) _scroll.jumpTo(target);
    _updateHints();
  }

  void _page(double direction) {
    final position = _scroll.position;
    final target =
        (position.pixels + direction * position.viewportDimension / 2)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final items = widget.items;
    final raisedIndex = widget.raisedIndex;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final hasRaised = raisedIndex != null;
    final totalHeight =
        HvpNavBar._barHeight + (hasRaised ? HvpNavBar._raise : 0);
    final barColor = c.isDark ? c.surface : c.surfaceHigh;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottomInset),
      child: SizedBox(
        height: totalHeight,
        child: LayoutBuilder(
          builder: (context, box) {
            // Six staff destinations do not fit legibly in a fixed phone-width
            // bar. Keep every tab reachable instead of shrinking labels/tap areas.
            final contentWidth =
                items.length * HvpNavBar._minSlotWidth > box.maxWidth
                    ? items.length * HvpNavBar._scrollSlotWidth
                    : box.maxWidth;
            final slot = contentWidth / items.length;
            // The overflow depends on this layout, so read it after painting.
            WidgetsBinding.instance.addPostFrameCallback((_) => _updateHints());
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ClipRect(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: contentWidth,
                        height: totalHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: HvpNavBar._barHeight,
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: barColor,
                                  shape: ChamferBorder(
                                    cut: 14,
                                    topLeft: true,
                                    topRight: true,
                                    bottomLeft: true,
                                    bottomRight: true,
                                    side: BorderSide(
                                        color: c.isDark
                                            ? c.borderStrong
                                            : c.border),
                                  ),
                                  shadows: <BoxShadow>[
                                    BoxShadow(
                                        color:
                                            c.shadow.fade(c.isDark ? 0.6 : 0.2),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6)),
                                  ],
                                ),
                                child: Row(
                                  children: <Widget>[
                                    for (var i = 0; i < items.length; i++)
                                      Expanded(
                                        child: _NavButton(
                                          item: items[i],
                                          selected: i == widget.currentIndex,
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
                                left: slot * raisedIndex +
                                    (slot - HvpNavBar._button) / 2,
                                top: 0,
                                child: _RaisedButton(
                                  item: items[raisedIndex],
                                  selected: raisedIndex == widget.currentIndex,
                                  onTap: () => _select(raisedIndex),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_moreLeft)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: HvpNavBar._hintWidth,
                    height: HvpNavBar._barHeight,
                    child: _ScrollHint(
                        toRight: false,
                        color: barColor,
                        onTap: () => _page(-1)),
                  ),
                if (_moreRight)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: HvpNavBar._hintWidth,
                    height: HvpNavBar._barHeight,
                    child: _ScrollHint(
                        toRight: true, color: barColor, onTap: () => _page(1)),
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
    widget.onSelected(index);
  }
}

/// Faded edge with a nudging arrow: there are more destinations this way.
class _ScrollHint extends StatefulWidget {
  const _ScrollHint(
      {required this.toRight, required this.color, required this.onTap});

  final bool toRight;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ScrollHint> createState() => _ScrollHintState();
}

class _ScrollHintState extends State<_ScrollHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    _wave();
  }

  /// Three nudges, then rest: enough to be noticed without moving forever.
  Future<void> _wave() async {
    for (var i = 0; i < 3 && mounted; i++) {
      await _nudge.forward().orCancel.catchError((_) {});
      if (!mounted) return;
      await _nudge.reverse().orCancel.catchError((_) {});
    }
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final toRight = widget.toRight;
    final label = toRight ? 'Xem thêm mục bên phải' : 'Xem thêm mục bên trái';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: toRight ? Alignment.centerLeft : Alignment.centerRight,
                end: toRight ? Alignment.centerRight : Alignment.centerLeft,
                colors: <Color>[widget.color.fade(0), widget.color],
                stops: const <double>[0, 0.55],
              ),
            ),
            child: Align(
              alignment: toRight ? Alignment.centerRight : Alignment.centerLeft,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset(toRight ? 0.2 : -0.2, 0),
                ).animate(_nudge),
                child: Icon(toRight ? HvpIcons.caretRight : HvpIcons.caretLeft,
                    size: 28, color: c.gold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton(
      {required this.item,
      required this.selected,
      required this.raised,
      required this.onTap});

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
            mainAxisAlignment:
                raised ? MainAxisAlignment.end : MainAxisAlignment.center,
            children: <Widget>[
              if (!raised) ...<Widget>[
                AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(selected ? item.activeIcon : item.icon,
                      size: 24, color: color),
                ),
                const SizedBox(height: 3),
              ],
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: t.label.copyWith(
                      color: color,
                      fontSize: 12,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 22 : 0,
                height: 3,
                decoration: BoxDecoration(
                    gradient: c.goldGradient,
                    borderRadius: BorderRadius.circular(1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaisedButton extends StatelessWidget {
  const _RaisedButton(
      {required this.item, required this.selected, required this.onTap});

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
              side:
                  BorderSide(color: selected ? c.textPrimary : c.bg, width: 3),
            ),
            shadows: <BoxShadow>[
              BoxShadow(
                  color: c.gold.fade(0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Icon(item.activeIcon, size: 30, color: c.onGold),
        ),
      ),
    );
  }
}
