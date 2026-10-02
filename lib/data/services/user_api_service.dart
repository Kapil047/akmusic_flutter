import '../models/playlist_model.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/song_model.dart';

class UserApiService {
  final ApiClient _client;

  UserApiService(this._client);

  /// Get favorite songs from Firestore
  Future<List<SongModel>> getFavorites() async {
    try {
      final response = await _client.dio.get('/user/favorites');
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List).map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          return SongModel(
            id: m['songId'] ?? '',
            title: m['title'] ?? 'Unknown Title',
            artist: m['artist'] ?? 'Unknown Artist',
            thumbnailUrl: m['thumbnail'],
            durationSeconds: m['duration'] is int ? m['duration'] : 0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('❌ [GET FAVORITES ERROR] $e');
    }
    return [];
  }

  /// Add song to Firestore favorites
  Future<bool> addFavorite(SongModel song) async {
    try {
      await _client.dio.post(
        '/user/favorites',
        data: song.toJson(),
      );
      debugPrint('❤️ [FAVORITE ADDED] "${song.title}" saved to Firestore');
      return true;
    } catch (e) {
      debugPrint('❌ [ADD FAVORITE ERROR] $e');
      return false;
    }
  }

  /// Remove song from Firestore favorites
  Future<bool> removeFavorite(String songId) async {
    try {
      await _client.dio.delete('/user/favorites/$songId');
      debugPrint('💔 [FAVORITE REMOVED] "$songId" removed from Firestore');
      return true;
    } catch (e) {
      debugPrint('❌ [REMOVE FAVORITE ERROR] $e');
      return false;
    }
  }

  /// Log playback history to Firestore
  Future<void> recordHistory(SongModel song) async {
    try {
      await _client.dio.post(
        '/user/history',
        data: song.toJson(),
      );
      debugPrint('🕒 [HISTORY RECORDED] "${song.title}" logged to Firestore');
    } catch (e) {
      debugPrint('❌ [HISTORY RECORD ERROR] $e');
    }
  }

  /// Get playback history from Firestore
  Future<List<SongModel>> getHistory() async {
    try {
      final response = await _client.dio.get('/user/history');
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List).map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          return SongModel(
            id: m['songId'] ?? '',
            title: m['title'] ?? 'Unknown Title',
            artist: m['artist'] ?? 'Unknown Artist',
            thumbnailUrl: m['thumbnail'],
            durationSeconds: m['duration'] is int ? m['duration'] : 0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('❌ [GET HISTORY ERROR] $e');
    }
    return [];
  }

  // ---------------- PLAYLISTS ----------------

  /// Get user custom playlists from Firestore
  Future<List<CustomPlaylist>> getPlaylists({bool onlyFavorite = false}) async {
    try {
      final response = await _client.dio.get(
        '/user/playlists',
        queryParameters: onlyFavorite ? {'favorite': 'true'} : null,
      );
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => CustomPlaylist.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ [GET PLAYLISTS ERROR] $e');
    }
    return [];
  }

  /// Create or save a custom playlist to Firestore
  Future<CustomPlaylist?> createPlaylist(
    String name, {
    String description = '',
    List<SongModel> tracks = const [],
    bool isFavorite = false,
    String? thumbnailUrl,
    String? id,
  }) async {
    try {
      final response = await _client.dio.post(
        '/user/playlists',
        data: {
          if (id != null) 'id': id,
          'name': name.trim(),
          'description': description.trim(),
          'tracks': tracks.map((s) => s.toJson()).toList(),
          'isFavorite': isFavorite,
          if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        },
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        debugPrint('📁 [PLAYLIST SAVED] "$name" saved to Firestore (isFavorite: $isFavorite)');
        return CustomPlaylist.fromJson(Map<String, dynamic>.from(data['data'] as Map));
      }
    } catch (e) {
      debugPrint('❌ [CREATE PLAYLIST ERROR] $e');
    }
    return null;
  }

  /// Save complete playlist directly to database
  Future<CustomPlaylist?> savePlaylist(CustomPlaylist playlist) async {
    return createPlaylist(
      playlist.name,
      description: playlist.description,
      tracks: playlist.songs,
      isFavorite: playlist.isFavorite,
      thumbnailUrl: playlist.artworkUrl,
      id: playlist.id,
    );
  }

  /// Toggle favorite on a playlist in database
  Future<bool> togglePlaylistFavorite(String playlistId, bool isFavorite) async {
    try {
      final response = await _client.dio.patch(
        '/user/playlists/$playlistId/favorite',
        data: {'isFavorite': isFavorite},
      );
      final data = response.data;
      debugPrint('⭐ [PLAYLIST FAVORITE] $playlistId => isFavorite: $isFavorite');
      return data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('❌ [TOGGLE PLAYLIST FAVORITE ERROR] $e');
      return false;
    }
  }

  /// Add track to playlist (Unlimited tracks)
  Future<bool> addTrackToPlaylist(String playlistId, SongModel song) async {
    try {
      final response = await _client.dio.post(
        '/user/playlists/$playlistId/tracks',
        data: song.toJson(),
      );
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('❌ [ADD TRACK TO PLAYLIST ERROR] $e');
      return false;
    }
  }

  /// Delete playlist from database
  Future<bool> deletePlaylist(String playlistId) async {
    try {
      final response = await _client.dio.delete('/user/playlists/$playlistId');
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('❌ [DELETE PLAYLIST ERROR] $e');
      return false;
    }
  }
}
