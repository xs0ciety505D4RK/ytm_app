import 'package:flutter/material.dart';
import '../api/ytmusic_api.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../ui/section_row.dart';
import '../ui/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Section>> _f = YtMusicApi.home();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() => _f = YtMusicApi.home());
          await _f;
        },
        child: FutureBuilder<List<Section>>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
              final p = PlayerService.i;
              final offline = [
                if (p.downloaded.isNotEmpty)
                  Section('Unduhan (offline)',
                      p.downloaded.map(Entry.fromSong).toList()),
                if (p.history.isNotEmpty)
                  Section('Terakhir diputar',
                      p.history.take(15).map(Entry.fromSong).toList()),
              ];
              return ListView(
                padding: const EdgeInsets.only(bottom: kBottomSpace),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Text('Beranda',
                        style: TextStyle(
                            fontSize: 34, fontWeight: FontWeight.w800)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                        'Tidak ada koneksi. Lagu unduhan tetap bisa diputar.\nTarik ke bawah untuk coba lagi.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .7))),
                  ),
                  for (final sec in offline) SectionRow(section: sec),
                ],
              );
            }
            return AnimatedBuilder(
              animation: PlayerService.i,
              builder: (context, _) {
                final h = PlayerService.i.history;
                final sections = [
                  if (h.isNotEmpty)
                    Section('Terakhir diputar',
                        h.take(15).map(Entry.fromSong).toList()),
                  ...snap.data!,
                ];
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: kBottomSpace),
                  itemCount: sections.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text('Beranda',
                            style: TextStyle(
                                fontSize: 34, fontWeight: FontWeight.w800)),
                      );
                    }
                    return SectionRow(section: sections[i - 1]);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
