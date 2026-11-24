import 'dart:convert';

class Song {
  final String id;
  final String title;
  final String artist;
  final String thumb;
  final String duration;
  final String? artistId;
  final String? albumId;

  Duration? get parsedDuration {
    final parts = duration.split(':').map(int.tryParse).toList();
    if (parts.isEmpty || parts.any((part) => part == null || part < 0)) {
      return null;
    }
    var seconds = 0;
    for (final part in parts) {
      seconds = seconds * 60 + part!;
    }
    return seconds > 0 ? Duration(seconds: seconds) : null;
  }

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumb,
    this.duration = '',
    this.artistId,
    this.albumId,
  });

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        artist: j['artist'] ?? '',
        thumb: j['thumb'] ?? '',
        duration: j['duration'] ?? '',
        artistId: j['artistId'],
        albumId: j['albumId'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'thumb': thumb,
        'duration': duration,
        'artistId': artistId,
        'albumId': albumId,
      };

  Song copyWith({String? thumb, String? artist, String? duration}) => Song(
        id: id,
        title: title,
        artist: artist ?? this.artist,
        thumb: thumb ?? this.thumb,
        duration: duration ?? this.duration,
        artistId: artistId,
        albumId: albumId,
      );

  String encode() => jsonEncode(toJson());
  static Song decode(String s) => Song.fromJson(jsonDecode(s));
}

/// Satu kartu di beranda/hasil cari: bisa lagu (song != null)
/// atau halaman lain (album, artis, playlist) lewat browseId.
class Entry {
  final Song? song;
  final String title;
  final String subtitle;
  final String thumb;
  final String? browseId;
  final String? params;

  const Entry({
    this.song,
    required this.title,
    this.subtitle = '',
    this.thumb = '',
    this.browseId,
    this.params,
  });

  factory Entry.fromSong(Song s) =>
      Entry(song: s, title: s.title, subtitle: s.artist, thumb: s.thumb);

  bool get isArtist => browseId?.startsWith('UC') ?? false;
  String get key => song?.id ?? '${browseId ?? title}|${params ?? ''}';
}

class Section {
  final String title;
  final List<Entry> entries;
  const Section(this.title, this.entries);
  List<Song> get songs => entries.map((e) => e.song).whereType<Song>().toList();
}

class Detail {
  final String title;
  final String subtitle;
  final String thumb;
  final List<Song> songs;
  final List<Section> sections;
  const Detail(this.title, this.subtitle, this.thumb, this.songs, this.sections);
}

class MoodTag {
  final String title;
  final String browseId;
  final String? params;
  const MoodTag(this.title, this.browseId, this.params);
}
