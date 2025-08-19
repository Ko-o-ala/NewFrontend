import 'dart:async';
import 'dart:typed_data';
import 'dart:convert'; // base64Decode
import 'package:socket_io_client/socket_io_client.dart' as IO;

class VoiceSocketService {
  VoiceSocketService._internal();
  static final VoiceSocketService _singleton = VoiceSocketService._internal();
  factory VoiceSocketService() => _singleton;
  static VoiceSocketService get instance => _singleton;

  IO.Socket? _socket;
  bool get isConnected => _socket?.connected == true;

  // 오디오 스트림: 항상 Uint8List로 흘려보냄
  final _audioController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get audioStream => _audioController.stream;

  final _assistantCtrl = StreamController<String>.broadcast();
  Stream<String> get assistantStream => _assistantCtrl.stream;

  void connect({required String url}) {
    // 이미 연결돼 있으면 재연결 방지
    if (_socket != null && _socket!.connected) return;

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
      ..onConnectError((e) => print('socket connect_error: $e'))
      ..onError((e) => print('socket error: $e'))
      // ====== 텍스트 응답 ======
      ..on('assistant_response', (data) {
        _assistantCtrl.add(data.toString());
      })
      // ====== 오디오 응답(여러 이벤트명 대응) ======
      ..on('audio_response', _handleAudioEvent)
      ..on('audio', _handleAudioEvent)
      ..on('audio_chunk', _handleAudioEvent)
      ..on('mp3', _handleAudioEvent)
      ..on('mp3_chunk', _handleAudioEvent)
      ..connect();
  }

  void _handleAudioEvent(dynamic data) {
    try {
      final bytes = _extractBytes(data);
      if (bytes.isEmpty) {
        print('⏩ skip non-audio or empty: ${data.runtimeType}');
        return;
      }

      // 디버깅: 길이 + 헤더 프리뷰(ID3/FF E*)
      final preview = bytes
          .take(8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      print('🎵 audio in: ${bytes.length} bytes [${preview}]');

      _audioController.add(bytes);
    } catch (e) {
      print('handleAudioEvent error: $e (${data.runtimeType})');
    }
  }

  /// 서버 페이로드를 Uint8List(MP3 바이트)로 정규화
  Uint8List _extractBytes(dynamic evt) {
    // 1) 바이트 그대로
    if (evt is Uint8List) return evt;
    if (evt is List<int>) return Uint8List.fromList(evt);

    // 2) 문자열: data URL 또는 base64
    if (evt is String) {
      final s = evt.startsWith('data:') ? evt.split(',').last : evt;
      try {
        return base64Decode(s);
      } catch (_) {
        // 혹시 그냥 텍스트면 스킵
        return Uint8List(0);
      }
    }

    // 3) Map 형태: 흔한 키 처리
    if (evt is Map) {
      // chunk_type: 'mp3_bytes', 'mp3_base64', 'pcm_bytes' 등 다양할 수 있음
      final audio = evt['audio'] ?? evt['chunk'] ?? evt['data'] ?? evt['bytes'];
      if (audio == null) return Uint8List(0);

      if (audio is Uint8List) return audio;
      if (audio is List<int>) return Uint8List.fromList(audio);

      if (audio is String) {
        final s = audio.startsWith('data:') ? audio.split(',').last : audio;
        try {
          return base64Decode(s);
        } catch (_) {
          return Uint8List(0);
        }
      }
    }

    return Uint8List(0);
  }

  void sendText(String text) {
    _socket?.emit('text_input', {"text": text});
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
