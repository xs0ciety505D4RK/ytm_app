import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../screens/now_playing.dart';
import '../services/player_service.dart';
import 'glass.dart';
import 'widgets.dart';

/// Mini player (muncul kalau ada lagu). Swipe kiri/kanan = next/prev.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.i;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final s = p.current;
        if (s == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => showNowPlaying(context),
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -300) p.next();
            if (v > 300) p.prev();
          },
          child: Glass(
            radius: 30,
            blur: 22,
            strength: 1.4,
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Art(s.thumb, size: 46, radius: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(p.error ?? s.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white60)),
                  ],
                ),
              ),
              // Gunakan StreamBuilder agar spinner HANYA tampil saat loading
              // benar-benar dibutuhkan, dan berhenti begitu buffering selesai.
              StreamBuilder<PlayerState>(
                stream: p.player.playerStateStream,
                builder: (context, snap) {
                  final state = snap.data;
                  // Spinner hanya saat p.loading (stream fetch) ATAU
                  // saat buffering awal (loading), bukan saat normal buffering
                  // yang terjadi terus-menerus pada stream YouTube.
                  final busy = p.loading ||
                      (state?.processingState == ProcessingState.loading);
                  return busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5)))
                      : IconButton(
                          onPressed: p.toggle,
                          icon: Icon(
                              p.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 30));
                },
              ),
              IconButton(
                  onPressed: p.next,
                  icon: const Icon(Icons.skip_next_rounded)),
            ]),
          ),
        );
      },
    );
  }
}
