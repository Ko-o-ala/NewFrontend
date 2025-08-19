// lib/services/llm_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class LlmService {
  static const String baseUrl = 'https://llm.tassoo.uk';

  /// A) 단순 API 형태 (예: /api/chat 로 message 전달)
  static Future<String> sendSimple(String message) async {
    final uri = Uri.parse('$baseUrl/api/chat'); // ⚠️ 실제 엔드포인트 맞추세요
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['reply'] ?? data['text'] ?? '응답이 없습니다.').toString();
    } else {
      throw Exception('서버 오류: ${res.statusCode} ${res.body}');
    }
  }

  /// B) OpenAI 호환 형태 (만약 OpenAI 포맷을 요구하는 프록시라면)
  static Future<String> sendOpenAIStyle(String message) async {
    final uri = Uri.parse('$baseUrl/v1/chat/completions'); // ⚠️ 필요 시 수정
    final body = {
      'model': 'gpt-4o-mini', // 또는 제공되는 모델명
      'messages': [
        {'role': 'user', 'content': message},
      ],
      'temperature': 0.7,
    };

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        // 'Authorization': 'Bearer YOUR_API_KEY', // 필요 시
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      // OpenAI 포맷: choices[0].message.content
      return data['choices']?[0]?['message']?['content']?.toString() ??
          '응답이 없습니다.';
    } else {
      throw Exception('서버 오류: ${res.statusCode} ${res.body}');
    }
  }
}
