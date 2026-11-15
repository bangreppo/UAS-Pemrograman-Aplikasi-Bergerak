import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiError implements Exception {
  final String message;
  final int? code;
  final dynamic data;
  ApiError(this.message, [this.code, this.data]);
  @override
  String toString() => message;
}

class Api {
  static const String _env = String.fromEnvironment('API');
  static String? token;
  static VoidCallback? onUnauthorized;

  static String get base {
    if (_env.isNotEmpty) return _env;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000/api';
    return 'http://127.0.0.1:8000/api';
  }

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
  }

  static Future<void> setToken(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove('token');
    } else {
      await p.setString('token', t);
    }
  }

  static dynamic _handle(http.Response res) {
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    var msg = 'Terjadi kesalahan (${res.statusCode}).';
    if (data is Map) {
      final errs = data['errors'];
      if (errs is Map && errs.isNotEmpty) {
        final first = errs.values.first;
        msg = first is List && first.isNotEmpty ? '${first.first}' : '$first';
      } else if (data['message'] != null && '${data['message']}'.isNotEmpty) {
        msg = '${data['message']}';
      }
    }
    if (res.statusCode == 401 && token != null) {
      onUnauthorized?.call();
      msg = 'Sesi berakhir. Silakan masuk kembali.';
    }
    throw ApiError(msg, res.statusCode, data);
  }

  static ApiError get _offline => ApiError('Tidak dapat terhubung ke server. Pastikan backend berjalan di $base.');

  static Future<dynamic> _send(String method, String path, {Map<String, dynamic>? query, Object? body}) async {
    var uri = Uri.parse('$base$path');
    if (query != null) {
      final q = <String, String>{};
      query.forEach((k, v) {
        if (v != null) q[k] = '$v';
      });
      if (q.isNotEmpty) uri = uri.replace(queryParameters: q);
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    http.Response res;
    try {
      switch (method) {
        case 'POST':
          res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'PUT':
          res = await http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers);
          break;
        default:
          res = await http.get(uri, headers: headers);
      }
    } catch (_) {
      throw _offline;
    }
    return _handle(res);
  }

  /// Unggah berkas (multipart). files: (nama field, bytes, nama berkas).
  static Future<dynamic> multipart(String path, {Map<String, String> fields = const {}, List<(String, Uint8List, String)> files = const []}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$base$path'));
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields.addAll(fields);
    for (final f in files) {
      req.files.add(http.MultipartFile.fromBytes(f.$1, f.$2, filename: f.$3));
    }
    http.Response res;
    try {
      res = await http.Response.fromStream(await req.send());
    } catch (_) {
      throw _offline;
    }
    return _handle(res);
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? q}) => _send('GET', path, query: q);
  static Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  static Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
  static Future<dynamic> delete(String path) => _send('DELETE', path);
}
