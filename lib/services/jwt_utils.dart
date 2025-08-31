import 'dart:convert';
import 'dart:developer';

/// JWT 토큰 관련 유틸리티 함수들
class JwtUtils {
  /// JWT 토큰에서 userID를 추출
  static String? extractUserIdFromToken(String token) {
    try {
      // JWT 토큰은 3부분으로 구성: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // payload 부분 디코딩
      final payload = parts[1];
      // Base64 디코딩 (패딩 추가)
      final normalized = base64.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp) as Map<String, dynamic>;

      // userID 추출
      return payloadMap['userID'] as String?;
    } catch (e) {
      log('JWT 토큰에서 userID 추출 실패: $e');
      return null;
    }
  }

  /// JWT 토큰에서 username을 추출
  static String? extractUsernameFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp) as Map<String, dynamic>;

      return payloadMap['username'] as String?;
    } catch (e) {
      log('JWT 토큰에서 username 추출 실패: $e');
      return null;
    }
  }

  /// JWT 토큰이 유효한지 확인
  static bool isTokenValid(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp) as Map<String, dynamic>;

      // 만료 시간 확인
      final exp = payloadMap['exp'] as int?;
      if (exp == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp > now;
    } catch (e) {
      log('JWT 토큰 유효성 확인 실패: $e');
      return false;
    }
  }
}
