import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import 'glass.dart';
import 'nav.dart';
import 'widgets.dart';

void _toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(m),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 120),
    ));
}

Future<String?> askPlaylistName(BuildContext context) async {
  final c = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A2030),
      title: const Text('Playlist baru'),
      content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama playlist')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Buat')),
      ],
    ),
  );
  return (r == null || r.isEmpty) ? null : r;
}

Widget _sheet(Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Glass(
        radius: 32,
        blur: 24,
        strength: 1.5,
        child: SafeArea(top: false, child: child),
      ),
    );

Widget _row(IconData icon, String label, VoidCallback onTap, {Color? color}) =>
    ListTile(
      leading: Icon(icon, color: color ?? Colors.white),
      title: Text(label),
      onTap: onTap,
    );

Future<void> showSongMenu(BuildContext context, Song s,
    {VoidCallback? onRemove, String removeLabel = 'Hapus'}) {
  final p = PlayerService.i;
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _sheet(Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
        leading: Art(s.thumb, size: 46, radius: 10),
        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(s.artist, maxLines: 1),
      ),
      const Divider(height: 1, color: Colors.white24),
      _row(Icons.playlist_play_rounded, 'Putar berikutnya', () {
        Navigator.pop(ctx);
        p.playNext(s);
        _toast(context, 'Akan diputar berikutnya');
      }),
      _row(Icons.queue_music_rounded, 'Tambah ke antrean', () {
        Navigator.pop(ctx);
        p.addToQueue(s);
        _toast(context, 'Ditambahkan ke antrean');
      }),
      if (s.artistId != null)
        _row(Icons.person_rounded, 'Buka artis', () {
          Navigator.pop(ctx);
          openBrowse(context, id: s.artistId!, title: s.artist);
        }),
      if (s.albumId != null)
        _row(Icons.album_rounded, 'Buka album', () {
          Navigator.pop(ctx);
          openBrowse(context, id: s.albumId!);
        }),
      // Tombol unduh: 3 state — belum unduh / sedang unduh / sudah unduh
      AnimatedBuilder(
        animation: p,
        builder: (_, __) {
          final isDownloading = p.progress.containsKey(s.id);
          final isDownloaded = p.isDownloaded(s);
          final pct = isDownloading
              ? ' (${(p.progress[s.id]! * 100).round()}%)'
              : '';
          return _row(
            isDownloaded
                ? Icons.download_done_rounded
                : isDownloading
                    ? Icons.downloading_rounded
                    : Icons.download_rounded,
            isDownloaded
                ? 'Hapus unduhan'
                : isDownloading
                    ? 'Batalkan unduhan$pct'
                    : 'Unduh untuk offline',
            () {
              if (isDownloaded) {
                Navigator.pop(ctx);
                p.deleteDownload(s);
                _toast(context, 'Unduhan dihapus');
              } else if (isDownloading) {
                p.cancelDownload(s.id);
                _toast(context, 'Unduhan dibatalkan');
              } else {
                Navigator.pop(ctx);
                p.download(s);
                _toast(context, 'Mulai mengunduh…');
              }
            },
          );
        },
      ),
      _row(Icons.playlist_add_rounded, 'Tambah ke playlist', () {
        Navigator.pop(ctx);
        showPlaylistPicker(context, s);
      }),
      _row(p.isLiked(s) ? Icons.favorite : Icons.favorite_border,
          p.isLiked(s) ? 'Hapus dari favorit' : 'Tambah ke favorit', () {
        Navigator.pop(ctx);
        p.toggleLike(s);
      }),
      if (onRemove != null)
        _row(Icons.delete_outline_rounded, removeLabel, () {
          Navigator.pop(ctx);
          onRemove();
        }, color: const Color(0xFFFF8A8A)),
    ])),
  );
}

Future<void> showPlaylistPicker(BuildContext context, Song s) {
  final p = PlayerService.i;
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _sheet(ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
      child: AnimatedBuilder(
        animation: p,
        builder: (_, __) => ListView(shrinkWrap: true, children: [
          _row(Icons.add_rounded, 'Playlist baru', () async {
            final name = await askPlaylistName(ctx);
            if (name == null) return;
            await p.createPlaylist(name);
            await p.addToPlaylist(name, s);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) _toast(context, 'Ditambahkan ke $name');
          }),
          for (final name in p.playlists.keys)
            _row(Icons.queue_music_rounded, name, () {
              p.addToPlaylist(name, s);
              Navigator.pop(ctx);
              _toast(context, 'Ditambahkan ke $name');
            }),
        ]),
      ),
    )),
  );
}
