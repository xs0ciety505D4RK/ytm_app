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
import '../models/song.dart';
import 'music_handler.dart';
import 'yt_stream_source.dart';

enum RepeatKind { off, all, one }

class PlayerService extends ChangeNotifier {
  PlayerService._();
  static final PlayerService i = PlayerService._();

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
        androidNotificationOngoing: false,
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
        duration: d,
      );

  // ---------- stream YouTube ----------

  /// Coba beberapa klien sampai ada yang mengembalikan stream audio.
  Future<List<AudioOnlyStreamInfo>> _streams(String id) async {
    Object? last;
    final attempts = <List<YoutubeApiClient>?>[
      [YoutubeApiClient.ios],
      [YoutubeApiClient.androidVr],
      null,
      [YoutubeApiClient.tv],
    ];
    for (final clients in attempts) {
      try {
        final m = clients == null
            ? await _yt.videos.streamsClient.getManifest(id)
            : await _yt.videos.streamsClient
                .getManifest(id, ytClients: clients);
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
    final t = e.toString().replaceAll('\n', ' ');
    return t.length > 90 ? '${t.substring(0, 90)}…' : t;
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
      for (final info in streams.take(4)) {
        if (req != _req) return;
        try {
          await _player.stop();
          await _player.setAudioSource(
            AudioSource.uri(_audioProxyUri(info.url)),
          );
          if (req != _req) return;
          await _player.play();
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
    error = null;
    _proxyRecoveryReq = -1;
    art.value = song.thumb;
    _handler.mediaItem.add(_item(song));
    _pushHistory(song);
    notifyListeners();
    try {
      final local = downloadPaths[song.id];
      if (local != null && File(local).existsSync()) {
        await _player.setAudioSource(AudioSource.uri(Uri.file(local)));
      } else {
        final list = await _streams(song.id);
        if (req != _req) return;
        Object? last;
        var opened = false;
        // Do not rely on one high-bitrate format: it may be unsupported by a
        // device or rejected upstream. Try up to two compatible alternatives.
        for (final info in list.take(2)) {
          final sources = <MapEntry<String, AudioSource>>[
            if (kBackend.isNotEmpty)
              MapEntry('relay', AudioSource.uri(_audioProxyUri(info.url))),
            MapEntry('langsung', AudioSource.uri(info.url)),
            MapEntry('cadangan', YtStreamSource(_yt, info)),
          ];
          for (final candidate in sources) {
            if (req != _req) return;
            try {
              try {
                await _player.stop().timeout(const Duration(seconds: 2));
              } catch (_) {}
              await _player
                  .setAudioSource(candidate.value)
                  .timeout(const Duration(seconds: 10));
              opened = true;
              break;
            } catch (e) {
              last = e;
              debugPrint(
                '[PlayerService] ${candidate.key} gagal; '
                'itag=${info.tag} ${info.container.name}/${info.audioCodec}: ${_short(e)}',
              );
              try {
                await _player.stop().timeout(const Duration(seconds: 2));
              } catch (_) {}
            }
          }
          if (opened) break;
        }
        if (!opened) throw last ?? Exception('Semua sumber audio gagal dibuka');
      }
      if (req != _req) return;
      _player.play();
    } catch (e) {
      if (req == _req) error = 'Gagal memutar: ${_short(e)}';
    }
    if (req == _req) loading = false;
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
