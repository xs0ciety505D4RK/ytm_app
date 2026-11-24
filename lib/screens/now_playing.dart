import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/player_service.dart';
import '../ui/glass.dart';
import '../ui/glass_lyrics_view.dart';
import '../ui/song_menu.dart';
import '../ui/widgets.dart';
import '../ui/nav.dart';
import 'equalizer_sheet.dart';
import 'queue_sheet.dart';

String _fmt(Duration d) => d.inHours > 0
    ? '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}'
    : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

void showNowPlaying(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => const NowPlaying(),
  );
}

class NowPlaying extends StatefulWidget {
  const NowPlaying({super.key});
  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> {
  bool _lyrics = false;
  static const _accent = Color(0xFF8FB8FF);

  void _sleepPicker() {
    final p = PlayerService.i;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Glass(
          radius: 32,
          blur: 24,
          strength: 1.5,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Timer tidur',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              for (final m in [15, 30, 45, 60])
                ListTile(
                  title: Text('$m menit'),
                  onTap: () {
                    p.setSleep(Duration(minutes: m));
                    Navigator.pop(ctx);
                  },
                ),
              if (p.sleepEnd != null)
                ListTile(
                  title: const Text('Matikan timer',
                      style: TextStyle(color: Color(0xFFFF8A8A))),
                  onTap: () {
                    p.setSleep(null);
                    Navigator.pop(ctx);
                  },
                ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.i;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.93,
      child: Glass(
        radius: 40,
        blur: 24,
        strength: 1.2,
        child: AnimatedBuilder(
          animation: p,
          builder: (context, _) {
            final s = p.current;
            if (s == null) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.fromLTRB(26, 12, 26, 28),
              child: Column(children: [
                Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 18),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _lyrics
                        ? GlassLyricsView(key: ValueKey(s.id), song: s)
                        : Center(
                            key: const ValueKey('art'),
                            child: AspectRatio(
                                aspectRatio: 1, child: Art(s.thumb, radius: 34)),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 21, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        GestureDetector(
                          onTap: s.artistId == null
                              ? null
                              : () {
                                  final nav = Navigator.of(context);
                                  nav.pop();
                                  pushBrowse(nav,
                                      id: s.artistId!, title: s.artist);
                                },
                          child: Text(s.artist,
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white70)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => p.toggleLike(s),
                    icon: Icon(
                        p.isLiked(s) ? Icons.favorite : Icons.favorite_border,
                        size: 28,
                        color: p.isLiked(s)
                            ? const Color(0xFFFF5C8A)
                            : Colors.white70),
                  ),
                ]),
                if (p.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(p.error!,
                        style: const TextStyle(color: Color(0xFFFF8A8A))),
                  ),
                if (p.loading && p.loadingStage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(p.loadingStage!,
                        style: const TextStyle(color: Colors.white60)),
                  ),
                StreamBuilder<Duration>(
                  stream: p.player.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final liveDuration = p.player.duration;
                    final dur = liveDuration != null && liveDuration > Duration.zero
                        ? liveDuration
                        : s.parsedDuration ?? Duration.zero;
                    final max = dur.inMilliseconds.toDouble();
                    return Column(children: [
                      Slider(
                        value: pos.inMilliseconds
                            .toDouble()
                            .clamp(0, max > 0 ? max : 1),
                        max: max > 0 ? max : 1,
                        onChanged: max > 0
                            ? (v) => p.player
                                .seek(Duration(milliseconds: v.toInt()))
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(pos),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white60)),
                            Text(_fmt(dur),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white60)),
                          ],
                        ),
                      ),
                    ]);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        onPressed: p.toggleShuffle,
                        icon: Icon(Icons.shuffle_rounded,
                            color: p.shuffle ? _accent : Colors.white60)),
                    IconButton(
                        iconSize: 40,
                        onPressed: p.prev,
                        icon: const Icon(Icons.skip_previous_rounded)),
                    StreamBuilder<PlayerState>(
                      stream: p.player.playerStateStream,
                      builder: (context, _) {
                        // PlayerService memiliki watchdog dan mematikan spinner
                        // setelah batas startup, termasuk jika native state macet.
                        final busy = p.loading;
                        return Glass(
                          radius: 40,
                          strength: 2,
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: busy
                                ? const Padding(
                                    padding: EdgeInsets.all(23),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 3))
                                : IconButton(
                                    iconSize: 42,
                                    onPressed: p.toggle,
                                    icon: Icon(p.playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded)),
                          ),
                        );
                      },
                    ),
                    IconButton(
                        iconSize: 40,
                        onPressed: p.next,
                        icon: const Icon(Icons.skip_next_rounded)),
                    IconButton(
                        onPressed: p.cycleRepeat,
                        icon: Icon(
                            p.repeat == RepeatKind.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: p.repeat == RepeatKind.off
                                ? Colors.white60
                                : _accent)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                        onPressed: () => setState(() => _lyrics = !_lyrics),
                        icon: Icon(Icons.lyrics_rounded,
                            color: _lyrics ? _accent : Colors.white70)),
                    IconButton(
                        onPressed: _sleepPicker,
                        icon: Icon(Icons.bedtime_rounded,
                            color:
                                p.sleepEnd != null ? _accent : Colors.white70)),
                    IconButton(
                        onPressed: () => showEqualizer(context),
                        icon: const Icon(Icons.equalizer_rounded,
                            color: Colors.white70)),
                    IconButton(
                        onPressed: () => showQueue(context),
                        icon: const Icon(Icons.queue_music_rounded,
                            color: Colors.white70)),
                    IconButton(
                        onPressed: () => showSongMenu(context, s),
                        icon: const Icon(Icons.more_horiz_rounded,
                            color: Colors.white70)),
                  ],
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
