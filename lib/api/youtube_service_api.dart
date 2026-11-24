import 'dart:convert';

import 'package:http/http.dart' as http;

/// Endpoints tambahan API YouTube milik pengguna. Katalog dan pencarian tetap
/// menggunakan API YouTube Music lama.
class YoutubeServiceApi {
  static const String _host = 'api-youtube-xs0ciety.vercel.app';
  static const Duration _streamTimeout = Duration(seconds: 3);
  static const Duration _lyricsTimeout = Duration(seconds: 5);
  static const Duration _translateTimeout = Duration(seconds: 8);

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
      '/api/Lyrics',
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
}
