import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../error/error_mapper.dart';
import '../utils/json_utils.dart';
import 'network_providers.dart';

enum UploadPurpose { evidence, avatar }

/// Uploads an image and returns its public URL (`POST /uploads?purpose=...`).
abstract class UploadService {
  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    UploadPurpose purpose = UploadPurpose.evidence,
  });
}

class DioUploadService implements UploadService {
  DioUploadService(this._dio);

  final Dio _dio;

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    UploadPurpose purpose = UploadPurpose.evidence,
  }) async {
    final form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    });
    try {
      final res = await _dio.post<dynamic>(
        '/uploads',
        queryParameters: <String, dynamic>{'purpose': purpose.name},
        data: form,
        options: Options(sendTimeout: const Duration(seconds: 60)),
      );
      final url = str(asMap(asMap(res.data)['data']), 'url');
      if (url.isEmpty) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
        );
      }
      return url;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

final uploadServiceProvider =
    Provider<UploadService>((ref) => DioUploadService(ref.watch(dioProvider)));
