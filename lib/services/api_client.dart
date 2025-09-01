// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient({required this.baseUrl, FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final String baseUrl; // 예: 'https://llm.tassoo.uk'  (끝에 / 없음)
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final token = await _storage.read(key: 'jwt');

    final updatedQuery = Map<String, String>.from(query ?? {});
    if (token != null && token.isNotEmpty) {
      updatedQuery['jwt'] = token;
    }

    // ✅ baseUrl 뒤의 / 제거, path는 있는 그대로(빈문자열 권장)
    final normalizedBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse(
      '$normalizedBase$path',
    ).replace(queryParameters: updatedQuery);

    final headers = <String, String>{'Accept': 'application/json'};
    print('Final request URI: $uri');
    print('Headers: $headers');

    final res = await http.get(uri, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET $uri -> ${res.statusCode} ${res.body}');
    }

    final decoded = json.decode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Unexpected JSON shape from $uri');
  }
}
