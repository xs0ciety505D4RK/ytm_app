import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class IslandOverlayApp extends StatelessWidget {
  const IslandOverlayApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        color: Colors.transparent,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: _IslandOverlay(),
        ),
      );
}

class _IslandOverlay extends StatefulWidget {
  const _IslandOverlay();

  @override
  State<_IslandOverlay> createState() => _IslandOverlayState();
}

class _IslandOverlayState extends State<_IslandOverlay> {
  StreamSubscription<dynamic>? _events;
  Map<String, dynamic> _state = const {};

  @override
  void initState() {
    super.initState();
    _events = FlutterOverlayWindow.overlayListener.listen(_receive);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_send('ready'));
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _receive(dynamic event) {
    try {
      final decoded = event is String ? jsonDecode(event) : event;
      if (decoded is Map && !decoded.containsKey('action')) {
        setState(() => _state = Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
  }

  Future<void> _send(String action) => FlutterOverlayWindow.shareData(
        jsonEncode({'action': action}),
      );

  @override
  Widget build(BuildContext context) {
    final thumb = _state['thumb']?.toString() ?? '';
    final title = _state['title']?.toString() ?? 'SoundXs';
    final artist = _state['loading'] == true
        ? 'Menyambungkan audio…'
        : (_state['artist']?.toString() ?? 'Pemutar musik');
    final playing = _state['playing'] == true;
    final duration = (_state['duration'] as num?)?.toDouble() ?? 0;
    final position = (_state['position'] as num?)?.toDouble() ?? 0;
    final progress = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xE6111420),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xEF313B54), Color(0xE810121B)],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: .23)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 22,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(children: [
                Expanded(
                  child: Row(children: [
                    _Artwork(url: thumb),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text(artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white70)),
                        ],
                      ),
                    ),
                    _IslandButton(
                      icon: Icons.skip_previous_rounded,
                      label: 'Sebelumnya',
                      onTap: () => _send('previous'),
                    ),
                    _IslandButton(
                      icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      label: playing ? 'Jeda' : 'Putar',
                      onTap: () => _send(playing ? 'pause' : 'play'),
                      emphasized: true,
                    ),
                    _IslandButton(
                      icon: Icons.skip_next_rounded,
                      label: 'Berikutnya',
                      onTap: () => _send('next'),
                    ),
                    _IslandButton(
                      icon: Icons.close_rounded,
                      label: 'Tutup Dynamic Island',
                      onTap: () => _send('dismiss'),
                      small: true,
                    ),
                  ]),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    value: duration > 0 ? progress : null,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF8FB8FF)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 38,
          height: 38,
          child: url.isEmpty
              ? const ColoredBox(
                  color: Color(0xFF2C3447),
                  child: Icon(Icons.music_note_rounded, size: 22),
                )
              : Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF2C3447),
                    child: Icon(Icons.music_note_rounded, size: 22),
                  )),
        ),
      );
}

class _IslandButton extends StatelessWidget {
  const _IslandButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
    this.small = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;
  final bool small;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: SizedBox(
          width: small ? 24 : 30,
          height: 38,
          child: IconButton(
            tooltip: label,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: onTap,
            icon: Icon(icon,
                size: emphasized ? 22 : 18,
                color: emphasized ? Colors.white : Colors.white70),
          ),
        ),
      );
}
