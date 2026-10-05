import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Rectangle with angled ("chamfered") corners, the signature card shape.
///
/// Defaults to cutting the top-left and bottom-right corners like a boxing
/// ticket/belt plate. Works with `ShapeDecoration`, `Material.shape`,
/// `InkWell.customBorder` and `ShapeBorderClipper`.
class ChamferBorder extends ShapeBorder {
  const ChamferBorder({
    this.cut = 12,
    this.topLeft = true,
    this.topRight = false,
    this.bottomRight = true,
    this.bottomLeft = false,
    this.side = BorderSide.none,
  });

  final double cut;
  final bool topLeft;
  final bool topRight;
  final bool bottomRight;
  final bool bottomLeft;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect rect) {
    final c = math.min(cut, math.min(rect.width, rect.height) / 2);
    final path = Path()..moveTo(rect.left + (topLeft ? c : 0), rect.top);
    path.lineTo(rect.right - (topRight ? c : 0), rect.top);
    if (topRight) path.lineTo(rect.right, rect.top + c);
    path.lineTo(rect.right, rect.bottom - (bottomRight ? c : 0));
    if (bottomRight) path.lineTo(rect.right - c, rect.bottom);
    path.lineTo(rect.left + (bottomLeft ? c : 0), rect.bottom);
    if (bottomLeft) path.lineTo(rect.left, rect.bottom - c);
    path.lineTo(rect.left, rect.top + (topLeft ? c : 0));
    path.close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final paint = side.toPaint();
    canvas.drawPath(_path(rect.deflate(side.width / 2)), paint);
  }

  @override
  ShapeBorder scale(double t) => ChamferBorder(
        cut: cut * t,
        topLeft: topLeft,
        topRight: topRight,
        bottomRight: bottomRight,
        bottomLeft: bottomLeft,
        side: side.scale(t),
      );

  ChamferBorder copyWith({double? cut, BorderSide? side}) => ChamferBorder(
        cut: cut ?? this.cut,
        topLeft: topLeft,
        topRight: topRight,
        bottomRight: bottomRight,
        bottomLeft: bottomLeft,
        side: side ?? this.side,
      );

  @override
  bool operator ==(Object other) =>
      other is ChamferBorder &&
      other.cut == cut &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft &&
      other.side == side;

  @override
  int get hashCode => Object.hash(cut, topLeft, topRight, bottomRight, bottomLeft, side);
}
