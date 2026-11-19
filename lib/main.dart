import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'services/player_service.dart';
import 'ui/bubble_nav.dart';
import 'ui/glass.dart';
import 'ui/mini_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Perf.load();
  await PlayerService.i.init(); // foreground service + notifikasi media
  runApp(const App());
  Permission.notification.request(); // Android 13+: izin notifikasi pemutar
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YTM Glass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C9CFF), brightness: Brightness.dark),
        sliderTheme: const SliderThemeData(
          trackHeight: 4,
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white24,
          thumbColor: Colors.white,
          overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
        ),
      ),
      builder: (context, child) => Stack(children: [
        const Positioned.fill(child: GlassBackground()),
        child!,
      ]),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _pc = PageController();

  static const _items = [
    NavItem(Icons.home_rounded, 'Beranda'),
    NavItem(Icons.explore_rounded, 'Jelajah'),
    NavItem(Icons.search_rounded, 'Cari'),
    NavItem(Icons.library_music_rounded, 'Koleksi'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.i;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(children: [
        PageView(
          controller: _pc,
          children: const [
            HomeScreen(),
            ExploreScreen(),
            SearchScreen(),
            LibraryScreen()
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom + 12,
          child: AnimatedBuilder(
            animation: p,
            builder: (context, _) =>
                Column(mainAxisSize: MainAxisSize.min, children: [
              if (p.current != null) const MiniPlayer(),
              if (p.current != null) const SizedBox(height: 10),
              RepaintBoundary(
                  child: BubbleNav(controller: _pc, items: _items)),
            ]),
          ),
        ),
      ]),
    );
  }
}
