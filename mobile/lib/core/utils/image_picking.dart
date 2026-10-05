import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// An image chosen by the user, already read into memory (works on web too).
class PickedImage {
  const PickedImage({required this.bytes, required this.filename, required this.mimeType});

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

/// Maps a file name to one of the MIME types accepted by `POST /uploads`.
String mimeTypeForFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

/// Opens camera/gallery. Returns null when the user cancels.
Future<PickedImage?> pickImage(ImageSource source) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
  final mime = file.mimeType ?? mimeTypeForFilename(name);
  return PickedImage(bytes: bytes, filename: name, mimeType: mime);
}
