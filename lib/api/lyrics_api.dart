import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Teks per baris (dipakai untuk terjemahan).
  List<String> get texts =>
      synced ? lines.map((e) => e.text).toList() : plain.split('\n');

  Map<String, dynamic> toJson() => {
        'plain': plain,
        'lines': [
          for (final l in lines) {'t': l.t.inMilliseconds, 'x': l.text}
        ],
      };

  factory Lyrics.fromJson(Map<String, dynamic> j) => Lyrics([
        for (final l in (j['lines'] as List? ?? []))
          LyricLine(Duration(milliseconds: l['t']), l['x'])
      ], j['plain'] ?? '');
}

/// Lirik dari LRCLIB (gratis) + terjemahan lewat Google Translate (endpoint
/// publik tanpa key). Semua hasil disimpan di penyimpanan lokal, jadi lirik
/// lagu yang sudah pernah dibuka / diunduh tetap muncul saat offline.
class LyricsApi {
  static const languages = {
    'id': 'Indonesia',
    'en': 'English',
    'ms': 'Melayu',
    'ja': '日本語',
    'ko': '한국어',
    'es': 'Español',
    'ar': 'العربية',
  };

  static Future<String> getLang() async =>
      (await SharedPreferences.getInstance()).getString('lyr_lang') ?? 'id';

  static Future<void> setLang(String code) async =>
      (await SharedPreferences.getInstance()).setString('lyr_lang', code);

  static Future<File> _file(String name) async =>
      File('${(await getApplicationDocumentsDirectory()).path}/$name');

  // ---------- lirik ----------

  static Future<Lyrics?> fetch(Song s) async {
    try {
      final f = await _file('lyr_${s.id}.json');
      if (await f.exists()) {
        return Lyrics.fromJson(jsonDecode(await f.readAsString()));
      }
    } catch (_) {}
    final l = await _fetchNet(s);
    if (l != null) {
      try {
        await (await _file('lyr_${s.id}.json'))
            .writeAsString(jsonEncode(l.toJson()));
      } catch (_) {}
    }
    return l;
  }

  static Future<Lyrics?> _fetchNet(Song s) async {
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

  // ---------- terjemahan ----------

  /// Terjemahan per baris (indeks sama dengan Lyrics.texts). Null = gagal.
  static Future<List<String>?> translate(Song s, Lyrics l, String lang) async {
    final f = await _file('lyr_${s.id}_$lang.json');
    try {
      if (await f.exists()) {
        return List<String>.from(jsonDecode(await f.readAsString()));
      }
    } catch (_) {}

    final src = l.texts;
    final out = <String>[];
    var i = 0;
    while (i < src.length) {
      var j = i;
      var len = 0;
      while (j < src.length && len + src[j].length < 3500) {
        len += src[j].length + 1;
        j++;
      }
      if (j == i) j = i + 1;
      final part = await _translateChunk(src.sublist(i, j), lang);
      if (part == null) return null;
      out.addAll(part);
      i = j;
    }
    try {
      await f.writeAsString(jsonEncode(out));
    } catch (_) {}
    return out;
  }

  static Future<String?> _raw(String text, String lang) async {
    try {
      final r = await http.post(
        Uri.https('translate.googleapis.com', '/translate_a/single',
            {'client': 'gtx', 'sl': 'auto', 'tl': lang, 'dt': 't'}),
        body: {'q': text},
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final buf = StringBuffer();
      for (final seg in (j[0] as List)) {
        buf.write(seg[0] ?? '');
      }
      return buf.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>?> _translateChunk(
      List<String> lines, String lang) async {
    final all = await _raw(lines.join('\n'), lang);
    if (all == null) return null;
    final parts = all.split('\n');
    if (parts.length == lines.length) {
      return parts.map((e) => e.trim()).toList();
    }
    // jumlah baris tidak cocok -> terjemahkan satu-satu
    final res = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        res.add('');
        continue;
      }
      res.add((await _raw(line, lang))?.trim() ?? '');
    }
    return res;
  }

  /// Dipanggil saat unduh: simpan lirik + terjemahan bahasa pilihan.
  static Future<void> prefetch(Song s) async {
    try {
      final l = await fetch(s);
      if (l != null) await translate(s, l, await getLang());
    } catch (_) {}
  }
}
