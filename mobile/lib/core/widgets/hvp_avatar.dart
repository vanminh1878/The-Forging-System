import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design/hvp_context.dart';

/// Circular avatar with a gold ring; falls back to initials.
class HvpAvatar extends StatelessWidget {
  const HvpAvatar({super.key, this.url, required this.name, this.size = 48, this.ring = true});

  final String? url;
  final String name;
  final double size;
  final bool ring;

  /// `Học Viên Mẫu` -> `HM` (first letter of first and last word).
  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final fallback = Center(
      child: Text(initialsOf(name), style: t.titleM.copyWith(color: c.gold, fontSize: size * 0.36)),
    );
    final hasUrl = url != null && url!.isNotEmpty;
    return Semantics(
      label: 'Ảnh đại diện của $name',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(ring ? 2.5 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ring ? c.goldGradient : null,
          color: ring ? null : c.surfaceHigh,
        ),
        child: ClipOval(
          child: ColoredBox(
            color: c.surfaceHigh,
            child: hasUrl
                ? CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => fallback,
                    errorWidget: (_, __, ___) => fallback,
                  )
                : fallback,
          ),
        ),
      ),
    );
  }
}
