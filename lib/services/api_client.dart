// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final apiClient = ApiClient(baseUrl: dotenv.env['API_BASE_URL']!);

class ApiClient {
  ApiClient({required this.baseUrl, FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final String baseUrl;
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final token = await _storage.read(key: 'jwt');

    // 기존 query map 복사 후 token 추가
    final updatedQuery = Map<String, String>.from(query ?? {});
    if (token != null && token.isNotEmpty) {
      updatedQuery['token'] = token;
    }

    final uri = Uri.parse(
      '$baseUrl$path',
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
