import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class LyricLine {
  final Duration t;
  final String text;
  const LyricLine(this.t, this.text);
}

class Lyrics {
  final List<LyricLine> lines; // kosong kalau tidak ada versi sinkron
  final String plain;
  const Lyrics(this.lines, this.plain);
  bool get synced => lines.isNotEmpty;
}

/// Lirik dari LRCLIB (gratis, tanpa API key).
class LyricsApi {
  static Future<Lyrics?> fetch(Song s) async {
    final title = s.title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
    for (final params in [
      {'track_name': title, 'artist_name': s.artist},
      {'q': '${s.artist} $title'},
    ]) {
      try {
        final r = await http.get(Uri.https('lrclib.net', '/api/search', params),
            headers: {'User-Agent': 'YTMGlass/1.0'});
        if (r.statusCode != 200) continue;
        final list = jsonDecode(utf8.decode(r.bodyBytes)) as List;
        if (list.isEmpty) continue;
        final withSync = list.firstWhere(
            (e) => (e['syncedLyrics'] ?? '').toString().isNotEmpty,
            orElse: () => null);
        if (withSync != null) {
          return Lyrics(_parse(withSync['syncedLyrics']),
              (withSync['plainLyrics'] ?? '').toString());
        }
        final plain = list.firstWhere(
            (e) => (e['plainLyrics'] ?? '').toString().isNotEmpty,
            orElse: () => null);
        if (plain != null) return Lyrics(const [], plain['plainLyrics']);
      } catch (_) {}
    }
    return null;
  }

  static List<LyricLine> _parse(String lrc) {
    final re = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\](.*)$');
    final out = <LyricLine>[];
    for (final line in lrc.split('\n')) {
      final m = re.firstMatch(line.trim());
      if (m == null) continue;
      final ms = (int.parse(m[1]!) * 60 + double.parse(m[2]!)) * 1000;
      out.add(LyricLine(Duration(milliseconds: ms.round()), m[3]!.trim()));
    }
    return out;
  }
}
