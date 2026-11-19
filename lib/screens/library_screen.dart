import 'package:flutter/material.dart';
import '../api/ytmusic_api.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../ui/glass.dart';
import '../ui/settings_sheet.dart';
import '../ui/song_menu.dart';
import '../ui/widgets.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  int _tab = 0; // 0 favorit, 1 playlist, 2 unduhan, 3 riwayat
  String? _open; // nama playlist yang dibuka

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = PlayerService.i;
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: p,
        builder: (context, _) => Column(children: [
          if (_open != null) _openHeader(p) else _header(),
          Expanded(child: _open != null ? _playlistDetail(p) : _body(p)),
        ]),
      ),
    );
  }

  Widget _header() => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          child: Row(children: [
            const Expanded(
              child: Text('Koleksi',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            ),
            IconButton(
                onPressed: () => showSettings(context),
                icon: const Icon(Icons.tune_rounded)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final (i, t) in ['Favorit', 'Playlist', 'Unduhan', 'Riwayat'].indexed)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Glass(
                    radius: 20,
                    blur: 0,
                    strength: _tab == i ? 2.2 : 0.8,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    child: Text(t,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _tab == i ? Colors.white : Colors.white60)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
      ]);

  Widget _openHeader(PlayerService p) {
    final songs = p.playlists[_open] ?? [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(children: [
        IconButton(
            onPressed: () => setState(() => _open = null),
            icon: const Icon(Icons.arrow_back_ios_new_rounded)),
        Expanded(
          child: Text(_open!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ),
        IconButton(
            onPressed: songs.isEmpty ? null : () => p.playQueue(songs, 0),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 34)),
        IconButton(
            onPressed: () {
              p.deletePlaylist(_open!);
              setState(() => _open = null);
            },
            icon: const Icon(Icons.delete_outline_rounded)),
      ]),
    );
  }

  Widget _empty(String t) => Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Center(
            child: Text(t,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54))),
      );

  Widget _songList(List<Song> songs, String emptyText,
      {void Function(Song)? onRemove, String removeLabel = 'Hapus'}) {
    if (songs.isEmpty) return ListView(children: [_empty(emptyText)]);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: kBottomSpace),
      itemCount: songs.length,
      itemBuilder: (context, i) => SongTile(
        song: songs[i],
        onTap: () => PlayerService.i.playQueue(songs, i),
        onRemove: onRemove == null ? null : () => onRemove(songs[i]),
        removeLabel: removeLabel,
      ),
    );
  }

  Widget _body(PlayerService p) {
    switch (_tab) {
      case 0:
        return _songList(p.likes,
            'Belum ada lagu favorit.\nTekan ikon hati pada lagu.');
      case 2:
        return _songList(
            p.downloaded, 'Belum ada unduhan.\nBuka menu lagu → Unduh untuk offline.',
            onRemove: p.deleteDownload, removeLabel: 'Hapus unduhan');
      case 3:
        return _songList(p.history, 'Belum ada riwayat putar.');
      default:
        final names = p.playlists.keys.toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: kBottomSpace),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: GestureDetector(
                onTap: () async {
                  final n = await askPlaylistName(context);
                  if (n != null) p.createPlaylist(n);
                },
                child: const Glass(
                  radius: 22,
                  blur: 0,
                  padding: EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(Icons.add_rounded),
                    SizedBox(width: 12),
                    Text('Playlist baru',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: GestureDetector(
                onTap: _importPlaylist,
                child: const Glass(
                  radius: 22,
                  blur: 0,
                  padding: EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(Icons.link_rounded),
                    SizedBox(width: 12),
                    Text('Impor playlist dari link',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
            for (final n in names)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: GestureDetector(
                  onTap: () => setState(() => _open = n),
                  child: Glass(
                    radius: 22,
                    blur: 0,
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      Art(p.playlists[n]!.isEmpty ? '' : p.playlists[n]!.first.thumb,
                          size: 54, radius: 14),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            Text('${p.playlists[n]!.length} lagu',
                                style: const TextStyle(
                                    fontSize: 12.5, color: Colors.white60)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white54),
                    ]),
                  ),
                ),
              ),
            if (names.isEmpty) _empty('Belum ada playlist.'),
          ],
        );
    }
  }

  Future<void> _importPlaylist() async {
    final c = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        title: const Text('Impor playlist'),
        content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'Tempel link playlist (…list=PL…)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Impor')),
        ],
      ),
    );
    if (link == null || link.isEmpty || !mounted) return;
    final msg = ScaffoldMessenger.of(context);
    try {
      final d = await YtMusicApi.importPlaylist(link);
      if (d == null || d.songs.isEmpty) {
        msg.showSnackBar(const SnackBar(
            content: Text('Playlist tidak ditemukan (harus publik).')));
        return;
      }
      final name = d.title.isEmpty ? 'Playlist impor' : d.title;
      final p = PlayerService.i;
      await p.createPlaylist(name);
      for (final s in d.songs) {
        await p.addToPlaylist(name, s);
      }
      msg.showSnackBar(SnackBar(content: Text('${d.songs.length} lagu diimpor ke $name')));
    } catch (_) {
      msg.showSnackBar(const SnackBar(content: Text('Gagal impor. Cek link/koneksi.')));
    }
  }

  Widget _playlistDetail(PlayerService p) => _songList(
        p.playlists[_open] ?? [],
        'Playlist kosong.\nTambah lagu lewat menu titik tiga.',
        removeLabel: 'Hapus dari playlist',
        onRemove: (s) => p.removeFromPlaylist(_open!, s),
      );
}
