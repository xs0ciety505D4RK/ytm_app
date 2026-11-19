import 'package:flutter/material.dart';
import '../api/ytmusic_api.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../ui/glass.dart';
import '../ui/mini_player.dart';
import '../ui/section_row.dart';
import '../ui/widgets.dart';

/// Halaman generik: artis, album, playlist, chart, kategori mood.
class DetailScreen extends StatefulWidget {
  const DetailScreen(
      {super.key, required this.browseId, this.params, this.title});
  final String browseId;
  final String? params;
  final String? title;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<Detail> _f =
      YtMusicApi.browse(widget.browseId, params: widget.params);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          bottom: false,
          child: FutureBuilder<Detail>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Column(children: [
                  _bar(widget.title ?? ''),
                  const Expanded(
                      child: Center(child: CircularProgressIndicator())),
                ]);
              }
              if (snap.hasError || snap.data == null) {
                return Column(children: [
                  _bar(widget.title ?? ''),
                  Expanded(
                    child: Center(
                      child: TextButton(
                        onPressed: () => setState(() => _f = YtMusicApi.browse(
                            widget.browseId,
                            params: widget.params)),
                        child: const Text('Gagal memuat. Coba lagi'),
                      ),
                    ),
                  ),
                ]);
              }
              return _content(snap.data!);
            },
          ),
        ),
        Positioned(
            left: 16,
            right: 16,
            bottom: bottom + 12,
            child: const MiniPlayer()),
      ]),
    );
  }

  Widget _bar(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
        child: Row(children: [
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded)),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _content(Detail d) {
    final p = PlayerService.i;
    final title = d.title.isNotEmpty ? d.title : (widget.title ?? '');
    final isArtist = widget.browseId.startsWith('UC');
    return ListView(
      padding: const EdgeInsets.only(bottom: 200),
      children: [
        _bar(''),
        if (d.thumb.isNotEmpty || d.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              if (d.thumb.isNotEmpty)
                Art(d.thumb, size: 220, radius: isArtist ? 110 : 28),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              if (d.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(d.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60)),
                ),
              if (d.songs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _pill(Icons.play_arrow_rounded, 'Putar',
                      () => p.playQueue(d.songs, 0)),
                  const SizedBox(width: 10),
                  _pill(Icons.shuffle_rounded, 'Acak', () {
                    final l = List.of(d.songs)..shuffle();
                    p.playQueue(l, 0);
                  }),
                ]),
              ],
            ]),
          ),
        const SizedBox(height: 12),
        for (int i = 0; i < d.songs.length; i++)
          SongTile(
              song: d.songs[i], onTap: () => p.playQueue(d.songs, i)),
        for (final s in d.sections) SectionRow(section: s),
        if (d.songs.isEmpty && d.sections.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
                child: Text('Tidak ada konten',
                    style: TextStyle(color: Colors.white54))),
          ),
      ],
    );
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Glass(
          radius: 24,
          strength: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
