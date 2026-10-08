import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  String? _token;

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('auth_token');
    } else {
      await prefs.setString('auth_token', token);
    }
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_token != null && _token!.isNotEmpty)
        'Authorization': 'Bearer $_token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleanPath').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers());
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path,
      [Map<String, dynamic>? body]) async {
    final res = await http.post(_uri(path),
        headers: _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  Future<Map<String, dynamic>> put(String path,
      [Map<String, dynamic>? body]) async {
    final res = await http.put(_uri(path),
        headers: _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(String path,
      [Map<String, dynamic>? body]) async {
    final res = await http.patch(_uri(path),
        headers: _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers());
    return _decode(res);
  }

  /// Headers for raw (multipart) requests - no Content-Type, so the
  /// http package can set the multipart boundary itself.
  Map<String, String> get authHeaders => _headers(json: false);

  Map<String, dynamic> decode(String body, int statusCode) {
    final parsed = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    if (statusCode >= 400) {
      final message = parsed is Map ? parsed['message']?.toString() : null;
      throw ApiException(
        status: statusCode,
        message: message ?? 'Request failed ($statusCode)',
        body: parsed is Map ? Map<String, dynamic>.from(parsed) : null,
      );
    }
    if (parsed is Map<String, dynamic>) return parsed;
    return {'data': parsed};
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final message = body is Map ? body['message']?.toString() : null;
      throw ApiException(
        status: res.statusCode,
        message: message ?? 'Request failed (${res.statusCode})',
        body: body,
      );
    }
    if (body is Map<String, dynamic>) return body;
    return {'data': body};
  }
}

class ApiException implements Exception {
  ApiException({required this.status, required this.message, this.body});

  final int status;
  final String message;
  final Map<String, dynamic>? body;

  @override
  String toString() => 'ApiException($status): $message';
}
