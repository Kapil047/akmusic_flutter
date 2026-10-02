import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../player/player_controller.dart';
import '../player/full_player_screen.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final song = playerState.currentSong;

    if (song == null) return const SizedBox.shrink();

    final durMs = playerState.duration.inMilliseconds;
    final posMs = playerState.position.inMilliseconds;
    final double progress = (durMs > 0) ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;

    final artworkUrl = song.highResThumbnail ?? song.thumbnailUrl;

    return Dismissible(
      key: ValueKey('mini_player_${song.id}'),
      direction: DismissDirection.down,
      onDismissed: (_) {
        ref.read(playerControllerProvider.notifier).closePlayer();
      },
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FullPlayerScreen(),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF16161D), // Dark glassmorphic background
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.22),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Hairline Progress Bar
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2.2,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    children: [
                      // 1. High-Res Artwork with Theme Border Glow
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.accentColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: artworkUrl != null && artworkUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: artworkUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 200,
                                  memCacheHeight: 200,
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFF22222E),
                                    child: Padding(padding: const EdgeInsets.all(6), child: Image.asset('assets/logo.png', fit: BoxFit.contain)),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF22222E),
                                  child: Padding(padding: const EdgeInsets.all(6), child: Image.asset('assets/logo.png', fit: BoxFit.contain)),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 2. Title & Artist in App Theme Typography
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. Play / Pause Button with Radiant Glow
                      if (playerState.isBuffering)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () => ref.read(playerControllerProvider.notifier).togglePlay(),
                          ),
                        ),

                      // 4. Skip Next Button
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 26),
                        tooltip: 'Next',
                        onPressed: () => ref.read(playerControllerProvider.notifier).skipNext(),
                      ),

                      // 5. Close / Dismiss Button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        tooltip: 'Close Music',
                        onPressed: () => ref.read(playerControllerProvider.notifier).closePlayer(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
