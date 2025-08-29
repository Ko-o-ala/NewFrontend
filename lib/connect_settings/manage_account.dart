import 'package:flutter/material.dart';
import 'package:my_app/user_model.dart';
import 'package:my_app/mkhome/setting_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ManageAccountPage extends StatefulWidget {
  const ManageAccountPage({super.key});

  @override
  State<ManageAccountPage> createState() => _ManageAccountPageState();
}

class _ManageAccountPageState extends State<ManageAccountPage> {
  late TextEditingController nameController;
  late TextEditingController currentPasswordController;
  late TextEditingController newPasswordController;
  late TextEditingController confirmPasswordController;

  bool isPasswordVisible = false;
  bool isNewPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;

  final storage = const FlutterSecureStorage();
  UserModel? user;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    currentPasswordController = TextEditingController();
    newPasswordController = TextEditingController();
    confirmPasswordController = TextEditingController();
    _loadUserData();
  }

  // 서버에서 사용자 정보 가져오기
  Future<void> _loadUserData() async {
    try {
      final userData = await fetchUserInfo();
      setState(() {
        nameController.text = userData.name;
        // email 필드는 API에서 제공하지 않으므로 제거
        user = userData;
      });
    } catch (e) {
      _showSnackBar('사용자 정보를 불러오는데 실패했습니다.', false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<UserModel> fetchUserInfo() async {
    try {
      final headers = await _getAuthHeaders();
      debugPrint('[PROFILE] Fetching user info with headers: $headers');

      final response = await http.get(
        Uri.parse('https://kooala.tassoo.uk/users/profile'),
        headers: headers,
      );

      debugPrint('[PROFILE] Response status: ${response.statusCode}');
      debugPrint('[PROFILE] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        debugPrint('[PROFILE] Parsed user data: $userData');

        // API 응답 구조에 맞게 수정
        if (userData['success'] == true && userData['data'] != null) {
          return UserModel.fromJson(userData['data']);
        } else {
          throw Exception('Invalid API response structure: ${response.body}');
        }
      } else {
        throw Exception(
          'Failed to fetch user profile: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[PROFILE] Error fetching user info: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await storage.read(key: 'jwt');
    if (token == null) {
      throw Exception('JWT 토큰이 없습니다.');
    }

    final cleanToken =
        token.startsWith('Bearer ') ? token.split(' ').last : token;
    return {
      'Authorization': 'Bearer $cleanToken',
      'Content-Type': 'application/json',
    };
  }

  Future<void> _saveChanges() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
    });

    try {
      final headers = await _getAuthHeaders();
      final profileData = {
        'name': nameController.text.trim(),
        // email 필드는 API에서 지원하지 않으므로 제거
      };

      // 비밀번호 변경이 요청된 경우
      if (newPasswordController.text.isNotEmpty) {
        if (newPasswordController.text != confirmPasswordController.text) {
          _showSnackBar('새 비밀번호가 일치하지 않습니다.', false);
          setState(() {
            isLoading = false;
          });
          return;
        }
        if (newPasswordController.text.length < 8) {
          _showSnackBar('비밀번호는 8자 이상이어야 합니다.', false);
          setState(() {
            isLoading = false;
          });
          return;
        }

        // 현재 비밀번호 확인
        if (currentPasswordController.text.isEmpty) {
          _showSnackBar('현재 비밀번호를 입력해주세요.', false);
          setState(() {
            isLoading = false;
          });
          return;
        }

        profileData['currentPassword'] = currentPasswordController.text;
        profileData['password'] = newPasswordController.text;
      }

      final url = Uri.parse('https://kooala.tassoo.uk/users/profile');
      final response = await http.patch(
        url,
        headers: headers,
        body: json.encode(profileData),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        _showSnackBar('프로필이 성공적으로 업데이트되었습니다.', true);

        // 비밀번호 필드 초기화
        currentPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();

        // 사용자 정보 다시 로드
        await _loadUserData();
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? '프로필 업데이트에 실패했습니다.';
        _showSnackBar(errorMessage, false);
      }
    } catch (e) {
      _showSnackBar('오류가 발생했습니다: ${e.toString()}', false);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isSuccess ? const Color(0xFF6C63FF) : Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '계정 탈퇴',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: const Text(
            '정말로 계정을 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/delete-account');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '탈퇴하기',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '프로필 수정',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1D1E33), Color(0xFF0A0E21)],
          ),
        ),
        child: FutureBuilder<UserModel>(
          future: fetchUserInfo(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              );
            }

            final user = snapshot.data!;
            nameController.text = user.name;
            // emailController.text = user.email; // This line is removed

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ListView(
                  children: [
                    // 헤더 카드
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
                      child: Row(
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
                              Icons.person,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 20),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '프로필 수정',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '계정 정보를 수정하고 관리하세요',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 기본 정보 수정 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
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
                                  color: const Color(0xFF6C63FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.edit_note,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                '기본 정보',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildEditableField(
                            "이름",
                            nameController,
                            Icons.person,
                          ),
                          const SizedBox(height: 20),
                          _buildReadOnlyField(
                            "생년월일",
                            user?.birthdate ?? '불러오는 중...',
                            Icons.calendar_today,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 비밀번호 변경 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
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
                                  color: const Color(0xFF6C63FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                '비밀번호 변경',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildPasswordField(
                            "현재 비밀번호",
                            currentPasswordController,
                            Icons.lock_outline,
                            isPasswordVisible,
                            (value) =>
                                setState(() => isPasswordVisible = value),
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            "새 비밀번호",
                            newPasswordController,
                            Icons.lock,
                            isNewPasswordVisible,
                            (value) =>
                                setState(() => isNewPasswordVisible = value),
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            "새 비밀번호 확인",
                            confirmPasswordController,
                            Icons.lock_reset,
                            isConfirmPasswordVisible,
                            (value) => setState(
                              () => isConfirmPasswordVisible = value,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0E21).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF6C63FF).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: const Color(0xFF6C63FF),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '비밀번호를 변경하려면 현재 비밀번호를 입력하고, 새 비밀번호를 두 번 입력해주세요.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 저장 버튼
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child:
                            isLoading
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  "변경사항 저장",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 탈퇴하기 버튼
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
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
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.warning,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                '계정 관리',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '계정을 완전히 삭제하고 싶으시다면 아래 버튼을 눌러주세요.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _showDeleteAccountDialog,
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.white,
                              ),
                              label: const Text(
                                '계정 탈퇴하기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade400,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E21),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6C63FF).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              hintText: label,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E21),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6C63FF).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isVisible,
    Function(bool) onVisibilityChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E21),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6C63FF).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: !isVisible,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              hintText: label,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white.withOpacity(0.7),
                ),
                onPressed: () => onVisibilityChanged(!isVisible),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
