// lib/services/voice_socket_service.dart
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class VoiceSocketService {
  // ✅ 싱글턴
  VoiceSocketService._();
  static final VoiceSocketService instance = VoiceSocketService._();

  IO.Socket? _socket;
  bool _connected = false;
  bool get isConnected => _connected;

  // 서버 → 앱 이벤트 스트림
  final _assistantCtrl = StreamController<String>.broadcast();
  final _transcriptionCtrl = StreamController<String>.broadcast();

  Stream<String> get assistantStream => _assistantCtrl.stream;
  Stream<String> get transcriptionStream => _transcriptionCtrl.stream;

  /// 서버 연결
  void connect({required String url, Map<String, dynamic>? query}) {
    if (_connected) return;

    // ⚠️ socket_io_client 는 보통 http(s) URL을 씁니다.
    // 서버가 wss 웹소켓만 직접 노출한다면 프록시/설정 참고.
    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery(query ?? {})
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) => _connected = true)
      ..onDisconnect((_) => _connected = false)
      ..onConnectError((e) => _connected = false)
      ..onError((e) {})
      // ▼ 서버 이벤트명은 서버에 맞게 조정
      ..on('assistant_response', (data) {
        _assistantCtrl.add('${data ?? ''}');
      })
      ..on('transcription', (data) {
        _transcriptionCtrl.add('${data ?? ''}');
      })
      ..connect();
  }

  /// 텍스트 보내기 (서버 이벤트명에 맞게)
  void sendText(String text) {
    if (!_connected || _socket == null) return;
    _socket!.emit('text_input', {'text': text});
  }

  void emit(String event, dynamic data) {
    if (!_connected || _socket == null) return;
    _socket!.emit(event, data);
  }

  void dispose() {
    _assistantCtrl.close();
    _transcriptionCtrl.close();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }
}
