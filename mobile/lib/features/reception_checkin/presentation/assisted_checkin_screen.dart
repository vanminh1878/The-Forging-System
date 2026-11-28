import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/evidence_photo_picker.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../../checkin/domain/checkin_failure.dart';
import '../../checkin/domain/checkin_session.dart';
import '../../checkin/presentation/widgets/checkin_result_view.dart';
import '../domain/member_hit.dart';
import 'assisted_checkin_controller.dart';
import 'reception_providers.dart';
import 'widgets/member_card.dart';

/// Builds the photo field of the form. Replaced in tests, where there is no camera.
typedef AssistedPhotoFieldBuilder = Widget Function(BuildContext context, ValueChanged<String?> onChanged);

Widget evidencePhotoFieldBuilder(BuildContext context, ValueChanged<String?> onChanged) => EvidencePhotoPicker(
      onChanged: onChanged,
      cameraOnly: true,
      label: 'Ảnh học viên tại quầy',
      hint: 'Chụp ảnh học viên đang ở quầy',
    );

final assistedPhotoFieldBuilderProvider = Provider<AssistedPhotoFieldBuilder>((ref) => evidencePhotoFieldBuilder);

/// The front desk checks a member into one session: confirm who and what, take the photo, send.
class AssistedCheckinScreen extends ConsumerStatefulWidget {
  const AssistedCheckinScreen({super.key, required this.memberId, required this.sessionId, this.member});

  final String memberId;
  final String sessionId;

  /// The search result the desk came from; shown on top when known.
  final MemberHit? member;

  @override
  ConsumerState<AssistedCheckinScreen> createState() => _AssistedCheckinScreenState();
}

class _AssistedCheckinScreenState extends ConsumerState<AssistedCheckinScreen> {
  String? _photoUrl;

  /// Bumped to rebuild the photo field empty (after "Chụp lại ảnh").
  int _photoGeneration = 0;

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(ReceptionPaths.checkin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistedCheckinProvider);
    final controller = ref.read(assistedCheckinProvider.notifier);
    final t = context.txt;

    if (state is AssistedDone) {
      return Scaffold(body: CheckinSuccessView(result: state.result, onDone: _leave));
    }
    if (state is AssistedFailed) {
      return Scaffold(
        body: CheckinFailureView(
          failure: CheckinFailure.from(state.error),
          typed: false,
          forFrontDesk: true,
          onScanAgain: () {
            setState(() {
              _photoUrl = null;
              _photoGeneration++;
            });
            controller.backToForm();
          },
          onRetry: controller.retry,
          onRenew: () => context.go(ReceptionPaths.memberships),
          onBack: _leave,
        ),
      );
    }

    final submitting = state is AssistedSubmitting;
    final session = _sessionOf(ref.watch(memberTodayProvider(widget.memberId)).valueOrNull?.sessions);
    final photoField = ref.watch(assistedPhotoFieldBuilderProvider);
    return Scaffold(
      appBar: const HvpAppBar(title: 'Check-in hộ', titleIcon: HvpIcons.userPlus),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          if (widget.member != null) ...<Widget>[MemberCard(member: widget.member!), const SizedBox(height: 12)],
          if (session != null) _SessionSummary(session: session),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: ValueKey<int>(_photoGeneration),
            child: photoField(context, (url) => setState(() => _photoUrl = url)),
          ),
          const SizedBox(height: 12),
          Text('Ảnh minh chứng là bắt buộc. Check-in hộ sẽ trừ 1 buổi của gói tập, giống như học viên tự check-in.', style: t.bodySmall),
          const SizedBox(height: 20),
          if (_photoUrl == null) ...<Widget>[
            const InlineBanner(message: 'Chụp ảnh học viên tại quầy để tiếp tục.', tone: ChipTone.info),
            const SizedBox(height: 12),
          ],
          HvpButton.gold(
            label: 'Xác nhận check-in hộ',
            icon: HvpIcons.checkCircle,
            loading: submitting,
            onPressed: _photoUrl == null || submitting
                ? null
                : () => controller.submit(memberId: widget.memberId, sessionId: widget.sessionId, evidenceUrl: _photoUrl!),
          ),
        ],
      ),
    );
  }

  CheckinSession? _sessionOf(List<CheckinSession>? sessions) {
    if (sessions == null) return null;
    for (final s in sessions) {
      if (s.sessionId == widget.sessionId) return s;
    }
    return null;
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session});

  final CheckinSession session;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return HvpCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconLabel(icon: HvpIcons.calendar, label: 'BUỔI CHECK-IN', style: t.label),
          const SizedBox(height: 4),
          Text(session.title, style: t.titleM),
          const SizedBox(height: 2),
          IconLabel(icon: HvpIcons.clock, label: '${formatTime(session.startsAt)} - ${formatTime(session.endsAt)}'),
          if (session.branchName.isNotEmpty) IconLabel(icon: HvpIcons.mapPin, label: session.branchName),
          if (session.coachName.isNotEmpty) IconLabel(icon: HvpIcons.glove, label: 'Coach ${session.coachName}', style: t.caption),
        ],
      ),
    );
  }
}
