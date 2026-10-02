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
                        'Mark as Favorite Playlist ',
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
                                  ? 'Created & favorited playlist "$name"! Saved '
                                  : 'Created playlist "$name"!',
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
        elevation: 0,
        title: const Text('Your Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              onTap: (_) => setState(() {}),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.playlist_play_rounded, size: 20),
                      const SizedBox(width: 6),
                      Text('Playlists (${playlists.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Favorites (${favorites.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('History (${history.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download_done_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Offline (${downloads.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Playlists Tab
          _buildPlaylistsTab(playlists),
          // 2. Favorites Tab (Direct clean list of favorite songs)
          _buildSongList(
            songs: favorites,
            emptyIcon: Icons.favorite_border_rounded,
            emptyMessage: 'No favorite songs yet.\nTap ❤️ on any song to save it!',
            onRefresh: () => ref.read(favoritesProvider.notifier).loadFavorites(),
            isFavoritesTab: true,
          ),
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

  Widget _buildPlaylistsTab(List<CustomPlaylist> playlists) {
    if (playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.playlist_play_rounded,
                size: 64,
                color: Colors.white24,
              ),
              const SizedBox(height: 16),
              const Text(
                'No custom playlists yet.\nTap "+ New Playlist" to create your first playlist!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15),
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
                onPressed: () => _showCreatePlaylistDialog(),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: playlists.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        final pl = playlists[index];
        final art = pl.artworkUrl;

        return Card(
          color: const Color(0xFF16161E),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF22222E), width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                        child: const Center(child: Icon(Icons.queue_music_rounded, color: AppTheme.primaryColor, size: 24)),
                      ),
                    )
                  : Container(
                      width: 52,
                      height: 52,
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      child: const Center(child: Icon(Icons.queue_music_rounded, color: AppTheme.primaryColor, size: 24)),
                    ),
            ),
            title: Text(
              pl.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            subtitle: Text(
              '${pl.songs.length} ${pl.songs.length == 1 ? "song" : "songs"}',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pl.songs.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryColor, size: 36),
                    onPressed: () {
                      ref.read(playerControllerProvider.notifier).playSong(pl.songs.first, playlist: pl.songs);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                  onPressed: () => _showPlaylistDetailSheet(pl),
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
