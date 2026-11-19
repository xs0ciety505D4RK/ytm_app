import 'dart:ui';
import 'package:flutter/material.dart';

/// Kartu kaca: blur latar + gradasi tipis + garis tepi terang.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = 28,
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
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.20 * strength),
                Colors.white.withValues(alpha: 0.05 * strength),
              ],
            ),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.26), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Latar gelap dengan cahaya warna-warni supaya efek kaca kelihatan.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, this.art});
  final String? art;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFF07090F))),
      if (art != null && art!.isNotEmpty)
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            child: ImageFiltered(
              key: ValueKey(art),
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Opacity(
                opacity: 0.45,
                child: Image.network(art!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            ),
          ),
        ),
      _blob(const Color(0xFF3B6BFF), -size.width * .3, -80, size.width * .9),
      _blob(const Color(0xFFFF4F8B), size.width * .45, size.height * .35,
          size.width * .8),
      _blob(const Color(0xFF19D3B5), -size.width * .2, size.height * .7,
          size.width * .8),
    ]);
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
              c.withValues(alpha: 0.38),
              c.withValues(alpha: 0),
            ]),
          ),
        ),
      );
}
