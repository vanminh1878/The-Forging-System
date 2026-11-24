import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/design/hvp_layout.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../domain/class_models.dart';
import '../class_providers.dart';
import '../widgets/class_tile.dart';

/// Coach tab "Lớp & bài học": the classes assigned to the signed-in coach.
/// Tapping one opens its roster, upcoming sessions and lesson plan.
class CoachClassesScreen extends ConsumerWidget {
  const CoachClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody<List<ClassSummary>>(
      value: ref.watch(coachClassesProvider),
      onRetry: () => ref.invalidate(coachClassesProvider),
      builder: (_, items) => HvpRefresh(
        onRefresh: () => ref.refresh(coachClassesProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: HvpLayout.tabPagePadding,
          children: <Widget>[
            if (items.isEmpty)
              const SizedBox(
                height: 360,
                child: EmptyState(
                  icon: HvpIcons.book,
                  title: 'Chưa có lớp được phân công',
                  message: 'Quản trị viên sẽ gán bạn làm coach của lớp.',
                ),
              ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClassTile(
                  item: item,
                  showCoach: false,
                  onTap: () => context.push(CoachPaths.classDetail(item.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
