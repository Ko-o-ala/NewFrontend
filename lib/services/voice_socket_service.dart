// lib/services/voice_socket_service.dart
import 'dart:async';
import 'dart:convert'; // base64Decode
import 'dart:typed_data';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ServerDisconnectEvent {
  final String reason; // 'sound' | 'silent' | 기타
  final String message; // 서버가 보낸 안내 메시지
  final int? timestampMs; // (옵션) 서버 타임스탬프(ms)
  final Map<String, dynamic>? stats; // (옵션) 세션 통계

  ServerDisconnectEvent({
    required this.reason,
    required this.message,
    this.timestampMs,
    this.stats,
  });
}

/// 음성/텍스트 실시간 통신용 소켓 서비스 (Singleton)
class VoiceSocketService {
  VoiceSocketService._internal();
  static final VoiceSocketService _singleton = VoiceSocketService._internal();
  factory VoiceSocketService() => _singleton;
  static VoiceSocketService get instance => _singleton;

  IO.Socket? _socket;
  String? _connectedUrl;
  String? _jwt; // JWT 토큰 저장

  bool get isConnected => _socket?.connected == true;
  String? get connectedUrl => _connectedUrl;

  // ===== Streams =====
  // 서버가 보내는 MP3 오디오 바이트
  final _audioController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get audioStream => _audioController.stream;

  // 서버가 보내는 텍스트 응답
  final _assistantCtrl = StreamController<String>.broadcast();
  Stream<String> get assistantStream => _assistantCtrl.stream;

  // 소켓 연결 상태: true=connected, false=disconnected (연결 시도 시작 시에도 false 한 번 쏨)
  final _connCtrl = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connCtrl.stream;

  // ==== 새 스트림: 서버가 의도적으로 끊을 때 상세 이벤트 ====
  final _serverDisconnectCtrl =
      StreamController<ServerDisconnectEvent>.broadcast();
  Stream<ServerDisconnectEvent> get serverDisconnectStream =>
      _serverDisconnectCtrl.stream;

  /// 서버에 연결합니다.
  /// [url] 예) `wss://llm.tassoo.uk`
  /// [jwt] JWT 토큰 (보안을 위해 헤더로 전송)
  void connect({required String url, String? jwt}) {
    print('🔍 connect() 메서드 호출됨');
    print('   - URL: $url');
    print('   - JWT: ${jwt != null ? "있음" : "없음"}');

    // 이미 같은 URL로 연결되어 있으면 무시
    if (_socket != null && _socket!.connected && _connectedUrl == url) {
      print('🔍 이미 연결됨 - 무시');
      return;
    }

    // 기존 소켓 정리(리스너 중복 방지)
    print('🔍 _tearDownSocket() 호출 전');
    _tearDownSocket();
    print('🔍 _tearDownSocket() 호출 후');

    _connectedUrl = url;
    _jwt = jwt; // JWT 저장
    _connCtrl.add(false); // connecting/disconnected 상태 알림

    // JWT 토큰 로그 출력
    if (jwt != null && jwt.isNotEmpty) {
      print('🔑 JWT 토큰 정보:');
      print('   - 전체 길이: ${jwt.length}');
      print(
        '   - 앞 20자: ${jwt.substring(0, jwt.length > 20 ? 20 : jwt.length)}...',
      );
      print(
        '   - 뒤 10자: ...${jwt.substring(jwt.length > 10 ? jwt.length - 10 : 0)}',
      );
    } else {
      print('⚠️ JWT 토큰이 없습니다');
    }

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection() // 기본 재연결 on
          .disableAutoConnect() // 명시적 connect 호출
          .build(),
    );

