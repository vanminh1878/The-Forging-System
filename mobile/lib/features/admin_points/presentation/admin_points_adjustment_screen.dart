import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../../fighter_record/domain/points_models.dart';
import '../../fighter_record/presentation/widgets/transaction_tile.dart';
import '../../reception_checkin/domain/member_hit.dart';
import 'admin_points_providers.dart';

/// Admin-only manual DP / Marks corrections and a member's point ledger.
class AdminPointsAdjustmentScreen extends ConsumerStatefulWidget {
  const AdminPointsAdjustmentScreen({super.key});

  @override
  ConsumerState<AdminPointsAdjustmentScreen> createState() =>
      _AdminPointsAdjustmentScreenState();
}

class _AdminPointsAdjustmentScreenState
    extends ConsumerState<AdminPointsAdjustmentScreen> {
  final _search = TextEditingController();
  String _query = '';
  MemberHit? _member;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _query.trim().length < 2
        ? null
        : ref.watch(adminPointsSearchProvider(_query));
    return Scaffold(
      appBar: AppBar(title: const Text('Điều chỉnh DP / Marks')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('TÌM HỌC VIÊN', style: context.txt.titleL),
          const SizedBox(height: 8),
          HvpTextField(
            label: 'Tên, mã học viên hoặc số điện thoại',
            controller: _search,
            prefixIcon: HvpIcons.search,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          if (results != null)
            results.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator())),
              error: (error, _) => Text(errorMessage(error),
                  style: TextStyle(color: context.hvp.red)),
              data: (data) => data.items.isEmpty
                  ? const EmptyState(
                      icon: HvpIcons.search,
                      title: 'Không tìm thấy học viên',
                      message: 'Thử lại với tên, mã hoặc số điện thoại khác.')
                  : Column(
                      children: <Widget>[
                        for (final member in data.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _MemberResult(
                              member: member,
                              selected: _member?.id == member.id,
                              onTap: () => setState(() => _member = member),
                            ),
                          ),
                      ],
                    ),
            ),
          if (_member != null) ...<Widget>[
            const SizedBox(height: 20),
            _MemberLedger(member: _member!)
          ],
        ],
      ),
    );
  }
}

class _MemberResult extends StatelessWidget {
  const _MemberResult(
      {required this.member, required this.selected, required this.onTap});
  final MemberHit member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HvpCard(
        onTap: onTap,
        highlighted: selected,
        child: Row(children: <Widget>[
          CircleAvatar(
              child: Text(member.fullName.substring(0, 1).toUpperCase())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(member.fullName, style: context.txt.titleS),
                  Text(
                      '${member.memberCode}${member.phone == null ? '' : ' · ${member.phone}'}',
                      style: context.txt.bodySmall),
                ]),
          ),
          Icon(selected ? HvpIcons.checkCircle : HvpIcons.caretRight,
              color: context.hvp.gold),
        ]),
      );
}

class _MemberLedger extends ConsumerWidget {
  const _MemberLedger({required this.member});
  final MemberHit member;

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminPointsLedgerProvider(member.id));
    ref.invalidate(adminPointsMonthlyProvider(member.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthly = ref.watch(adminPointsMonthlyProvider(member.id));
    final ledger = ref.watch(adminPointsLedgerProvider(member.id));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('SỔ ĐIỂM · ${member.fullName.toUpperCase()}',
              style: context.txt.titleL),
          const SizedBox(height: 10),
          monthly.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(errorMessage(error),
                style: TextStyle(color: context.hvp.red)),
            data: (status) => _MonthlyCapWarning(status: status),
          ),
          const SizedBox(height: 12),
          _AdjustmentForm(memberId: member.id, onSaved: () => _refresh(ref)),
          const SizedBox(height: 20),
          Text('GIAO DỊCH GẦN ĐÂY', style: context.txt.titleM),
          const SizedBox(height: 8),
          AsyncBody<PointsPage>(
            value: ledger,
            onRetry: () => ref.invalidate(adminPointsLedgerProvider(member.id)),
            loading: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            builder: (_, page) => page.items.isEmpty
                ? const EmptyState(
                    icon: HvpIcons.receipt,
                    title: 'Chưa có giao dịch',
                    message: 'Sổ DP và Marks của học viên đang trống.')
                : Column(children: <Widget>[
                    for (final transaction in page.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(children: <Widget>[
                          TransactionTile(transaction: transaction),
                          Align(
                            alignment: Alignment.centerRight,
                            child: HvpButton.ghost(
                              label: 'Đảo giao dịch',
                              small: true,
                              onPressed: () =>
                                  _showReverse(context, ref, transaction),
                            ),
                          ),
                        ]),
                      ),
                  ]),
          ),
        ]);
  }

  Future<void> _showReverse(
      BuildContext context, WidgetRef ref, PointTransaction transaction) async {
    final reason = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đảo giao dịch'),
        content: HvpTextField(
            label: 'Lý do đảo giao dịch',
            controller: reason,
            required: true,
            maxLines: 3),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('HUỶ')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, reason.text.trim()),
              child: const Text('ĐẢO GIAO DỊCH')),
        ],
      ),
    );
    reason.dispose();
    if (value == null || value.length < 3 || !context.mounted) return;
    try {
      await ref
          .read(adminPointsRepositoryProvider)
          .reverse(transaction.id, reason: value);
      _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã đảo giao dịch.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    }
  }
}

