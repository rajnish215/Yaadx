import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

String newOperationId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class CloudFailure implements Exception {
  final int status;
  final String code;
  const CloudFailure(this.status, this.code);
}

abstract class CloudGateway {
  Future<Map<String, dynamic>> request(
    String uid,
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]);
  Future<String> upload(String uid, String path, String kind, String id);
  Future<String> download(String uid, String id);
}

class CloudApi implements CloudGateway {
  CloudApi({
    required String baseUrl,
    required this.currentUid,
    required this.token,
  }) : base = Uri.parse(baseUrl) {
    if (base.host.isEmpty ||
        (base.path.isNotEmpty && base.path != '/') ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.scheme != 'https' &&
            !(kDebugMode &&
                base.scheme == 'http' &&
                ['10.0.2.2', 'localhost', '127.0.0.1'].contains(base.host)))) {
      throw ArgumentError('Use an HTTPS API URL (local HTTP is debug-only).');
    }
  }
  final Uri base;
  final String? Function() currentUid;
  final Future<String?> Function(bool force) token;
  void _check(String uid) {
    if (currentUid() != uid) throw const CloudFailure(401, 'account_changed');
  }

  @override
  Future<Map<String, dynamic>> request(
    String uid,
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      _check(uid);
      final bearer = await token(attempt == 1);
      _check(uid);
      if (bearer == null) throw const CloudFailure(401, 'sign_in_required');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      try {
        final req = await client
            .openUrl(method, base.resolve(path))
            .timeout(const Duration(seconds: 8));
        req.followRedirects = false;
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
        if (data != null) {
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode(data));
        }
        final response = await req.close().timeout(const Duration(seconds: 12));
        final text = await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 12));
        _check(uid);
        if (response.statusCode == 401 && attempt == 0) continue;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          String code = 'sync_failed';
          try {
            code = (jsonDecode(text) as Map)['error'] as String? ?? code;
          } catch (_) {}
          throw CloudFailure(response.statusCode, code);
        }
        return Map<String, dynamic>.from(jsonDecode(text) as Map);
      } finally {
        client.close(force: true);
      }
    }
    throw const CloudFailure(401, 'sign_in_required');
  }

  String _type(String path, String kind) {
    final ext = path.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'm4a' || 'mp4' => 'audio/mp4',
      _ => throw const CloudFailure(400, 'unsupported_media_type'),
    };
  }

  Uri _signed(String value) {
    final u = Uri.parse(value);
    if (u.scheme != 'https' || u.userInfo.isNotEmpty) {
      throw const CloudFailure(400, 'invalid_storage_url');
    }
    return u;
  }

  @override
  Future<String> upload(String uid, String path, String kind, String id) async {
    _check(uid);
    final file = File(path);
    if (!await file.exists()) {
      throw const CloudFailure(400, 'local_media_missing');
    }
    final size = await file.length();
    if (size > 20 * 1024 * 1024) {
      throw const CloudFailure(400, 'media_too_large');
    }
    final type = _type(path, kind);
    final result = await request(uid, 'POST', '/v1/media', {
      'id': id,
      'kind': kind,
      'contentType': type,
      'byteSize': size,
    });
    if (result['ready'] != true) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      try {
        _check(uid);
        final req = await client.putUrl(_signed(result['uploadUrl'] as String));
        req.followRedirects = false;
        req.headers.set(HttpHeaders.contentTypeHeader, type);
        req.contentLength = size;
        await req
            .addStream(file.openRead())
            .timeout(const Duration(seconds: 60));
        final response = await req.close().timeout(const Duration(seconds: 30));
        await response.drain<void>();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw const CloudFailure(503, 'media_upload_failed');
        }
      } finally {
        client.close(force: true);
      }
      await request(uid, 'POST', '/v1/media/$id/complete');
    }
    _check(uid);
    return id;
  }

  @override
  Future<String> download(String uid, String id) async {
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)) {
      throw const CloudFailure(400, 'invalid_media_id');
    }
    _check(uid);
    final directory = await getApplicationSupportDirectory();
    final folder = Directory(
      '${directory.path}/cloud_media/${base64Url.encode(utf8.encode(uid))}',
    );
    await folder.create(recursive: true);
    final result = await request(uid, 'GET', '/v1/media/$id');
    final ext = switch (result['contentType']) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/jpeg' => 'jpg',
      'audio/mpeg' => 'mp3',
      'audio/wav' => 'wav',
      _ => 'm4a',
    };
    final file = File('${folder.path}/$id.$ext');
    if (await file.exists() && await file.length() == result['byteSize']) {
      return file.path;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final temp = File('${file.path}.part');
    try {
      final req = await client.getUrl(_signed(result['downloadUrl'] as String));
      req.followRedirects = false;
      final response = await req.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const CloudFailure(503, 'media_download_failed');
      }
      final sink = temp.openWrite();
      var count = 0;
      try {
        await for (final bytes in response.timeout(
          const Duration(seconds: 20),
        )) {
          count += bytes.length;
          if (count > 20 * 1024 * 1024) {
            throw const CloudFailure(400, 'media_too_large');
          }
          sink.add(bytes);
        }
      } finally {
        await sink.close();
      }
      if (count != result['byteSize']) {
        throw const CloudFailure(503, 'media_download_incomplete');
      }
      _check(uid);
      await temp.rename(file.path);
      return file.path;
    } finally {
      client.close(force: true);
      if (await temp.exists()) await temp.delete();
    }
  }
}
