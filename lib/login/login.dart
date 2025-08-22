import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart'; // kDebugMode

final storage = FlutterSecureStorage();

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  late TapGestureRecognizer _tapRecognizer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tapRecognizer = TapGestureRecognizer()..onTap = _handleSignUp;
  }

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    _tapRecognizer.dispose();
    super.dispose();
  }

  void _handleSignUp() {
    Navigator.pushNamed(context, '/sign-in');
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    final response = await http.post(
      Uri.parse('https://kooala.tassoo.uk/users/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userID': idController.text.trim(),
        'password': passwordController.text.trim(),
      }),
    );
    print('📦 로그인 응답: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = json.decode(response.body);
      final token = decoded['data']['token'];
      final responseUserId = decoded['data']['userID']; // ✅ 수정
      final username = decoded['data']['name'] as String;

      if (kDebugMode) {
        // 전체 토큰 출력 (개발용)
        debugPrint('🔐 JWT token: $token', wrapWidth: 1024);

        // JWT payload 디코드해서 보기
        final parts = token.split('.');
        if (parts.length == 3) {
          final payloadJson = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])),
          );
          debugPrint('📦 JWT payload: $payloadJson', wrapWidth: 1024);
        }
      }
      await storage.write(key: 'jwt', value: token);
      await storage.write(key: 'userID', value: responseUserId); // 로그인 후
      await storage.write(key: 'username', value: username);
      // 저장된 값 검증 로그
      if (kDebugMode) {
        final savedJwt = await storage.read(key: 'jwt');
        final savedUserId = await storage.read(key: 'userID');
        debugPrint(
          '💾 saved jwt length=${savedJwt?.length}, userID=$savedUserId',
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 실패. 아이디 또는 비밀번호를 확인하세요.')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/');
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Center(
                    child: Text(
                      '로그인',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: idController,
                    decoration: InputDecoration(
                      hintText: '아이디',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: '비밀번호',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8183D9),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              '로그인',
                              style: TextStyle(color: Colors.white),
                            ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        text: '계정이 없으신가요? ',
                        style: const TextStyle(color: Colors.black),
                        children: [
                          TextSpan(
                            text: '회원가입하기',
                            style: const TextStyle(
                              color: Color(0xFF8183D9),
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: _tapRecognizer,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final storage = FlutterSecureStorage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈 화면'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await storage.delete(key: 'jwt');
              await storage.delete(key: 'username');
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: const Center(child: Text('로그인 완료!')),
    );
  }
}

class SleepScreen extends StatelessWidget {
  final storage = FlutterSecureStorage();

  Future<String> _loadUsername() async {
    return await storage.read(key: 'username') ?? '사용자';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadUsername(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('수면 화면')),
          body: Center(child: Text('${snapshot.data}아 안녕!')),
        );
      },
    );
  }
}
