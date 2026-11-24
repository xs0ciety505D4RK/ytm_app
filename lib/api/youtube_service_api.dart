import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/song.dart';

/// Client for the user's YouTube API. Unsupported or unavailable operations
/// are handled by the existing YouTube Music client at the call site.
class YoutubeServiceApi {
  static const String _host = 'api-youtube-xs0ciety.vercel.app';
  static const Duration _searchTimeout = Duration(seconds: 5);
  static const Duration _streamTimeout = Duration(seconds: 3);
  static const Duration _lyricsTimeout = Duration(seconds: 5);
  static const Duration _translateTimeout = Duration(seconds: 8);

  static Future<List<Entry>> searchSongs(String query) async {
    final response = await _get(
      '/api/search',
      {'q': query},
      timeout: _searchTimeout,
    );
    final items = _listData(response);
    return items
        .map(_entryFromMap)
        .whereType<Entry>()
        .toList(growable: false);
  }

  static Future<List<Section>> home() async {
    final response = await _get('/api/home', const {});
    final data = response['data'];
    final rawSections = data is Map ? data['sections'] : null;
    if (rawSections is! List) return const [];

    final sections = <Section>[];
    for (final raw in rawSections.whereType<Map>()) {
      final title = _text(raw['title'] ?? raw['name']);
      final rawItems = raw['items'] ??
          raw['songs'] ??
          raw['contents'] ??
          raw['results'] ??
          raw['data'];
      if (title.isEmpty || rawItems is! List) continue;
      final entries = rawItems
          .whereType<Map>()
          .map(_entryFromMap)
          .whereType<Entry>()
          .toList(growable: false);
      if (entries.isNotEmpty) sections.add(Section(title, entries));
    }
    return sections;
  }

  static Future<Uri?> streamUri(String videoId) async {
    final response = await _get(
      '/api/stream',
      {'videoId': videoId},
      timeout: _streamTimeout,
    );
    final data = response['data'];
    if (data is! Map) return null;
    final raw = data['audioUrl']?.toString() ?? data['url']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) return null;
    return uri;
  }

  static Future<String?> lyrics(String videoId) async {
    final response = await _get(
      '/api/lyrics',
      {'videoId': videoId},
      timeout: _lyricsTimeout,
    );
    final data = response['data'];
    if (data is! Map || data['available'] == false) return null;
    final text = data['lyrics']?.toString();
    return text == null || text.trim().isEmpty ? null : text;
  }

  static Future<String?> translate(String text, String target) async {
    if (text.trim().isEmpty) return '';
    final response = await _get(
      '/api/translate',
      {'text': text, 'target': target},
      timeout: _translateTimeout,
    );
    final translated = response['translatedText']?.toString();
    return translated == null || translated.isEmpty ? null : translated;
  }

  static Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query, {
    required Duration timeout,
  }) async {
    final uri = Uri.https(_host, path, query);
    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(timeout);

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['error']?.toString() : null;
      throw Exception(
        'YouTube API ${response.statusCode}'
        '${detail == null ? '' : ': $detail'}',
      );
    }
    if (decoded is! Map || decoded['success'] == false) {
      final detail = decoded is Map ? decoded['error']?.toString() : null;
      throw Exception(detail ?? 'Respons YouTube API tidak valid');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static List<dynamic> _listData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) return data;
    if (data is Map && data['results'] is List) {
      return data['results'] as List;
    }
    if (response['results'] is List) return response['results'] as List;
    return const [];
  }

  static Entry? _entryFromMap(Map raw) {
    final id = (raw['videoId'] ?? raw['id'] ?? raw['video_id'])?.toString();
    final title = _text(raw['title'] ?? raw['name']);
    if (id == null || id.isEmpty || title.isEmpty) return null;

    final artist = _text(
      raw['artist'] ?? raw['author'] ?? raw['channel'] ?? raw['uploader'],
    );
    final duration = _duration(raw['duration'] ?? raw['durationText']);
    final thumb = _thumbnail(
      raw['thumbnail'] ??
          raw['thumb'] ??
          raw['thumbnailUrl'] ??
          raw['thumbnail_url'],
    );
    return Entry.fromSong(Song(
      id: id,
      title: title,
      artist: artist,
      thumb: thumb,
      duration: duration,
    ));
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    if (value is String || value is num) return value.toString();
    if (value is Map) {
      for (final key in ['name', 'text', 'title', 'artist']) {
        final nested = value[key];
        if (nested != null) return _text(nested);
      }
    }
    return '';
  }

  static String _duration(dynamic value) {
    if (value is String) return value;
    if (value is num && value >= 0) {
      final seconds = value.round();
      final minutes = seconds ~/ 60;
      return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
    }
    return '';
  }

  static String _thumbnail(dynamic value) {
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return _thumbnail(value.last);
    if (value is Map) {
      final url = value['url'] ?? value['src'];
      if (url is String) return url;
      for (final key in ['thumbnails', 'thumbnail']) {
        if (value[key] != null) return _thumbnail(value[key]);
      }
    }
    return '';
  }
}
