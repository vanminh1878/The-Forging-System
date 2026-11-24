import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../domain/class_models.dart';
import '../../domain/session_types.dart';
import '../class_providers.dart';
import '../widgets/class_form_sheet.dart';
import '../widgets/class_tile.dart';
import '../widgets/session_form_sheet.dart';

/// CLS-06: admin class list (tab "Đào tạo") with session type filter pills.
///
/// With [readOnly] (reception tab "Lớp học") nothing can be created or edited;
/// tapping a class opens [detailPath].
class ClassListScreen extends ConsumerStatefulWidget {
  const ClassListScreen({super.key, this.readOnly = false, this.detailPath});

  final bool readOnly;

  /// Route of one class; defaults to the admin class detail.
  final String Function(String classId)? detailPath;

  @override
  ConsumerState<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends ConsumerState<ClassListScreen> {
  ClassQuery _query = const ClassQuery();

  void _setType(String? code) =>
      setState(() => _query = ClassQuery(sessionTypeCode: code));

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(classPageProvider(_query));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('LỚP HỌC', style: context.txt.titleL),
                  if (!widget.readOnly) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                      HvpButton.primary(
                          label: 'Tạo lớp',
                          icon: HvpIcons.book,
                          small: true,
                          onPressed: () => showClassForm(context)),
                      HvpButton.secondary(
                          label: 'Tạo buổi',
                          icon: HvpIcons.calendarCheck,
                          small: true,
                          onPressed: () => showSessionForm(context)),
                    ]),
                  ],
                ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: <Widget>[
              _pill('Tất cả', null),
              for (final type in sessionTypes) _pill(type.label, type.code),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AsyncBody<ClassPage>(
              value: result,
              onRetry: () => ref.invalidate(classPageProvider(_query)),
              builder: (_, page) => HvpRefresh(
                onRefresh: () => ref.refresh(classPageProvider(_query).future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    if (page.items.isEmpty)
                      const SizedBox(
                          height: 320,
                          child: EmptyState(
                              icon: HvpIcons.book,
                              title: 'Chưa có lớp',
                              message: 'Không có lớp thuộc loại này.')),
                    for (final item in page.items)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ClassTile(
                              onTap: () => context.push((widget.detailPath ??
                                  AdminPaths.classDetail)(item.id)),
                              item: item,
                              showCoach: !widget.readOnly,
                              onEdit: widget.readOnly
                                  ? null
                                  : () =>
                                      showClassForm(context, existing: item))),
                    if (page.totalPages > 1)
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          children: <Widget>[
                            TextButton.icon(
                                onPressed: page.page > 1
                                    ? () => _goTo(page.page - 1)
                                    : null,
                                icon: const Icon(HvpIcons.caretLeft),
                                label: const Text('Trang trước')),
                            TextButton.icon(
                                onPressed: page.hasMore
                                    ? () => _goTo(page.page + 1)
                                    : null,
                                icon: const Icon(HvpIcons.caretRight),
                                label: const Text('Trang sau')),
                          ]),
                  ],
                ),
              ),
            ),
          ),
        ]);
  }

  void _goTo(int page) => setState(() =>
      _query = ClassQuery(sessionTypeCode: _query.sessionTypeCode, page: page));

  Widget _pill(String label, String? code) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _query.sessionTypeCode == code,
          onSelected: (_) => _setType(code),
        ),
      );
}
