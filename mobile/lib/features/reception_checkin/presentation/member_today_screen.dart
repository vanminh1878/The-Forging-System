import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/icon_label.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../../checkin/domain/checkin_session.dart';
import '../../checkin/presentation/widgets/session_status.dart';
import '../domain/member_hit.dart';
import 'reception_providers.dart';
import 'widgets/member_card.dart';

/// How often the list is reloaded while it is open: windows open and close on the clock.
const Duration memberTodayRefreshEvery = Duration(seconds: 60);

/// One learner's sessions of today, with the ones the front desk can check them into.
class MemberTodayScreen extends ConsumerStatefulWidget {
  const MemberTodayScreen({super.key, required this.memberId, this.member});

  final String memberId;

  /// The search result the desk came from; shown on top. Absent when the screen is opened from a link.
  final MemberHit? member;

  @override
  ConsumerState<MemberTodayScreen> createState() => _MemberTodayScreenState();
}

class _MemberTodayScreenState extends ConsumerState<MemberTodayScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(memberTodayRefreshEvery, (_) => ref.invalidate(memberTodayProvider(widget.memberId)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(memberTodayProvider(widget.memberId));
    final t = context.txt;
    return Scaffold(
      appBar: const HvpAppBar(title: 'Check-in hỗ trợ', titleIcon: HvpIcons.scan),
      body: AsyncBody<TodayCheckin>(
        value: today,
        onRetry: () => ref.invalidate(memberTodayProvider(widget.memberId)),
        builder: (context, data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(memberTodayProvider(widget.memberId));
            await ref.read(memberTodayProvider(widget.memberId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, HvpLayout.navClearance),
            children: <Widget>[
              if (widget.member != null) ...<Widget>[MemberCard(member: widget.member!), const SizedBox(height: 12)],
              if (!data.eligibility.canCheckin && data.eligibility.message != null) ...<Widget>[
                InlineBanner(title: 'Chưa check-in được', message: data.eligibility.message!),
                const SizedBox(height: 12),
              ],
              IconLabel(icon: HvpIcons.calendar, label: 'BUỔI HÔM NAY', style: t.label),
              const SizedBox(height: 8),
              if (data.sessions.isEmpty)
                const EmptyState(
                  icon: HvpIcons.calendar,
                  title: 'Không có buổi nào hôm nay',
                  message: 'Học viên không có buổi nào cần check-in hôm nay.',
                )
              else
                for (final session in data.sessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SessionRow(
                      session: session,
                      onCheckin: () => context.push(ReceptionPaths.assistedCheckin(widget.memberId, session.sessionId), extra: widget.member),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onCheckin});

  final CheckinSession session;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final range = '${formatTime(session.startsAt)} - ${formatTime(session.endsAt)}';
    return HvpCard(
      semanticLabel: '${session.title}, $range, ${checkinStatusLabel(session)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(session.title, style: t.titleS),
          const SizedBox(height: 2),
          IconLabel(icon: HvpIcons.clock, label: range),
          if (session.branchName.isNotEmpty) IconLabel(icon: HvpIcons.mapPin, label: session.branchName),
          if (session.coachName.isNotEmpty) IconLabel(icon: HvpIcons.glove, label: 'Coach ${session.coachName}', style: t.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              StatusChip(label: checkinStatusLabel(session), tone: checkinStatusTone(session.state), icon: checkinStatusIcon(session.state)),
              if (session.isExam) const StatusChip(label: 'Kiểm tra', tone: ChipTone.info, icon: HvpIcons.exam),
            ],
          ),
          if (!session.canCheckin && session.message != null && session.state != CheckinState.checkedIn) ...<Widget>[
            const SizedBox(height: 6),
            Text(session.message!, style: t.caption),
          ],
          if (session.canCheckin) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: HvpButton.gold(label: 'Check-in hộ', icon: HvpIcons.scan, small: true, onPressed: onCheckin),
            ),
          ],
        ],
      ),
    );
  }
}
