import '../parsers/yt_normalizer.dart';

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? thumbnailUrl;
  final int durationSeconds;

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.thumbnailUrl,
    this.durationSeconds = 0,
  });

  /// Factory constructor for direct normalized backend /search results
  factory SongModel.fromSearchJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: (json['artists'] is List && (json['artists'] as List).isNotEmpty)
          ? (json['artists'] as List).join(', ')
          : 'Unknown Artist',
      album: json['album'],
      durationSeconds: json['duration'] is int ? json['duration'] : 0,
      thumbnailUrl: YtNormalizer.extractThumbnail(json['thumbnails']),
    );
  }

  /// Defensive constructor for raw YouTube nested objects (e.g., from Album, Playlist, or Home shelves)
  factory SongModel.fromYtRaw(Map<String, dynamic> raw) {
    String id = raw['videoId'] ?? raw['id'] ?? '';
    String title = YtNormalizer.extractText(raw['title'], 'Unknown Title');
    String artist = YtNormalizer.extractText(raw['subtitle'] ?? raw['author'] ?? raw['artist'], 'Unknown Artist');
    String? thumb = YtNormalizer.extractThumbnail(raw['thumbnails'] ?? raw['thumbnail']);
    int duration = YtNormalizer.parseDurationString(raw['duration']);

    // Check nested flex columns if present (Album / Playlist structure)
    if (raw['flex_columns'] is List && (raw['flex_columns'] as List).isNotEmpty) {
      final cols = raw['flex_columns'] as List;
      if (cols.isNotEmpty && cols[0] is Map) {
        final colTitle = cols[0]['title'];
        title = YtNormalizer.extractText(colTitle, title);
        // check endpoint videoId
        if (colTitle is Map && colTitle['endpoint'] != null && colTitle['endpoint']['payload'] != null) {
          id = colTitle['endpoint']['payload']['videoId'] ?? id;
        }
      }
      if (cols.length > 1 && cols[1] is Map) {
        artist = YtNormalizer.extractText(cols[1]['title'], artist);
      }
    }

    return SongModel(
      id: id,
      title: title,
      artist: artist,
      album: raw['album'] != null ? YtNormalizer.extractText(raw['album']) : null,
      thumbnailUrl: thumb,
      durationSeconds: duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songId': id,
      'title': title,
      'artist': artist,
      'album': album,
      'thumbnail': thumbnailUrl,
      'duration': durationSeconds,
    };
  }
}
