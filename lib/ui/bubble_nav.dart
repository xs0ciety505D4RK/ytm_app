import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

/// Navbar kaca dengan gelembung yang ikut posisi swipe PageView.
/// - Gelembung melar saat bergerak, lalu mengerut dan nge-zoom ikon aktif.
/// - Bisa di-swipe langsung di navbar maupun di halaman.
class BubbleNav extends StatelessWidget {
  const BubbleNav({super.key, required this.controller, required this.items});

  final PageController controller;
  final List<NavItem> items;

  static const double height = 68;
  static const double pad = 8;

  double _page() {
    if (controller.hasClients && controller.position.haveDimensions) {
      return controller.page ?? controller.initialPage.toDouble();
    }
    return controller.initialPage.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    return LayoutBuilder(builder: (context, c) {
      final itemW = (c.maxWidth - pad * 2) / n;
      final pageW = MediaQuery.of(context).size.width;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) {
          final pos = controller.position;
          controller.jumpTo((pos.pixels + d.delta.dx * (pageW / itemW))
              .clamp(pos.minScrollExtent, pos.maxScrollExtent));
        },
        onHorizontalDragEnd: (_) => controller.animateToPage(
          _page().round(),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutBack,
        ),
        child: Glass(
          radius: 36,
          blur: 22,
          child: SizedBox(
            height: height,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final page = _page();
                final frac = page - page.floorToDouble();
                final stretch = math.sin(math.pi * frac); // 0..1..0
                final bw = itemW * (1 + 0.45 * stretch) - 6;
                final bh = (height - 14) * (1 - 0.10 * stretch);
                final center = pad + (page + 0.5) * itemW;

                return Stack(alignment: Alignment.center, children: [
                  Positioned(
                    left: center - bw / 2,
                    top: (height - bh) / 2,
                    width: bw,
                    height: bh,
                    child: const _Bubble(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: pad),
                    child: Row(
                      children: [
                        for (int i = 0; i < n; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => controller.animateToPage(i,
                                  duration: const Duration(milliseconds: 520),
                                  curve: Curves.easeOutBack),
                              child: _item(i, page),
                            ),
                          ),
                      ],
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
      );
    });
  }

  Widget _item(int i, double page) {
    final near = (1 - (page - i).abs()).clamp(0.0, 1.0); // 1 = aktif
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.scale(
          scale: 1 + 0.28 * near,
          child: Icon(
            items[i].icon,
            size: 24,
            color: Color.lerp(Colors.white60, Colors.white, near),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          items[i].label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color.lerp(Colors.white54, Colors.white, near),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: RadialGradient(
          center: const Alignment(-0.5, -0.8),
          radius: 1.3,
          colors: [
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7FB2FF).withValues(alpha: 0.35),
            blurRadius: 18,
          ),
        ],
      ),
    );
  }
}
