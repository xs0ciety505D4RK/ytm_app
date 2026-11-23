import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/song.dart';

/// Fallback streaming only. YouTube Music remains the source of catalog,
/// search, playlists, and radio; this API can only resolve public SoundCloud
/// tracks to a temporary stream URL.
class SoundCloudApi {
  static final Uri _endpoint =
      Uri.parse('https://api-music-xs0ciety.vercel.app/api/sc-proxy');
  static const Duration _requestLimit = Duration(seconds: 4);

  static Future<Uri?> findStreamFor(Song song) async {
    final query = '${song.title} ${song.artist}'.trim();
    if (query.length < 2) return null;

    final search = await _get({
      'action': 'search',
      'q': query,
      'limit': '8',
    });
    final rawResults = search['results'];
    if (rawResults is! List) return null;

    final results = rawResults
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final match = _bestMatch(song, results);
    final permalink = match?['permalinkUrl']?.toString();
    if (permalink == null || permalink.isEmpty) return null;

    final metadata = await _get({
      'action': 'resolve',
      'url': permalink,
    });
    final rawStream = metadata['streamUrl']?.toString();
    if (rawStream == null || rawStream.isEmpty) return null;

    final stream = Uri.tryParse(rawStream);
    if (stream == null || stream.scheme != 'https' || !stream.hasAuthority) {
      return null;
    }
    return stream;
  }

  static Future<Map<String, dynamic>> _get(
    Map<String, String> query,
  ) async {
    final response = await http
        .get(
          _endpoint.replace(queryParameters: query),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(_requestLimit);

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['error']?.toString() : null;
      throw Exception(
        'SoundCloud API ${response.statusCode}'
        '${detail == null ? '' : ': $detail'}',
      );
    }
    if (decoded is! Map) {
      throw Exception('Respons SoundCloud API tidak valid');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Map<String, dynamic>? _bestMatch(
    Song song,
    List<Map<String, dynamic>> results,
  ) {
    final targetTitle = song.title.trim().toLowerCase();
    final targetTokens = _tokens(song.title);
    final targetArtistTokens = _tokens(song.artist);
    final targetDuration = _durationSeconds(song.duration);

    Map<String, dynamic>? best;
    var bestScore = -1.0;
    for (final candidate in results) {
      final title = candidate['title']?.toString() ?? '';
      if (title.isEmpty) continue;
      final titleLower = title.trim().toLowerCase();
      final exactTitle = targetTitle.isNotEmpty &&
          (titleLower == targetTitle ||
              titleLower.contains(targetTitle) ||
              targetTitle.contains(titleLower));
      final titleCoverage = _coverage(targetTokens, _tokens(title));
      if (!exactTitle && titleCoverage < 0.5) continue;

      final artist = candidate['artist'];
      final artistName = artist is Map
          ? (artist['username']?.toString() ?? '')
          : artist?.toString() ?? '';
      final searchableArtist = '$artistName $title';
      final artistCoverage =
          _coverage(targetArtistTokens, _tokens(searchableArtist));

      var score = (exactTitle ? 1.0 : titleCoverage) * 0.82 +
          artistCoverage * 0.16;
      final durationMs = candidate['duration'];
      if (targetDuration != null && durationMs is num && durationMs > 0) {
        final difference = (targetDuration - durationMs / 1000).abs();
        if (difference > 90 && difference > targetDuration * 0.4) continue;
        score += difference <= 20 ? 0.04 : difference <= 60 ? 0.01 : -0.12;
      }
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
  }

  static List<String> _tokens(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.length > 1 &&
          !const {'official', 'audio', 'video', 'lyrics', 'lyric', 'feat', 'ft'}
              .contains(token))
      .toSet()
      .toList();

  static double _coverage(List<String> target, List<String> candidate) {
    if (target.isEmpty) return 0;
    final candidateSet = candidate.toSet();
    final matches = target.where(candidateSet.contains).length;
    return matches / target.length;
  }

  static int? _durationSeconds(String value) {
    final parts = value.split(':').map(int.tryParse).toList();
    if (parts.isEmpty || parts.any((part) => part == null)) return null;
    var total = 0;
    for (final part in parts) {
      total = total * 60 + part!;
    }
    return total;
  }
}
