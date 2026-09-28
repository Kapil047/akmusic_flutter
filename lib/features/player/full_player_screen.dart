import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../player/player_controller.dart';

class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showSpeedDialog(BuildContext context, WidgetRef ref, double currentSpeed) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Playback Speed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: speeds.map((s) {
                  final isSelected = (s == currentSpeed);
                  return ChoiceChip(
                    label: Text('${s}x'),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6C5CE7),
                    onSelected: (_) {
                      ref.read(playerControllerProvider.notifier).setSpeed(s);
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
    final currentItem = playerState.currentItem;

    if (currentItem == null) {
      return const Scaffold(body: Center(child: Text('No song playing')));
    }

    final totalSeconds = playerState.duration.inSeconds.toDouble();
    final currentSeconds = playerState.position.inSeconds.toDouble().clamp(0.0, totalSeconds > 0 ? totalSeconds : 0.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Now Playing', style: TextStyle(fontSize: 16, color: Colors.white70)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Text('${playerState.speed}x', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showSpeedDialog(context, ref, playerState.speed),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 8),
              // Big Album Art
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.width * 0.8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withOpacity(0.35),
                        blurRadius: 35,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: currentItem.artUri != null
                        ? CachedNetworkImage(
                            imageUrl: currentItem.artUri.toString(),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[900],
                              child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                            ),
                          )
                        : Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                          ),
                  ),
                ),
              ),

              // Title, Artist & Like Action
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentItem.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currentItem.artist ?? 'AK Music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.favorite_border_rounded, size: 28, color: Colors.white70),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Added to Favorites ❤️')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Progress Seekbar
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF6C5CE7),
                      inactiveTrackColor: Colors.white24,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: currentSeconds,
                      min: 0.0,
                      max: totalSeconds > 0 ? totalSeconds : 1.0,
                      onChanged: (val) {
                        ref.read(playerControllerProvider.notifier).seekTo(Duration(seconds: val.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(playerState.position), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        Text(_formatDuration(playerState.duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),

              // Player Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, color: Colors.white54, size: 24),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 38),
                    onPressed: () => ref.read(playerControllerProvider.notifier).skipPrev(),
                  ),
                  // Big Play/Pause
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C5CE7),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: playerState.isBuffering
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                          : Icon(
                              playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                      onPressed: () => ref.read(playerControllerProvider.notifier).togglePlay(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 38),
                    onPressed: () => ref.read(playerControllerProvider.notifier).skipNext(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.repeat_rounded, color: Colors.white54, size: 24),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
