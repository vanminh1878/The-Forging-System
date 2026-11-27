import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../domain/admin_setting.dart';
import 'admin_settings_providers.dart';

class AdminSettingsGroup extends ConsumerWidget {
  const AdminSettingsGroup({super.key, required this.group});
  final String group;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncBody<List<AdminSetting>>(
        value: ref.watch(adminSettingsProvider),
        onRetry: () => ref.invalidate(adminSettingsProvider),
        builder: (_, settings) {
          final items = settings
              .where((item) => item.group == group)
              .toList(growable: false);
          if (items.isEmpty) {
            return const EmptyState(
                icon: HvpIcons.gear,
                title: 'Chưa có cấu hình',
                message: 'Nhóm này chưa có tham số khả dụng.');
          }
          return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
            for (final item in items)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SettingCard(setting: item))
          ]);
        },
      );
}

class _SettingCard extends ConsumerStatefulWidget {
  const _SettingCard({required this.setting});
  final AdminSetting setting;
  @override
  ConsumerState<_SettingCard> createState() => _SettingCardState();
}

class _SettingCardState extends ConsumerState<_SettingCard> {
  late final TextEditingController _value =
      TextEditingController(text: '${widget.setting.value}');
  final _reason = TextEditingController();
  @override
  void dispose() {
    _value.dispose();
    _reason.dispose();
    super.dispose();
  }

  Object? _parse() {
    if (widget.setting.type == 'BOOL') return _value.text == 'true';
    if (widget.setting.type == 'INT') return int.tryParse(_value.text);
    return _value.text;
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(adminSettingsSubmitProvider).submitting;
    return HvpCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
          Text(widget.setting.key, style: context.txt.titleS),
          const SizedBox(height: 4),
          Text(widget.setting.description, style: context.txt.bodySmall),
          const SizedBox(height: 10),
          if (widget.setting.type == 'BOOL')
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_value.text == 'true' ? 'Bật' : 'Tắt'),
                value: _value.text == 'true',
                onChanged: (value) => setState(() => _value.text = '$value'))
          else
            HvpTextField(
                label: 'Giá trị',
                controller: _value,
                keyboardType: widget.setting.type == 'INT'
                    ? TextInputType.number
                    : TextInputType.text),
          HvpTextField(label: 'Lý do thay đổi', controller: _reason),
          const SizedBox(height: 8),
          HvpButton.primary(
              label: 'Lưu',
              small: true,
              loading: submitting,
              onPressed: submitting
                  ? null
                  : () async {
                      final value = _parse();
                      if (value == null || _reason.text.trim().length < 3) {
                        return;
                      }
                      final ok = await ref
                          .read(adminSettingsSubmitProvider.notifier)
                          .run(() => ref
                              .read(adminSettingsRepositoryProvider)
                              .update(widget.setting.key, value, _reason.text));
                      if (ok) ref.invalidate(adminSettingsProvider);
                    }),
        ]));
  }
}
