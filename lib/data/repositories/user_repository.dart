import '../models/playlist_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/song_model.dart';
import '../../data/services/user_api_service.dart';
import '../services/music_api_service.dart';

final userApiServiceProvider = Provider<UserApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return UserApiService(client);
});

// 1. Favorites Notifier (Songs)
class FavoritesNotifier extends StateNotifier<List<SongModel>> {
  final UserApiService _api;

  FavoritesNotifier(this._api) : super([]) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final list = await _api.getFavorites();
    state = list;
  }

  bool isFavorite(String songId) {
    return state.any((s) => s.id == songId);
  }

  Future<void> toggleFavorite(SongModel song) async {
    final exists = isFavorite(song.id);
    if (exists) {
      // Optimistic removal
      state = state.where((s) => s.id != song.id).toList();
      await _api.removeFavorite(song.id);
    } else {
      // Optimistic add
      state = [song, ...state];
      await _api.addFavorite(song);
    }
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<SongModel>>((ref) {
  final api = ref.watch(userApiServiceProvider);
  return FavoritesNotifier(api);
});

// 2. Playback History Notifier
class HistoryNotifier extends StateNotifier<List<SongModel>> {
  final UserApiService _api;

  HistoryNotifier(this._api) : super([]) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    final list = await _api.getHistory();
    state = list;
  }

  Future<void> addHistory(SongModel song) async {
    // Add locally to top of history
    state = [song, ...state.where((s) => s.id != song.id)];
    await _api.recordHistory(song);
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<SongModel>>((ref) {
  final api = ref.watch(userApiServiceProvider);
  return HistoryNotifier(api);
});

// 3. Custom Playlists Notifier (Saved in database, unlimited songs, favorite support)
class PlaylistNotifier extends StateNotifier<List<CustomPlaylist>> {
  final UserApiService _api;

  PlaylistNotifier(this._api) : super([]) {
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    final list = await _api.getPlaylists();
    state = list;
  }

  Future<CustomPlaylist?> createPlaylist(
    String name, {
    String description = '',
    List<SongModel> tracks = const [],
    bool isFavorite = false,
    String? thumbnailUrl,
  }) async {
    final newPl = await _api.createPlaylist(
      name,
      description: description,
      tracks: tracks,
      isFavorite: isFavorite,
      thumbnailUrl: thumbnailUrl,
    );
    if (newPl != null) {
      state = [newPl, ...state];
      return newPl;
    }
    // Local fallback if offline
    final fallback = CustomPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      songs: tracks,
      isFavorite: isFavorite,
      thumbnailUrl: thumbnailUrl,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    state = [fallback, ...state];
    return fallback;
  }

  Future<bool> toggleFavorite(String playlistId) async {
    final idx = state.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return false;

    final current = state[idx];
    final newStatus = !current.isFavorite;
    final updated = current.copyWith(isFavorite: newStatus);

    final updatedList = List<CustomPlaylist>.from(state);
    updatedList[idx] = updated;
    state = updatedList;

    // Sync to Firestore database
    return await _api.togglePlaylistFavorite(playlistId, newStatus);
  }

  Future<CustomPlaylist?> savePlaylist(CustomPlaylist playlist) async {
    final existingIdx = state.indexWhere((p) => p.id == playlist.id);
    if (existingIdx != -1) {
      final updatedList = List<CustomPlaylist>.from(state);
      updatedList[existingIdx] = playlist;
      state = updatedList;
    } else {
      state = [playlist, ...state];
    }
    return await _api.savePlaylist(playlist);
  }

  Future<bool> addSongToPlaylist(String playlistId, SongModel song) async {
    final idx = state.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return false;

    final pl = state[idx];
    if (pl.songs.any((s) => s.id == song.id)) return true; // already added

    final updatedSongs = [...pl.songs, song];
    final updatedPl = pl.copyWith(songs: updatedSongs);
    final updatedList = List<CustomPlaylist>.from(state);
    updatedList[idx] = updatedPl;
    state = updatedList;

    // Sync to backend database
    return await _api.addTrackToPlaylist(playlistId, song);
  }

  Future<bool> deletePlaylist(String playlistId) async {
    state = state.where((p) => p.id != playlistId).toList();
    return await _api.deletePlaylist(playlistId);
  }
}

final playlistProvider = StateNotifierProvider<PlaylistNotifier, List<CustomPlaylist>>((ref) {
  final api = ref.watch(userApiServiceProvider);
  return PlaylistNotifier(api);
});

// 4. Favorite Playlists Provider
final favoritePlaylistsProvider = Provider<List<CustomPlaylist>>((ref) {
  return ref.watch(playlistProvider).where((p) => p.isFavorite).toList();
});
