import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../../../core/widgets/inline_banner.dart';
import '../domain/admin_challenge.dart';
import 'admin_challenge_providers.dart';

class AdminChallengeFormScreen extends ConsumerStatefulWidget {
  const AdminChallengeFormScreen({super.key, this.challengeId});
  final String? challengeId;
  @override
  ConsumerState<AdminChallengeFormScreen> createState() => _AdminChallengeFormScreenState();
}

class _AdminChallengeFormScreenState extends ConsumerState<AdminChallengeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController(); final _title = TextEditingController(); final _description = TextEditingController();
  final _target = TextEditingController(text: '1'); final _dp = TextEditingController(text: '0'); final _marks = TextEditingController(text: '0'); final _reason = TextEditingController();
  String _type = 'DAILY'; String _context = 'SESSION';
  late DateTime _startsAt = DateTime.now().add(const Duration(minutes: 5));
  late DateTime _endsAt = DateTime.now().add(const Duration(days: 1));
  bool _loaded = false;
  String? _status;
  late final Future<AdminChallenge>? _challengeFuture = widget.challengeId == null ? null : ref.read(adminChallengeRepositoryProvider).detail(widget.challengeId!);
  bool get _editing => widget.challengeId != null;

  @override void dispose() { for (final controller in [_code, _title, _description, _target, _dp, _marks, _reason]) { controller.dispose(); } super.dispose(); }
  void _load(AdminChallenge challenge) { if (_loaded) return; _loaded = true; _status = challenge.status; _code.text = challenge.code ?? ''; _title.text = challenge.title; _description.text = challenge.description ?? ''; _target.text = '${challenge.target}'; _dp.text = '${challenge.rewardDp}'; _marks.text = '${challenge.rewardMarks}'; _type = challenge.challengeType; _context = challenge.context; _startsAt = challenge.startsAt.toLocal(); _endsAt = challenge.endsAt.toLocal(); }
  ChallengeInput? _input() {
    if (!_formKey.currentState!.validate()) return null;
    final target = int.tryParse(_target.text); final dp = int.tryParse(_dp.text); final marks = int.tryParse(_marks.text);
    if (target == null || target < 1 || dp == null || dp < 0 || marks == null || marks < 0 || !_endsAt.isAfter(_startsAt)) return null;
    return ChallengeInput(code: _code.text.trim().isEmpty ? null : _code.text, title: _title.text, description: _description.text.trim().isEmpty ? null : _description.text, challengeType: _type, context: _context, target: target, rewardDp: dp, rewardMarks: marks, startsAt: _startsAt, endsAt: _endsAt);
  }
  Future<void> _save() async {
    final input = _input(); if (input == null) { setState(() {}); return; }
    if (_editing && _reason.text.trim().length < 3) { setState(() {}); return; }
    final ok = await ref.read(adminChallengeSubmitProvider.notifier).run(() => _editing ? ref.read(adminChallengeRepositoryProvider).update(widget.challengeId!, input, _reason.text) : ref.read(adminChallengeRepositoryProvider).create(input));
    if (ok && mounted) Navigator.of(context).pop();
  }
  Future<void> _setEnabled(bool enabled) async {
    if (_reason.text.trim().length < 3) { setState(() {}); return; }
    final ok = await ref.read(adminChallengeSubmitProvider.notifier).run(
      () => ref.read(adminChallengeRepositoryProvider).setEnabled(
        widget.challengeId!, enabled: enabled, reason: _reason.text,
      ),
    );
    if (ok && mounted) setState(() => _status = enabled ? 'OPEN' : 'CLOSED');
  }
  Future<void> _date(bool start) async {
    final current = start ? _startsAt : _endsAt;
    final day = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time != null) setState(() { final value = DateTime(day.year, day.month, day.day, time.hour, time.minute); if (start) { _startsAt = value; } else { _endsAt = value; } });
  }
  @override
  Widget build(BuildContext context) {
    if (!_editing) return _form(context);
    return FutureBuilder<AdminChallenge>(future: _challengeFuture, builder: (_, snapshot) {
      if (snapshot.hasError) return Scaffold(appBar: const HvpAppBar(title: 'Sửa Challenge'), body: InlineBanner(message: snapshot.error.toString()));
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      _load(snapshot.data!); return _form(context);
    });
  }
  Widget _form(BuildContext context) {
    final state = ref.watch(adminChallengeSubmitProvider);
    return Scaffold(appBar: HvpAppBar(title: _editing ? 'Sửa Challenge' : 'Tạo Challenge'), body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: <Widget>[
      HvpTextField(label: 'Tên Challenge', controller: _title, maxLength: 150, validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Nhập ít nhất 2 ký tự.' : null), const SizedBox(height: 12),
      HvpTextField(label: 'Mã Challenge', controller: _code, hint: 'Không bắt buộc, VD: DAILY-001', maxLength: 64, inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_-]'))]), const SizedBox(height: 12),
      HvpTextField(label: 'Mô tả', controller: _description, maxLines: 3, maxLength: 2000), const SizedBox(height: 16),
      _select('Chu kỳ', _type, const ['DAILY', 'WEEKLY', 'MONTHLY', 'EVENT'], (v) => setState(() => _type = v!)), const SizedBox(height: 12),
      _select('Bối cảnh', _context, const ['SESSION', 'WORKSHOP', 'EXAM'], (v) => setState(() => _context = v!)), const SizedBox(height: 12),
      HvpTextField(label: 'Mục tiêu', controller: _target, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: _positive), const SizedBox(height: 12),
      HvpTextField(label: 'Điểm DP thưởng', controller: _dp, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: _nonnegative), const SizedBox(height: 12),
      HvpTextField(label: 'Marks thưởng', controller: _marks, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: _nonnegative), const SizedBox(height: 16),
      _dateTile('Bắt đầu', _startsAt, () => _date(true)), _dateTile('Kết thúc', _endsAt, () => _date(false)),
      if (!_endsAt.isAfter(_startsAt)) const Padding(padding: EdgeInsets.only(top: 8), child: InlineBanner(message: 'Thời điểm kết thúc phải sau thời điểm bắt đầu.')),
       if (_editing) ...<Widget>[
         const SizedBox(height: 12),
         HvpTextField(label: 'Lý do cập nhật / đổi trạng thái', controller: _reason, maxLength: 500, validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Nhập lý do ít nhất 3 ký tự.' : null),
         const SizedBox(height: 12),
         if (_status == 'OPEN') HvpButton.secondary(label: 'Đóng Challenge', expand: true, loading: state.submitting, onPressed: state.submitting ? null : () => _setEnabled(false))
         else if (_status != 'CANCELLED') HvpButton.gold(label: 'Mở Challenge', expand: true, loading: state.submitting, onPressed: state.submitting ? null : () => _setEnabled(true)),
       ],
      if (state.error != null) ...<Widget>[const SizedBox(height: 12), InlineBanner(message: state.error!)], const SizedBox(height: 24),
      HvpButton.primary(label: _editing ? 'Lưu thay đổi' : 'Tạo Challenge', expand: true, loading: state.submitting, onPressed: _save),
    ])));
  }
  Widget _select(String label, String value, List<String> values, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(initialValue: value, decoration: InputDecoration(labelText: label), items: values.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: onChanged);
  Widget _dateTile(String label, DateTime value, VoidCallback tap) => ListTile(contentPadding: EdgeInsets.zero, title: Text(label), subtitle: Text('${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}'), trailing: const Icon(Icons.calendar_today_outlined), onTap: tap);
  String? _positive(String? value) => (int.tryParse(value ?? '') ?? 0) < 1 ? 'Nhập số nguyên lớn hơn 0.' : null;
  String? _nonnegative(String? value) => int.tryParse(value ?? '') == null ? 'Nhập số nguyên từ 0.' : null;
}
