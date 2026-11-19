import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

/// Opsional: URL backend Vercel. Isi lewat
/// --dart-define=BACKEND_URL=https://nama-lo.vercel.app
/// Backend hanya meneruskan + cache request; kalau gagal, app nembak langsung.
const kBackend = String.fromEnvironment('BACKEND_URL');

enum SearchKind { songs, albums, artists }

class _Runs {
  final List<String> texts;
  final String? artistId;
  final String? albumId;
  const _Runs(this.texts, this.artistId, this.albumId);
}

class YtMusicApi {
  static const _base = 'https://music.youtube.com/youtubei/v1';
  static const _key = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
  static const _filters = {
    SearchKind.songs: 'EgWKAQIIAWoMEA4QChADEAQQCRAF',
    SearchKind.albums: 'EgWKAQIYAWoMEA4QChADEAQQCRAF',
    SearchKind.artists: 'EgWKAQIgAWoMEA4QChADEAQQCRAF',
  };
  static const _types = {
    'Song', 'Video', 'Lagu', 'Album', 'Artist', 'Artis', 'Single', 'EP',
    'Playlist', 'Daftar putar'
  };

  // ================= public =================

  static Future<List<Section>> home() async {
    final j = await _post('browse', {'browseId': 'FEmusic_home'});
    final s = parseSections(j);
    if (s.isNotEmpty) return s;
    return [Section('Populer', await search('lagu populer'))];
  }

  static Future<List<Entry>> search(String q,
      {SearchKind kind = SearchKind.songs}) async {
    final j = await _post('search', {'query': q, 'params': _filters[kind]});
    return _dedupe(_collect(j, 'musicResponsiveListItemRenderer')
        .map(_entryFromListItem)
        .whereType<Entry>());
  }

  /// Halaman artis / album / playlist / chart / kategori mood.
  static Future<Detail> browse(String id, {String? params}) async {
    final j = await _post(
        'browse', {'browseId': id, if (params != null) 'params': params});

    Map<String, dynamic>? header;
    for (final k in [
      'musicImmersiveHeaderRenderer',
      'musicVisualHeaderRenderer',
      'musicDetailHeaderRenderer',
      'musicResponsiveHeaderRenderer',
      'musicEditablePlaylistDetailHeaderRenderer',
    ]) {
      final c = _collect(j, k);
      if (c.isNotEmpty) {
        header = c.first;
        break;
      }
    }
    final title = _g(header, ['title', 'runs', 0, 'text']) ?? '';
    final subRuns = _g(header, ['subtitle', 'runs']) ??
        _g(header, ['straplineTextOne', 'runs']);
    final subtitle = _runs(subRuns, filter: false).texts.join(' • ');
    final thumb = _lastThumb(_firstKey(header, 'thumbnails'));
    final fallbackArtist = _runs(subRuns).texts.isNotEmpty
        ? _runs(subRuns).texts.first
        : '';

    final songs = <Song>[];
    for (final key in ['musicShelfRenderer', 'musicPlaylistShelfRenderer']) {
      for (final shelf in _collect(j, key)) {
        for (final c in (shelf['contents'] as List? ?? [])) {
          final r = c['musicResponsiveListItemRenderer'];
          if (r == null) continue;
          final e = _entryFromListItem(r);
          var s = e?.song;
          if (s == null) continue;
          if (s.thumb.isEmpty) s = s.copyWith(thumb: thumb);
          if (s.artist.isEmpty || RegExp(r'^[\d.,]+\s*\w*$').hasMatch(s.artist)) {
            s = s.copyWith(artist: fallbackArtist);
          }
          songs.add(s);
        }
      }
    }
    final seen = <String>{};
    final uniq = songs.where((s) => seen.add(s.id)).toList();
    return Detail(title, subtitle, thumb, uniq, parseSections(j));
  }

  static Future<List<MoodTag>> moods() async {
    final j = await _post('browse', {'browseId': 'FEmusic_moods_and_genres'});
    final out = <MoodTag>[];
    for (final r in _collect(j, 'musicNavigationButtonRenderer')) {
      final t = _g(r, ['buttonText', 'runs', 0, 'text']);
      final b = _g(r, ['clickCommand', 'browseEndpoint', 'browseId']);
      if (t == null || b == null) continue;
      out.add(MoodTag(
          t, b, _g(r, ['clickCommand', 'browseEndpoint', 'params'])));
    }
    return out;
  }

