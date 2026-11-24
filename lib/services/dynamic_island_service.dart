import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../ui/glass.dart';
import 'player_service.dart';

class DynamicIslandService {
  DynamicIslandService._();
  static final DynamicIslandService instance = DynamicIslandService._();

  StreamSubscription<dynamic>? _overlayEvents;
  StreamSubscription<Duration>? _positionEvents;
  bool _initialized = false;
  bool _starting = false;
  bool _sharing = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _overlayEvents = FlutterOverlayWindow.overlayListener.listen(
      (event) => unawaited(_handleOverlayEvent(event)),
      onError: (Object error) => debugPrint('Overlay event error: $error'),
    );
    PlayerService.i.addListener(_onPlayerChanged);
    _positionEvents = PlayerService.i.player.positionStream.listen((_) {
      unawaited(_publishState());
    });
    if (Perf.dynamicIsland.value) unawaited(restore());
  }

  Future<bool> permissionGranted() =>
      FlutterOverlayWindow.isPermissionGranted();

  Future<bool> setEnabled(bool enabled) async {
    if (!enabled) {
      await Perf.setDynamicIsland(false);
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (_) {}
      return true;
    }

    var granted = await permissionGranted();
    if (!granted) {
      granted = await FlutterOverlayWindow.requestPermission() ?? false;
    }
    if (!granted) return false;

    await Perf.setDynamicIsland(true);
    await _ensureOverlay();
    return true;
  }

  Future<void> restore() async {
    try {
      if (await permissionGranted()) await _ensureOverlay();
    } catch (error) {
      debugPrint('Dynamic Island restore failed: $error');
    }
  }

  void _onPlayerChanged() {
    if (Perf.dynamicIsland.value && PlayerService.i.current != null) {
      unawaited(_ensureOverlay());
    }
    unawaited(_publishState());
  }

  Future<void> _ensureOverlay() async {
    if (_starting || !Perf.dynamicIsland.value ||
        PlayerService.i.current == null) {
      return;
    }
    _starting = true;
    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) return;
      if (!await FlutterOverlayWindow.isActive()) {
        final screen = await FlutterOverlayWindow.getScreenSize();
        final reportedWidth = screen.x.round();
        final width = reportedWidth <= 0
            ? 360
            : math.min(reportedWidth, 420).toInt();
        await FlutterOverlayWindow.showOverlay(
          height: 84,
          width: width,
          alignment: OverlayAlignment.topCenter,
          enableDrag: true,
          positionGravity: PositionGravity.auto,
          overlayTitle: 'YTM Glass',
          overlayContent: 'Kontrol pemutar aktif',
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      await _publishState();
    } catch (error) {
      debugPrint('Dynamic Island overlay failed: $error');
    } finally {
      _starting = false;
    }
  }

  Future<void> _publishState() async {
    if (_sharing || !Perf.dynamicIsland.value) return;
    final player = PlayerService.i;
    final song = player.current;
    if (song == null) return;
    _sharing = true;
    try {
      if (!await FlutterOverlayWindow.isActive()) return;
      await FlutterOverlayWindow.shareData(jsonEncode({
        'title': song.title,
        'artist': song.artist,
        'thumb': song.thumb,
        'playing': player.playing,
        'loading': player.loading,
        'position': player.player.position.inMilliseconds,
        'duration': (player.player.duration ?? song.parsedDuration)?.inMilliseconds ?? 0,
      }));
    } catch (error) {
      debugPrint('Dynamic Island state update failed: $error');
    } finally {
      _sharing = false;
    }
  }

  Future<void> _handleOverlayEvent(dynamic event) async {
    Map<String, dynamic>? message;
    try {
      if (event is String) {
        final decoded = jsonDecode(event);
        if (decoded is Map) message = Map<String, dynamic>.from(decoded);
      } else if (event is Map) {
        message = Map<String, dynamic>.from(event);
      }
    } catch (_) {}
    final action = message?['action']?.toString();
    final player = PlayerService.i;
    switch (action) {
      case 'play':
        await player.play();
        break;
      case 'pause':
        await player.pause();
        break;
      case 'toggle':
        await player.toggle();
        break;
      case 'next':
        await player.next();
        break;
      case 'previous':
        await player.prev();
        break;
      case 'dismiss':
        await setEnabled(false);
        break;
      case 'ready':
        await _publishState();
        break;
    }
  }

  Future<void> dispose() async {
    await _overlayEvents?.cancel();
    await _positionEvents?.cancel();
    PlayerService.i.removeListener(_onPlayerChanged);
    _initialized = false;
  }
}
