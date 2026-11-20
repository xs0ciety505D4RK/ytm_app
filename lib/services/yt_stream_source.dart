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
    final raw = _yt.videos.streamsClient.get(info);

    // YouTube may omit the size. Reporting 0 bytes makes ExoPlayer treat a
    // perfectly valid response as an empty source. The underlying client also
    // starts every download at byte zero, so don't advertise Range support.
    if (total <= 0) {
      return StreamAudioResponse(
        rangeRequestsSupported: false,
        sourceLength: null,
        contentLength: null,
        offset: null,
        stream: raw,
        contentType: info.codec.toString(),
      );
    }

    return StreamAudioResponse(
      rangeRequestsSupported: false,
      sourceLength: null,
      contentLength: total,
      offset: null,
      stream: raw,
      contentType: info.codec.toString(),
    );
  }
}
