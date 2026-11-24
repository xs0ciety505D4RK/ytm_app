import 'package:flutter/material.dart';
import 'glass.dart';

void showSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Glass(
        radius: 32,
        blur: 24,
        strength: 1.5,
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('Pengaturan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: Perf.blur,
              builder: (_, on, __) => SwitchListTile(
                title: const Text('Efek blur kaca'),
                subtitle: const Text('Matikan kalau terasa berat / patah-patah'),
                value: on,
                onChanged: Perf.setBlur,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: Perf.dynamicIsland,
              builder: (_, on, __) => SwitchListTile(
                secondary: const Icon(Icons.graphic_eq_rounded),
                title: const Text('Dynamic Island'),
                subtitle: const Text(
                    'Tampilkan kontrol pemutar mengambang di dalam aplikasi'),
                value: on,
                onChanged: Perf.setDynamicIsland,
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    ),
  );
}
