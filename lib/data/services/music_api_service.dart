import '../models/playlist_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../models/song_model.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final musicApiServiceProvider = Provider<MusicApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return MusicApiService(client);
});

class SuggestionResponse {
  final String? top;
  final List<String> all;
  final bool isPersonalized;

  const SuggestionResponse({
    this.top,
    this.all = const [],
    this.isPersonalized = false,
  });

  factory SuggestionResponse.fromJson(Map<String, dynamic> json) {
    return SuggestionResponse(
      top: json['top'] as String?,
      all: (json['all'] is List)
          ? (json['all'] as List).map((e) => e.toString()).toList()
          : [],
      isPersonalized: json['isPersonalized'] == true,
    );
  }
}

class MusicApiService {
  final ApiClient _client;

  MusicApiService(this._client);

  /// Search songs, albums, or artists
  Future<List<SongModel>> search(String query, {String type = 'song'}) async {
    try {
      final response = await _client.dio.get(
        '/search',
        queryParameters: {'q': query, 'type': type},
      );

      final data = response.data;
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List;
        debugPrint('🔍 [SEARCH SUCCESS] Retrieved ${list.length} tracks for "$query"');
        return list
            .map((item) => SongModel.fromSearchJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e, stack) {
      debugPrint('❌ [SEARCH ERROR] $e\n$stack');
    }
    return [];
  }

  /// Live search auto-suggestions (Personalized 3-Layer + Ranking)
  Future<SuggestionResponse> getSuggestions(String query) async {
    try {
      final response = await _client.dio.get(
        '/suggestions',
        queryParameters: {'q': query, 'limit': 10},
      );

      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return SuggestionResponse.fromJson(Map<String, dynamic>.from(data['data'] as Map));
      }
    } catch (e) {
      debugPrint('❌ [SUGGESTIONS ERROR] $e');
    }
    return const SuggestionResponse();
  }

    /// Record song playback to backend for personalization
  Future<void> recordPlay({
    required String songId,
    required String title,
    String? artist,
    String? thumbnail,
    int? duration,
  }) async {
    try {
      final response = await _client.dio.post('/play/record', data: {
        'songId': songId,
        'title': title,
        'artist': artist,
        'thumbnail': thumbnail,
        'duration': duration,
      });
      final data = response.data;
      if (data is Map && data['data'] is Map && data['data']['recorded'] == false) {
        debugPrint('[WARN] [RECORD PLAY] not saved — reason: ${data['data']['reason']}');
      } else {
        debugPrint('🎵 [RECORD PLAY SUCCESS] Logged "$title"');
      }
    } catch (e) {
      debugPrint('[WARN] [RECORD PLAY ERROR] $e');
    }
  }

  /// Convenience helper to record play directly from SongModel
  Future<void> recordPlaySong(SongModel song) => recordPlay(
    songId: song.id,
    title: song.title,
    artist: song.artist,
    thumbnail: song.thumbnailUrl,
    duration: song.durationSeconds,
  );

  /// Get personalized home feed (Recent > Top > Favorites > Trending)
  Future<List<SongModel>> getHomeFeed({int limit = 20}) async {
    try {
      final response = await _client.dio.get(
        '/suggestions',
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data is Map && data['data'] is Map && data['data']['all'] is List) {
        final list = data['data']['all'] as List;
        final songs = <SongModel>[];
        for (final item in list) {
          if (item is Map) {
            final songId = item['songId']?.toString() ?? item['id']?.toString() ?? '';
            final title = item['title']?.toString() ?? '';
            if (songId.isNotEmpty && title.isNotEmpty) {
              songs.add(
                SongModel(
                  id: songId,
                  title: title,
                  artist: item['artist']?.toString() ?? 'Various Artists',
                  album: item['album']?.toString() ?? 'AK Music',
                  durationSeconds: item['duration'] is int ? item['duration'] as int : 0,
                  thumbnailUrl: item['thumbnail']?.toString(),
                ),
              );
            }
          }
        }
        if (songs.isNotEmpty) {
          debugPrint('✨ [HOME FEED] Loaded ${songs.length} personalized recommendations');
          return songs;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [GET HOME FEED ERROR] $e');
    }
    return search('Trending Hits 2026', type: 'song');
  }

  /// Record user search query for future personalization
  Future<void> recordSearch(String query) async {
    if (query.trim().isEmpty) return;
    try {
      await _client.dio.post('/search/record', data: {'query': query.trim()});
    } catch (_) {}
  }

  /// Play-time "Queue Auto-Suggest": given the song that's currently
  /// playing, returns related songs via YouTube's radio engine (getUpNext)
  Future<List<SongModel>> getNextSongs({
    required String currentSongId,
    List<String> excludeIds = const [],
    int limit = 10,
  }) async {
    try {
      final response = await _client.dio.post(
        '/queue/next',
        data: {
          'currentSongId': currentSongId,
          'excludeIds': excludeIds,
          'limit': limit,
        },
      );
      final data = response.data;
      if (data is Map && data['data'] is Map && data['data']['songs'] is List) {
        final list = data['data']['songs'] as List;
        return list
            .whereType<Map>()
            .map(
              (item) => SongModel(
                id: item['songId']?.toString() ?? item['id']?.toString() ?? '',
                title: item['title']?.toString() ?? '',
                artist: item['artist']?.toString() ?? 'Various Artists',
                album: item['album']?.toString() ?? 'AK Music',
                durationSeconds: item['duration'] is int ? item['duration'] as int : 0,
                thumbnailUrl: item['thumbnail']?.toString(),
              ),
            )
            .where((s) => s.id.isNotEmpty && s.title.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[WARN] [GET NEXT SONGS ERROR] $e');
    }
    return [];
  }


  /// Get remote playlist / album tracks by ID
  Future<CustomPlaylist?> getPlaylist(String id) async {
    try {
      final response = await _client.dio.get('/playlist/$id');
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final d = Map<String, dynamic>.from(data['data'] as Map);
        final title = d['title']?.toString() ?? 'Playlist';
        final description = d['description']?.toString() ?? '';
        final rawTracks = d['tracks'] as List? ?? [];
        final songs = <SongModel>[];
        for (final item in rawTracks) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            songs.add(
              SongModel(
                id: m['id']?.toString() ?? m['songId']?.toString() ?? '',
                title: m['title']?.toString() ?? 'Unknown Title',
                artist: m['artist']?.toString() ?? 'Various Artists',
                album: m['album']?.toString(),
                thumbnailUrl: m['thumbnail']?.toString(),
                durationSeconds: m['duration'] is int ? m['duration'] as int : 0,
              ),
            );
          }
        }
        return CustomPlaylist(
          id: id,
          name: title,
          description: description,
          songs: songs,
          isFavorite: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      debugPrint('❌ [GET PLAYLIST ERROR] $e');
    }
    return null;
  }

}
