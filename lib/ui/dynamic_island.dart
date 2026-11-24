import 'package:flutter/material.dart';
import '../screens/now_playing.dart';
import '../services/player_service.dart';
import 'glass.dart';
import 'widgets.dart';

class DynamicIsland extends StatelessWidget {
  const DynamicIsland({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.i;
    return ValueListenableBuilder<bool>(
      valueListenable: Perf.dynamicIsland,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final song = player.current;
            if (song == null) return const SizedBox.shrink();
            final top = MediaQuery.of(context).padding.top;
            return Positioned(
              top: top + 8,
              left: 16,
              right: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: GestureDetector(
                    onTap: () => showNowPlaying(context),
                    child: Glass(
                      radius: 28,
                      blur: 20,
                      strength: 1.3,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Art(song.thumb, size: 34, radius: 17),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                              Text(player.loadingStage ?? song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white60)),
                            ],
                          ),
                        ),
                        _Control(
                          icon: Icons.skip_previous_rounded,
                          tooltip: 'Sebelumnya',
                          onPressed: player.prev,
                        ),
                        _Control(
                          icon: player.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          tooltip: player.playing ? 'Jeda' : 'Putar',
                          onPressed: player.toggle,
                        ),
                        _Control(
                          icon: Icons.skip_next_rounded,
                          tooltip: 'Berikutnya',
                          onPressed: player.next,
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 34, height: 38),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
      );
}
