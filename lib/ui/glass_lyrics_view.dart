import 'package:flutter/material.dart';

import '../api/lyrics_api.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import 'glass.dart';

class GlassLyricsView extends StatefulWidget {
  const GlassLyricsView({super.key, required this.song});
  final Song song;

  @override
  State<GlassLyricsView> createState() => _GlassLyricsViewState();
}

class _GlassLyricsViewState extends State<GlassLyricsView> {
  Lyrics? _lyrics;
  bool _loading = true;
  bool _translated = false;
  bool _translating = false;
  String? _translationError;
  List<String>? _translation;
  String _language = 'id';
  final ScrollController _scroll = ScrollController();
  int _lastLine = -2;

  double get _rowHeight => _translated && _translation != null ? 108 : 72;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final language = await LyricsApi.getLang();
      final lyrics = await LyricsApi.fetch(widget.song);
      if (!mounted) return;
      setState(() {
        _language = language;
        _lyrics = lyrics;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _translate() async {
    final lyrics = _lyrics;
    if (lyrics == null || _translating) return;
    setState(() {
      _translating = true;
      _translationError = null;
      _translation = null;
    });
    try {
      final result = await LyricsApi.translate(widget.song, lyrics, _language);
      if (!mounted) return;
      setState(() {
        _translation = result;
        _translating = false;
        _translationError = result == null ? 'Terjemahan gagal. Coba lagi saat online.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _translating = false;
        _translationError = 'Terjemahan gagal. Coba lagi saat online.';
      });
    }
  }

  Future<void> _toggleTranslation() async {
    setState(() => _translated = !_translated);
    if (_translated && _translation == null) await _translate();
  }

  Future<void> _selectLanguage(String code) async {
    setState(() {
      _language = code;
      _translation = null;
      _translationError = null;
    });
    await LyricsApi.setLang(code);
    if (_translated) await _translate();
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => GestureDetector(
        onTap: onTap,
        child: Glass(
          radius: 20,
          blur: selected ? 12 : 0,
          strength: selected ? 1.4 : 0.7,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 16,
                color: selected ? const Color(0xFFB7D1FF) : Colors.white70),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.white70)),
          ]),
        ),
      );

  Widget _toolbar(Lyrics lyrics) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
        child: Row(children: [
          _chip(
            icon: Icons.translate_rounded,
            label: _translated ? 'Terjemahan aktif' : 'Terjemahkan',
            selected: _translated,
            onTap: _toggleTranslation,
          ),
          if (_translated) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              initialValue: _language,
              onSelected: _selectLanguage,
              color: const Color(0xFF1A2030),
              itemBuilder: (_) => [
                for (final entry in LyricsApi.languages.entries)
                  PopupMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              child: IgnorePointer(
                child: _chip(
                  icon: Icons.language_rounded,
                  label: LyricsApi.languages[_language] ?? _language,
                  selected: false,
                  onTap: () {},
                ),
              ),
            ),
          ],
          const Spacer(),
          if (_translating)
            const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_translationError != null)
            IconButton(
              tooltip: 'Coba terjemahkan lagi',
              visualDensity: VisualDensity.compact,
              onPressed: _translate,
              icon: const Icon(Icons.refresh_rounded, size: 19),
            )
          else
            Icon(
              lyrics.synced ? Icons.graphic_eq_rounded : Icons.subject_rounded,
              color: const Color(0xFFB7D1FF),
              size: 19,
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 30,
      blur: 18,
      strength: 1.15,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lyrics == null
              ? const _EmptyLyrics()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.lyrics_rounded,
                          size: 18, color: Color(0xFFB7D1FF)),
                      const SizedBox(width: 8),
                      Text(
                        _lyrics!.synced ? 'LIRIK SINKRON' : 'LIRIK',
                        style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                            color: Colors.white70),
                      ),
                      const Spacer(),
                      const Text('Ketuk baris untuk melompat',
                          style: TextStyle(fontSize: 10, color: Colors.white38)),
                    ]),
                    _toolbar(_lyrics!),
                    if (_translationError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_translationError!,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFFFA6B6))),
                      ),
                    Expanded(
                      child: _lyrics!.synced
                          ? _synced(_lyrics!)
                          : _plain(_lyrics!),
                    ),
                  ],
                ),
    );
  }

  Widget _plain(Lyrics lyrics) {
    final lines = lyrics.texts;
    if (lines.isEmpty || lines.every((line) => line.trim().isEmpty)) {
      return const _EmptyLyrics();
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: lines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final translation = _translated && _translation != null &&
                index < _translation!.length
            ? _translation![index]
            : '';
        return Glass(
          radius: 18,
          blur: 0,
          strength: 0.55,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lines[index],
                  style: const TextStyle(fontSize: 16, height: 1.35)),
              if (translation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(translation,
                    style: const TextStyle(
                        fontSize: 13, height: 1.3, color: Colors.white60)),
              ],
            ],
          ),
        );
      },
    );
  }

  int _lineAt(List<LyricLine> lines, Duration position) {
    var low = 0;
    var high = lines.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (lines[middle].t <= position) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low - 1;
  }

  Widget _synced(Lyrics lyrics) => LayoutBuilder(
        builder: (context, constraints) => StreamBuilder<Duration>(
          stream: PlayerService.i.player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final current = _lineAt(lyrics.lines, position);
            if (current != _lastLine) {
              _lastLine = current;
              if (current >= 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_scroll.hasClients) return;
                  final target = (current * _rowHeight -
                          constraints.maxHeight / 2 +
                          _rowHeight / 2)
                      .clamp(0.0, _scroll.position.maxScrollExtent);
                  _scroll.animateTo(
                    target,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                  );
                });
              }
            }
            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemExtent: _rowHeight,
              itemCount: lyrics.lines.length,
              itemBuilder: (context, index) {
                final line = lyrics.lines[index];
                final active = index == current;
                final translation = _translated && _translation != null &&
                        index < _translation!.length
                    ? _translation![index]
                    : '';
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => PlayerService.i.player.seek(line.t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0x332E5DAB)
                          : Colors.white.withValues(alpha: 0.025),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? const Color(0x667EB5FF)
                            : Colors.white.withValues(alpha: 0.045),
                      ),
                      boxShadow: active
                          ? const [
                              BoxShadow(
                                color: Color(0x222F80ED),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: TextStyle(
                              fontSize: active ? 20 : 17,
                              height: 1.2,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600,
                              color: active ? Colors.white : Colors.white54,
                            ),
                            child: Text(
                              line.text.isEmpty ? '♪' : line.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (translation.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(translation,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    height: 1.2,
                                    color: active
                                        ? Colors.white70
                                        : Colors.white38)),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class _EmptyLyrics extends StatelessWidget {
  const _EmptyLyrics();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lyrics_outlined, size: 36, color: Colors.white38),
          SizedBox(height: 10),
          Text('Lirik tidak ditemukan',
              style: TextStyle(color: Colors.white70)),
        ]),
      );
}
