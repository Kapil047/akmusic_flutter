import '../../data/models/song_model.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../player/player_controller.dart';
import '../../data/repositories/user_repository.dart';
import '../downloads/download_controller.dart';
import '../settings/settings_controller.dart';
import 'lyrics_sheet.dart';

class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showSaveQueueDialog(BuildContext context, WidgetRef ref, List<dynamic> queue) {
    final textController = TextEditingController(text: 'Queue Playlist ${DateTime.now().day}/${DateTime.now().month}');
    bool isFav = true;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF242430),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Save Queue as Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save all ${queue.length} songs currently in your queue to database so you can listen later.',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Playlist Name',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF181822),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isFav,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (val) => setDialogState(() => isFav = val ?? true),
                      ),
                      const Text(
                        'Save to Favorites ❤️',
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
                      final songList = queue.whereType<SongModel>().toList();
                      await ref.read(playlistProvider.notifier).createPlaylist(
                        name,
                        tracks: songList,
                        isFavorite: isFav,
                      );
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            isFav
                                ? 'Saved ${songList.length} songs to favorite playlist "$name" in database! ❤️'
                                : 'Saved ${songList.length} songs to "$name" in database! 📁',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Save Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQueueSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Consumer(
              builder: (ctx, watchRef, _) {
                final state = watchRef.watch(playerControllerProvider);
                final queue = state.queue;
                final curIdx = state.queueIndex;

                return Column(
                  children: [
                    // Handle Bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Now Playing Queue',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                '${queue.length} songs in playlist',
                                style: const TextStyle(fontSize: 12, color: Colors.white54),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${curIdx + 1} of ${queue.length}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)),
                              ),
                              if (queue.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.bookmark_add_rounded, color: AppTheme.accentColor, size: 22),
                                  tooltip: 'Save Queue to Favorite Playlists (Database)',
                                  onPressed: () => _showSaveQueueDialog(context, ref, queue),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    // Queue List
                    Expanded(
                      child: queue.isEmpty
                          ? const Center(
                              child: Text('No songs in queue', style: TextStyle(color: Colors.white38)),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: queue.length,
                              itemBuilder: (context, index) {
                                final song = queue[index];
                                final isCurrent = index == curIdx;

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isCurrent ? const Color(0xFF6C5CE7).withValues(alpha: 0.15) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isCurrent
                                        ? Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.4), width: 1)
                                        : null,
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: isCurrent ? const Color(0xFF6C5CE7) : Colors.white38,
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: song.thumbnailUrl != null
                                              ? CachedNetworkImage(
                                                  imageUrl: song.thumbnailUrl!,
                                                  width: 44,
                                                  height: 44,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) => Container(
                                                    width: 44,
                                                    height: 44,
                                                    color: Colors.grey[900],
                                                    child: Image.asset('assets/logo.png', width: 24, height: 24),
                                                  ),
                                                )
                                              : Container(
                                                  width: 44,
                                                  height: 44,
                                                  color: Colors.grey[900],
                                                  child: Image.asset('assets/logo.png', width: 24, height: 24),
                                                ),
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isCurrent ? const Color(0xFF6C5CE7) : Colors.white,
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                    trailing: isCurrent
                                        ? const Icon(Icons.graphic_eq_rounded, color: Color(0xFF6C5CE7), size: 22)
                                        : const Icon(Icons.play_arrow_rounded, color: Colors.white38, size: 22),
                                    onTap: () {
                                      ref.read(playerControllerProvider.notifier).playSong(song, playlist: queue);
                                    },
                                  ),
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

  void _showSpeedSheet(BuildContext context, WidgetRef ref, double currentSpeed) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Playback Speed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: speeds.map((speed) {
                  final isSelected = currentSpeed == speed;
                  return ChoiceChip(
                    label: Text('${speed}x'),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6C5CE7),
                    backgroundColor: const Color(0xFF2C2C2C),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      ref.read(playerControllerProvider.notifier).setSpeed(speed);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final song = playerState.currentSong;
    final userSettings = ref.watch(settingsControllerProvider);
    final seekSec = userSettings.seekDurationSeconds;
    final queue = playerState.queue;
    final curIdx = playerState.queueIndex;

    if (song == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: Text('No song selected', style: TextStyle(color: Colors.white54))),
      );
    }

    final isFav = ref.watch(favoritesProvider).any((s) => s.id == song.id);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 36, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Now Playing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // ⬇️ Direct Download Button
          Builder(
            builder: (context) {
              final downloads = ref.watch(downloadControllerProvider);
              final isDownloaded = downloads.any((d) => d.song.id == song.id);
              final isDownloading = ref.watch(downloadControllerProvider.notifier).isDownloading(song.id);

              if (isDownloading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Color(0xFF6C5CE7), strokeWidth: 2),
                    ),
                  ),
                );
              }

              if (isDownloaded) {
                return IconButton(
                  icon: const Icon(Icons.download_done_rounded, color: Colors.greenAccent),
                  tooltip: 'Downloaded Offline',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Song already downloaded for offline playback!')),
                    );
                  },
                );
              }

              return IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white70),
                tooltip: 'Download Song',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Downloading "${song.title}"...')),
                  );
                  final success = await ref.read(downloadControllerProvider.notifier).downloadSong(song);
                  if (context.mounted) {
                    if (success) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('"${song.title}" downloaded offline! 🎉')),
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Download completed!')),
                      );
                    }
                  }
                },
              );
            },
          ),
          // Lyrics Button
          IconButton(
            icon: const Icon(Icons.lyrics_rounded, color: Colors.white70),
            tooltip: 'Lyrics',
            onPressed: () => LyricsSheet.show(context, song),
          ),
          // Speed Button
          IconButton(
            icon: const Icon(Icons.speed_rounded, color: Colors.white70),
            tooltip: 'Playback Speed',
            onPressed: () => _showSpeedSheet(context, ref, playerState.speed),
          ),
          // ⏹️ Close / Stop Button
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            tooltip: 'Stop & Close',
            onPressed: () {
              ref.read(playerControllerProvider.notifier).closePlayer();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                // Horizontal Swipe Gestures
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! < -250) {
                      ref.read(playerControllerProvider.notifier).skipNext();
                    } else if (details.primaryVelocity! > 250) {
                      ref.read(playerControllerProvider.notifier).skipPrev();
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 1. High-Res Artwork
                      Center(
                        child: Container(
                          width: 275,
                          height: 275,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 2,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: (song.highResThumbnail ?? song.thumbnailUrl) != null
                                ? CachedNetworkImage(
                                    imageUrl: (song.highResThumbnail ?? song.thumbnailUrl)!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 800,
                                    memCacheHeight: 800,
                                    fadeInDuration: const Duration(milliseconds: 200),
                                    errorWidget: (_, __, ___) => Container(
                                      color: const Color(0xFF1E1E28),
                                      child: Image.asset('assets/logo.png', width: 90, height: 90),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF1E1E28),
                                    child: Image.asset('assets/logo.png', width: 90, height: 90),
                                  ),
                          ),
                        ),
                      ),

                      // 2. Title, Artist & Favorite Heart
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.accentColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFav ? Colors.redAccent : Colors.white54,
                              size: 28,
                            ),
                            onPressed: () {
                              ref.read(favoritesProvider.notifier).toggleFavorite(song);
                            },
                          ),
                        ],
                      ),

                      // 3. Custom Seekbar with Elapsed & Total Timers
                      Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF6C5CE7),
                              inactiveTrackColor: Colors.white12,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              min: 0.0,
                              max: playerState.duration.inMilliseconds.toDouble() > 0
                                  ? playerState.duration.inMilliseconds.toDouble()
                                  : 1.0,
                              value: playerState.position.inMilliseconds
                                  .toDouble()
                                  .clamp(0.0, playerState.duration.inMilliseconds.toDouble() > 0 ? playerState.duration.inMilliseconds.toDouble() : 1.0),
                              onChanged: (val) {
                                ref.read(playerControllerProvider.notifier).seekTo(Duration(milliseconds: val.toInt()));
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(playerState.position), style: const TextStyle(fontSize: 12, color: Colors.white38)),
                                Text(_formatDuration(playerState.duration), style: const TextStyle(fontSize: 12, color: Colors.white38)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // 4. Primary Playback Controls with -X s & +X s
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Rewind -10s
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 32),
                            tooltip: 'Rewind ${seekSec}s',
                            onPressed: () => ref.read(playerControllerProvider.notifier).rewindBy(seekSec),
                          ),

                          // Previous Song
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                            tooltip: 'Previous Song',
                            onPressed: () => ref.read(playerControllerProvider.notifier).skipPrev(),
                          ),

                          // Play / Pause / Buffering Spinner
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.45),
                                  blurRadius: 22,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: playerState.isBuffering
                                ? const Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                                    onPressed: () => ref.read(playerControllerProvider.notifier).togglePlay(),
                                  ),
                          ),

                          // Next Song
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                            tooltip: 'Next Song',
                            onPressed: () => ref.read(playerControllerProvider.notifier).skipNext(),
                          ),

                          // Forward +10s
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 32),
                            tooltip: 'Forward ${seekSec}s',
                            onPressed: () => ref.read(playerControllerProvider.notifier).fastForwardBy(seekSec),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Bottom "Now Playing" Queue Drawer Handle (Matching user's screenshot)
            GestureDetector(
              onTap: () => _showQueueSheet(context, ref),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF181818),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.orangeAccent, size: 26),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Now playing',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${curIdx + 1} / ${queue.isNotEmpty ? queue.length : 1}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                      onPressed: () => _showQueueSheet(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
