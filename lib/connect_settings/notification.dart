import 'package:flutter/material.dart';

class Notice extends StatelessWidget {
  const Notice({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '이용약관/개인정보',
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
        child: SafeArea(
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
                          Icons.description,
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
                              '이용약관 및 개인정보',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '서비스 이용에 관한 중요한 정보입니다',
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

                // 이용약관 섹션
                _buildSectionCard(
                  title: '이용약관',
                  icon: Icons.gavel,
                  content: '''
이 약관은 사용자(이하 "이용자")가 서비스 제공자(이하 "개발자")가 제공하는 '수면 관리 앱'(이하 "서비스")을 이용함에 있어 필요한 권리, 의무 및 책임사항을 규정합니다.

1. 서비스 개요
• 본 서비스는 이용자의 수면 패턴, 습관, 환경 등의 데이터를 수집 및 분석하여 개인 맞춤형 수면 개선 가이드를 제공합니다.
• 본 서비스는 의료 서비스를 대신하지 않으며, 질병 진단이나 치료를 목적으로 하지 않습니다.

2. 이용자의 권리 및 의무
• 이용자는 서비스를 개인적인 비상업적 용도로만 사용할 수 있습니다.
• 이용자는 정확한 정보를 입력해야 하며, 계정 관리에 대한 모든 책임은 이용자 본인에게 있습니다.

3. 지적재산권 및 콘텐츠 정책
• 서비스에 포함된 모든 콘텐츠의 저작권은 개발자에게 있습니다.
• 이용자는 서비스 내 콘텐츠를 개인적 용도로만 사용할 수 있습니다.

4. 책임 제한
• 본 서비스는 수면 개선을 지원하는 도구로 제공됩니다.
• 실제 건강 상태에 대한 책임은 사용자 본인에게 있습니다.
• 전문적인 의료 조언을 대체하지 않습니다.
''',
                ),

                const SizedBox(height: 24),

                // 개인정보 처리방침 섹션
                _buildSectionCard(
                  title: '개인정보 처리방침',
                  icon: Icons.security,
                  content: '''
1. 수집하는 개인정보
• 수면 시간, 수면 환경, 활동 패턴 등 수면 관련 데이터
• 계정 정보 및 서비스 이용 기록

2. 개인정보의 이용 목적
• 수면 분석 및 맞춤형 기능 제공
• 서비스 개선 및 고객 지원
• 법적 의무 이행

3. 개인정보의 보호
• 수집된 개인정보는 관련 법령에 따라 안전하게 보호됩니다.
• 명시된 목적 외에는 사용되지 않습니다.
• 암호화 및 접근 제한을 통해 보안을 유지합니다.

4. 개인정보의 보유 및 파기
• 서비스 이용 기간 동안 보유합니다.
• 서비스 해지 시 즉시 파기됩니다.
• 법적 보존 의무가 있는 경우 해당 기간 동안 보관합니다.

5. 이용자의 권리
• 개인정보 열람, 정정, 삭제 요청 가능
• 개인정보 처리 중단 요청 가능
• 문의사항은 고객센터를 통해 접수
''',
                ),

                const SizedBox(height: 24),

                // 서비스 변경 및 중단 섹션
                _buildSectionCard(
                  title: '서비스 변경 및 중단',
                  icon: Icons.update,
                  content: '''
1. 서비스 변경
• 개발자는 서비스 개선 및 정책 변경을 위해 사전 공지 없이 일부 기능을 수정할 수 있습니다.
• 변경 사항은 앱 내 공지사항을 통해 공지됩니다.

2. 서비스 중단
• 정기 점검 및 긴급 점검이 필요한 경우 서비스를 일시 중단할 수 있습니다.
• 중단 사유와 예상 소요 시간을 사전에 공지합니다.

3. 약관 변경
• 약관 변경 시 변경 사항을 명시하여 공지합니다.
• 이용자가 계속 서비스를 이용하는 경우 변경된 약관에 동의한 것으로 간주됩니다.
• 중요한 변경 사항은 별도 동의를 받을 수 있습니다.
''',
                ),

                const SizedBox(height: 24),

                // 문의 및 연락처 섹션 제거됨
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
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
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
