import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/color_utils.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/scan_frame.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/checkin_failure.dart';
import '../domain/checkin_session.dart';
import 'checkin_providers.dart';
import 'checkin_scan_controller.dart';
import 'widgets/checkin_result_view.dart';
import 'widgets/manual_code_sheet.dart';

/// The member points the camera at the QR on the front-desk screen; the server checks it in.
/// [sessionId] is the session picked on the Check-in tab (optional).
class CheckinScanScreen extends ConsumerWidget {
  const CheckinScanScreen({super.key, this.sessionId});

  final String? sessionId;

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(StudentPaths.checkin);
    }
  }

  /// The member cannot scan (no camera, web, a damaged QR): ask for the 6 digits and send them the same way.
  Future<void> _enterCode(BuildContext context, WidgetRef ref) async {
    final digits = await showManualCodeSheet(context);
    if (digits != null) await ref.read(checkinScanProvider.notifier).onTypedCode(digits, sessionId: sessionId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinScanProvider);
    final controller = ref.read(checkinScanProvider.notifier);
    final scanner = ref.watch(qrScannerBuilderProvider);
    final picked = ref.watch(todayCheckinProvider).valueOrNull?.sessions.where((s) => s.sessionId == sessionId);
    final pickedSession = picked != null && picked.isNotEmpty ? picked.first : null;

    return Scaffold(
      appBar: const HvpAppBar(
          title: 'Quét mã check-in', titleIcon: HvpIcons.scan),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          scanner(context, (code) => controller.onCode(code, sessionId: sessionId)),
          if (state is ScanIdle) ...<Widget>[
            const Center(child: ScanFrame(size: 260)),
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: _Hint(session: pickedSession),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Center(
                child: HvpButton.secondary(
                  label: 'Nhập mã thủ công',
                  icon: HvpIcons.list,
                  small: true,
                  onPressed: () => _enterCode(context, ref),
                ),
              ),
            ),
          ],
          if (state is ScanSubmitting) const _Busy(),
          if (state is ScanChoosing) _ChooseSessionPanel(state: state, onPick: controller.choose, onCancel: controller.scanAgain),
          if (state is ScanFailed)
            Positioned.fill(
              child: CheckinFailureView(
                failure: CheckinFailure.from(state.error),
                typed: state.code.isTyped,
                onScanAgain: () {
                  controller.scanAgain();
                  if (state.code.isTyped) _enterCode(context, ref);
                },
                onRetry: controller.retry,
                onRenew: () => context.push(StudentPaths.membership),
                onBack: () => _leave(context),
              ),
            ),
          if (state is ScanDone) Positioned.fill(child: CheckinSuccessView(result: state.result, onDone: () => _leave(context))),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({this.session});

  final CheckinSession? session;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.black.fade(0.55), borderRadius: BorderRadius.circular(8)),
          child: Text(
            'Đưa mã QR trên màn hình phòng tập vào khung',
            style: t.body.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        if (session != null) ...<Widget>[
          const SizedBox(height: 8),
          StatusChip(label: '${session!.title} · ${formatTime(session!.startsAt)}', tone: ChipTone.gold),
        ],
      ],
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.fade(0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Đang check-in…', style: context.txt.body.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// Sheet over the camera, anchored to the bottom.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: HvpCard(child: child)),
      ),
    );
  }
}

class _ChooseSessionPanel extends StatelessWidget {
  const _ChooseSessionPanel({required this.state, required this.onPick, required this.onCancel});

  final ScanChoosing state;
  final ValueChanged<String> onPick;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return _BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Bạn check-in buổi nào?', style: t.titleM),
          const SizedBox(height: 4),
          Text('Có nhiều buổi đang mở tại chi nhánh này.', style: t.bodySmall),
          const SizedBox(height: 12),
          for (final s in state.sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HvpCard(
                semanticLabel: 'Check-in ${s.title}',
                onTap: () => onPick(s.sessionId),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(s.title, style: t.titleS),
                          Text('${formatTime(s.startsAt)} - ${formatTime(s.endsAt)}', style: t.caption),
                        ],
                      ),
                    ),
                    const Icon(HvpIcons.caretRight),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(width: double.infinity, child: HvpButton.secondary(label: 'Hủy', onPressed: onCancel, small: true)),
        ],
      ),
    );
  }
}
