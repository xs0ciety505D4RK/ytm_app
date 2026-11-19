import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import 'glass.dart';
import 'song_menu.dart';

class Art extends StatelessWidget {
  const Art(this.url, {super.key, this.size, this.radius = 14});
  final String url;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = ((size ?? 640) * dpr).round().clamp(64, 1024);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? const ColoredBox(color: Colors.white12)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: px,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => const ColoredBox(color: Colors.white12),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Colors.white12),
              ),
      ),
    );
  }
}

class SongTile extends StatelessWidget {
  const SongTile(
      {super.key,
      required this.song,
      required this.onTap,
      this.onRemove,
      this.removeLabel = 'Hapus'});
  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.i;
    return AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final active = p.current?.id == song.id;
        final liked = p.isLiked(song);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: GestureDetector(
            onTap: onTap,
            onLongPress: () => showSongMenu(context, song,
                onRemove: onRemove, removeLabel: removeLabel),
            child: Glass(
              radius: 22,
              blur: 0,
              strength: active ? 1.8 : 1,
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Art(song.thumb, size: 54, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(children: [
                        if (p.isDownloaded(song))
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.download_done_rounded,
                                size: 14, color: Color(0xFF8FB8FF)),
                          ),
                        Expanded(
                          child: Text(
                              p.progress.containsKey(song.id)
                                  ? 'Mengunduh ${(p.progress[song.id]! * 100).round()}%'
                                  : song.duration.isEmpty
                                      ? song.artist
                                      : '${song.artist}  ${song.duration}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5, color: Colors.white60)),
                        ),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => p.toggleLike(song),
                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? const Color(0xFFFF5C8A) : Colors.white54),
                ),
                IconButton(
                  onPressed: () => showSongMenu(context, song,
                      onRemove: onRemove, removeLabel: removeLabel),
                  icon: const Icon(Icons.more_vert_rounded,
                      color: Colors.white54),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

const double kBottomSpace = 200; // ruang untuk navbar + mini player
