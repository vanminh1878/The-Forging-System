import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/error/api_exception.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../domain/schedule_models.dart';
import '../providers/schedule_providers.dart';
import '../widgets/session_detail_body.dart';

/// "Nội dung buổi tập": read-only detail of one session (no check-in, no actions).
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sessionDetailProvider(sessionId);
    ref.listen(provider, (_, next) {
      final error = next.error;
      if (error is ApiException &&
          (error.statusCode == 404 || error.code == 'NOT_FOUND')) {
        HvpToast.show(context, 'Buổi tập không còn trên lịch của bạn',
            type: ToastType.warning);
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(StudentPaths.schedule);
        }
      }
    });
    final c = context.hvp;
    final t = context.txt;
    return Scaffold(
      appBar: const HvpAppBar(title: 'Nội dung buổi tập'),
      body: AsyncBody<SessionDetail>(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        builder: (context, detail) => SessionDetailBody(detail: detail),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(HvpIcons.info, size: 16, color: c.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '% hoàn thành và điểm DP do Coach xác nhận sau buổi tập — học viên không tự đánh dấu hoàn thành.',
                  style: t.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
