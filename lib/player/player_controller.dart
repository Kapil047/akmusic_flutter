import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/song_model.dart';
import 'audio_player_handler.dart';

final audioHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  throw UnimplementedError('Initialize audioHandler in main.dart');
});

class PlayerStateData {
  final MediaItem? currentItem;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double speed;

  const PlayerStateData({
    this.currentItem,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
  });

  PlayerStateData copyWith({
    MediaItem? currentItem,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    double? speed,
  }) {
    return PlayerStateData(
      currentItem: currentItem ?? this.currentItem,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
    );
  }
}

class PlayerController extends StateNotifier<PlayerStateData> {
  final AudioPlayerHandler _handler;

  PlayerController(this._handler) : super(const PlayerStateData()) {
    // Listen to mediaItem changes
    _handler.mediaItem.listen((item) {
      state = state.copyWith(
        currentItem: item,
        duration: item?.duration ?? Duration.zero,
      );
    });

    // Listen to playback state (playing, buffering, speed)
    _handler.playbackState.listen((playback) {
      state = state.copyWith(
        isPlaying: playback.playing,
        isBuffering: playback.processingState == AudioProcessingState.buffering,
        position: playback.position,
        speed: playback.speed,
      );
    });

    // Continuously listen to position for smooth seekbar updates
    _handler.player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });
  }

  void playSong(SongModel song) => _handler.playSong(song);
  void togglePlay() {
    if (state.isPlaying) {
      _handler.pause();
    } else {
      _handler.play();
    }
  }

  void seekTo(Duration position) => _handler.seek(position);
  void skipNext() => _handler.skipToNext();
  void skipPrev() => _handler.skipToPrevious();
  void setSpeed(double speed) => _handler.setSpeed(speed);
}

final playerControllerProvider = StateNotifierProvider<PlayerController, PlayerStateData>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return PlayerController(handler);
});
