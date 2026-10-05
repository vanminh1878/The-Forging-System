import 'package:flutter/material.dart';

import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import 'hvp_logo.dart';

/// Hairline under the fixed logo header: gold fading out at both ends, with a
/// short bright tick in the middle.
class HvpHeaderRule extends StatelessWidget {
  const HvpHeaderRule({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return ExcludeSemantics(
      child: SizedBox(
        height: 3,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            Positioned(
              left: 40,
              right: 40,
              bottom: 0,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: <Color>[c.gold.fade(0), c.gold.fade(0.7), c.gold.fade(0)]),
                ),
              ),
            ),
            Container(width: 22, height: 3, color: c.goldBright),
          ],
        ),
      ),
    );
  }
}

/// Fixed top bar of every screen: the small HVP logo centred, an optional page
/// title row under it (left aligned), back arrow / actions at the sides.
class HvpAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HvpAppBar({super.key, this.title, this.actions, this.bottom, this.logoHeight = 38});

  /// Page title shown under the logo (upper-cased). Omit on screens that carry their own heading.
  final String? title;
  final List<Widget>? actions;

  /// Extra row under the title (e.g. a [TabBar]).
  final PreferredSizeWidget? bottom;
  final double logoHeight;

  static const double _toolbar = 56;
  static const double _titleRow = 38;
  static const double _rule = 3;

  double get _belowToolbar => (title == null ? 0 : _titleRow) + (bottom?.preferredSize.height ?? 0) + _rule;

  @override
  Size get preferredSize => Size.fromHeight(_toolbar + _belowToolbar);

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return AppBar(
      centerTitle: true,
      toolbarHeight: _toolbar,
      title: HvpLogo(height: logoHeight),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_belowToolbar),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (title != null)
              SizedBox(
                height: _titleRow,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Transform(
                          transform: Matrix4.skewX(-0.45),
                          child: Container(width: 5, height: 20, color: c.gold),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Semantics(
                            header: true,
                            child: Text(
                              title!.toUpperCase(),
                              style: t.titleL.copyWith(fontSize: 22),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (bottom != null) bottom!,
            const HvpHeaderRule(),
          ],
        ),
      ),
    );
  }
}

/// Same header for screens that are not a Scaffold with an app bar (sign-in,
/// splash): logo centred, optional back button, safe-area aware.
class HvpLogoHeader extends StatelessWidget {
  const HvpLogoHeader({super.key, this.showBack = false, this.logoHeight = 56});

  final bool showBack;
  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: logoHeight + 20,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  HvpLogo(height: logoHeight),
                  if (showBack)
                    Positioned(
                      left: 4,
                      child: BackButton(color: c.gold),
                    ),
                ],
              ),
            ),
            const HvpHeaderRule(),
          ],
        ),
      ),
    );
  }
}
