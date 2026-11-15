import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/hvp_toast.dart';
import '../domain/renewal_models.dart';
import 'reception_memberships_providers.dart';
import 'renewal_notifier.dart';
import 'widgets/evidence_sheet.dart';
import 'widgets/reason_sheet.dart';

/// Runs [action]; when the request was handled by someone else the inbox is stale, so reload it.
Future<T> _reloadWhenHandled<T>(
    WidgetRef ref, Future<T> Function() action) async {
  try {
    return await action();
  } on ApiException catch (e) {
    if (e.code == 'RENEWAL_ALREADY_HANDLED') {
      ref.invalidate(renewalListProvider);
    }
    rethrow;
  }
}

/// MEM-13 / AMB-07: collect the payment photo, then approve [request].
Future<void> askApproveRenewal(
    BuildContext context, WidgetRef ref, RenewalRequest request) async {
  final price =
      request.priceVnd == null ? '' : ' · ${formatInt(request.priceVnd!)}đ';
  final message = await showEvidenceSheet(
    context,
    title: 'Xác nhận đã thu phí',
    summary: '${request.memberName} · ${request.packageName}$price',
    confirmLabel: 'Xác nhận & kích hoạt gói',
    packageTypeId: request.packageTypeId.isEmpty ? null : request.packageTypeId,
    initialClassId: request.classInfo?.id,
    memberId: request.memberId,
    submit: (url, classId) => _reloadWhenHandled(
      ref,
      () => ref
          .read(receptionMembershipsRepositoryProvider)
          .approveRenewal(request.id, evidenceUrl: url, classId: classId),
    ),
  );
  if (message == null) return;
  ref.invalidate(renewalListProvider);
  if (context.mounted) {
    HvpToast.success(context, message.isEmpty ? 'Đã kích hoạt gói.' : message);
  }
}

/// MEM-14: ask why, then cancel [request].
Future<void> askCancelRenewal(
    BuildContext context, WidgetRef ref, RenewalRequest request) async {
  final done = await showReasonSheet(
    context,
    title: 'Huỷ yêu cầu gia hạn',
    summary: '${request.memberName} · ${request.packageName}',
    confirmLabel: 'Huỷ yêu cầu',
    emptyMessage: 'Vui lòng nhập lý do huỷ.',
    submit: (reason) => _reloadWhenHandled(
      ref,
      () => ref
          .read(receptionMembershipsRepositoryProvider)
          .cancelRenewal(request.id, reason: reason),
    ),
  );
  if (done != true) return;
  ref.invalidate(renewalListProvider);
  if (context.mounted) {
    HvpToast.success(context, 'Đã huỷ yêu cầu — học viên được thông báo.');
  }
}
