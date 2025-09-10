import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController birthdateController = TextEditingController();
  final TextEditingController genderController = TextEditingController();

  // 실시간 체크는 제거. 중복 결과만 표시
  bool? _isIdAvailable; // null: 모름, false: 중복, true: 사용가능
  String? _idHelperText; // 메시지

  int? selectedGender;
  bool isPasswordVisible = false;
  bool agreedToPrivacy = false;
  bool isLoading = false;

  // 오류 메시지
  String? _idError;
  String? _passwordError;
  String? _birthdateError;
  String? _generalError;

  final storage = const FlutterSecureStorage();

  // "YYYY-MM-DD" 또는 "YYYYMMDD" 형식 + 실제 존재 날짜 검사
  final _birthdateRegexWithDash = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  final _birthdateRegexWithoutDash = RegExp(r'^\d{8}$');

  // 아이디 형식 검사: 영문, 숫자, 언더스코어만 허용 (한글 제외)
  final _idRegex = RegExp(r'^[a-zA-Z0-9_]+$');

  bool _isIdValid(String s) {
    final t = s.trim();
    return t.isNotEmpty && _idRegex.hasMatch(t);
  }

  bool _isBirthdateValid(String s) {
    final t = s.trim();

    // YYYY-MM-DD 형식 검사
    if (_birthdateRegexWithDash.hasMatch(t)) {
      final parts = t.split('-');
      final y = int.parse(parts[0]),
          m = int.parse(parts[1]),
          d = int.parse(parts[2]);
      final dt = DateTime(y, m, d);
      return dt.year == y && dt.month == m && dt.day == d;
    }

    // YYYYMMDD 형식 검사
    if (_birthdateRegexWithoutDash.hasMatch(t)) {
      final y = int.parse(t.substring(0, 4));
      final m = int.parse(t.substring(4, 6));
      final d = int.parse(t.substring(6, 8));
      final dt = DateTime(y, m, d);
      return dt.year == y && dt.month == m && dt.day == d;
    }

    return false;
  }

  // 아이디 입력 변경 시: 이전 중복 에러/메시지만 리셋
  void _onIdChanged(String value) {
    setState(() {
      // 아이디 형식 검사
      if (value.isNotEmpty && !_isIdValid(value)) {
        _idError = '영문, 숫자, 언더스코어(_)만 사용 가능합니다';
      } else {
        _idError = null;
      }

      // 이전 중복 에러/메시지 리셋
      if (_isIdAvailable == false || _idHelperText != null) {
        _isIdAvailable = null;
        _idHelperText = null;
      }
    });
  }

  // 아이디 중복 확인
  Future<void> _checkIdAvailability(String id) async {
    setState(() {
      _isIdAvailable = null;
      _idHelperText = '확인 중...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://kooala.tassoo.uk/users/all'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> users = data['data'];
          final bool isDuplicate = users.any(
            (user) =>
                user['userID'] != null &&
                user['userID'].toString().toLowerCase() == id.toLowerCase(),
          );

          setState(() {
            _isIdAvailable = !isDuplicate;
            _idHelperText = isDuplicate ? '이미 존재하는 아이디입니다' : '사용 가능한 아이디입니다';
          });
        } else {
          setState(() {
            _isIdAvailable = null;
            _idHelperText = '확인 실패';
          });
        }
      } else {
        setState(() {
          _isIdAvailable = null;
          _idHelperText = '확인 실패';
        });
      }
    } catch (e) {
      setState(() {
        _isIdAvailable = null;
        _idHelperText = '확인 실패';
      });
      // ignore: avoid_print
      print('아이디 중복 확인 실패: $e');
    }
  }

  // 비밀번호 변경 시 오류 메시지
  void _onPasswordChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = null;
      } else if (value.length < 6) {
        _passwordError = '비밀번호는 6글자 이상 입력해주세요';
      } else {
        _passwordError = null;
      }
    });
  }

  // 생년월일 변경 시 오류 메시지
  void _onBirthdateChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _birthdateError = null;
      } else if (!_isBirthdateValid(value)) {
        if (value.length == 8 && !_birthdateRegexWithoutDash.hasMatch(value)) {
          _birthdateError = 'yyyy-mm-dd 또는 yyyymmdd 형식으로 입력해주세요';
        } else if (value.length == 10 &&
            !_birthdateRegexWithDash.hasMatch(value)) {
          _birthdateError = 'yyyy-mm-dd 또는 yyyymmdd 형식으로 입력해주세요';
        } else if (value.length < 8) {
          _birthdateError = 'yyyy-mm-dd 또는 yyyymmdd 형식으로 입력해주세요';
        } else {
          _birthdateError = '올바른 생년월일을 입력해주세요';
        }
      } else {
        _birthdateError = null;
      }
    });
  }

  // 폼 유효성 검사
  String? _validateForm() {
    // 아이디
    if (idController.text.trim().isEmpty) {
      return '아이디를 입력해주세요';
    }
    if (!_isIdValid(idController.text)) {
      return '영문, 숫자, 언더스코어(_)만 사용 가능합니다';
    }
    if (_isIdAvailable == false) {
      return '이미 사용 중인 아이디입니다. 다른 아이디를 입력해주세요.';
    }
    if (_isIdAvailable == null) {
      return '아이디 중복 검사를 해주세요.';
    }

    // 생년월일
    if (birthdateController.text.trim().isEmpty) {
      return '생년월일을 입력해주세요';
    }
    if (!_isBirthdateValid(birthdateController.text)) {
      return '올바른 생년월일 형식으로 입력해주세요 (예: 1995-08-07 또는 19950807)';
    }

    // 비밀번호
    if (passwordController.text.isEmpty) {
      return '비밀번호를 입력해주세요';
    }
    if (passwordController.text.length < 6) {
      return '비밀번호는 6글자 이상 입력해주세요';
    }

    // 성별
    if (selectedGender == null) {
      return '성별을 선택해주세요';
    }

    // 개인정보 동의
    if (!agreedToPrivacy) {
      return '개인정보 처리방침에 동의해주세요';
    }

    return null;
  }

  // 시작하기 버튼 클릭
  void _onStartButtonPressed() {
    final errorMessage = _validateForm();
    if (errorMessage != null) {
      setState(() {
        _generalError = errorMessage;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _generalError = null;
          });
        }
      });
    } else {
      _handleSignUp();
    }
  }

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    birthdateController.dispose();
    genderController.dispose();
    super.dispose();
  }

  bool get isFormValid {
    return idController.text.trim().isNotEmpty &&
        _isIdValid(idController.text) &&
        passwordController.text.length >= 6 &&
        _isBirthdateValid(birthdateController.text) &&
        agreedToPrivacy;
  }

  Future<void> _showAlert(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  // 생년월일을 YYYY-MM-DD 형식으로 변환
  String _formatBirthdate(String input) {
    final trimmed = input.trim();

    // 이미 YYYY-MM-DD 형식이면 그대로 반환
    if (_birthdateRegexWithDash.hasMatch(trimmed)) {
      return trimmed;
    }

    // YYYYMMDD 형식이면 YYYY-MM-DD로 변환
    if (_birthdateRegexWithoutDash.hasMatch(trimmed)) {
      final y = trimmed.substring(0, 4);
      final m = trimmed.substring(4, 6);
      final d = trimmed.substring(6, 8);
      return '$y-$m-$d';
    }

    // 유효하지 않은 형식이면 원본 반환 (서버에서 에러 처리)
    return trimmed;
  }

  Future<void> _handleSignUp() async {
    setState(() => isLoading = true);

    try {
      final savedName = await storage.read(key: 'name') ?? '사용자';

      final response = await http.post(
        Uri.parse('https://kooala.tassoo.uk/users/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userID': idController.text.trim(),
          'name': savedName,
          'password': passwordController.text,
          'birthdate': _formatBirthdate(birthdateController.text),
          'gender': selectedGender,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final username = decoded['data']['name'];
        final token = decoded['data']['token'];
        final userId = decoded['data']['userID']?.toString();

        await storage.write(key: 'userID', value: userId);
        await storage.write(key: 'username', value: username);
        await storage.write(key: 'jwt', value: token);

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/complete');
      } else if (response.statusCode == 409) {
        if (!mounted) return;
        setState(() {
          _isIdAvailable = false;
          _idHelperText = '이미 사용 중인 아이디예요';
        });
        await _showAlert('아이디 중복', '이미 사용 중인 아이디입니다. 다른 아이디를 입력해 주세요.');
      } else {
        throw Exception('회원가입 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _getGenderText() {
    switch (selectedGender) {
      case 1:
        return '남자';
      case 2:
        return '여자';
      case 0:
        return '선택 안함';
      default:
        return '성별을 선택하고 싶지 않음';
    }
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D1E33),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in const [
                {'v': 1, 't': '남자'},
                {'v': 2, 't': '여자'},
                {'v': 0, 't': '선택 안함'},
              ])
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF6C63FF),
                  ),
                  title: Text(
                    e['t'] as String,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    setState(() {
                      selectedGender = e['v'] as int;
                      genderController.text = _getGenderText();
                    });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 뒤로가기 버튼
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 10),

              // 헤더 섹션
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '계정을 생성하세요',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1분이면 끝나요!\n편하게 시작해보세요 😊',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 회원가입 폼
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_circle,
                            color: Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "회원가입 정보",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 아이디 입력 + 중복확인
                    _buildIdField(),
                    const SizedBox(height: 16),

                    // 생년월일
                    _buildInputField(
                      controller: birthdateController,
                      hint: '생년월일 (예: 1995-08-07 또는 19950807)',
                      icon: Icons.calendar_today,

                      errorText: _birthdateError,
                      isValid: _isBirthdateValid(birthdateController.text),
                      onChanged: _onBirthdateChanged,
                    ),
                    const SizedBox(height: 16),

                    // 성별 선택(바텀시트)
                    _buildInputField(
                      controller: genderController,
                      hint: '성별 선택',
                      icon: Icons.person_outline,
                      isReadOnly: true,
                      onTap: _showGenderPicker,
                      isValid: selectedGender != null,
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호
                    _buildInputField(
                      controller: passwordController,
                      hint: '비밀번호',
                      icon: Icons.lock,
                      errorText: _passwordError,
                      helperText: _passwordError ?? '6글자 이상 입력해주세요',
                      obscureText: !isPasswordVisible,
                      isValid:
                          passwordController.text.length >= 6 &&
                          _passwordError == null,
                      onChanged: _onPasswordChanged,
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white54,
                        ),
                        onPressed:
                            () => setState(
                              () => isPasswordVisible = !isPasswordVisible,
                            ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 개인정보 동의
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E21),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color:
                              agreedToPrivacy
                                  ? const Color(0xFF4CAF50).withOpacity(0.5)
                                  : const Color(0xFF6C63FF).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: agreedToPrivacy,
                            onChanged:
                                (value) => setState(
                                  () => agreedToPrivacy = value ?? false,
                                ),
                            activeColor: const Color(0xFF4CAF50),
                            checkColor: Colors.white,
                          ),
                          Expanded(
                            child: Text(
                              '개인정보 처리방침을 읽고 동의합니다',
                              style: TextStyle(
                                color:
                                    agreedToPrivacy
                                        ? const Color(0xFF4CAF50)
                                        : Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 오류 메시지
              if (_generalError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _generalError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_generalError != null) const SizedBox(height: 20),

              // 시작하기 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !isLoading ? _onStartButtonPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                  child:
                      isLoading
                          ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            '시작하기',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 공용 입력 필드
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? helperText,
    String? errorText,
    bool? isValid,
    bool isReadOnly = false,
    VoidCallback? onTap,
    bool obscureText = false,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    final borderColor =
        (errorText != null && errorText.isNotEmpty)
            ? Colors.red
            : (isValid == true)
            ? Colors.green
            : const Color(0xFF6C63FF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: isReadOnly ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: TextField(
              controller: controller,
              readOnly: isReadOnly,
              onTap: onTap,
              showCursor: !isReadOnly ? null : false,
              enableInteractiveSelection: !isReadOnly,
              obscureText: obscureText,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: const Color(0xFF0A0E21),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color:
                        (errorText != null && errorText.isNotEmpty)
                            ? Colors.red
                            : const Color(0xFF6C63FF),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
                suffixIcon:
                    suffixIcon ??
                    (isReadOnly
                        ? const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white70,
                        )
                        : (isValid == true
                            ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            )
                            : null)),
              ),
            ),
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              helperText,
              style: TextStyle(
                color:
                    (errorText != null && errorText.isNotEmpty)
                        ? Colors.red
                        : (isValid == false)
                        ? Colors.red
                        : Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
        if (errorText != null && errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // 아이디 입력 + 중복확인 버튼
  Widget _buildIdField() {
    final bool duplicated = (_isIdAvailable == false);

    // 상태에 따른 스타일
    bool? isValid;
    String? errorMsg;

    // 아이디 형식 에러가 있으면 우선 표시
    if (_idError != null) {
      isValid = false;
      errorMsg = _idError;
    } else if (_isIdAvailable == true) {
      isValid = true;
      errorMsg = null;
    } else if (_isIdAvailable == false) {
      isValid = false;
      errorMsg = _idHelperText;
    } else {
      isValid = null;
      errorMsg = _idHelperText; // '확인 중...' 포함
    }

    return Row(
      children: [
        Expanded(
          child: _buildInputField(
            controller: idController,
            hint: '아이디',
            icon: Icons.person,
            isValid: isValid,
            errorText: errorMsg,
            onChanged: _onIdChanged,
            suffixIcon:
                duplicated
                    ? Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 16,
                      ),
                    )
                    : null,
          ),
        ),
        const SizedBox(width: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton(
            onPressed:
                idController.text.trim().isNotEmpty &&
                        _isIdValid(idController.text)
                    ? () => _checkIdAvailability(idController.text.trim())
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  idController.text.trim().isNotEmpty &&
                          _isIdValid(idController.text)
                      ? const Color(0xFF6C63FF) // 입력 있음: 파란색
                      : const Color(
                        0xFF6C63FF,
                      ).withOpacity(0.3), // 입력 없음: 흐린 파란색
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '중복 확인하기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    idController.text.trim().isNotEmpty &&
                            _isIdValid(idController.text)
                        ? Colors
                            .white // 입력 있음: 흰색
                        : Colors.white.withOpacity(0.5), // 입력 없음: 흐린 흰색
              ),
            ),
          ),
        ),
      ],
    );
  }
}
