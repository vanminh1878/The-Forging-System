import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../../../core/widgets/hvp_button.dart';
import '../domain/rank_configuration.dart';
import 'admin_settings_providers.dart';

class RankConfigurationScreen extends ConsumerWidget {
  const RankConfigurationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar:
          const HvpAppBar(title: 'Cấu hình hạng', titleIcon: HvpIcons.trophy),
      body: AsyncBody<List<RankConfiguration>>(
          value: ref.watch(rankConfigurationsProvider),
          onRetry: () => ref.invalidate(rankConfigurationsProvider),
          builder: (_, ranks) =>
              ListView(padding: const EdgeInsets.all(16), children: <Widget>[
                for (final rank in ranks)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _RankCard(rank: rank))
              ])));
}

class _RankCard extends ConsumerStatefulWidget {
  const _RankCard({required this.rank});
  final RankConfiguration rank;
  @override
  ConsumerState<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends ConsumerState<_RankCard> {
  late final months =
      TextEditingController(text: '${widget.rank.minActiveMonths}');
  final reason = TextEditingController();
  late bool trial = widget.rank.requiresTrial;
  String? role;
  @override
  void initState() {
    super.initState();
    role = widget.rank.approvalRole ?? 'COACH';
  }

  @override
  void dispose() {
    months.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HvpCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
            Row(children: <Widget>[
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: context.hvp.goldSoft),
                  child: Icon(HvpIcons.trophy, color: context.hvp.gold)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Text(widget.rank.name, style: context.txt.titleS),
                    Text('Điều kiện thăng hạng', style: context.txt.bodySmall)
                  ]))
            ]),
            const SizedBox(height: 20),
            Text('ĐIỀU KIỆN DUY TRÌ', style: context.txt.label),
            const SizedBox(height: 8),
            HvpTextField(
                label: 'Thời gian ở hạng (tháng)',
                controller: months,
                keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            Text('RANK TRIAL', style: context.txt.label),
            const SizedBox(height: 4),
            Text(
                'Yêu cầu học viên hoàn thành thử thách trước khi được lên hạng.',
                style: context.txt.bodySmall),
            const SizedBox(height: 8),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Yêu cầu Rank Trial'),
                value: trial,
                onChanged: (v) => setState(() => trial = v)),
            if (trial)
              DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Người chấm'),
                  items: const ['COACH', 'HEAD_COACH', 'ADMIN']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() => role = v)),
            const SizedBox(height: 16),
            HvpTextField(
                label: 'Lý do thay đổi',
                controller: reason,
                required: true,
                maxLines: 2),
            const SizedBox(height: 14),
            HvpButton.primary(
                label: 'Lưu thay đổi',
                icon: HvpIcons.check,
                small: true,
                onPressed: () async {
                  final value = int.tryParse(months.text);
                  if (value == null || reason.text.trim().length < 3) return;
                  await ref.read(rankConfigurationRepositoryProvider).update(
                      widget.rank,
                      minActiveMonths: value,
                      requiresTrial: trial,
                      approvalRole: role,
                      reason: reason.text);
                  ref.invalidate(rankConfigurationsProvider);
                })
          ]));
}
