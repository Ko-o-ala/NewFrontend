import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
const Map<String, String> usualBedtimeMap = {
  '오후 9시 이전': 'before9pm',
  '오후 9시~새벽 12시': '9to12pm',
  '새벽 12시~새벽 2시': '12to2am',
  '새벽 2시 이후': 'after2am',
};

const Map<String, String> usualWakeupTimeMap = {
  '오전 5시 이전': 'before5am',
  '오전 5시~오전 7시': '5to7am',
  '오전 7시~오전 9시': '7to9am',
  '오전 9시 이후': 'after9am',
};

const Map<String, String> dayActivityTypeMap = {
  '실내 활동': 'indoor',
  '실외 활동': 'outdoor',
  '비슷함': 'mixed',
};

const Map<String, String> morningSunlightExposureMap = {
  '거의 매일': 'daily',
  '가끔': 'sometimes',
  '거의 없음': 'rarely',
};

class HabitPage1 extends StatefulWidget {
  final VoidCallback onNext;
  const HabitPage1({Key? key, required this.onNext}) : super(key: key);

  @override
  State<HabitPage1> createState() => _HabitPage1State();
}

class _HabitPage1State extends State<HabitPage1> {
  String? usualBedTime,
      usualWakeupTime,
      dayActivityType,
      morningSunlightExposure;

  bool get isValid =>
      usualBedTime != null &&
      usualWakeupTime != null &&
      dayActivityType != null &&
      morningSunlightExposure != null;

  Widget _buildQ(
    String title,
    List<String> opts,
    String? gv,
    Function(String?) oc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        ...opts.map(
          (o) => RadioListTile(
            title: Text(o),
            value: o,
            groupValue: gv,
            onChanged: oc,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Image.asset('lib/assets/koala.png', width: 120),
              const SizedBox(height: 16),
              _buildQ(
                'Q5. 평소 취침 시간은 어떻게 되시나요?',
                ['오후 9시 이전', '오후 9시~새벽 12시', '새벽 12시~새벽 2시', '새벽 2시 이후'],
                usualBedTime,
                (v) => setState(() => usualBedTime = v),
              ),
              _buildQ(
                'Q6. 평소 기상 시간은 어떻게 되시나요?',
                ['오전 5시 이전', '오전 5시~오전 7시', '오전 7시~오전 9시', '오전 9시 이후'],
                usualWakeupTime,
                (v) => setState(() => usualWakeupTime = v),
              ),
              _buildQ(
                'Q7. 하루 중 어느 활동이 더 많은가요?',
                ['실내 활동', '실외 활동', '비슷함'],
                dayActivityType,
                (v) => setState(() => dayActivityType = v),
              ),
              _buildQ(
                'Q8. 평소 아침 햇빛을 쬐는 빈도는 어떻게 되나요?',
                ['거의 매일', '가끔', '거의 없음'],
                morningSunlightExposure,
                (v) => setState(() => morningSunlightExposure = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    isValid
                        ? () async {
                          final m = OnboardingData.answers;

                          m['usualBedtime'] = usualBedtimeMap[usualBedTime];
                          m['usualWakeupTime'] =
                              usualWakeupTimeMap[usualWakeupTime];
                          m['dayActivityType'] =
                              dayActivityTypeMap[dayActivityType];
                          m['morningSunlightExposure'] =
                              morningSunlightExposureMap[morningSunlightExposure];

                          await storage.write(
                            key: 'usualBedtime',
                            value: usualBedtimeMap[usualBedTime] ?? '',
                          );
                          await storage.write(
                            key: 'usualWakeupTime',
                            value: usualWakeupTimeMap[usualWakeupTime] ?? '',
                          );
                          await storage.write(
                            key: 'dayActivityType',
                            value: dayActivityTypeMap[dayActivityType] ?? '',
                          );
                          await storage.write(
                            key: 'morningSunlightExposure',
                            value:
                                morningSunlightExposureMap[morningSunlightExposure] ??
                                '',
                          );

                          widget.onNext();
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8183D9),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('다음', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
