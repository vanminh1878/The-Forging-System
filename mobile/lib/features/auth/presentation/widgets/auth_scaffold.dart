import 'package:flutter/material.dart';

import '../../../../core/design/chamfer_border.dart';
import '../../../../core/design/color_utils.dart';
import '../../../../core/design/hvp_backdrop.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/spotlight.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/hvp_app_bar.dart';

/// Shared layout of the unauthenticated screens: the fixed logo header, then the
/// page title and the form on the "gym corner" backdrop, and the tagline at the
/// bottom.
///
/// With [spotlightTitle] the title sits in an octagonal sign lit by three
/// ceiling lamps (sign-in); otherwise it is a plain heading.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showBack = false,
    this.spotlightTitle = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;
  final bool spotlightTitle;

  static const double _maxWidth = 440;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: HvpBackdrop(
        glow: 0.7,
        slashes: false,
        child: Column(
          children: <Widget>[
            HvpLogoHeader(showBack: showBack),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _maxWidth),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (spotlightTitle)
                                _SpotlightTitle(title: title).entrance(0)
                              else ...<Widget>[
                                const SizedBox(height: 28),
                                Semantics(
                                  header: true,
                                  child: Text(title.toUpperCase(), style: t.displayM),
                                ).entrance(0),
                              ],
                              if (subtitle != null)
                                Padding(
                                  padding: EdgeInsets.only(top: spotlightTitle ? 16 : 8),
                                  child: Text(
                                    subtitle!,
                                    style: t.bodySmall.copyWith(color: context.hvp.textMuted),
                                    textAlign: spotlightTitle ? TextAlign.center : TextAlign.start,
                                  ),
                                ),
                              const SizedBox(height: 24),
                              child.entrance(1),
                              const Spacer(),
                              const SizedBox(height: 24),
                              const _Tagline(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The octagonal sign with the screen title, lit by [HvpSpotlight].
class _SpotlightTitle extends StatelessWidget {
  const _SpotlightTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    // The frame occupies y = frameTop..designHeight of the spotlight's design box
    // and 288/340 of its width (26/340 free on each side).
    return SizedBox(
      height: HvpSpotlight.designHeight,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: HvpSpotlight()),
          Positioned(
            left: 0,
            right: 0,
            top: HvpSpotlight.frameTop,
            height: HvpSpotlight.designHeight - HvpSpotlight.frameTop,
            child: FractionallySizedBox(
              widthFactor: 288 / HvpSpotlight.designWidth,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: c.gold.fade(c.isDark ? 0.05 : 0.07),
                  shape: ChamferBorder(
                    cut: 30,
                    topRight: true,
                    bottomLeft: true,
                    side: BorderSide(color: c.gold, width: 1.8),
                  ),
                  shadows: c.isDark ? <BoxShadow>[BoxShadow(color: c.gold.fade(0.28), blurRadius: 10)] : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: ChamferBorder(
                        cut: 24,
                        topRight: true,
                        bottomLeft: true,
                        side: BorderSide(color: c.gold.fade(0.35)),
                      ),
                    ),
                    child: Center(
                      child: Semantics(
                        header: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(title.toUpperCase(), style: t.displayL.copyWith(fontSize: 46)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gym slogan at the bottom of the screen.
class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(width: 36, height: 1, color: c.gold.fade(0.7)),
          const SizedBox(height: 12),
          Text(
            'WE BUILD DISCIPLINE',
            style: t.label.copyWith(color: c.gold, fontSize: 12, letterSpacing: 4.2, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'THE CORNER',
            style: t.label.copyWith(color: c.textMuted, fontSize: 11, letterSpacing: 4.2, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