    // ===== 이벤트 바인딩 =====
    _socket!
      ..onConnect((_) {
        print('🟢 socket connected: $url');
        print('📡 WebSocket 연결 성공 - authorize 이벤트로 JWT 전송 예정');
        _connCtrl.add(true);

        // 연결 후 JWT로 인증
        if (_jwt != null && _jwt!.isNotEmpty) {
          print('🔐 authorize 이벤트 전송 중...');
          print('   - 이벤트명: authorize');
          print('   - 토큰 길이: ${_jwt!.length}');
          print(
            '   - 토큰 앞 20자: ${_jwt!.substring(0, _jwt!.length > 20 ? 20 : _jwt!.length)}...',
          );

          _socket?.emit('authorize', {'token': _jwt});
          print('✅ authorize 이벤트 전송 완료');
        } else {
          print('⚠️ JWT가 없어서 authorize 이벤트를 전송하지 않습니다');
        }
      })
      ..on('connect', (_) {
        print('🟢 socket connect 이벤트 발생: $url');
        print('📡 WebSocket 연결 성공 - authorize 이벤트로 JWT 전송 예정');
        _connCtrl.add(true);

        // 연결 후 JWT로 인증
        if (_jwt != null && _jwt!.isNotEmpty) {
          print('🔐 authorize 이벤트 전송 중...');
          print('   - 이벤트명: authorize');
          print('   - 토큰 길이: ${_jwt!.length}');
          print(
            '   - 토큰 앞 20자: ${_jwt!.substring(0, _jwt!.length > 20 ? 20 : _jwt!.length)}...',
          );

          _socket?.emit('authorize', {'token': _jwt});
          print('✅ authorize 이벤트 전송 완료');
        } else {
          print('⚠️ JWT가 없어서 authorize 이벤트를 전송하지 않습니다');
        }
      })
      ..onReconnect((_) {
        print('🔄 socket reconnected');
        print('📡 WebSocket 재연결 성공 - authorize 이벤트로 JWT 전송 예정');
        _connCtrl.add(true);

        // 재연결 후에도 JWT로 인증
        if (_jwt != null && _jwt!.isNotEmpty) {
          print('🔐 재연결 후 authorize 이벤트 전송 중...');
          print('   - 이벤트명: authorize');
          print('   - 토큰 길이: ${_jwt!.length}');
          print(
            '   - 토큰 앞 20자: ${_jwt!.substring(0, _jwt!.length > 20 ? 20 : _jwt!.length)}...',
          );

          _socket?.emit('authorize', {'token': _jwt});
          print('✅ 재연결 후 authorize 이벤트 전송 완료');
        } else {
          print('⚠️ JWT가 없어서 재연결 후 authorize 이벤트를 전송하지 않습니다');
        }
      })
      ..on('reconnect', (_) {
        print('🔄 socket reconnect 이벤트 발생');
        print('📡 WebSocket 재연결 성공 - authorize 이벤트로 JWT 전송 예정');
        _connCtrl.add(true);

        // 재연결 후에도 JWT로 인증
        if (_jwt != null && _jwt!.isNotEmpty) {
          print('🔐 재연결 후 authorize 이벤트 전송 중...');
          print('   - 이벤트명: authorize');
          print('   - 토큰 길이: ${_jwt!.length}');
          print(
            '   - 토큰 앞 20자: ${_jwt!.substring(0, _jwt!.length > 20 ? 20 : _jwt!.length)}...',
          );

          _socket?.emit('authorize', {'token': _jwt});
          print('✅ 재연결 후 authorize 이벤트 전송 완료');
        } else {
          print('⚠️ JWT가 없어서 재연결 후 authorize 이벤트를 전송하지 않습니다');
        }
      })
      ..onReconnectAttempt((att) {
        print('… reconnect attempt #$att');
        _connCtrl.add(false);
      })
      ..onConnectError((e) {
        print('⛔️ socket connect_error: $e');
        _connCtrl.add(false);
      })
      ..onError((e) {
        print('⛔️ socket error: $e');
        _connCtrl.add(false);
      })
      ..onDisconnect((reason) {
        print('🔌 socket disconnected: $reason');
        _connCtrl.add(false);
      })
      // ===== 서버 이벤트: 인증 응답 =====
      ..on('auth_success', (data) {
        print('✅ JWT 인증 성공!');
        print('   - 서버 응답: $data');
        print('   - 인증 완료 - 대화 가능');
      })
      ..on('auth_failed', (data) {
        print('❌ JWT 인증 실패!');
        print('   - 서버 응답: $data');
        print('   - 연결을 끊습니다');
        _connCtrl.add(false); // 인증 실패 시 연결 끊기
      })
      // ===== 서버 이벤트: 텍스트 응답 =====
      ..on('assistant_response', (data) {
        _assistantCtrl.add(data.toString());
      })
      // ===== 서버 이벤트: 오디오(MP3) 응답 (가능성 있는 이벤트명 모두 대응) =====
      ..on('audio_response', _handleAudioEvent)
      ..on('audio', _handleAudioEvent)
      ..on('audio_chunk', _handleAudioEvent)
      ..on('mp3', _handleAudioEvent)
      ..on('mp3_chunk', _handleAudioEvent)
      // 서버에서 커스텀 종료 통지 시
      ..on('server_disconnect', (payload) {
        // payload: Map 또는 [Map, ...] 모두 대응
        Map<String, dynamic>? m;
        if (payload is Map) {
          m = Map<String, dynamic>.from(payload);
        } else if (payload is List &&
            payload.isNotEmpty &&
            payload.first is Map) {
          m = Map<String, dynamic>.from(payload.first as Map);
        }

        String reason = m?['reason']?.toString() ?? 'unknown';
        String message = m?['message']?.toString() ?? 'Server is disconnecting';
        // 서버가 timestamp / timestampMs 중 뭘 보내든 흡수
        int? _toInt(dynamic v) {
          if (v is int) return v;
          if (v is String) return int.tryParse(v);
          return null;
        }

        Map<String, dynamic>? stats;
        if (m?['session_stats'] is Map) {
          stats = Map<String, dynamic>.from(m!['session_stats']);
        }

        final int? ts = _toInt(m?['timestamp']) ?? _toInt(m?['timestampMs']);

        final evt = ServerDisconnectEvent(
          reason: reason,
          message: message,
          timestampMs: ts,
          stats: stats,
        );

        // 1) 구독자에게 먼저 알리고
        _serverDisconnectCtrl.add(evt);
        print('⚠️ server_disconnect: $m');

        // 2) UI에도 안내(선택)
        _assistantCtrl.add('⚠️ 서버 연결이 끊어졌습니다. ($reason)');

        // 3) 연결 상태 false → 소켓 종료
        _connCtrl.add(false);
        _socket?.disconnect();
      })
      // 실제 연결 시작
      ..connect();

