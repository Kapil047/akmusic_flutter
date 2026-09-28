import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../player/player_controller.dart';
import '../player/full_player_screen.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final currentItem = playerState.currentItem;

    if (currentItem == null) return const SizedBox.shrink();

    final progress = (playerState.duration.inMilliseconds > 0)
        ? (playerState.position.inMilliseconds / playerState.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, anim, _) => const FullPlayerScreen(),
            transitionsBuilder: (context, anim, _, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              );
            },
          ),
        );
      },
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            // Linear Progress Indicator
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Artwork Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: currentItem.artUri != null
                          ? CachedNetworkImage(
                              imageUrl: currentItem.artUri.toString(),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white54),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              color: Colors.grey[850],
                              child: const Icon(Icons.music_note, color: Colors.white54),
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Title & Artist
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentItem.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentItem.artist ?? 'AK Music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Play/Pause Action
                    IconButton(
                      icon: playerState.isBuffering
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                      onPressed: () => ref.read(playerControllerProvider.notifier).togglePlay(),
                    ),
                    // Next Action
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 28, color: Colors.white70),
                      onPressed: () => ref.read(playerControllerProvider.notifier).skipNext(),
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
