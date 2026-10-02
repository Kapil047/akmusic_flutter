import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../player/player_controller.dart';
import '../downloads/download_controller.dart';

class SongActionSheet {
  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E26),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (ctx, ref, _) {
            final isFav = ref.watch(favoritesProvider).any((s) => s.id == song.id);
            final artworkUrl = song.highResThumbnail ?? song.thumbnailUrl;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle Bar
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Song Info Header
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: artworkUrl != null && artworkUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: artworkUrl,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    width: 52,
                                    height: 52,
                                    color: Colors.grey[900],
                                    padding: const EdgeInsets.all(8),
                                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                                  ),
                                )
                              : Container(
                                  width: 52,
                                  height: 52,
                                  color: Colors.grey[900],
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
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppTheme.accentColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),

                    // 1. Play Next
                    ListTile(
                      leading: const Icon(Icons.playlist_play_rounded, color: AppTheme.accentColor, size: 28),
                      title: const Text('Play Next', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Insert right after current playing song', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        ref.read(playerControllerProvider.notifier).playNext(song);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Playing "${song.title}" next ⏭️')),
                        );
                      },
                    ),

                    // 2. Add to Queue
                    ListTile(
                      leading: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 26),
                      title: const Text('Add to Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Append to the end of your playlist', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        ref.read(playerControllerProvider.notifier).addToQueue(song);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added "${song.title}" to queue ➕')),
                        );
                      },
                    ),

                    // 3. Add to Custom Playlist
                    ListTile(
                      leading: const Icon(Icons.playlist_add_rounded, color: AppTheme.primaryColor, size: 28),
                      title: const Text('Add to Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Save to your custom playlists', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showAddToPlaylistDialog(context, ref, song);
                      },
                    ),

                    // 4. Favorite Toggle
                    ListTile(
                      leading: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? Colors.redAccent : Colors.white70,
                        size: 26,
                      ),
                      title: Text(
                        isFav ? 'Remove from Favorites' : 'Add to Favorites',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        ref.read(favoritesProvider.notifier).toggleFavorite(song);
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isFav ? 'Removed from favorites' : 'Saved to favorites ❤️')),
                        );
                      },
                    ),

                    // 5. Download Offline
                    ListTile(
                      leading: const Icon(Icons.download_rounded, color: Colors.white70, size: 26),
                      title: const Text('Download Offline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        ref.read(downloadControllerProvider.notifier).downloadSong(song);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloading "${song.title}"...')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref, SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogCtx) {
        return Consumer(
          builder: (ctx, watchRef, _) {
            final playlists = watchRef.watch(playlistProvider);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add to Playlist',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded, color: AppTheme.accentColor, size: 20),
                          label: const Text('New Playlist', style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            _showCreatePlaylistDialog(context, ref, songToAdd: song);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12),

                    if (playlists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 40),
                              const SizedBox(height: 8),
                              const Text('No custom playlists created yet.', style: TextStyle(color: Colors.white54)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogCtx);
                                  _showCreatePlaylistDialog(context, ref, songToAdd: song);
                                },
                                child: const Text('Create Your First Playlist', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final pl = playlists[index];
                            final hasSong = pl.songs.any((s) => s.id == song.id);

                            return ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.playlist_play_rounded, color: AppTheme.accentColor, size: 26),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      pl.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (pl.isFavorite)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 16),
                                    ),
                                ],
                              ),
                              subtitle: Text('${pl.songs.length} songs', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: hasSong
                                  ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22)
                                  : const Icon(Icons.add_circle_outline_rounded, color: Colors.white54, size: 22),
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(dialogCtx);
                                await ref.read(playlistProvider.notifier).addSongToPlaylist(pl.id, song);
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Added "${song.title}" to "${pl.name}" 🎉')),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref, {SongModel? songToAdd}) {
    final textController = TextEditingController();
    bool isFav = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF242430),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('New Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. My Punjabi Bangers',
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
                        'Mark as Favorite ❤️',
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
                    final messenger = ScaffoldMessenger.of(context);
                    final name = textController.text.trim();
                    if (name.isNotEmpty) {
                      Navigator.pop(dialogCtx);
                      final newPl = await ref.read(playlistProvider.notifier).createPlaylist(
                        name,
                        isFavorite: isFav,
                      );
                      if (songToAdd != null && newPl != null) {
                        await ref.read(playlistProvider.notifier).addSongToPlaylist(newPl.id, songToAdd);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              isFav
                                  ? 'Created & favorited "$name" with "${songToAdd.title}"! ❤️ (Saved in Database)'
                                  : 'Created "$name" and added "${songToAdd.title}"! 🎉',
                            ),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              isFav
                                  ? 'Favorite playlist "$name" saved to database! ❤️'
                                  : 'Playlist "$name" created! 📁',
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
}