    // 연결 후 즉시 JWT 전송 (이벤트 바인딩이 실패할 경우를 대비)
    Future.delayed(Duration(milliseconds: 100), () {
      if (_jwt != null && _jwt!.isNotEmpty) {
        print('🔐 연결 후 즉시 authorize 이벤트 전송...');
        print('   - 이벤트명: authorize');
        print('   - 토큰 길이: ${_jwt!.length}');
        print(
          '   - 토큰 앞 20자: ${_jwt!.substring(0, _jwt!.length > 20 ? 20 : _jwt!.length)}...',
        );

        _socket?.emit('authorize', {'token': _jwt});
        print('✅ 연결 후 즉시 authorize 이벤트 전송 완료');
      }
    });
  }

  /// 텍스트 전송 (사용자 발화 등)
  void sendText(String text) {
    if (!isConnected) {
      print('⚠️ sendText called while socket not connected.');
      return;
    }

    print('💬 대화 메시지 전송:');
    print('   - 이벤트명: text_input');
    print('   - 메시지: "$text"');
    print('   - 메시지 길이: ${text.length}');
    print('   - JWT 없이 전송 (이미 인증됨)');

    _socket?.emit('text_input', {'text': text});
    print('✅ 대화 메시지 전송 완료');
  }

  /// 수동 종료
  void disconnect() {
    _socket?.disconnect();
    _connCtrl.add(false);
  }

  /// 내부: 오디오 이벤트 핸들링
  void _handleAudioEvent(dynamic data) {
    try {
      final bytes = _extractBytes(data);
      if (bytes.isEmpty) {
        print('⏩ skip non-audio or empty: ${data.runtimeType}');
        return;
      }
      // 프리뷰 로그 (ID3/Frame Sync 확인용)
      final preview = bytes
          .take(8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      print('🎵 audio in: ${bytes.length} bytes [$preview]');
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
        return Uint8List(0);
      }
    }

    // 3) Map 형태: 흔한 키 처리
    if (evt is Map) {
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

  /// 수동 재연결 (대화 중단 후 재시작)
  void reconnect() {
    print('🔄 수동 재연결 시작...');
    if (_jwt != null && _jwt!.isNotEmpty && _connectedUrl != null) {
      connect(url: _connectedUrl!, jwt: _jwt);
    } else {
      print('⚠️ JWT 또는 URL이 없어서 재연결할 수 없습니다');
    }
  }

  /// 기존 소켓 리스너/리소스 정리 (중복 연결 방지)
  void _tearDownSocket() {
    try {
      _socket?.off('assistant_response');
      _socket?.off('audio_response');
      _socket?.off('audio');
      _socket?.off('audio_chunk');
      _socket?.off('mp3');
      _socket?.off('mp3_chunk');
      _socket?.off('server_disconnect');
      _socket?.off('auth_success');
      _socket?.off('auth_failed');

      _socket?.dispose();
      _jwt = null; // JWT 초기화
    } catch (_) {
      // ignore
    }
    _socket = null;
  }

  /// 앱에서 완전히 서비스 종료 시 호출
  void dispose() {
    _tearDownSocket();
    // StreamController는 싱글턴 수명과 동일하게 쓰는 경우 닫지 않는 편이 안전하지만,
    // 확실히 종료하려면 아래를 열어 사용하세요.
    // _audioController.close();
    // _assistantCtrl.close();
    // _connCtrl.close();
  }
}
