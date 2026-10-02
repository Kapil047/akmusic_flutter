import '../../data/models/playlist_model.dart';
import '../../core/theme/app_theme.dart';
import '../shell/song_action_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/song_model.dart';
import '../../data/services/music_api_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../player/player_controller.dart';
import 'search_history_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _topSuggestion;
  List<String> _suggestions = [];
  bool _isPersonalizedTop = false;
  List<SongModel> _results = [];
  bool _isLoading = false;
  String _selectedType = 'song';

  final List<String> _trendingSeeds = [
    'Arijit Singh',
    'Trending Hindi',
    'Sidhu Moosewala',
    'Diljit Dosanjh',
    'Romantic Lo-Fi',
    'Bollywood 2026',
    'Punjabi Hits',
    'Atif Aslam',
    'AP Dhillon',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _topSuggestion = null;
        _isPersonalizedTop = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final api = ref.read(musicApiServiceProvider);
        final response = await api.getSuggestions(query.trim());
        if (mounted && _searchController.text.trim().isNotEmpty) {
          setState(() {
            _topSuggestion = response.top;
            _suggestions = response.all;
            _isPersonalizedTop = response.isPersonalized;
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();

    // 1. Record search for personalization
    ref.read(musicApiServiceProvider).recordSearch(query);

    // 2. Save to local search history
    ref.read(searchHistoryProvider.notifier).addQuery(query);

    setState(() {
      _isLoading = true;
      _suggestions = [];
      _topSuggestion = null;
    });

    try {
      final api = ref.read(musicApiServiceProvider);
      final songs = await api.search(query.trim(), type: _selectedType);
      if (mounted) {
        setState(() {
          _results = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildTopSuggestionCard() {
    if (_topSuggestion == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C5CE7).withValues(alpha: 0.25),
            const Color(0xFF6C5CE7).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: const Icon(Icons.auto_awesome, color: Color(0xFF6C5CE7), size: 24),
        title: Text(
          _topSuggestion!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          _isPersonalizedTop ? 'Suggested for you' : 'Top Suggestion',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF6C5CE7), size: 20),
        onTap: () {
          _searchController.text = _topSuggestion!;
          _performSearch(_topSuggestion!);
        },
      ),
    );
  }

  void _openPlaylistSheet(SongModel item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return FutureBuilder<CustomPlaylist?>(
          future: ref.read(musicApiServiceProvider).getPlaylist(item.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
              );
            }

            final playlist = snapshot.data ??
                CustomPlaylist(
                  id: item.id,
                  name: item.title,
                  description: item.artist,
                  songs: [],
                  thumbnailUrl: item.highResThumbnail ?? item.thumbnailUrl,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                );

            return Consumer(
              builder: (ctx, watchRef, _) {
                final allSaved = watchRef.watch(playlistProvider);
                final savedPl = allSaved.where((p) => p.id == playlist.id).firstOrNull;
                final isFav = savedPl?.isFavorite ?? false;

                return DraggableScrollableSheet(
                  initialChildSize: 0.75,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  expand: false,
                  builder: (_, scrollController) {
                    return Column(
                      children: [
                        // Handle bar
                        Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12, bottom: 12),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                        // Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: (item.thumbnailUrl ?? item.highResThumbnail) != null
                                    ? CachedNetworkImage(
                                        imageUrl: (item.thumbnailUrl ?? item.highResThumbnail)!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 140,
                                        memCacheHeight: 140,
                                        placeholder: (_, __) => Container(
                                          width: 56,
                                          height: 56,
                                          color: const Color(0xFF22222E),
                                          child: const Center(child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 22)),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          width: 56,
                                          height: 56,
                                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                          padding: const EdgeInsets.all(8),
                                          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                                        ),
                                      )
                                    : Container(
                                        width: 56,
                                        height: 56,
                                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                        padding: const EdgeInsets.all(8),
                                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      playlist.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${playlist.songs.length} songs',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.accentColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Action buttons row: Play All & Save to Favorites
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              if (playlist.songs.isNotEmpty)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                    label: const Text('Play All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      Navigator.pop(sheetCtx);
                                      ref.read(playerControllerProvider.notifier).playSong(
                                        playlist.songs.first,
                                        playlist: playlist.songs,
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: isFav ? Colors.redAccent : AppTheme.primaryColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: Icon(
                                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: isFav ? Colors.redAccent : Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    isFav ? 'Favorited ❤️' : 'Save to Favorites',
                                    style: TextStyle(
                                      color: isFav ? Colors.redAccent : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    if (isFav) {
                                      await ref.read(playlistProvider.notifier).toggleFavorite(playlist.id);
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Removed "${playlist.name}" from favorites')),
                                      );
                                    } else {
                                      final toSave = playlist.copyWith(isFavorite: true);
                                      await ref.read(playlistProvider.notifier).savePlaylist(toSave);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Saved "${playlist.name}" to Favorite Playlists in database! ❤️'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white12),
                        // Tracklist
                        Expanded(
                          child: playlist.songs.isEmpty
                              ? const Center(
                                  child: Text('No tracks found in playlist', style: TextStyle(color: Colors.white38)),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  itemCount: playlist.songs.length,
                                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                                  itemBuilder: (context, sIdx) {
                                    final s = playlist.songs[sIdx];
                                    final sArt = s.highResThumbnail ?? s.thumbnailUrl;
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: sArt != null
                                            ? CachedNetworkImage(
                                                imageUrl: sArt,
                                                width: 42,
                                                height: 42,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(width: 42, height: 42, color: Colors.grey[900]),
                                      ),
                                      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                      subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
                                        onPressed: () => SongActionSheet.show(context, s),
                                      ),
                                      onTap: () {
                                        ref.read(playerControllerProvider.notifier).playSong(s, playlist: playlist.songs);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchHistory = ref.watch(searchHistoryProvider);
    final isSearchActive = _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Search Music', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // 1. Search Text Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              onSubmitted: _performSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search songs ...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6C5CE7)),
                suffixIcon: isSearchActive
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                          setState(() {
                            _results = [];
                            _suggestions = [];
                            _topSuggestion = null;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2. Filter Chips (Commented out for unified clean song search architecture)
          /*
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('Songs', 'song'),
                const SizedBox(width: 8),
                _buildFilterChip('Videos', 'video'),
                const SizedBox(width: 8),
                _buildFilterChip('Albums', 'album'),
                const SizedBox(width: 8),
                _buildFilterChip('Artists', 'artist'),
                const SizedBox(width: 8),
                _buildFilterChip('Playlists', 'playlist'),
              ],
            ),
          ),
          */

          // 3. Live Suggestions Dropdown (Top 1 Highlighted Card + Rest)
          if (_suggestions.isNotEmpty || _topSuggestion != null)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // ⭐ Top 1 Highlighted Card
                  _buildTopSuggestionCard(),

                  // Remaining Suggestions
                  ..._suggestions.where((s) => s != _topSuggestion).map((suggestion) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                      title: Text(suggestion, style: const TextStyle(color: Colors.white70)),
                      trailing: const Icon(Icons.north_west_rounded, color: Colors.white24, size: 18),
                      onTap: () {
                        _searchController.text = suggestion;
                        _performSearch(suggestion);
                      },
                    );
                  }),
                ],
              ),
            )
          // 4. Loading indicator
          else if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
              ),
            )
          // 5. Results List
          else if (_results.isNotEmpty)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final song = _results[index];
                  final isFav = ref.watch(favoritesProvider).any((s) => s.id == song.id);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: (song.thumbnailUrl ?? song.highResThumbnail) != null
                          ? CachedNetworkImage(
                              imageUrl: (song.thumbnailUrl ?? song.highResThumbnail)!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              memCacheWidth: 120,
                              memCacheHeight: 120,
                              placeholder: (_, __) => Container(
                                width: 50,
                                height: 50,
                                color: const Color(0xFF22222E),
                                child: const Center(child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 20)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: const Color(0xFF22222E),
                                padding: const EdgeInsets.all(6),
                                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[900],
                              padding: const EdgeInsets.all(6),
                              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                            ),
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    subtitle: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(song.durationSeconds),
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                          tooltip: 'Options',
                          onPressed: () => SongActionSheet.show(context, song),
                        ),
                        IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? Colors.redAccent : Colors.white38,
                            size: 20,
                          ),
                          onPressed: () {
                            ref.read(favoritesProvider.notifier).toggleFavorite(song);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      ref.read(playerControllerProvider.notifier).playSong(song);
                    },
                  );
                },
              ),
            )
          // 6. Search History & Trending Suggestions View
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Recent Searches
                  if (searchHistory.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Searches',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () => ref.read(searchHistoryProvider.notifier).clearAll(),
                          child: const Text('Clear All', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...searchHistory.map((query) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_rounded, color: Colors.white38, size: 20),
                          title: Text(query, style: const TextStyle(color: Colors.white70)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white24, size: 18),
                            onPressed: () => ref.read(searchHistoryProvider.notifier).removeQuery(query),
                          ),
                          onTap: () {
                            _searchController.text = query;
                            _performSearch(query);
                          },
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Trending Suggestions Chips
                  const Text(
                    'Trending Suggestions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _trendingSeeds.map((seed) {
                      return ActionChip(
                        backgroundColor: const Color(0xFF1E1E1E),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        avatar: const Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFF6C5CE7)),
                        label: Text(seed, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        onPressed: () {
                          _searchController.text = seed;
                          _performSearch(seed);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF6C5CE7),
      backgroundColor: const Color(0xFF1E1E1E),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() => _selectedType = type);
        if (_searchController.text.trim().isNotEmpty) {
          _performSearch(_searchController.text.trim());
        }
      },
    );
  }
}
