import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../domain/admin_setting.dart';
import 'admin_settings_providers.dart';
import 'setting_ui_metadata.dart';

class AdminSettingsGroup extends ConsumerWidget {
  const AdminSettingsGroup({super.key, required this.group});
  final String group;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncBody<List<AdminSetting>>(
        value: ref.watch(adminSettingsProvider),
        onRetry: () => ref.invalidate(adminSettingsProvider),
        builder: (context, settings) {
          final items = settings
              .where((item) => item.group == group)
              .toList(growable: false);
          if (items.isEmpty) {
            return const EmptyState(
                icon: HvpIcons.gear,
                title: 'Chưa có cấu hình',
                message: 'Nhóm này chưa có tham số khả dụng.');
          }
          final info = groupUi[group];
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: <Widget>[
                if (info != null) ...<Widget>[
                  Text(info.title.toUpperCase(), style: context.txt.titleL),
                  const SizedBox(height: 4),
                  Text(info.description, style: context.txt.bodySmall),
                  if (info.warning != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(info.warning!,
                        style: context.txt.bodySmall
                            .copyWith(color: context.hvp.amber))
                  ],
                  const SizedBox(height: 20),
                ],
                for (final item in items)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
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
  bool _changed = false;
  bool _saving = false;
  bool _showReasonError = false;
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
    final meta = settingUi(widget.setting);
    return HvpCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
          Text(meta.title, style: context.txt.titleS),
          const SizedBox(height: 4),
          Text(meta.description, style: context.txt.bodySmall),
          const SizedBox(height: 16),
          if (widget.setting.type == 'BOOL')
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_value.text == 'true' ? 'Bật' : 'Tắt'),
                value: _value.text == 'true',
                onChanged: (value) => setState(() {
                      _value.text = '$value';
                      _changed = true;
                    }))
          else
            HvpTextField(
                label: 'Giá trị',
                controller: _value,
                helper: meta.unit == null ? null : 'Đơn vị: ${meta.unit}',
                onChanged: (_) => setState(() => _changed = true),
                keyboardType: widget.setting.type == 'INT'
                    ? TextInputType.number
                    : TextInputType.text),
          const SizedBox(height: 16),
          if (_changed) ...<Widget>[
            HvpTextField(
                label: 'Lý do thay đổi',
                controller: _reason,
                required: true,
                maxLines: 2,
                onChanged: (_) => setState(() => _showReasonError = false),
                validator: (_) => null),
            if (_showReasonError)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Nhập lý do tối thiểu 3 ký tự.',
                      style: context.txt.bodySmall
                          .copyWith(color: context.hvp.red))),
            const SizedBox(height: 16),
          ],
          HvpButton.primary(
              label: 'Lưu thay đổi',
              small: true,
              loading: _saving,
              onPressed: _saving
                  ? null
                  : !_changed
                      ? null
                      : () async {
                          final value = _parse();
                          if (value == null || _reason.text.trim().length < 3) {
                            setState(() => _showReasonError = true);
                            return;
                          }
                          setState(() => _saving = true);
                          try {
                            await ref
                                .read(adminSettingsRepositoryProvider)
                                .update(
                                    widget.setting.key, value, _reason.text);
                            if (!context.mounted) return;
                            setState(() {
                              _changed = false;
                              _showReasonError = false;
                            });
                            ref.invalidate(adminSettingsProvider);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Đã lưu thay đổi.')));
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMessage(error))));
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _saving = false);
                            }
                          }
                        }),
        ]));
  }
}
