import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/player_service.dart';
import '../ui/glass.dart';

void showEqualizer(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _EqSheet(),
  );
}

class _EqSheet extends StatelessWidget {
  const _EqSheet();

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.i;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Glass(
        radius: 32,
        blur: 24,
        strength: 1.5,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: FutureBuilder<AndroidEqualizerParameters>(
              future: p.eq.parameters.timeout(const Duration(seconds: 6)),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                        'Equalizer belum siap. Putar lagu dulu lalu coba lagi.'),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()));
                }
                final params = snap.data!;
                final min = params.minDecibels;
                final max = params.maxDecibels;
                final bands = params.bands;

                void preset(double Function(double t) f) {
                  for (final (i, b) in bands.indexed) {
                    final t = bands.length == 1 ? 0.0 : i / (bands.length - 1);
                    b.setGain((f(t) * max).clamp(min, max));
                  }
                }

                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Expanded(
                      child: Text('Equalizer',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    StreamBuilder<bool>(
                      stream: p.eq.enabledStream,
                      builder: (_, s) => Switch(
                          value: s.data ?? false, onChanged: p.eq.setEnabled),
                    ),
                  ]),
                  Wrap(spacing: 8, children: [
                    ActionChip(
                        label: const Text('Flat'),
                        onPressed: () => preset((t) => 0)),
                    ActionChip(
                        label: const Text('Bass'),
                        onPressed: () =>
                            preset((t) => t < 0.5 ? 0.8 * (1 - t * 2) : 0)),
                    ActionChip(
                        label: const Text('Vokal'),
                        onPressed: () => preset(
                            (t) => (t > 0.25 && t < 0.8) ? 0.5 : -0.1)),
                    ActionChip(
                        label: const Text('Treble'),
                        onPressed: () =>
                            preset((t) => t > 0.5 ? 0.8 * (t * 2 - 1) : 0)),
                  ]),
                  const SizedBox(height: 8),
                  for (final b in bands)
                    StreamBuilder<double>(
                      stream: b.gainStream,
                      builder: (_, s) => Row(children: [
                        SizedBox(
                          width: 62,
                          child: Text(
                              b.centerFrequency >= 1000
                                  ? '${(b.centerFrequency / 1000).toStringAsFixed(1)} kHz'
                                  : '${b.centerFrequency.round()} Hz',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ),
                        Expanded(
                          child: Slider(
                            value: (s.data ?? b.gain).clamp(min, max),
                            min: min,
                            max: max,
                            onChanged: b.setGain,
                          ),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 6),
                  Row(children: [
                    const SizedBox(
                      width: 62,
                      child: Text('Boost',
                          style:
                              TextStyle(fontSize: 12, color: Colors.white70)),
                    ),
                    Expanded(
                      child: StreamBuilder<double>(
                        stream: p.loud.targetGainStream,
                        builder: (_, s) => Slider(
                          value: (s.data ?? 0).clamp(0.0, 10.0),
                          min: 0,
                          max: 10,
                          onChanged: p.loud.setTargetGain,
                        ),
                      ),
                    ),
                  ]),
                  StreamBuilder<bool>(
                    stream: p.loud.enabledStream,
                    builder: (_, s) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Penguat volume'),
                      value: s.data ?? false,
                      onChanged: p.loud.setEnabled,
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}
