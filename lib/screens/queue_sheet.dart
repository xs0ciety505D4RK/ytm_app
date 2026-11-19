import 'dart:math';
import 'package:flutter/material.dart';
import '../services/player_service.dart';
import '../ui/glass.dart';
import '../ui/widgets.dart';

void showQueue(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QueueSheet(),
  );
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  static const double _h = 64;

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.i;
    final ctrl =
        ScrollController(initialScrollOffset: max(0, (p.index - 2) * _h));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Glass(
          radius: 32,
          blur: 24,
          strength: 1.5,
          child: AnimatedBuilder(
            animation: p,
            builder: (context, _) => Column(children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Antrean',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  itemExtent: _h,
                  itemCount: p.queue.length,
                  itemBuilder: (context, i) {
                    final s = p.queue[i];
                    final active = i == p.index;
                    return ListTile(
                      selected: active,
                      selectedTileColor: Colors.white12,
                      leading: Art(s.thumb, size: 44, radius: 10),
                      title: Text(s.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(s.artist, maxLines: 1),
                      trailing: active
                          ? const Icon(Icons.graphic_eq_rounded)
                          : null,
                      onTap: () => p.jumpTo(i),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