  /// Lagu serupa (autoplay / radio).
  static Future<List<Song>> radio(String videoId) async {
    final j = await _post('next', {
      'videoId': videoId,
      'playlistId': 'RDAMVM$videoId',
      'isAudioOnly': true,
    });
    final out = <Song>[];
    for (final r in _collect(j, 'playlistPanelVideoRenderer')) {
      final id = r['videoId'];
      if (id == null) continue;
      final runs = _runs(_g(r, ['longBylineText', 'runs']));
      out.add(Song(
        id: id,
        title: _g(r, ['title', 'runs', 0, 'text']) ?? '',
        artist: runs.texts.isNotEmpty ? runs.texts.first : '',
        thumb: _lastThumb(_g(r, ['thumbnail', 'thumbnails'])),
        duration: _g(r, ['lengthText', 'runs', 0, 'text']) ?? '',
        artistId: runs.artistId,
        albumId: runs.albumId,
      ));
    }
    final seen = <String>{};
    return out.where((s) => seen.add(s.id)).toList();
  }

  /// Impor playlist publik dari link, mis. ...?list=PLxxxx
  static Future<Detail?> importPlaylist(String link) async {
    final m = RegExp(r'list=([\w-]+)').firstMatch(link);
    if (m == null) return null;
    return browse('VL${m[1]}');
  }

  // ================= http =================

