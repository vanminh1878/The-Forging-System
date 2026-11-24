import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/color_utils.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/image_picking.dart';
import '../../../../core/widgets/hvp_avatar.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/profile_providers.dart';

/// AUTH-14: avatar with a camera badge.
///
/// Picking a photo only shows a preview marked "Chưa lưu": nothing is uploaded
/// until the learner taps "Lưu ảnh". "Hủy" drops the preview and the saved photo
/// stays as it was.
class AvatarEditor extends ConsumerStatefulWidget {
  const AvatarEditor({super.key, required this.name});

  final String name;

  @override
  ConsumerState<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends ConsumerState<AvatarEditor> {
  /// The photo picked but not saved yet.
  PickedImage? _pending;

  Future<void> _pick() async {
    final source = await showOptionSheet<ImageSource>(
      context,
      title: 'Ảnh đại diện',
      options: const <SheetOption<ImageSource>>[
        SheetOption<ImageSource>(
            value: ImageSource.camera,
            label: 'Chụp ảnh',
            icon: HvpIcons.camera),
        SheetOption<ImageSource>(
            value: ImageSource.gallery,
            label: 'Chọn từ thư viện',
            icon: HvpIcons.image),
      ],
    );
    if (source == null || !mounted) return;
    final picked = await ref.read(profileImagePickerProvider)(source);
    if (picked == null || !mounted) return;
    ref.read(profileAvatarProvider.notifier).reset();
    setState(() => _pending = picked);
  }

  Future<void> _save() async {
    final photo = _pending;
    if (photo == null) return;
    final ok = await ref.read(profileAvatarProvider.notifier).change(photo);
    if (!mounted) return;
    if (ok) {
      setState(() => _pending = null);
      HvpToast.success(context, 'Đã lưu ảnh đại diện.');
    } else {
      // The preview stays so the learner can retry without picking again.
      HvpToast.error(
          context,
          ref.read(profileAvatarProvider).error ??
              'Không lưu được ảnh đại diện.');
    }
  }

  void _cancel() {
    ref.read(profileAvatarProvider.notifier).reset();
    setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final busy = ref.watch(profileAvatarProvider).submitting;
    final url = ref.watch(currentUserProvider.select((u) => u?.avatarUrl));
    final pending = _pending;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Center(
          child: SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              children: <Widget>[
                if (pending == null)
                  HvpAvatar(url: url, name: widget.name, size: 88)
                else
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.amber, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.memory(pending.bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => HvpAvatar(
                              url: null, name: widget.name, size: 84)),
                    ),
                  ),
                if (busy)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: c.bg.fade(0.6)),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    tooltip: 'Đổi ảnh đại diện',
                    style: IconButton.styleFrom(
                        backgroundColor: c.gold, foregroundColor: c.onGold),
                    onPressed: busy ? null : _pick,
                    icon: const Icon(HvpIcons.camera, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (pending != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(busy ? 'Đang lưu ảnh…' : 'Ảnh mới chưa được lưu',
              style: t.bodySmall.copyWith(color: c.amber)),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: HvpButton.secondary(
                    label: 'Hủy',
                    expand: true,
                    onPressed: busy ? null : _cancel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HvpButton.primary(
                    label: 'Lưu ảnh',
                    icon: HvpIcons.check,
                    expand: true,
                    loading: busy,
                    onPressed: busy ? null : _save),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
