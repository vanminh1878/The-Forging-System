import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../domain/member_hit.dart';
import 'reception_providers.dart';
import 'widgets/member_card.dart';

/// Front desk "Check-in" tab: find the learner who needs help, then see their sessions of today.
class ReceptionCheckinTab extends ConsumerStatefulWidget {
  const ReceptionCheckinTab({super.key});

  @override
  ConsumerState<ReceptionCheckinTab> createState() =>
      _ReceptionCheckinTabState();
}

class _ReceptionCheckinTabState extends ConsumerState<ReceptionCheckinTab> {
  final TextEditingController _field = TextEditingController();
  Timer? _debounce;

  /// The text actually searched: it follows the field a moment after typing stops.
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _typed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && value.trim() != _query) {
        setState(() => _query = value.trim());
      }
    });
  }

  void _submitted(String value) {
    _debounce?.cancel();
    setState(() => _query = value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Check-in hỗ trợ', style: t.titleL),
              const SizedBox(height: 4),
              Text('Giúp học viên không tự check-in được. Cần ảnh minh chứng.',
                  style: t.bodySmall),
              const SizedBox(height: 12),
              HvpButton.secondary(
                label: 'Hiển thị mã QR quầy',
                icon: HvpIcons.scan,
                small: true,
                onPressed: () => context.push(ReceptionPaths.branchQr),
              ),
              const SizedBox(height: 14),
              HvpTextField(
                label: 'Tìm học viên',
                hint: 'Tên, số điện thoại hoặc mã học viên',
                controller: _field,
                prefixIcon: HvpIcons.search,
                maxLength: 100,
                textInputAction: TextInputAction.search,
                onChanged: _typed,
                onSubmitted: _submitted,
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody<MemberSearchResult>(
            value: ref.watch(memberSearchProvider(_query)),
            onRetry: () => ref.invalidate(memberSearchProvider(_query)),
            builder: (context, result) {
              if (result.items.isEmpty) {
                return _query.isEmpty
                    ? const EmptyState(
                        icon: HvpIcons.users, title: 'Chưa có học viên')
                    : const EmptyState(
                        icon: HvpIcons.users,
                        title: 'Không tìm thấy học viên',
                        message:
                            'Kiểm tra lại tên, số điện thoại hoặc mã học viên.',
                      );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                    16, 4, 16, HvpLayout.navClearance),
                itemCount: result.items.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        result.hasMoreThanShown
                            ? 'Hiển thị ${result.items.length} trên ${result.total} học viên. Gõ thêm để thu hẹp.'
                            : '${result.total} học viên',
                        style: t.caption,
                      ),
                    );
                  }
                  final member = result.items[i - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MemberCard(
                      member: member,
                      onTap: () => context.push(
                          ReceptionPaths.memberToday(member.id),
                          extra: member),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
