import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../domain/staff_models.dart';
import '../staff_providers.dart';

class StaffFilterSheet extends ConsumerStatefulWidget {
  const StaffFilterSheet({super.key, required this.initial});
  final StaffQuery initial;

  @override
  ConsumerState<StaffFilterSheet> createState() => _StaffFilterSheetState();
}

class _StaffFilterSheetState extends ConsumerState<StaffFilterSheet> {
  late StaffRole? _role = widget.initial.role;
  late StaffStatus? _status = widget.initial.status;
  late String? _branchId = widget.initial.branchId;

  @override
  Widget build(BuildContext context) {
    final branches = ref.watch(staffBranchesProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _dropdown(
                'Vai trò',
                _role?.wire ?? '',
                <String, String>{
                  '': 'Tất cả vai trò',
                  for (final role in StaffRole.values) role.wire: role.label,
                },
                (value) => setState(() => _role = StaffRole.values
                    .where((role) => role.wire == value)
                    .firstOrNull)),
            const SizedBox(height: 20),
            _dropdown(
                'Trạng thái',
                _status?.wire ?? '',
                <String, String>{
                  '': 'Tất cả trạng thái',
                  for (final status in StaffStatus.values)
                    status.wire: status.label,
                },
                (value) => setState(() => _status = StaffStatus.values
                    .where((status) => status.wire == value)
                    .firstOrNull)),
            const SizedBox(height: 20),
            branches.when(
              data: (items) => _dropdown(
                  'Chi nhánh',
                  _branchId ?? '',
                  <String, String>{
                    '': 'Tất cả chi nhánh',
                    if (_branchId != null &&
                        !items.any((item) => item.id == _branchId))
                      _branchId!: 'Chi nhánh đã chọn',
                    for (final branch in items) branch.id: branch.name,
                  },
                  (value) =>
                      setState(() => _branchId = value == '' ? null : value)),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Column(children: <Widget>[
                Text(
                    'Không tải được chi nhánh. Bạn vẫn có thể lọc vai trò và trạng thái.',
                    style: context.txt.bodySmall),
                TextButton(
                    onPressed: () => ref.invalidate(staffBranchesProvider),
                    child: const Text('Tải lại chi nhánh')),
              ]),
            ),
            const SizedBox(height: 24),
            HvpButton.primary(
                label: 'Áp dụng bộ lọc',
                expand: true,
                onPressed: () {
                  Navigator.of(context).pop(StaffQuery(
                      q: widget.initial.q,
                      role: _role,
                      status: _status,
                      branchId: _branchId));
                }),
            const SizedBox(height: 10),
            HvpButton.ghost(
                label: 'Xóa bộ lọc',
                expand: true,
                onPressed: () {
                  Navigator.of(context).pop(StaffQuery(q: widget.initial.q));
                }),
          ]),
    );
  }

  Widget _dropdown(String label, String selected, Map<String, String> options,
          ValueChanged<String?> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: context.txt.label),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            style: context.txt.body,
            dropdownColor: context.hvp.surface,
            items: options.entries
                .map((entry) => DropdownMenuItem(
                    value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      );
}
