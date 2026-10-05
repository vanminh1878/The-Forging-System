import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../design/chamfer_border.dart';
import '../design/color_utils.dart';
import '../design/hvp_context.dart';
import '../design/hvp_icons.dart';
import '../error/error_mapper.dart';
import '../network/upload_service.dart';
import '../utils/image_picking.dart';
import 'hvp_bottom_sheet.dart';
import 'hvp_toast.dart';

/// Picks a photo (camera or gallery), uploads it with `POST /uploads?purpose=evidence`
/// and reports the resulting URL through [onChanged] (null when removed).
class EvidencePhotoPicker extends ConsumerStatefulWidget {
  const EvidencePhotoPicker({
    super.key,
    required this.onChanged,
    this.label = 'Ảnh minh chứng',
    this.hint = 'Chụp hoặc chọn ảnh từ thư viện',
    this.purpose = UploadPurpose.evidence,
    this.initialUrl,
  });

  final ValueChanged<String?> onChanged;
  final String label;
  final String hint;
  final UploadPurpose purpose;
  final String? initialUrl;

  @override
  ConsumerState<EvidencePhotoPicker> createState() => _EvidencePhotoPickerState();
}

class _EvidencePhotoPickerState extends ConsumerState<EvidencePhotoPicker> {
  Uint8List? _preview;
  String? _url;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
  }

  Future<void> _choose() async {
    final source = await showOptionSheet<ImageSource>(
      context,
      title: widget.label,
      options: const <SheetOption<ImageSource>>[
        SheetOption<ImageSource>(value: ImageSource.camera, label: 'Chụp ảnh', icon: HvpIcons.camera),
        SheetOption<ImageSource>(value: ImageSource.gallery, label: 'Chọn từ thư viện', icon: HvpIcons.image),
      ],
    );
    if (source == null || !mounted) return;
    final picked = await pickImage(source);
    if (picked == null || !mounted) return;
    setState(() {
      _preview = picked.bytes;
      _uploading = true;
    });
    try {
      final url = await ref.read(uploadServiceProvider).uploadImage(
            bytes: picked.bytes,
            filename: picked.filename,
            mimeType: picked.mimeType,
            purpose: widget.purpose,
          );
      if (!mounted) return;
      setState(() {
        _url = url;
        _uploading = false;
      });
      widget.onChanged(url);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _uploading = false;
      });
      HvpToast.error(context, errorMessage(error));
    }
  }

  void _remove() {
    setState(() {
      _preview = null;
      _url = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final hasImage = _preview != null || _url != null;
    final shape = ChamferBorder(cut: 10, side: BorderSide(color: c.borderStrong));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.label.toUpperCase(), style: t.label),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: hasImage ? 'Đổi ảnh minh chứng' : 'Thêm ảnh minh chứng',
          child: Material(
            color: c.surfaceHigh,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: shape,
              onTap: _uploading ? null : _choose,
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (_preview != null)
                      Image.memory(_preview!, fit: BoxFit.cover)
                    else if (_url != null)
                      Image.network(_url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _Placeholder(hint: widget.hint))
                    else
                      _Placeholder(hint: widget.hint),
                    if (_uploading)
                      ColoredBox(
                        color: c.bg.fade(0.6),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    if (hasImage && !_uploading)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton.filled(
                          tooltip: 'Gỡ ảnh',
                          style: IconButton.styleFrom(backgroundColor: c.bg.fade(0.75), foregroundColor: c.textPrimary),
                          onPressed: _remove,
                          icon: const Icon(HvpIcons.close, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(HvpIcons.camera, size: 32, color: c.gold),
        const SizedBox(height: 8),
        Text(hint, style: context.txt.bodySmall),
      ],
    );
  }
}
