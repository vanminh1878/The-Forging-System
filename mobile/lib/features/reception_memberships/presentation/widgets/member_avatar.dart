import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_avatar.dart';

/// A learner's avatar; a frozen account gets a snowflake badge on the corner.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.url,
    required this.name,
    required this.size,
    required this.frozen,
  });

  final String? url;
  final String name;
  final double size;
  final bool frozen;

  @override
  Widget build(BuildContext context) {
    final avatar = HvpAvatar(url: url, name: name, size: size);
    if (!frozen) return avatar;
    final c = context.hvp;
    final badge = size >= 52 ? 22.0 : 18.0;
    return Semantics(
      label: 'Tài khoản đã đóng băng',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            avatar,
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: c.info,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bg, width: 2),
                ),
                child: Icon(HvpIcons.frozen, size: badge - 6, color: c.bgDeep),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