  static Future<Map<String, dynamic>> _post(
      String endpoint, Map<String, dynamic> body) async {
    final payload = {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20261115.01.00',
          'hl': 'id',
          'gl': 'ID',
        }
      },
      ...body,
    };

    if (kBackend.isNotEmpty) {
      try {
        final b = base64Url.encode(utf8.encode(jsonEncode(payload)));
        final uri = Uri.parse('$kBackend/api/yt')
            .replace(queryParameters: {'e': endpoint, 'b': b});
        final r = await http.get(uri).timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
      } catch (_) {}
    }

    final r = await http.post(
      Uri.parse('$_base/$endpoint?prettyPrint=false&key=$_key'),
      headers: {
        'Content-Type': 'application/json',
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/',
        'User-Agent': _ua,
      },
      body: jsonEncode(payload),
    );
    if (r.statusCode != 200) {
      throw Exception('YouTube Music error ${r.statusCode}');
    }
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  // ================= parsing =================

  static dynamic _g(dynamic o, List<dynamic> path) {
    for (final p in path) {
      if (o is Map && p is String) {
        o = o[p];
      } else if (o is List && p is int && p < o.length) {
        o = o[p];
      } else {
        return null;
      }
    }
    return o;
  }

  static List<Map<String, dynamic>> _collect(dynamic node, String key) {
    final out = <Map<String, dynamic>>[];
    void walk(dynamic n) {
      if (n is Map) {
        n.forEach((k, v) {
          if (k == key && v is Map<String, dynamic>) {
            out.add(v);
          } else {
            walk(v);
          }
        });
      } else if (n is List) {
        for (final e in n) {
          walk(e);
        }
      }
    }

    walk(node);
    return out;
  }

  static dynamic _firstKey(dynamic node, String key) {
    if (node is Map) {
      if (node.containsKey(key)) return node[key];
      for (final v in node.values) {
        final r = _firstKey(v, key);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final v in node) {
        final r = _firstKey(v, key);
        if (r != null) return r;
      }
    }
    return null;
  }

  static String _hiRes(String url) {
    if (url.contains('googleusercontent') || url.contains('ggpht')) {
      return url.replaceAll(RegExp(r'=w\d+-h\d+.*$'), '=w512-h512-l90-rj');
    }
    return url;
  }

  static String _lastThumb(dynamic thumbs) {
    if (thumbs is List && thumbs.isNotEmpty) {
      return _hiRes(thumbs.last['url'] ?? '');
    }
    return '';
  }

  static _Runs _runs(dynamic runs, {bool filter = true}) {
    final texts = <String>[];
    String? artistId, albumId;
    if (runs is List) {
      for (final e in runs) {
        final t = (e['text'] ?? '').toString();
        final bid =
            _g(e, ['navigationEndpoint', 'browseEndpoint', 'browseId'])
                ?.toString();
        if (bid != null) {
          if (bid.startsWith('UC')) {
            artistId ??= bid;
          } else if (bid.startsWith('MPREb')) {
            albumId ??= bid;
          }
        }
        if (t.trim().isEmpty || t.trim() == '•') continue;
        if (filter && _types.contains(t)) continue;
        texts.add(t);
      }
    }
    return _Runs(texts, artistId, albumId);
  }

  static Song _songFromListItem(Map<String, dynamic> r, String id) {
    const col = 'musicResponsiveListItemFlexColumnRenderer';
    final runs = _runs(_g(r, ['flexColumns', 1, col, 'text', 'runs']));
    final last = runs.texts.isNotEmpty ? runs.texts.last : '';
    return Song(
      id: id,
      title: _g(r, ['flexColumns', 0, col, 'text', 'runs', 0, 'text']) ?? '',
      artist: runs.texts.isNotEmpty ? runs.texts.first : '',
      thumb: _lastThumb(_g(r, [
        'thumbnail',
        'musicThumbnailRenderer',
        'thumbnail',
        'thumbnails'
      ])),
      duration: RegExp(r'^\d+:\d+').hasMatch(last) ? last : '',
      artistId: runs.artistId,
      albumId: runs.albumId,
    );
  }

  static Entry? _entryFromListItem(Map<String, dynamic> r) {
    const col = 'musicResponsiveListItemFlexColumnRenderer';
    final id = _g(r, ['playlistItemData', 'videoId']) ??
        _g(r, [
          'overlay',
          'musicItemThumbnailOverlayRenderer',
          'content',
          'musicPlayButtonRenderer',
          'playNavigationEndpoint',
          'watchEndpoint',
          'videoId'
        ]);
    if (id != null) return Entry.fromSong(_songFromListItem(r, id));

    final bid = _g(r, ['navigationEndpoint', 'browseEndpoint', 'browseId']);
    if (bid == null) return null;
    final runs =
        _runs(_g(r, ['flexColumns', 1, col, 'text', 'runs']), filter: false);
    return Entry(
      title: _g(r, ['flexColumns', 0, col, 'text', 'runs', 0, 'text']) ?? '',
      subtitle: runs.texts.join(' • '),
      thumb: _lastThumb(_g(r, [
        'thumbnail',
        'musicThumbnailRenderer',
        'thumbnail',
        'thumbnails'
      ])),
      browseId: bid,
      params: _g(r, ['navigationEndpoint', 'browseEndpoint', 'params']),
    );
  }

  static Entry? _entryFromTwoRow(Map<String, dynamic> r) {
    final ne = r['navigationEndpoint'];
    final vid = _g(ne, ['watchEndpoint', 'videoId']);
    final title = _g(r, ['title', 'runs', 0, 'text']) ?? '';
    final thumb = _lastThumb(_g(r, [
      'thumbnailRenderer',
      'musicThumbnailRenderer',
      'thumbnail',
      'thumbnails'
    ]));
    final runs = _runs(_g(r, ['subtitle', 'runs']), filter: vid != null);
    if (vid != null) {
      return Entry.fromSong(Song(
        id: vid,
        title: title,
        artist: runs.texts.isNotEmpty ? runs.texts.first : '',
        thumb: thumb,
        artistId: runs.artistId,
        albumId: runs.albumId,
      ));
    }
    String? bid = _g(ne, ['browseEndpoint', 'browseId']);
    final params = _g(ne, ['browseEndpoint', 'params']);
    if (bid == null) {
      final pl = _g(ne, ['watchPlaylistEndpoint', 'playlistId']);
      if (pl != null) bid = 'VL$pl';
    }
    if (bid == null) return null;
    return Entry(
        title: title,
        subtitle: runs.texts.join(' • '),
        thumb: thumb,
        browseId: bid,
        params: params);
  }

  static List<Entry> _dedupe(Iterable<Entry> items) {
    final seen = <String>{};
    return items.where((e) => seen.add(e.key)).toList();
  }

  /// Semua carousel (baris kartu) di satu halaman.
  static List<Section> parseSections(Map<String, dynamic> j) {
    final out = <Section>[];
    for (final shelf in _collect(j, 'musicCarouselShelfRenderer')) {
      final title = _g(shelf, [
            'header',
            'musicCarouselShelfBasicHeaderRenderer',
            'title',
            'runs',
            0,
            'text'
          ]) ??
          '';
      final entries = <Entry>[];
      for (final c in (shelf['contents'] as List? ?? [])) {
        final two = c['musicTwoRowItemRenderer'];
        final row = c['musicResponsiveListItemRenderer'];
        final e = two != null
            ? _entryFromTwoRow(two)
            : row != null
                ? _entryFromListItem(row)
                : null;
        if (e != null) entries.add(e);
      }
      if (entries.isNotEmpty && title.toString().isNotEmpty) {
        out.add(Section(title, _dedupe(entries)));
      }
    }
    return out;
  }
}
