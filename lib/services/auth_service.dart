import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static const _jwtKey = 'jwt';
  static const _userIdKey = 'userID';

  static const _storage = FlutterSecureStorage();

  static Future<bool> isLoggedIn() async {
    final jwt = await _storage.read(key: _jwtKey);
    final uid =
        await _storage.read(key: _userIdKey) ??
        await _storage.read(key: 'userId'); // fallback
    debugPrint(
      '[AuthService] 토큰 존재: ${jwt?.isNotEmpty == true}, 사용자ID 존재: ${uid?.isNotEmpty == true}',
    );
    return (jwt?.isNotEmpty ?? false) && (uid?.isNotEmpty ?? false);
  }

  static Future<void> saveSession({
    required String token,
    required String userId,
    String? username,
  }) async {
    await _storage.write(key: _jwtKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    if (username != null) {
      await _storage.write(key: 'username', value: username);
    }

    if (kDebugMode) {
      final checkJwt = await _storage.read(key: _jwtKey);
      final checkUid = await _storage.read(key: _userIdKey);
      debugPrint(
        '[AuthService] 저장 확인 jwt? ${checkJwt != null}, userID? ${checkUid != null}',
      );
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _userIdKey); // ✅ userID도 함께 삭제
    await _storage.delete(key: 'username');
  }
}
