import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/network/upload_service.dart';
import 'package:hvp_forging/core/utils/image_picking.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_providers.dart';
import 'package:hvp_forging/features/fighter_record/presentation/providers/fighter_record_providers.dart';
import 'package:hvp_forging/features/profile/presentation/providers/profile_providers.dart';
import 'package:hvp_forging/features/profile/presentation/widgets/profile_details.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/test_harness.dart';
import '../fighter_record/fixtures.dart';
import 'fixtures.dart';

const _url = 'https://api.hvp.vn/files/hvp/avatars/u/x.jpg';

class _FakeUpload implements UploadService {
  Object? error;
  final List<UploadPurpose> purposes = <UploadPurpose>[];

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    UploadPurpose purpose = UploadPurpose.evidence,
  }) async {
    purposes.add(purpose);
    if (error != null) throw error!;
    return _url;
  }
}

class _AvatarProbe extends ConsumerWidget {
  const _AvatarProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text('avatar:${ref.watch(currentUserProvider)?.avatarUrl}');
}

PickedImage? _picked = PickedImage(
    bytes: Uint8List.fromList(<int>[1, 2, 3]),
    filename: 'a.jpg',
    mimeType: 'image/jpeg');

Future<void> _pump(
    WidgetTester tester, FakeProfileRepository repo, _FakeUpload upload) async {
  await pumpHvp(
    tester,
    const Scaffold(
      body: SingleChildScrollView(
          child: Column(children: <Widget>[_AvatarProbe(), ProfileDetails()])),
    ),
    overrides: <Override>[
      profileRepositoryProvider.overrideWithValue(repo),
      uploadServiceProvider.overrideWithValue(upload),
      profileImagePickerProvider.overrideWithValue((_) async => _picked),
      fighterRecordRepositoryProvider
          .overrideWithValue(FakeFighterRecordRepository()),
      authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(restored: makeUser(AppRole.student))),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _pickPhoto(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Chỉnh sửa hồ sơ'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Đổi ảnh đại diện'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chụp ảnh'));
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('LƯU ẢNH'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => _picked = PickedImage(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      filename: 'a.jpg',
      mimeType: 'image/jpeg'));

  testWidgets('the camera badge only exists in edit mode', (tester) async {
    await _pump(tester, FakeProfileRepository(), _FakeUpload());
    expect(find.byTooltip('Đổi ảnh đại diện'), findsNothing);
    await tester.tap(find.byTooltip('Chỉnh sửa hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Đổi ảnh đại diện'), findsOneWidget);
  });

  testWidgets(
      'picking a photo only previews it: nothing is uploaded or saved yet',
      (tester) async {
    final repo = FakeProfileRepository();
    final upload = _FakeUpload();
    await _pump(tester, repo, upload);
    await _pickPhoto(tester);

    expect(find.text('Ảnh mới chưa được lưu'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('LƯU ẢNH'), findsOneWidget);
    expect(find.text('HỦY'), findsOneWidget);
    expect(upload.purposes, isEmpty);
    expect(repo.updates, isEmpty);
    expect(find.text('avatar:null'), findsOneWidget);
    expect(find.text('Đã lưu ảnh đại diện.'), findsNothing);
  });

  testWidgets(
      'Lưu ảnh uploads it as avatar, PATCHes avatarUrl and updates the user',
      (tester) async {
    final repo = FakeProfileRepository()
      ..onUpdate = (_) async => sampleProfile(avatarUrl: _url);
    final upload = _FakeUpload();
    await _pump(tester, repo, upload);
    await _pickPhoto(tester);
    await _tapSave(tester);

    expect(upload.purposes, <UploadPurpose>[UploadPurpose.avatar]);
    expect(repo.updates.single, <String, Object?>{'avatarUrl': _url});
    expect(find.text('avatar:$_url'), findsOneWidget);
    expect(find.text('Đã lưu ảnh đại diện.'), findsOneWidget);
    // the preview and its buttons are gone once saved
    expect(find.text('Ảnh mới chưa được lưu'), findsNothing);
    expect(find.text('LƯU ẢNH'), findsNothing);
  });

  testWidgets('Hủy drops the preview and keeps the saved photo',
      (tester) async {
    final repo = FakeProfileRepository();
    final upload = _FakeUpload();
    await _pump(tester, repo, upload);
    await _pickPhoto(tester);
    await tester.tap(find.text('HỦY'));
    await tester.pumpAndSettle();

    expect(find.text('Ảnh mới chưa được lưu'), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(upload.purposes, isEmpty);
    expect(repo.updates, isEmpty);
    expect(find.text('avatar:null'), findsOneWidget);
  });

  testWidgets('picking again replaces the preview, still one save',
      (tester) async {
    final repo = FakeProfileRepository()
      ..onUpdate = (_) async => sampleProfile(avatarUrl: _url);
    final upload = _FakeUpload();
    await _pump(tester, repo, upload);
    await _pickPhoto(tester);
    await tester.tap(find.byTooltip('Đổi ảnh đại diện'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chụp ảnh'));
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(upload.purposes, hasLength(1));
    expect(repo.updates, hasLength(1));
  });

  testWidgets('cancelling the picker does nothing', (tester) async {
    _picked = null;
    final repo = FakeProfileRepository();
    final upload = _FakeUpload();
    await _pump(tester, repo, upload);
    await _pickPhoto(tester);

    expect(find.text('Ảnh mới chưa được lưu'), findsNothing);
    expect(upload.purposes, isEmpty);
    expect(repo.updates, isEmpty);
  });

  testWidgets(
      'an upload error shows its message, saves nothing and keeps the preview',
      (tester) async {
    final repo = FakeProfileRepository()
      ..onUpdate = (_) async => sampleProfile(avatarUrl: _url);
    final upload = _FakeUpload()
      ..error = const ApiException(code: 'X', message: 'Ảnh quá lớn.');
    await _pump(tester, repo, upload);
    await _pickPhoto(tester);
    await _tapSave(tester);

    expect(find.text('Ảnh quá lớn.'), findsOneWidget);
    expect(repo.updates, isEmpty);
    expect(find.text('avatar:null'), findsOneWidget);
    expect(find.text('Ảnh mới chưa được lưu'), findsOneWidget);

    // retrying without picking again works once the upload recovers
    upload.error = null;
    await _tapSave(tester);
    expect(repo.updates.single, <String, Object?>{'avatarUrl': _url});
    expect(find.text('avatar:$_url'), findsOneWidget);
  });

  testWidgets('a rejected avatar URL shows the API message', (tester) async {
    final repo = FakeProfileRepository()
      ..onUpdate = (_) async => throw const ApiException(
          code: 'INVALID_AVATAR_URL',
          message:
              'Ảnh đại diện không hợp lệ. Vui lòng tải ảnh lên trước rồi chọn lại.');
    await _pump(tester, repo, _FakeUpload());
    await _pickPhoto(tester);
    await _tapSave(tester);

    expect(find.textContaining('Ảnh đại diện không hợp lệ'), findsOneWidget);
    expect(find.text('avatar:null'), findsOneWidget);
  });
}
