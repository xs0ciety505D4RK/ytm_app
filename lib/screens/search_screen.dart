import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ytmusic_api.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../ui/glass.dart';
import '../ui/nav.dart';
import '../ui/widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final _c = TextEditingController();
  List<Entry> _results = [];
  bool _loading = false;
  String? _error;
  List<String> _recent = [];
  SearchKind _kind = SearchKind.songs;
  String _lastQuery = '';

  static const _kinds = {
    SearchKind.songs: 'Lagu',
    SearchKind.albums: 'Album',
    SearchKind.artists: 'Artis',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _recent = p.getStringList('recent') ?? []);
    });
  }

  Future<void> _remember(String q) async {
    _recent.remove(q);
    _recent.insert(0, q);
    if (_recent.length > 12) _recent = _recent.sublist(0, 12);
    (await SharedPreferences.getInstance()).setStringList('recent', _recent);
  }

  Future<void> _go(String q, {bool remember = true}) async {
    q = q.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    _c.text = q;
    _lastQuery = q;
    if (remember) _remember(q);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await YtMusicApi.search(q, kind: _kind);
      if (mounted) setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'Pencarian gagal. Cek koneksi lo.');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      bottom: false,
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Cari',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Glass(
            radius: 26,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _c,
              textInputAction: TextInputAction.search,
              onSubmitted: _go,
              decoration: InputDecoration(
                hintText: 'Lagu, artis, atau album',
                border: InputBorder.none,
                icon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () {
                    _c.clear();
                    setState(() => _results = []);
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            for (final e in _kinds.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _kind = e.key);
                    if (_lastQuery.isNotEmpty) _go(_lastQuery, remember: false);
                  },
                  child: Glass(
                    radius: 18,
                    blur: 16,
                    strength: _kind == e.key ? 2.2 : 0.8,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(e.value,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _kind == e.key
                                ? Colors.white
                                : Colors.white60)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_results.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (_recent.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
                child: Text('Ketik sesuatu lalu tekan cari',
                    style: TextStyle(color: Colors.white54))),
          )
        else ...[
          const Text('Pencarian terakhir',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in _recent)
              GestureDetector(
                onTap: () => _go(r),
                child: Glass(
                  radius: 18,
                  blur: 16,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(r),
                ),
              ),
          ]),
        ],
      ]);
    }
    final songs = _results.map((e) => e.song).whereType<Song>().toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: kBottomSpace),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final e = _results[i];
        if (e.song != null) {
          return SongTile(
            song: e.song!,
            onTap: () => PlayerService.i
                .playQueue(songs, songs.indexWhere((s) => s.id == e.song!.id)),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: GestureDetector(
            onTap: () => openEntry(context, e, songs),
            child: Glass(
              radius: 22,
              blur: 20,
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Art(e.thumb, size: 54, radius: e.isArtist ? 27 : 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(e.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: Colors.white60)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ]),
            ),
          ),
        );
      },
    );
  }
}
