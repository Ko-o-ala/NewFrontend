import 'dart:async';
import 'dart:typed_data';
import 'package:socket_io_client/socket_io_client.dart' as IO;
//import 'dart:convert';
//import 'package:flutter_sound/public/flutter_sound_player.dart';
//import 'package:http/http.dart' as http;

class VoiceSocketService {
  VoiceSocketService._internal();
  static final VoiceSocketService _singleton = VoiceSocketService._internal();
  factory VoiceSocketService() => _singleton;
  static VoiceSocketService get instance => _singleton;

  IO.Socket? _socket;
  bool get isConnected => _socket?.connected == true;

  //스트림 컨트롤러(방금 추가)
  final _audioController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<String> get assistantStream => _assistantCtrl.stream;

  final _assistantCtrl = StreamController<String>.broadcast();

  void connect({required String url}) {
    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        print('socket connected');
      })
      ..on('assistant_response', (data) {
        _assistantCtrl.add(data.toString());
      })
      ..on('audio_response', (data) {
        if (data["chunk_type"] == "pcm_bytes" && data["audio"] is List) {
          final bytes = Uint8List.fromList(List<int>.from(data["audio"]));
          _audioController.add(bytes);
        }
      })
      ..connect();
  }

  void sendText(String text) {
    _socket?.emit('text_input', {"text": text}); // 👈 이벤트 이름 일치 확인!
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
