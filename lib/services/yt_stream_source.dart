import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    show YoutubeExplode, AudioOnlyStreamInfo;

/// Cadangan kalau URL langsung ditolak (403): audio diambil lewat HTTP client
/// youtube_explode yang sudah mengurus header & throttling, lalu disuapkan
/// ke ExoPlayer lewat proxy lokal just_audio.
class YtStreamSource extends StreamAudioSource {
  YtStreamSource(this._yt, this.info);
  final YoutubeExplode _yt;
  final AudioOnlyStreamInfo info;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final total = info.size.totalBytes;
    final s = start ?? 0;
    final e = (end == null || end > total) ? total : end;
    final raw = _yt.videos.streamsClient.get(info);
    return StreamAudioResponse(
      sourceLength: total,
      contentLength: e - s,
      offset: s,
      stream: (s == 0 && e == total) ? raw : _slice(raw, s, e),
      contentType: 'audio/${info.container.name}',
    );
  }

  Stream<List<int>> _slice(Stream<List<int>> src, int start, int end) async* {
    var pos = 0;
    await for (final c in src) {
      final next = pos + c.length;
      if (next <= start) {
        pos = next;
        continue;
      }
      final from = start > pos ? start - pos : 0;
      final to = end < next ? end - pos : c.length;
      yield (from == 0 && to == c.length) ? c : c.sublist(from, to);
      pos = next;
      if (pos >= end) break;
    }
  }
}
