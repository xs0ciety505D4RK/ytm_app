import 'package:flutter/material.dart';
import '../models/song.dart';
import '../screens/detail_screen.dart';
import '../services/player_service.dart';

void pushBrowse(NavigatorState nav,
    {required String id, String? params, String? title}) {
  nav.push(MaterialPageRoute(
    builder: (_) => DetailScreen(browseId: id, params: params, title: title),
  ));
}

void openBrowse(BuildContext c,
        {required String id, String? params, String? title}) =>
    pushBrowse(Navigator.of(c), id: id, params: params, title: title);

/// Lagu -> putar (dengan antrean = lagu-lagu satu baris). Lainnya -> buka halaman.
void openEntry(BuildContext c, Entry e, List<Song> queue) {
  final s = e.song;
  if (s != null) {
    final i = queue.indexWhere((x) => x.id == s.id);
    PlayerService.i.playQueue(i < 0 ? [s] : queue, i < 0 ? 0 : i);
  } else if (e.browseId != null) {
    openBrowse(c, id: e.browseId!, params: e.params, title: e.title);
  }
}
