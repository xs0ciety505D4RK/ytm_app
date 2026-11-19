import 'package:flutter/material.dart';
import '../models/song.dart';
import 'nav.dart';
import 'widgets.dart';

/// Judul + baris kartu horizontal (lagu, album, artis, playlist).
class SectionRow extends StatelessWidget {
  const SectionRow({super.key, required this.section});
  final Section section;

  @override
  Widget build(BuildContext context) {
    final queue = section.songs;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Text(section.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      SizedBox(
        height: 215,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: section.entries.length,
          itemBuilder: (context, i) {
            final e = section.entries[i];
            return GestureDetector(
              onTap: () => openEntry(context, e, queue),
              child: Container(
                width: 148,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  crossAxisAlignment: e.isArtist
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Art(e.thumb, size: 148, radius: e.isArtist ? 74 : 22),
                    const SizedBox(height: 8),
                    Text(e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: e.isArtist ? TextAlign.center : null,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(e.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: e.isArtist ? TextAlign.center : null,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white60)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
