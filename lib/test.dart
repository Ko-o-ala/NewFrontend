import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class MP3TestPage extends StatefulWidget {
  const MP3TestPage({super.key});
  @override
  State<MP3TestPage> createState() => _MP3TestPageState();
}

class _MP3TestPageState extends State<MP3TestPage> {
  final AudioPlayer _player = AudioPlayer();
  static const _assetPath = 'audio/sample.mp3'; // <-- 'assets/' 빼기!

  @override
  void initState() {
    super.initState();
    _configureAudio(); // iOS/Android 라우팅 설정
    _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _configureAudio() async {
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
  }

  Future<void> _play() async {
    try {
      switch (_player.state) {
        case PlayerState.paused:
          await _player.resume();
          break;
        case PlayerState.playing:
          // 원하면 처음부터 다시
          await _player.seek(Duration.zero);
          break;
        default: // stopped, completed, idle(초기)
          await _player.play(AssetSource(_assetPath));
      }
    } catch (e) {
      debugPrint('재생 실패: $e');
    }
  }

  Future<void> _pause() async => _player.pause();
  Future<void> _stop() async => _player.stop();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(title: const Text('MP3 테스트')),
      body: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _play,
              icon: const Icon(Icons.play_arrow),
              color: color,
              iconSize: 48,
            ),
            IconButton(
              onPressed: _pause,
              icon: const Icon(Icons.pause),
              color: color,
              iconSize: 48,
            ),
            IconButton(
              onPressed: _stop,
              icon: const Icon(Icons.stop),
              color: color,
              iconSize: 48,
            ),
          ],
        ),
      ),
    );
  }
}
