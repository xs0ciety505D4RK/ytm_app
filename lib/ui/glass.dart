import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/player_service.dart';

/// Pengaturan performa. Blur bisa dimatikan untuk HP/tablet yang lemah.
class Perf {
  static final ValueNotifier<bool> blur = ValueNotifier(true);
  static final ValueNotifier<bool> dynamicIsland = ValueNotifier(false);

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    blur.value = p.getBool('blur') ?? true;
    dynamicIsland.value = p.getBool('dynamic_island') ?? false;
  }

  static Future<void> setBlur(bool v) async {
    blur.value = v;
    (await SharedPreferences.getInstance()).setBool('blur', v);
  }

  static Future<void> setDynamicIsland(bool v) async {
    dynamicIsland.value = v;
    await (await SharedPreferences.getInstance())
        .setBool('dynamic_island', v);
  }
}

/// Kartu kaca. blur = 0 (default) berarti versi "flat" yang ringan:
/// gradasi + garis tepi tanpa BackdropFilter. Blur sungguhan hanya dipakai
/// di navbar, mini player, dan sheet (jumlahnya sedikit).
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = 0,
    this.padding,
    this.strength = 1,
  });

  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ValueListenableBuilder<bool>(
      valueListenable: Perf.blur,
      builder: (context, on, _) {
        final useBlur = on && blur > 0;
        final k = useBlur ? strength : strength * 1.3;
        final box = Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: (0.20 * k).clamp(0, 0.6)),
                Colors.white.withValues(alpha: (0.05 * k).clamp(0, 0.4)),
              ],
            ),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.26), width: 1),
          ),
          child: child,
        );
        return ClipRRect(
          borderRadius: r,
          child: useBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: box)
              : box,
        );
      },
    );
  }
}

/// Latar gelap + cahaya warna. Cover lagu aktif ditampilkan dalam resolusi
/// sangat kecil lalu diregangkan, sehingga tampak blur tanpa filter yang berat.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return RepaintBoundary(
      child: Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF07090F))),
        Positioned.fill(
          child: ValueListenableBuilder<String?>(
            valueListenable: PlayerService.i.art,
            builder: (context, art, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: (art == null || art.isEmpty)
                  ? const SizedBox.shrink()
                  : Opacity(
                      key: ValueKey(art),
                      opacity: 0.42,
                      child: CachedNetworkImage(
                        imageUrl: art,
                        fit: BoxFit.cover,
                        memCacheWidth: 64,
                        filterQuality: FilterQuality.low,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
            ),
          ),
        ),
        _blob(const Color(0xFF3B6BFF), -size.width * .3, -80, size.width * .9),
        _blob(const Color(0xFFFF4F8B), size.width * .45, size.height * .35,
            size.width * .8),
        _blob(const Color(0xFF19D3B5), -size.width * .2, size.height * .7,
            size.width * .8),
      ]),
    );
  }

  Widget _blob(Color c, double left, double top, double d) => Positioned(
        left: left,
        top: top,
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              c.withValues(alpha: 0.34),
              c.withValues(alpha: 0),
            ]),
          ),
        ),
      );
}
