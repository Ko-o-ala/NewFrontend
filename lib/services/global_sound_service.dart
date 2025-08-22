import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class GlobalSoundService extends ChangeNotifier {
  static final GlobalSoundService _i = GlobalSoundService._internal();
  factory GlobalSoundService() => _i;
  GlobalSoundService._internal() {
    player.playerStateStream.listen((s) {
      _isPlaying = s.playing;
      if (s.processingState == ProcessingState.completed) {
        _currentPlaying = null;
      }
      notifyListeners();
    });
  }

  final AudioPlayer player = AudioPlayer();
  String? _currentPlaying;
  bool _isPlaying = false;

  String? get currentPlaying => _currentPlaying;
  bool get isPlaying => _isPlaying;

  Future<void> playAsset(String file) async {
    if (_currentPlaying == file && _isPlaying) {
      await pause();
      return;
    }
    await player.setAsset('assets/sounds/$file');
    _currentPlaying = file;
    await player.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> pause() async {
    await player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> stop() async {
    await player.stop();
    _isPlaying = false;
    _currentPlaying = null;
    notifyListeners();
  }
}