class _MonthlyCapWarning extends StatelessWidget {
  const _MonthlyCapWarning({required this.status});
  final MonthlyPointStatus status;

  @override
  Widget build(BuildContext context) {
    final reached = status.dpCapReached || status.marksCapReached;
    return HvpCard(
      accent: reached ? context.hvp.amber : context.hvp.info,
      child:
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(reached ? HvpIcons.warning : HvpIcons.info,
            color: reached ? context.hvp.amber : context.hvp.info),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(reached ? 'ĐÃ CHẠM HẠN MỨC THÁNG' : 'HẠN MỨC THÁNG',
                    style: context.txt.titleS),
                Text(
                    'DP ${formatInt(status.dpUsed)} / ${formatInt(status.dpCap)} · Marks ${formatInt(status.marksUsed)} / ${formatInt(status.marksCap)}',
                    style: context.txt.bodySmall),
                const SizedBox(height: 4),
                Text(
                    'Điều chỉnh thủ công và đảo giao dịch không bị chặn bởi hạn mức tháng.',
                    style: context.txt.bodySmall),
              ]),
        ),
      ]),
    );
  }
}

class _AdjustmentForm extends ConsumerStatefulWidget {
  const _AdjustmentForm({required this.memberId, required this.onSaved});
  final String memberId;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AdjustmentForm> createState() => _AdjustmentFormState();
}

class _AdjustmentFormState extends ConsumerState<_AdjustmentForm> {
  final _form = GlobalKey<FormState>();
  final _dp = TextEditingController(text: '0');
  final _marks = TextEditingController(text: '0');
  final _reason = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _dp.dispose();
    _marks.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit({bool confirmed = false}) async {
    if (!_form.currentState!.validate()) return;
    final dp = int.parse(_dp.text.trim());
    final marks = int.parse(_marks.text.trim());
    if (dp == 0 && marks == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần nhập thay đổi DP hoặc Marks.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(adminPointsRepositoryProvider).adjust(widget.memberId,
          dpDelta: dp,
          marksDelta: marks,
          reason: _reason.text,
          confirmed: confirmed);
      if (!mounted) return;
      _dp.text = '0';
      _marks.text = '0';
      _reason.clear();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã ghi nhận điều chỉnh.')));
    } on ApiException catch (error) {
      if (error.code == 'CONFIRMATION_REQUIRED' && mounted) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Xác nhận điều chỉnh lớn'),
            content: Text(error.message),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('HUỶ')),
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('XÁC NHẬN')),
            ],
          ),
        );
        if (accepted == true && mounted) await _submit(confirmed: true);
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => HvpCard(
        child: Form(
          key: _form,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('ĐIỀU CHỈNH THỦ CÔNG', style: context.txt.titleM),
                const SizedBox(height: 10),
                HvpTextField(
                    label: 'Thay đổi DP',
                    controller: _dp,
                    keyboardType: TextInputType.number,
                    validator: _integerValidator),
                const SizedBox(height: 10),
                HvpTextField(
                    label: 'Thay đổi Marks',
                    controller: _marks,
                    keyboardType: TextInputType.number,
                    validator: _integerValidator),
                const SizedBox(height: 10),
                HvpTextField(
                    label: 'Lý do',
                    controller: _reason,
                    required: true,
                    maxLines: 3,
                    validator: (value) =>
                        value == null || value.trim().length < 3
                            ? 'Nhập lý do tối thiểu 3 ký tự.'
                            : null),
                const SizedBox(height: 12),
                HvpButton.primary(
                    label: 'Ghi nhận điều chỉnh',
                    expand: true,
                    loading: _submitting,
                    onPressed: _submitting ? null : _submit),
              ]),
        ),
      );

  String? _integerValidator(String? value) =>
      int.tryParse(value?.trim() ?? '') == null
          ? 'Nhập số nguyên, có thể âm.'
          : null;
}
