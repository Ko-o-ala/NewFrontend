import 'dart:async';
import 'dart:typed_data';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class VoiceSocketService {
  VoiceSocketService._internal();
  static final VoiceSocketService _singleton = VoiceSocketService._internal();
  factory VoiceSocketService() => _singleton;
  static VoiceSocketService get instance => _singleton;

  IO.Socket? _socket;
  bool get isConnected => _socket?.connected == true;

  Stream<Uint8List> get audioStream => _audioCtrl.stream;

  final _assistantCtrl = StreamController<String>.broadcast();
  final _transcriptionCtrl = StreamController<String>.broadcast();
  final _audioCtrl = StreamController<Uint8List>.broadcast();

  Stream<String> get assistantStream => _assistantCtrl.stream;
  Stream<String> get transcriptionStream => _transcriptionCtrl.stream;

  void connect({required String url, Map<String, dynamic>? query}) {
    if (isConnected || _socket != null) return;

    final builder =
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableReconnection()
            .setReconnectionDelay(500)
            .disableAutoConnect();

    if (query != null && query.isNotEmpty) {
      builder.setQuery(query);
    }

    _socket = IO.io(url, builder.build());

    _socket!
      ..onConnect((_) => print('✅ socket connected'))
      ..onDisconnect((_) => print('🔌 socket disconnected'))
      ..onConnectError((e) => print('⚠️ connect error: $e'))
      ..onError((e) => print('⚠️ socket error: $e'))
      // ✅ 서버 응답 텍스트
      ..on('assistant_response', (data) {
        _assistantCtrl.add((data ?? '').toString());
      })
      // ✅ STT 변환 텍스트
      ..on('transcription', (data) {
        _transcriptionCtrl.add((data ?? '').toString());
      })
      // ✅ 여기! PCM 음성 스트림 수신 핸들러
      ..on('audio_chunk', (data) {
        if (data is List) {
          final bytes = Uint8List.fromList(data.cast<int>());
          _audioCtrl.add(bytes);
        }
      })
      ..connect();
  }

  void sendText(String text) {
    if (!isConnected) {
      print('⚠️ not connected, drop text: $text');
      return;
    }
    _socket!.emit('text_input', {'text': text});
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
