import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/error/api_exception.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../membership/presentation/providers/membership_providers.dart';
import '../../../membership/presentation/widgets/package_class_picker.dart';
import '../reception_memberships_providers.dart';

/// The "payment collected" modal: a required photo, then [submit] with its URL
/// and the chosen class.
/// When [packageTypeId] is given and the package has classes, a class picker
/// comes first ([initialClassId] pre-selects one) and a free class is required.
/// Resolves to the message returned by [submit], or null when dismissed.
Future<String?> showEvidenceSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required Future<String> Function(String evidenceUrl, String? classId) submit,
  String? summary,
  String? packageTypeId,
  String? initialClassId,
}) =>
    showHvpSheet<String>(
      context,
      title: title,
      builder: (_) => _EvidenceSheet(
        confirmLabel: confirmLabel,
        submit: submit,
        summary: summary,
        packageTypeId: packageTypeId,
        initialClassId: initialClassId,
      ),
    );

class _EvidenceSheet extends ConsumerStatefulWidget {
  const _EvidenceSheet({
    required this.confirmLabel,
    required this.submit,
    this.summary,
    this.packageTypeId,
    this.initialClassId,
  });

  final String confirmLabel;
  final String? summary;
  final String? packageTypeId;
  final String? initialClassId;
  final Future<String> Function(String evidenceUrl, String? classId) submit;

  @override
  ConsumerState<_EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends ConsumerState<_EvidenceSheet> {
  String? _url;
  late String? _classId = widget.initialClassId;
  bool _submitting = false;
  String? _error;

  Future<void> _confirm(bool needsClass) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final message = await widget.submit(_url!, needsClass ? _classId : null);
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      final id = widget.packageTypeId;
      final classGone = e is ApiException &&
          (e.code == 'CLASS_FULL' || e.code == 'CLASS_INACTIVE');
      if (classGone && id != null) ref.invalidate(packageClassesProvider(id));
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = errorMessage(e);
          if (classGone) _classId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.packageTypeId;
    final options =
        id == null ? null : ref.watch(packageClassesProvider(id)).valueOrNull;
    final needsClass = options != null && options.isNotEmpty;
    // Without a package to pick a class for, nothing waits on the class list.
    final classReady = id == null ||
        (options != null &&
            (options.isEmpty ||
                options.any((c) => c.id == _classId && !c.isFull)));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.summary != null) ...<Widget>[
            Text(widget.summary!, style: context.txt.body),
            const SizedBox(height: 14)
          ],
          if (id != null && !(options?.isEmpty ?? false)) ...<Widget>[
            Text('Lớp học', style: context.txt.label),
            const SizedBox(height: 8),
            PackageClassPicker(
              packageTypeId: id,
              selectedId: _classId,
              enabled: !_submitting,
              onChanged: (c) => setState(() => _classId = c.id),
            ),
            const SizedBox(height: 6),
          ],
          ref.watch(evidencePhotoBuilderProvider)(
              context, (url) => setState(() => _url = url)),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            InlineBanner(message: _error!)
          ],
          const SizedBox(height: 20),
          HvpButton.gold(
            label: widget.confirmLabel,
            expand: true,
            loading: _submitting,
            onPressed: _url == null || _submitting || !classReady
                ? null
                : () => _confirm(needsClass),
          ),
        ],
      ),
    );
  }
}
