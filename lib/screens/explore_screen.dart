import 'package:flutter/material.dart';
import '../api/ytmusic_api.dart';
import '../models/song.dart';
import '../ui/glass.dart';
import '../ui/nav.dart';
import '../ui/widgets.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<List<MoodTag>> _moods = YtMusicApi.moods();

  static const _colors = [
    Color(0xFF3B6BFF),
    Color(0xFFFF4F8B),
    Color(0xFF19D3B5),
    Color(0xFFFFB02E),
    Color(0xFF9B5CFF),
    Color(0xFFFF6B4A),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: kBottomSpace),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Text('Jelajah',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                  child: _big(context, Icons.new_releases_rounded,
                      'Rilisan baru', 'FEmusic_new_releases')),
              const SizedBox(width: 12),
              Expanded(
                  child: _big(context, Icons.bar_chart_rounded, 'Tangga lagu',
                      'FEmusic_charts')),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 26, 20, 12),
            child: Text('Mood & genre',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          FutureBuilder<List<MoodTag>>(
            future: _moods,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()));
              }
              final tags = snap.data ?? [];
              if (tags.isEmpty) {
                return Center(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _moods = YtMusicApi.moods()),
                    child: const Text('Gagal memuat. Coba lagi'),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final (i, t) in tags.indexed)
                    GestureDetector(
                      onTap: () => openBrowse(context,
                          id: t.browseId, params: t.params, title: t.title),
                      child: Glass(
                        radius: 20,
                        blur: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: _colors[i % _colors.length],
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(t.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _big(BuildContext c, IconData icon, String label, String id) =>
      GestureDetector(
        onTap: () => openBrowse(c, id: id, title: label),
        child: Glass(
          radius: 26,
          strength: 1.6,
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 30),
            const SizedBox(height: 22),
            Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}
