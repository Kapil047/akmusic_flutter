import 'song_model.dart';

class CustomPlaylist {
  final String id;
  final String name;
  final String description;
  final List<SongModel> songs;
  final bool isFavorite;
  final String? thumbnailUrl;
  final int createdAt;

  const CustomPlaylist({
    required this.id,
    required this.name,
    this.description = '',
    this.songs = const [],
    this.isFavorite = false,
    this.thumbnailUrl,
    required this.createdAt,
  });

  /// Artwork URL derived from explicit thumbnail or first song's thumbnail
  String? get artworkUrl =>
      thumbnailUrl ??
      (songs.isNotEmpty
          ? (songs.first.highResThumbnail ?? songs.first.thumbnailUrl)
          : null);

  CustomPlaylist copyWith({
    String? id,
    String? name,
    String? description,
    List<SongModel>? songs,
    bool? isFavorite,
    String? thumbnailUrl,
    int? createdAt,
  }) {
    return CustomPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      songs: songs ?? this.songs,
      isFavorite: isFavorite ?? this.isFavorite,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CustomPlaylist.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'] ?? json['songs'] ?? [];
    final List<SongModel> songList = [];

    if (rawTracks is List) {
      for (final item in rawTracks) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          songList.add(
            SongModel(
              id: m['songId']?.toString() ?? m['id']?.toString() ?? '',
              title: m['title']?.toString() ?? 'Unknown Title',
              artist: m['artist']?.toString() ?? 'Unknown Artist',
              album: m['album']?.toString(),
              thumbnailUrl: m['thumbnail']?.toString() ?? m['thumbnailUrl']?.toString(),
              durationSeconds: m['duration'] is int ? m['duration'] as int : 0,
            ),
          );
        }
      }
    }

    return CustomPlaylist(
      id: json['id']?.toString() ?? 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'My Playlist',
      description: json['description']?.toString() ?? '',
      songs: songList,
      isFavorite: json['isFavorite'] == true,
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? json['thumbnail']?.toString(),
      createdAt: json['createdAt'] is int
          ? json['createdAt'] as int
          : DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'tracks': songs.map((s) => s.toJson()).toList(),
      'isFavorite': isFavorite,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'createdAt': createdAt,
    };
  }
}
