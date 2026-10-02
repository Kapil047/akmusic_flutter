import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/playlist_model.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../player/player_controller.dart';
import '../downloads/download_controller.dart';
import '../shell/song_action_sheet.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _playlistFilter = 'all'; // 'all' or 'favorites'
  String _favoritesSubTab = 'songs'; // 'songs' or 'playlists'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog({bool markAsFavorite = false}) {
    final textController = TextEditingController();
    bool isFav = markAsFavorite;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF242430),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Create Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Punjabi Bangers, Gym Beats',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF181822),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isFav,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (val) => setDialogState(() => isFav = val ?? false),
                      ),
                      const Text(
                        'Mark as Favorite Playlist ❤️',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final name = textController.text.trim();
                    if (name.isNotEmpty) {
                      Navigator.pop(dialogCtx);
                      await ref.read(playlistProvider.notifier).createPlaylist(
                        name,
                        isFavorite: isFav,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFav
                                  ? 'Created & favorited playlist "$name"! Saved in database ❤️'
                                  : 'Created playlist "$name"! Saved in database 📁',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPlaylistDetailSheet(CustomPlaylist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Consumer(
          builder: (ctx, watchRef, _) {
            final allPlaylists = watchRef.watch(playlistProvider);
            final current = allPlaylists.where((p) => p.id == playlist.id).firstOrNull ?? playlist;

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // Handle Bar
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        current.name,
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                    if (current.isFavorite)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 12),
                                            SizedBox(width: 4),
                                            Text('Favorite', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${current.songs.length} songs (Unlimited) • Saved in Database ☁️',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.accentColor),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  current.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: current.isFavorite ? Colors.redAccent : Colors.white70,
                                  size: 26,
                                ),
                                tooltip: current.isFavorite ? 'Remove from favorites' : 'Save to favorites (Database)',
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  await ref.read(playlistProvider.notifier).toggleFavorite(current.id);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        current.isFavorite
                                            ? 'Removed "${current.name}" from favorites'
                                            : 'Saved "${current.name}" to favorites ❤️ (Database Synced)',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                              if (current.songs.isNotEmpty)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  label: const Text('Play All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.pop(sheetCtx);
                                    ref.read(playerControllerProvider.notifier).playSong(
                                      current.songs.first,
                                      playlist: current.songs,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12),

                    // Songs List
                    Expanded(
                      child: current.songs.isEmpty
                          ? const Center(
                              child: Text(
                                'No songs in this playlist yet.\nTap ⋮ on any song to add it!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white38),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: current.songs.length,
                              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                              itemBuilder: (context, idx) {
                                final song = current.songs[idx];
                                final art = song.highResThumbnail ?? song.thumbnailUrl;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: art != null && art.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: art,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 120,
                                            memCacheHeight: 120,
                                            placeholder: (_, __) => Container(
                                              width: 48,
                                              height: 48,
                                              color: const Color(0xFF22222E),
                                              child: const Center(child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 20)),
                                            ),
                                            errorWidget: (_, __, ___) => Container(
                                              width: 48,
                                              height: 48,
                                              color: Colors.grey[900],
                                              padding: const EdgeInsets.all(6),
                                              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                                            ),
                                          )
                                        : Container(
                                            width: 48,
                                            height: 48,
                                            color: Colors.grey[900],
                                            padding: const EdgeInsets.all(6),
                                            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                                          ),
                                  ),
                                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                                    onPressed: () => SongActionSheet.show(context, song),
                                  ),
                                  onTap: () {
                                    ref.read(playerControllerProvider.notifier).playSong(song, playlist: current.songs);
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
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistProvider);
    final favoritePlaylists = ref.watch(favoritePlaylistsProvider);
    final favorites = ref.watch(favoritesProvider);
    final history = ref.watch(historyProvider);
    final downloads = ref.watch(downloadControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _showCreatePlaylistDialog(),
            )
          : null,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Your Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          onTap: (_) => setState(() {}),
          tabs: [
            Tab(
              icon: const Icon(Icons.playlist_play_rounded, size: 20),
              text: 'Playlists (${playlists.length})',
            ),
            Tab(
              icon: const Icon(Icons.favorite_rounded, size: 20),
              text: 'Favorites (${favorites.length + favoritePlaylists.length})',
            ),
            Tab(
              icon: const Icon(Icons.history_rounded, size: 20),
              text: 'History (${history.length})',
            ),
            Tab(
              icon: const Icon(Icons.download_done_rounded, size: 20),
              text: 'Offline (${downloads.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Playlists Tab (Unlimited custom playlists + Favorite filter)
          _buildPlaylistsTab(playlists, favoritePlaylists),
          // 2. Favorites Tab (Both Favorite Songs and Favorite Playlists)
          _buildFavoritesTab(favorites, favoritePlaylists),
          // 3. History Tab
          _buildSongList(
            songs: history,
            emptyIcon: Icons.history_rounded,
            emptyMessage: 'No recently played songs.\nStart playing music to build your history!',
            onRefresh: () => ref.read(historyProvider.notifier).loadHistory(),
            isFavoritesTab: false,
          ),
          // 4. Offline Downloads Tab
          _buildDownloadsList(downloads),
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab(List<CustomPlaylist> allPlaylists, List<CustomPlaylist> favPlaylists) {
    final displayList = _playlistFilter == 'favorites' ? favPlaylists : allPlaylists;

    return Column(
      children: [
        // Filter Pills Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: Text('All Playlists (${allPlaylists.length})'),
                selected: _playlistFilter == 'all',
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                checkmarkColor: AppTheme.accentColor,
                labelStyle: TextStyle(
                  color: _playlistFilter == 'all' ? Colors.white : Colors.white60,
                  fontWeight: _playlistFilter == 'all' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => setState(() => _playlistFilter = 'all'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 16),
                label: Text('Favorites (${favPlaylists.length})'),
                selected: _playlistFilter == 'favorites',
                selectedColor: Colors.redAccent.withValues(alpha: 0.3),
                checkmarkColor: Colors.redAccent,
                labelStyle: TextStyle(
                  color: _playlistFilter == 'favorites' ? Colors.white : Colors.white60,
                  fontWeight: _playlistFilter == 'favorites' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => setState(() => _playlistFilter = 'favorites'),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: displayList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _playlistFilter == 'favorites' ? Icons.favorite_border_rounded : Icons.playlist_play_rounded,
                          size: 64,
                          color: _playlistFilter == 'favorites' ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _playlistFilter == 'favorites'
                              ? 'No favorite playlists yet.\nTap ❤️ on any playlist to save it to favorites!'
                              : 'No custom playlists yet.\nTap "+ New Playlist" to create your first unlimited playlist!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          label: const Text('Create Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () => _showCreatePlaylistDialog(markAsFavorite: _playlistFilter == 'favorites'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayList.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final pl = displayList[index];
                    final art = pl.artworkUrl;

                    return Card(
                      color: const Color(0xFF16161E),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: art != null && art.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: art,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 120,
                                  memCacheHeight: 120,
                                  placeholder: (_, __) => Container(
                                    width: 52,
                                    height: 52,
                                    color: const Color(0xFF22222E),
                                    child: const Center(child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 20)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 52,
                                    height: 52,
                                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                    padding: const EdgeInsets.all(8),
                                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                                  ),
                                )
                              : Container(
                                  width: 52,
                                  height: 52,
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  padding: const EdgeInsets.all(8),
                                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                                ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                pl.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                              ),
                            ),
                            if (pl.isFavorite)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 16),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${pl.songs.length} songs • Database ☁️',
                          style: const TextStyle(color: AppTheme.accentColor, fontSize: 13),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Favorite Toggle
                            IconButton(
                              icon: Icon(
                                pl.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: pl.isFavorite ? Colors.redAccent : Colors.white38,
                                size: 22,
                              ),
                              tooltip: pl.isFavorite ? 'Remove favorite' : 'Save to favorite (Database)',
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await ref.read(playlistProvider.notifier).toggleFavorite(pl.id);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      pl.isFavorite
                                          ? 'Removed "${pl.name}" from favorites'
                                          : 'Saved "${pl.name}" to favorites ❤️ (Saved in Database)',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                            // Play All
                            if (pl.songs.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryColor, size: 34),
                                onPressed: () {
                                  ref.read(playerControllerProvider.notifier).playSong(pl.songs.first, playlist: pl.songs);
                                },
                              ),
                            // Delete
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF242430),
                                    title: Text('Delete "${pl.name}"?'),
                                    content: const Text('Are you sure you want to delete this playlist from your database?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref.read(playlistProvider.notifier).deletePlaylist(pl.id);
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () => _showPlaylistDetailSheet(pl),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFavoritesTab(List<SongModel> favSongs, List<CustomPlaylist> favPlaylists) {
    return Column(
      children: [
        // Sub-tabs toggle: Songs | Playlists
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _favoritesSubTab = 'songs'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _favoritesSubTab == 'songs' ? AppTheme.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Favorite Songs (${favSongs.length})',
                      style: TextStyle(
                        color: _favoritesSubTab == 'songs' ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _favoritesSubTab = 'playlists'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _favoritesSubTab == 'playlists' ? AppTheme.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Playlists (${favPlaylists.length})',
                          style: TextStyle(
                            color: _favoritesSubTab == 'playlists' ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Sub-tab content
        Expanded(
          child: _favoritesSubTab == 'songs'
              ? _buildSongList(
                  songs: favSongs,
                  emptyIcon: Icons.favorite_border_rounded,
                  emptyMessage: 'No favorite songs yet.\nTap ❤️ on any song to save it!',
                  onRefresh: () => ref.read(favoritesProvider.notifier).loadFavorites(),
                  isFavoritesTab: true,
                )
              : _buildFavoritePlaylistsList(favPlaylists),
        ),
      ],
    );
  }

  Widget _buildFavoritePlaylistsList(List<CustomPlaylist> favPlaylists) {
    if (favPlaylists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.favorite_rounded, size: 44, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Favorite Playlists Yet',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can save any playlist to your favorites in database!\nTap ❤️ on any playlist so you can listen to it anytime later.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text('Create Favorite Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _showCreatePlaylistDialog(markAsFavorite: true),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: favPlaylists.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        final pl = favPlaylists[index];
        final art = pl.artworkUrl;

        return Card(
          color: const Color(0xFF16161E),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: art != null && art.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: art,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
                      memCacheHeight: 120,
                      placeholder: (_, __) => Container(
                        width: 52,
                        height: 52,
                        color: const Color(0xFF22222E),
                        child: const Center(child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 20)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        padding: const EdgeInsets.all(8),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                      ),
                    )
                  : Container(
                      width: 52,
                      height: 52,
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
            ),
            title: Text(
              pl.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
            subtitle: Text(
              '${pl.songs.length} songs • Saved in Database ☁️',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 22),
                  tooltip: 'Remove from favorites',
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref.read(playlistProvider.notifier).toggleFavorite(pl.id);
                    messenger.showSnackBar(
                      SnackBar(content: Text('Removed "${pl.name}" from favorites')),
                    );
                  },
                ),
                if (pl.songs.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryColor, size: 34),
                    onPressed: () {
                      ref.read(playerControllerProvider.notifier).playSong(pl.songs.first, playlist: pl.songs);
                    },
                  ),
              ],
            ),
            onTap: () => _showPlaylistDetailSheet(pl),
          ),
        );
      },
    );
  }

  Widget _buildDownloadsList(List<DownloadItem> downloads) {
    if (downloads.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_done_rounded, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No downloaded songs.\nDownload any song to listen without internet!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: downloads.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        final item = downloads[index];
        final song = item.song;
        final art = song.highResThumbnail ?? song.thumbnailUrl;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: art != null
                ? CachedNetworkImage(
                    imageUrl: art,
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
                      color: Colors.grey[900],
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
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: const Text('Downloaded MP3 (Offline)', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                onPressed: () => SongActionSheet.show(context, song),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
                onPressed: () {
                  ref.read(downloadControllerProvider.notifier).removeDownload(song.id);
                },
              ),
            ],
          ),
          onTap: () {
            ref.read(playerControllerProvider.notifier).playSong(song);
          },
        );
      },
    );
  }

  Widget _buildSongList({
    required List<SongModel> songs,
    required IconData emptyIcon,
    required String emptyMessage,
    required Future<void> Function() onRefresh,
    required bool isFavoritesTab,
  }) {
    if (songs.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppTheme.primaryColor,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(emptyIcon, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
        itemBuilder: (context, index) {
          final song = songs[index];
          final art = song.highResThumbnail ?? song.thumbnailUrl;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: art != null
                  ? CachedNetworkImage(
                      imageUrl: art,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[900],
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
            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
              onPressed: () => SongActionSheet.show(context, song),
            ),
            onTap: () {
              ref.read(playerControllerProvider.notifier).playSong(song, playlist: songs);
            },
          );
        },
      ),
    );
  }
}
