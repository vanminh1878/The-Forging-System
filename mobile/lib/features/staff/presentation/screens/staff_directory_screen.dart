import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../domain/staff_models.dart';
import '../staff_providers.dart';
import '../widgets/create_staff_sheet.dart';
import '../widgets/staff_filter_sheet.dart';
import '../widgets/staff_member_card.dart';

/// STF-05: read-only staff management inside the Admin members destination.
class StaffDirectoryScreen extends ConsumerStatefulWidget {
  const StaffDirectoryScreen({super.key});

  @override
  ConsumerState<StaffDirectoryScreen> createState() =>
      _StaffDirectoryScreenState();
}

class _StaffDirectoryScreenState extends ConsumerState<StaffDirectoryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  StaffQuery _query = const StaffQuery();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && value.trim() != _query.q) {
        setState(() => _query = _query.withSearch(value));
      }
    });
  }

  Future<void> _filter() async {
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    final current = _search.text.trim() == _query.q
        ? _query
        : _query.withSearch(_search.text);
    final selected = await showHvpSheet<StaffQuery>(context,
        title: 'Bộ lọc nhân sự',
        builder: (_) => StaffFilterSheet(initial: current));
    if (!mounted) return;
    setState(() => _query = selected ?? current);
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _query = const StaffQuery());
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(staffPageProvider(_query));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(children: <Widget>[
                    Expanded(child: Text('NHÂN SỰ', style: context.txt.titleL)),
                    IconButton(
                        tooltip: 'Tạo nhân sự',
                        icon: const Icon(HvpIcons.plus),
                        onPressed: () => showHvpSheet<void>(context,
                            title: 'Tạo nhân sự',
                            builder: (_) => const CreateStaffSheet())),
                    IconButton(
                        tooltip: 'Làm mới danh sách',
                        icon: const Icon(HvpIcons.retry),
                        onPressed: () =>
                            ref.invalidate(staffPageProvider(_query))),
                  ]),
                  Text('Coach, lễ tân và quản trị viên',
                      style: context.txt.bodySmall),
                  const SizedBox(height: 16),
                  HvpTextField(
                      label: 'Tìm nhân sự',
                      hint: 'Tên, email hoặc số điện thoại',
                      controller: _search,
                      prefixIcon: HvpIcons.search,
                      maxLength: 100,
                      onChanged: _searchChanged,
                      onSubmitted: (value) {
                        _debounce?.cancel();
                        setState(() => _query = _query.withSearch(value));
                      }),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: <Widget>[
                    TextButton.icon(
                        onPressed: _filter,
                        icon: const Icon(HvpIcons.filter, size: 18),
                        label: Text(_query.activeFilters == 0
                            ? 'Bộ lọc'
                            : 'Bộ lọc (${_query.activeFilters})')),
                    if (_query.activeFilters > 0 || _search.text.isNotEmpty)
                      TextButton(
                          onPressed: _reset,
                          child: const Text('Xóa tìm kiếm / lọc')),
                  ]),
                ],
              )),
          Expanded(
              child: AsyncBody<StaffPage>(
            value: result,
            onRetry: () => ref.invalidate(staffPageProvider(_query)),
            builder: (_, page) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(staffPageProvider(_query));
                await ref.read(staffPageProvider(_query).future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  Text(
                      '${page.total} nhân sự · Trang ${page.page}/${page.totalPages}',
                      style: context.txt.caption),
                  const SizedBox(height: 12),
                  if (page.items.isEmpty)
                    EmptyState(
                        icon: HvpIcons.users,
                        title: 'Không có nhân sự phù hợp',
                        message: 'Thử đổi từ khóa hoặc bộ lọc.',
                        actionLabel: 'Xóa bộ lọc',
                        onAction: _reset),
                  for (final member in page.items)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: StaffMemberCard(member: member)),
                  if (page.totalPages > 1)
                    Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        children: <Widget>[
                          TextButton.icon(
                              onPressed: page.page > 1
                                  ? () => setState(() =>
                                      _query = _query.withPage(page.page - 1))
                                  : null,
                              icon: const Icon(HvpIcons.caretLeft),
                              label: const Text('Trang trước')),
                          TextButton.icon(
                              onPressed: page.hasMore
                                  ? () => setState(() =>
                                      _query = _query.withPage(page.page + 1))
                                  : null,
                              icon: const Icon(HvpIcons.caretRight),
                              label: const Text('Trang sau')),
                        ]),
                ],
              ),
            ),
          )),
        ]);
  }
}
