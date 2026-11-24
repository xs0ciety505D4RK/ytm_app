import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    show YoutubeExplode, YoutubeApiClient, AudioOnlyStreamInfo;
import '../api/lyrics_api.dart';
import '../api/ytmusic_api.dart';
import '../api/youtube_service_api.dart';
import '../models/song.dart';
import 'music_handler.dart';
import 'yt_stream_source.dart';

enum RepeatKind { off, all, one }

class _ResolveResult {
  const _ResolveResult({
    required this.kind,
    this.uri,
    this.streams,
    this.error,
  });

  final String kind;
  final Uri? uri;
  final List<AudioOnlyStreamInfo>? streams;
  final Object? error;
}

class PlayerService extends ChangeNotifier {
  PlayerService._();
  static final PlayerService i = PlayerService._();
  static const Duration _startupLimit = Duration(seconds: 18);
  static const Duration _manifestLimit = Duration(seconds: 6);
  static const Duration _youtubePhaseLimit = Duration(seconds: 5);

  final AndroidEqualizer eq = AndroidEqualizer();
  final AndroidLoudnessEnhancer loud = AndroidLoudnessEnhancer();
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [eq, loud]),
  );
  final YoutubeExplode _yt = YoutubeExplode();
  final Random _rnd = Random();
  late final MusicHandler _handler;

  /// URL cover lagu aktif (latar belakang hanya mendengarkan ini).
  final ValueNotifier<String?> art = ValueNotifier(null);

  // antrean
  List<Song> queue = [];
  int index = -1;
  final List<int> _stack = [];
  bool shuffle = false;
  RepeatKind repeat = RepeatKind.off;
  bool loading = false;
  String? loadingStage;
  String? error;
  int _req = 0;
  bool _advancing = false;
  int _proxyRecoveryReq = -1;

  // koleksi
  List<Song> likes = [];
  List<Song> history = [];
  Map<String, List<Song>> playlists = {};

  // unduhan (offline)
  List<Song> downloaded = [];
  Map<String, String> downloadPaths = {};
  final Map<String, double> progress = {};
  // Untuk membatalkan unduhan
  final Map<String, bool> _cancelDownload = {};

  // sleep timer
  Timer? _sleep;
  DateTime? sleepEnd;

  AudioPlayer get player => _player;
  bool get playing => _player.playing;
  Song? get current =>
      (index >= 0 && index < queue.length) ? queue[index] : null;

  Future<void> init() async {
    _handler = await AudioService.init(
      builder: () => MusicHandler(
        _player,
        onNext: () => next(),
        onPrev: () => prev(),
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.glass.ytm_glass.audio',
        androidNotificationChannelName: 'Pemutar musik',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
      ),
    );
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && !_advancing) {
        _advancing = true;
        next(auto: true).whenComplete(() => _advancing = false);
      }
      notifyListeners();
    });
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        if (kBackend.isEmpty ||
            loading ||
            current == null ||
            _proxyRecoveryReq == _req) {
          return;
        }
        final req = _req;
        _proxyRecoveryReq = req;
        unawaited(_recoverWithAudioProxy(req));
      },
    );
    _player.durationStream.listen((d) {
      final s = current;
      if (s != null && d != null) _handler.mediaItem.add(_item(s, d));
    });
    await _load();
  }

  MediaItem _item(Song s, [Duration? d]) => MediaItem(
        id: s.id,
        title: s.title,
        artist: s.artist,
        artUri: s.thumb.isEmpty ? null : Uri.parse(s.thumb),
        duration: d ?? s.parsedDuration,
      );

  Future<void> _refreshDuration(Song song, int req) async {
    if (song.parsedDuration != null) return;
    try {
      final video = await _yt.videos.get(song.id).timeout(
            const Duration(seconds: 5),
          );
      final duration = video.duration;
      if (duration == null || req != _req || current?.id != song.id) return;
      final formatted = duration.inHours > 0
          ? '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}'
          : '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      final updated = song.copyWith(duration: formatted);
      queue[index] = updated;
      _handler.mediaItem.add(_item(updated, duration));
      notifyListeners();
    } catch (e) {
      debugPrint('[PlayerService] metadata duration gagal: ${_short(e)}');
    }
  }

  // ---------- stream YouTube ----------

  /// Coba beberapa klien sampai ada yang mengembalikan stream audio.
  static const YoutubeApiClient _ytMusicPlayer = YoutubeApiClient(
    {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20261115.01.00',
          'userAgent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
          'hl': 'id',
          'gl': 'ID',
        }
      }
    },
    'https://music.youtube.com/youtubei/v1/player?key='
        'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30&prettyPrint=false',
    headers: {
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/',
    },
  );

  Future<List<AudioOnlyStreamInfo>> _streams(String id,
      {void Function(String stage)? onStage, Stopwatch? startup}) async {
    Object? last;
    final overall = startup ?? (Stopwatch()..start());
    final manifestStarted = Stopwatch()..start();
    // Keep YouTube Music browse/search unchanged. Try its player client first,
    // then Music Android and SDK-less Android before the generic fallbacks.
    final attempts = <MapEntry<String, List<YoutubeApiClient>>>[
      MapEntry('YouTube Music WEB_REMIX', [_ytMusicPlayer]),
      MapEntry('YouTube Music Android', [YoutubeApiClient.androidMusic]),
      MapEntry('Android SDK-less', [YoutubeApiClient.androidSdkless]),
      MapEntry('Android VR', [YoutubeApiClient.androidVr]),
      MapEntry('TV', [YoutubeApiClient.tv]),
    ];
    for (final attempt in attempts) {
      final totalRemaining = _startupLimit - overall.elapsed;
      final manifestRemaining = _manifestLimit - manifestStarted.elapsed;
      final remaining = totalRemaining.compareTo(manifestRemaining) < 0
          ? totalRemaining
          : manifestRemaining;
      if (remaining <= Duration.zero) break;
      const perClientLimit = Duration(seconds: 3);
      final timeout = remaining.compareTo(perClientLimit) < 0
          ? remaining
          : perClientLimit;
      onStage?.call('Mencari stream audio (${attempt.key})...');
      try {
        final m = await _yt.videos.streamsClient
            .getManifest(id, ytClients: attempt.value)
            .timeout(timeout);
        final l = m.audioOnly.toList();
        if (l.isNotEmpty) {
          l.sort((a, b) {
            final byCompatibility =
                _streamCompatibility(a).compareTo(_streamCompatibility(b));
            if (byCompatibility != 0) return byCompatibility;
            return b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond);
          });
          return l;
        }
      } catch (e) {
        last = e;
        debugPrint(
          '[PlayerService] manifest ${attempt.key} gagal: ${_short(e)}',
        );
        // Future.timeout does not cancel the request. The shared six-second
        // manifest budget still allows one fast fallback client without
        // letting a stalled client keep the user waiting for a full minute.
      }
    }
    throw last ?? Exception('Tidak ada stream audio');
  }

  int _streamCompatibility(AudioOnlyStreamInfo info) {
    final codec = '${info.audioCodec} ${info.container.name}'.toLowerCase();
    if (codec.contains('aac') ||
        codec.contains('mp4a') ||
        codec.contains('mp4')) {
      return 0;
    }
    if (codec.contains('opus')) return 1;
    return 2;
  }

  String _short(Object e) {
    final t = e.toString().replaceAll('\n', ' ').trim();
    final reason = RegExp(r'Reason:\s*(.+)$').firstMatch(t)?.group(1);
    final message = reason == null || reason.isEmpty
        ? t
        : 'YouTube: $reason';
    return message.length > 180 ? '${message.substring(0, 180)}…' : message;
  }

  void _setLoadingStage(int req, String stage) {
    if (req != _req) return;
    loadingStage = stage;
    notifyListeners();
  }

  Duration _stageTimeout(Stopwatch started, Duration requested,
      {Duration limit = _startupLimit}) {
    final remaining = limit - started.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException(
        'Startup audio melewati ${limit.inSeconds} detik',
        limit,
      );
    }
    return remaining.compareTo(requested) < 0 ? remaining : requested;
  }

  Future<void> _prepareAndStart(
    AudioSource source, {
    required int req,
    required Stopwatch started,
    required String label,
    Duration limit = _startupLimit,
  }) async {
    _setLoadingStage(req, 'Membuka sumber audio ($label)...');
    try {
      await _player
          .stop()
          .timeout(_stageTimeout(started, const Duration(seconds: 1),
              limit: limit));
    } catch (_) {}
    if (req != _req) return;
    await _player
        .setAudioSource(source)
        .timeout(_stageTimeout(started, const Duration(seconds: 5),
            limit: limit));
    if (req != _req) return;

    _setLoadingStage(req, 'Menunggu audio mulai...');
    unawaited(_player.play());
    await _player.positionStream
        .firstWhere((position) => position > Duration.zero)
        .timeout(_stageTimeout(started, const Duration(seconds: 5),
            limit: limit));
    if (req != _req) return;
  }

  Uri _audioProxyUri(Uri source) {
    final base = kBackend.replaceFirst(RegExp(r'/+$'), '');
    final encoded = base64Url
        .encode(utf8.encode(source.toString()))
        .replaceAll('=', '');
    return Uri.parse('$base/api/audio?u=$encoded');
  }

  Future<void> _recoverWithAudioProxy(int req) async {
    if (req != _req || kBackend.isEmpty || current == null) return;
    final song = current!;
    try {
        final streams = await _streams(song.id);
      for (final info in streams.take(2)) {
        if (req != _req) return;
        try {
          await _player.stop().timeout(const Duration(seconds: 1));
          await _player.setAudioSource(
            AudioSource.uri(_audioProxyUri(info.url)),
          ).timeout(const Duration(seconds: 4));
          if (req != _req) return;
          unawaited(_player.play());
          return;
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ---------- pemutaran ----------

  Future<void> playQueue(List<Song> q, int i) async {
    queue = List.of(q);
    _stack.clear();
    await _playIndex(i);
  }

  Future<void> _playIndex(int i) async {
    if (i < 0 || i >= queue.length) return;
    final req = ++_req;
    index = i;
    final song = queue[i];
    loading = true;
    loadingStage = 'Menyiapkan audio...';
    error = null;
    _proxyRecoveryReq = -1;
    art.value = song.thumb;
    _handler.mediaItem.add(_item(song));
    _pushHistory(song);
    notifyListeners();
    final started = Stopwatch()..start();
    try {
      final local = downloadPaths[song.id];
      if (local != null && File(local).existsSync()) {
        await _prepareAndStart(
          AudioSource.uri(Uri.file(local)),
          req: req,
          started: started,
          label: 'unduhan lokal',
        );
      } else {
        Object? last;
        var opened = false;
        _setLoadingStage(req, 'Mencari sumber audio tercepat...');
        final pending = <String, Future<_ResolveResult>>{
          'api': () async {
            try {
              final uri = await YoutubeServiceApi.streamUri(song.id).timeout(
                _stageTimeout(started, const Duration(seconds: 3)),
              );
              return _ResolveResult(
                kind: 'api',
                uri: uri,
                error: uri == null
                    ? Exception('API tidak mengirim URL stream')
                    : null,
              );
            } catch (e) {
              return _ResolveResult(kind: 'api', error: e);
            }
          }(),
          'youtube': () async {
            try {
              final streams = await _streams(
                song.id,
                onStage: (stage) => _setLoadingStage(req, stage),
                startup: started,
              );
              return _ResolveResult(kind: 'youtube', streams: streams);
            } catch (e) {
              return _ResolveResult(kind: 'youtube', error: e);
            }
          }(),
        };

        while (pending.isNotEmpty && !opened && req == _req &&
            started.elapsed < _startupLimit) {
          final result = await Future.any(pending.values).timeout(
            _stageTimeout(started, const Duration(seconds: 7)),
          );
          pending.remove(result.kind);
          if (result.error != null) {
            last = result.error;
            debugPrint(
                '[PlayerService] resolver ${result.kind} gagal: ${_short(result.error!)}');
            continue;
          }

          if (result.uri != null) {
            try {
              await _prepareAndStart(
                AudioSource.uri(result.uri!),
                req: req,
                started: started,
                label: 'API YouTube baru',
                limit: _youtubePhaseLimit,
              );
              opened = true;
            } catch (e) {
              last = e;
              debugPrint('[PlayerService] API YouTube baru gagal: ${_short(e)}');
            }
            continue;
          }

          for (final info in (result.streams ?? const <AudioOnlyStreamInfo>[])
              .take(2)) {
            final sources = <MapEntry<String, AudioSource>>[
              MapEntry('langsung', AudioSource.uri(info.url)),
              MapEntry('cadangan', YtStreamSource(_yt, info)),
              if (kBackend.isNotEmpty)
                MapEntry('relay', AudioSource.uri(_audioProxyUri(info.url))),
            ];
            for (final candidate in sources) {
              if (req != _req || started.elapsed >= _startupLimit) break;
              try {
                await _prepareAndStart(
                  candidate.value,
                  req: req,
                  started: started,
                  label: candidate.key,
                );
                opened = true;
                break;
              } catch (e) {
                last = e;
                debugPrint(
                  '[PlayerService] ${candidate.key} gagal; '
                  'itag=${info.tag} ${info.container.name}/${info.audioCodec}: ${_short(e)}',
                );
                if (req == _req && started.elapsed < _startupLimit) {
                  try {
                    await _player.stop().timeout(const Duration(seconds: 1));
                  } catch (_) {}
                }
              }
            }
            if (opened || started.elapsed >= _startupLimit) break;
          }
        }
        if (!opened) throw last ?? Exception('Semua sumber audio gagal dibuka');
      }
      if (req == _req && current?.parsedDuration == null) {
        unawaited(_refreshDuration(song, req));
      }
    } catch (e) {
      if (req == _req) {
        try {
          if (started.elapsed < _startupLimit) {
            await _player.stop().timeout(const Duration(seconds: 1));
          }
        } catch (_) {}
        error = e is TimeoutException
            ? 'Gagal memutar: waktu habis pada ${loadingStage ?? 'audio'}.'
            : 'Gagal memutar: ${_short(e)}';
      }
    }
    if (req == _req) {
      loading = false;
      loadingStage = null;
    }
    notifyListeners();
  }

  Future<void> jumpTo(int i) async {
    _stack.add(index);
    await _playIndex(i);
  }

  Future<void> toggle() async {
    if (error != null && current != null) {
      await _playIndex(index); // coba lagi
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> next({bool auto = false}) async {
    if (queue.isEmpty) return;
    if (auto && repeat == RepeatKind.one) {
      await _player.seek(Duration.zero);
      _player.play();
      return;
    }
    int n;
    if (shuffle && queue.length > 1) {
      do {
        n = _rnd.nextInt(queue.length);
      } while (n == index);
    } else {
      n = index + 1;
    }
    if (n >= queue.length) {
      if (repeat == RepeatKind.all) {
        n = 0;
      } else {
        // autoplay: sambung dengan radio dari lagu terakhir
        try {
          final more = await YtMusicApi.radio(current!.id);
          final ids = queue.map((e) => e.id).toSet();
          final fresh = more.where((s) => !ids.contains(s.id)).toList();
          if (fresh.isEmpty) {
            await _player.pause();
            return;
          }
          queue.addAll(fresh);
          n = index + 1;
        } catch (_) {
          await _player.pause();
          return;
        }
      }
    }
    _stack.add(index);
    await _playIndex(n);
  }

  Future<void> prev() async {
    if (_player.position.inSeconds > 4 || queue.isEmpty) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_stack.isNotEmpty) {
      await _playIndex(_stack.removeLast());
    } else if (index > 0) {
      await _playIndex(index - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = RepeatKind.values[(repeat.index + 1) % 3];
    notifyListeners();
  }

  // ---------- antrean ----------

  Future<void> playNext(Song s) async {
    if (current == null) return playQueue([s], 0);
    queue.insert(index + 1, s);
    notifyListeners();
  }

  Future<void> addToQueue(Song s) async {
    if (current == null) return playQueue([s], 0);
    queue.add(s);
    notifyListeners();
  }

  // ---------- sleep timer ----------

  void setSleep(Duration? d) {
    _sleep?.cancel();
    _sleep = null;
    sleepEnd = null;
    if (d != null) {
      sleepEnd = DateTime.now().add(d);
      _sleep = Timer(d, () {
        _player.pause();
        sleepEnd = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // ---------- favorit ----------

  bool isLiked(Song s) => likes.any((e) => e.id == s.id);

  Future<void> toggleLike(Song s) async {
    if (isLiked(s)) {
      likes.removeWhere((e) => e.id == s.id);
    } else {
      likes.insert(0, s);
    }
    notifyListeners();
    await _save();
  }

  // ---------- playlist ----------

  Future<void> createPlaylist(String name) async {
    playlists.putIfAbsent(name, () => []);
    notifyListeners();
    await _save();
  }

  Future<void> deletePlaylist(String name) async {
    playlists.remove(name);
    notifyListeners();
    await _save();
  }

  Future<void> addToPlaylist(String name, Song s) async {
    final l = playlists.putIfAbsent(name, () => []);
    if (!l.any((e) => e.id == s.id)) l.add(s);
    notifyListeners();
    await _save();
  }

  Future<void> removeFromPlaylist(String name, Song s) async {
    playlists[name]?.removeWhere((e) => e.id == s.id);
    notifyListeners();
    await _save();
  }

  // ---------- unduhan ----------

  bool isDownloaded(Song s) => downloadPaths.containsKey(s.id);

  /// Batalkan unduhan yang sedang berjalan.
  void cancelDownload(String id) {
    _cancelDownload[id] = true;
  }

  /// Unduh audio + lirik supaya bisa dipakai tanpa internet.
  /// - Progress disimpan di [progress]
  /// - Error ditangani dengan bersih (file sementara dihapus)
  /// - Bisa dibatalkan via [cancelDownload]
  Future<void> download(Song s) async {
    if (isDownloaded(s) || progress.containsKey(s.id)) return;
    progress[s.id] = 0;
    _cancelDownload.remove(s.id);
    notifyListeners();

    File? tempFile;
    try {
      final list = await _streams(s.id);
      final a = list.first;
      final dir = await getApplicationDocumentsDirectory();
      tempFile = File('${dir.path}/dl_${s.id}.${a.container.name}');

      // Hapus file lama jika ada (dari download gagal sebelumnya)
      if (tempFile.existsSync()) await tempFile.delete();

      final sink = tempFile.openWrite();
      final total = a.size.totalBytes;
      var got = 0;
      var lastShown = 0.0;
      var failed = false;

      try {
        await for (final chunk in _yt.videos.streamsClient.get(a)) {
          // Cek pembatalan
          if (_cancelDownload[s.id] == true) {
            failed = true;
            break;
          }
          sink.add(chunk);
          got += chunk.length;
          final pr = total > 0 ? got / total : 0.0;
          if (pr - lastShown > 0.03) {
            lastShown = pr;
            progress[s.id] = pr;
            notifyListeners();
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (failed || (_cancelDownload[s.id] == true)) {
        // Hapus file tidak lengkap
        if (tempFile.existsSync()) await tempFile.delete();
      } else {
        // Verifikasi file tidak kosong
        if (tempFile.existsSync() && tempFile.lengthSync() > 1024) {
          downloadPaths[s.id] = tempFile.path;
          downloaded.insert(0, s);
          await _save();
          // Lirik ikut tersimpan (gagal pun tidak masalah)
          unawaited(LyricsApi.prefetch(s));
        } else {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      }
    } catch (e) {
      // Bersihkan file sementara jika error
      try {
        if (tempFile != null && tempFile.existsSync()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }

    progress.remove(s.id);
    _cancelDownload.remove(s.id);
    notifyListeners();
  }

  Future<void> deleteDownload(Song s) async {
    final path = downloadPaths.remove(s.id);
    downloaded.removeWhere((e) => e.id == s.id);
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    notifyListeners();
    await _save();
  }

  // ---------- riwayat ----------

  void _pushHistory(Song s) {
    history.removeWhere((e) => e.id == s.id);
    history.insert(0, s);
    if (history.length > 50) history = history.sublist(0, 50);
    _save();
  }

  // ---------- simpan ----------

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('likes', likes.map((e) => e.encode()).toList());
    await p.setStringList('history', history.map((e) => e.encode()).toList());
    await p.setStringList(
        'downloads', downloaded.map((e) => e.encode()).toList());
    await p.setString('dl_paths', jsonEncode(downloadPaths));
    await p.setString(
        'playlists',
        jsonEncode(playlists.map(
            (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()))));
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    likes = (p.getStringList('likes') ?? []).map(Song.decode).toList();
    history = (p.getStringList('history') ?? []).map(Song.decode).toList();
    downloaded =
        (p.getStringList('downloads') ?? []).map(Song.decode).toList();
    final dl = p.getString('dl_paths');
    if (dl != null) {
      final raw = Map<String, dynamic>.from(jsonDecode(dl));
      // Hapus path yang filenya sudah tidak ada
      downloadPaths = {};
      for (final entry in raw.entries) {
        final path = entry.value as String;
        if (File(path).existsSync()) {
          downloadPaths[entry.key] = path;
        }
      }
      // Sinkronkan list downloaded dengan path yang valid
      downloaded.retainWhere((s) => downloadPaths.containsKey(s.id));
    }
    notifyListeners();
  }
}
