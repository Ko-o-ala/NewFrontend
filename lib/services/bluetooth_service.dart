import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService extends ChangeNotifier {
  BluetoothConnection? _connection;
  bool _isConnected = false;
  List<BluetoothDevice> _devicesList = [];

  bool get isConnected => _isConnected;
  List<BluetoothDevice> get devicesList => _devicesList;

  // 디바이스 검색
  Future<void> scanDevices() async {
    _devicesList.clear();

    try {
      List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      _devicesList =
          devices
              .where(
                (device) =>
                    device.name?.contains('raspberry') == true ||
                    device.name?.contains('RaspberryPi') == true,
              )
              .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('디바이스 검색 오류: $e');
    }
  }

  // 디바이스 연결
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _isConnected = true;

      // 수신 데이터 리스너 설정
      _connection!.input!.listen(
        _onDataReceived,
        onDone: () {
          _isConnected = false;
          notifyListeners();
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('연결 오류: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  // 연결 해제
  void disconnect() {
    _connection?.dispose();
    _connection = null;
    _isConnected = false;
    notifyListeners();
  }

  // 데이터 전송
  void sendMessage(Map<String, dynamic> message) {
    if (_connection != null && _isConnected) {
      try {
        String jsonString = jsonEncode(message) + '\n';
        _connection!.output.add(Uint8List.fromList(utf8.encode(jsonString)));
      } catch (e) {
        debugPrint('메시지 전송 오류: $e');
      }
    }
  }

  // LED 제어 명령 전송
  void sendLEDControl(List<int> color, double brightness) {
    Map<String, dynamic> message = {
      'type': 'led_control',
      'payload': {'color': color, 'brightness': brightness.round()},
    };
    sendMessage(message);
  }

  // 오디오 스트리밍 시작
  void startAudioStreaming() {
    Map<String, dynamic> message = {'type': 'audio_start', 'payload': {}};
    sendMessage(message);
  }

  // 오디오 스트리밍 중지
  void stopAudioStreaming() {
    Map<String, dynamic> message = {'type': 'audio_stop', 'payload': {}};
    sendMessage(message);
  }

  // 오디오 데이터 전송
  void sendAudioData(String encodedData) {
    Map<String, dynamic> message = {
      'type': 'audio_data',
      'payload': {'data': encodedData},
    };
    sendMessage(message);
  }

  // 수신 데이터 처리
  void _onDataReceived(Uint8List data) {
    try {
      String receivedString = String.fromCharCodes(data);
      Map<String, dynamic> receivedData = jsonDecode(receivedString);

      String messageType = receivedData['type'];
      if (messageType == 'audio_data') {
        // 오디오 데이터 처리 (AudioService에게 전달)
        String audioData = receivedData['payload']['data'];
        // AudioService를 통해 재생
      }
    } catch (e) {
      debugPrint('수신 데이터 처리 오류: $e');
    }
  }
}
