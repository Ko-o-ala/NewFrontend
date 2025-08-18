import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class AudioService extends ChangeNotifier {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecording = false;
  bool _isPlaying = false;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  Function(String)? onAudioData;

  AudioService() {
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    await Permission.microphone.request();

    await _recorder!.openRecorder();
    await _player!.openPlayer();
  }

  Future<void> startRecording() async {
    if (_recorder == null || _isRecording) return;

    try {
      await _recorder!.startRecorder(
        toFile: 'audio.aac', // ✅ 파일에 저장
        codec: Codec.aacADTS,
      );

      _isRecording = true;
      notifyListeners();
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
    }
  }

  Future<void> stopRecording() async {
    if (_recorder == null || !_isRecording) return;

    try {
      final path = await _recorder!.stopRecorder();
      _isRecording = false;
      notifyListeners();

      if (path != null && onAudioData != null) {
        final fileData = await _readFileAsBytes(path);
        final encoded = base64Encode(fileData);
        onAudioData!(encoded);
      }
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
    }
  }

  Future<Uint8List> _readFileAsBytes(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }

  Future<void> playAudioData(String encodedData) async {
    if (_player == null) return;

    try {
      Uint8List audioData = base64Decode(encodedData);
      await _player!.startPlayer(
        fromDataBuffer: audioData,
        codec: Codec.pcm16,
        sampleRate: 16000,
        numChannels: 1,
      );
    } catch (e) {
      debugPrint('오디오 재생 오류: $e');
    }
  }

  // ✅ 여기 추가!
  Future<void> transcribeAudio(String encodedData) async {
    try {
      Uint8List audioData = base64Decode(encodedData);
      final file = File(
        '/tmp/audio.wav',
      ); // 임시 저장 경로 (iOS/Android는 다른 경로 써야 할 수도 있음)
      await file.writeAsBytes(audioData);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://your-stt-server.com/api/transcribe'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final result = jsonDecode(responseBody);
        final transcript = result['text'] ?? 'STT 실패';
        debugPrint('🎙️ STT 결과: $transcript');

        if (onAudioData != null) {
          onAudioData!(transcript);
        }
      } else {
        debugPrint('STT 요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('STT 처리 오류: $e');
    }
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _player?.closePlayer();

    super.dispose();
  }
}
