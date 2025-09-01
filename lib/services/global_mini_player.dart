import 'package:flutter/material.dart';
import 'package:my_app/services/global_sound_service.dart';

class GlobalMiniPlayer extends StatelessWidget {
  GlobalMiniPlayer({Key? key}) : super(key: key);
  final GlobalSoundService service = GlobalSoundService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (_, __) {
        if (service.currentPlaying == null) return const SizedBox.shrink();
        final title = service.currentPlaying!
            .replaceAll('.mp3', '')
            .replaceAll('_', ' ');
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        service.isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        if (service.isPlaying) {
                          service.pause();
                        } else if (service.currentPlaying != null) {
                          service.player.play();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.stop_circle,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: service.stop,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
