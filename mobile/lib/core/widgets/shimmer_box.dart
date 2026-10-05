import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../design/hvp_context.dart';

/// Skeleton block; wrap several in [ShimmerList] to share one animation.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height = 16, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.hvp.surfaceHigh,
      highlightColor: context.hvp.surfaceHighest,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

/// Column of skeleton cards used as the loading state of lists.
class ShimmerList extends StatelessWidget {
  const ShimmerList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 72,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    this.spacing = 10,
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return Semantics(
      label: 'Đang tải',
      child: ExcludeSemantics(
        child: Shimmer.fromColors(
          baseColor: c.surfaceHigh,
          highlightColor: c.surfaceHighest,
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: padding,
            itemCount: itemCount,
            separatorBuilder: (_, __) => SizedBox(height: spacing),
            itemBuilder: (_, __) => Container(
              height: itemHeight,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),
    );
  }
}
