import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../api/lyrics_api.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../ui/glass.dart';
import '../ui/song_menu.dart';
import '../ui/widgets.dart';
import '../ui/nav.dart';
import 'equalizer_sheet.dart';
import 'queue_sheet.dart';

String _fmt(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

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
                        ? LyricsView(key: ValueKey(s.id), song: s)
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
                    final dur = p.player.duration ?? Duration.zero;
                    final max = dur.inMilliseconds.toDouble();
                    return Column(children: [
                      Slider(
                        value: pos.inMilliseconds
                            .toDouble()
                            .clamp(0, max > 0 ? max : 1),
                        max: max > 0 ? max : 1,
                        onChanged: (v) =>
                            p.player.seek(Duration(milliseconds: v.toInt())),
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

class LyricsView extends StatefulWidget {
  const LyricsView({super.key, required this.song});
  final Song song;
  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  Lyrics? _l;
  bool _loading = true;
  bool _tr = false;
  bool _trLoading = false;
  bool _trFailed = false;
  List<String>? _trLines;
  String _lang = 'id';
  final _sc = ScrollController();
  int _last = -1;

  double get _h => (_tr && _trLines != null) ? 104 : 52;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _lang = await LyricsApi.getLang();
    final l = await LyricsApi.fetch(widget.song);
    if (!mounted) return;
    setState(() {
      _l = l;
      _loading = false;
    });
  }

  Future<void> _translate() async {
    final l = _l;
    if (l == null) return;
    setState(() {
      _trLoading = true;
      _trFailed = false;
      _trLines = null;
    });
    final t = await LyricsApi.translate(widget.song, l, _lang);
    if (!mounted) return;
    setState(() {
      _trLines = t;
      _trLoading = false;
      _trFailed = t == null;
    });
  }

  void _toggleTr() {
    setState(() => _tr = !_tr);
    if (_tr && _trLines == null) _translate();
  }

  Future<void> _setLang(String code) async {
    _lang = code;
    await LyricsApi.setLang(code);
    setState(() => _trLines = null);
    if (_tr) _translate();
  }

  Widget _chip(IconData icon, String label, bool active) => Glass(
        radius: 18,
        strength: active ? 2.2 : 0.9,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? Colors.white : Colors.white70),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.white70)),
        ]),
      );

  Widget _controls() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          GestureDetector(
              onTap: _toggleTr,
              child: _chip(Icons.translate_rounded, 'Terjemah', _tr)),
          if (_tr) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: _setLang,
              color: const Color(0xFF1A2030),
              itemBuilder: (_) => [
                for (final e in LyricsApi.languages.entries)
                  PopupMenuItem(value: e.key, child: Text(e.value)),
              ],
              child: _chip(Icons.language_rounded,
                  LyricsApi.languages[_lang] ?? _lang, false),
            ),
          ],
          const SizedBox(width: 10),
          if (_trLoading)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
          if (_trFailed && !_trLoading)
            const Flexible(
              child: Text('Gagal menerjemahkan (butuh internet)',
                  style: TextStyle(fontSize: 12, color: Color(0xFFFF8A8A))),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final l = _l;
    if (l == null) {
      return const Center(
          child: Text('Lirik tidak ditemukan',
              style: TextStyle(color: Colors.white60)));
    }
    return Column(children: [
      _controls(),
      Expanded(child: l.synced ? _synced(l) : _plain(l)),
    ]);
  }

  String? _trAt(int i) {
    if (!_tr || _trLines == null || i >= _trLines!.length) return null;
    final t = _trLines![i];
    return t.isEmpty ? null : t;
  }

  Widget _plain(Lyrics l) {
    final lines = l.texts;
    return ListView.builder(
      itemCount: lines.length,
      itemBuilder: (context, i) {
        final t = _trAt(i);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lines[i], style: const TextStyle(fontSize: 17, height: 1.4)),
            if (t != null)
              Text(t,
                  style: const TextStyle(
                      fontSize: 14, height: 1.3, color: Colors.white60)),
          ]),
        );
      },
    );
  }

  Widget _synced(Lyrics l) {
    return LayoutBuilder(builder: (context, c) {
      return StreamBuilder<Duration>(
        stream: PlayerService.i.player.positionStream,
        builder: (context, ps) {
          final pos = ps.data ?? Duration.zero;
          int cur = -1;
          for (int i = 0; i < l.lines.length; i++) {
            if (l.lines[i].t <= pos) cur = i;
          }
          if (cur != _last && cur >= 0) {
            _last = cur;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_sc.hasClients) return;
              _sc.animateTo(
                (cur * _h - c.maxHeight / 2 + _h / 2)
                    .clamp(0, _sc.position.maxScrollExtent),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              );
            });
          }
          return ListView.builder(
            controller: _sc,
            itemExtent: _h,
            itemCount: l.lines.length,
            itemBuilder: (context, i) {
              final t = _trAt(i);
              final active = i == cur;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => PlayerService.i.player.seek(l.lines[i].t),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: TextStyle(
                          fontSize: active ? 21 : 18,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : Colors.white38,
                        ),
                        child: Text(
                            l.lines[i].text.isEmpty ? '•' : l.lines[i].text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (t != null)
                        Text(t,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                color:
                                    active ? Colors.white70 : Colors.white30)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    });
  }
}
