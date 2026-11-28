import 'package:flutter/material.dart';

import '../design/chamfer_border.dart';
import '../design/hvp_context.dart';
import '../design/hvp_layout.dart';

/// One destination of [HvpSubNav].
class HvpSubNavItem {
  const HvpSubNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Secondary navigation under a page header: one chamfered panel, the selected
/// destination filled with the accent colour, every destination with an icon.
///
/// It is a [TabBar], so it follows [controller] or the nearest
/// [DefaultTabController]. More than three destinations scroll sideways.
class HvpSubNav extends StatelessWidget implements PreferredSizeWidget {
  const HvpSubNav({super.key, required this.items, this.controller});

  final List<HvpSubNavItem> items;
  final TabController? controller;

  static const double _margin = 6;
  static const double _inset = 3;
  static const double height = HvpLayout.minTap + 2 * (_margin + _inset);

  static const int _maxFixed = 3;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final scrollable = items.length > _maxFixed;
    final style = t.titleS.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: _margin),
      child: Material(
        color: c.surface,
        shape: ChamferBorder(cut: 10, side: BorderSide(color: c.borderStrong)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(_inset),
          child: TabBar(
            controller: controller,
            isScrollable: scrollable,
            tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
            dividerHeight: 0,
            indicatorWeight: 0,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: ShapeDecoration(
              gradient: c.goldGradient,
              shape: const ChamferBorder(cut: 8),
            ),
            labelColor: c.onGold,
            unselectedLabelColor: c.textMuted,
            labelStyle: style,
            unselectedLabelStyle: style,
            labelPadding: EdgeInsets.symmetric(horizontal: scrollable ? 10 : 4),
            tabs: <Widget>[
              for (final item in items)
                Tab(
                  height: HvpLayout.minTap,
                  // A label too wide for its share shrinks; it is never cut.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(item.icon, size: 19),
                        const SizedBox(width: 5),
                        Text(item.label.toUpperCase(), maxLines: 1),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page split into sections: [HvpSubNav] on top, the chosen section below, so
/// the lower sections never need a long scroll to be reached.
class HvpSubTabs extends StatelessWidget {
  const HvpSubTabs({super.key, required this.items, required this.children});

  final List<HvpSubNavItem> items;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    assert(items.length == children.length, 'one child per destination');
    return DefaultTabController(
      length: items.length,
      child: Column(
        children: <Widget>[
          HvpSubNav(items: items),
          Expanded(child: TabBarView(children: children)),
        ],
      ),
    );
  }
}
