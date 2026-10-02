import '../data/services/music_api_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/song_model.dart';
import '../data/repositories/user_repository.dart';
import 'audio_player_handler.dart';

final audioHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  throw UnimplementedError('Initialize audioHandler in main.dart');
});

class PlayerStateData {
  final MediaItem? currentItem;
  final SongModel? currentSong;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double speed;
  final List<SongModel> queue;
  final int queueIndex;

  const PlayerStateData({
    this.currentItem,
    this.currentSong,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.queue = const [],
    this.queueIndex = 0,
  });

  PlayerStateData copyWith({
    MediaItem? currentItem,
    SongModel? currentSong,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    double? speed,
    List<SongModel>? queue,
    int? queueIndex,
    bool clearCurrentSong = false,
  }) {
    return PlayerStateData(
      currentItem: clearCurrentSong ? null : (currentItem ?? this.currentItem),
      currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
      isPlaying: clearCurrentSong ? false : (isPlaying ?? this.isPlaying),
      isBuffering: clearCurrentSong ? false : (isBuffering ?? this.isBuffering),
      position: clearCurrentSong ? Duration.zero : (position ?? this.position),
      duration: clearCurrentSong ? Duration.zero : (duration ?? this.duration),
      speed: speed ?? this.speed,
      queue: clearCurrentSong ? const [] : (queue ?? this.queue),
      queueIndex: clearCurrentSong ? 0 : (queueIndex ?? this.queueIndex),
    );
  }
}

class PlayerController extends StateNotifier<PlayerStateData> {
  final AudioPlayerHandler _handler;
  final Ref _ref;

  PlayerController(this._handler, this._ref) : super(const PlayerStateData()) {
    // 1. Auto-sync currentSong, details, and artwork on ANY song transition (manual or auto-advance)
    _handler.mediaItem.listen((item) {
      if (item == null) return;

      final queue = _handler.songQueue;
      final curIdx = _handler.currentIndex;
      SongModel? newSong;

      if (curIdx >= 0 && curIdx < queue.length && queue[curIdx].id == item.id) {
        newSong = queue[curIdx];
      } else {
        newSong = queue.where((s) => s.id == item.id).firstOrNull ??
            SongModel(
              id: item.id,
              title: item.title,
              artist: item.artist ?? 'Various Artists',
              album: item.album ?? 'AK Music',
              durationSeconds: item.duration?.inSeconds ?? 0,
              thumbnailUrl: item.artUri?.toString(),
            );
      }

      final hasChanged = state.currentSong?.id != newSong.id;

      state = state.copyWith(
        currentItem: item,
        currentSong: newSong,
        duration: item.duration ?? Duration.zero,
        queue: queue,
        queueIndex: curIdx >= 0 ? curIdx : 0,
      );

      // Auto-record history & personalization metrics when song changes/advances
      if (hasChanged) {
        _ref.read(historyProvider.notifier).addHistory(newSong);
        _ref.read(musicApiServiceProvider).recordPlay(
          songId: newSong.id,
          title: newSong.title,
          artist: newSong.artist,
          thumbnail: newSong.highResThumbnail ?? newSong.thumbnailUrl,
          duration: newSong.durationSeconds,
        );
      }
    });

    _handler.playbackState.listen((playback) {
      final isBuff = playback.processingState == AudioProcessingState.buffering ||
          playback.processingState == AudioProcessingState.loading;
      state = state.copyWith(
        isPlaying: playback.playing,
        isBuffering: isBuff,
        position: playback.position,
        speed: playback.speed,
        queue: _handler.songQueue,
        queueIndex: _handler.currentIndex >= 0 ? _handler.currentIndex : 0,
      );
    });

    _handler.player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });
  }

  void playSong(SongModel song, {List<SongModel>? playlist}) {
    _handler.playSong(song, playlist: playlist);
    state = state.copyWith(
      currentSong: song,
      isPlaying: true,
      isBuffering: true,
      queue: _handler.songQueue,
      queueIndex: _handler.currentIndex >= 0 ? _handler.currentIndex : 0,
    );
    // Auto-record in playback history
    _ref.read(historyProvider.notifier).addHistory(song);
    _ref.read(musicApiServiceProvider).recordPlay(
      songId: song.id,
      title: song.title,
      artist: song.artist,
      thumbnail: song.highResThumbnail ?? song.thumbnailUrl,
      duration: song.durationSeconds,
    );
  }

  void togglePlay() {
    if (state.isPlaying) {
      _handler.pause();
    } else {
      _handler.play();
    }
  }

  /// Complete stop and dismiss mini-player bar
  void closePlayer() {
    _handler.stop();
    state = state.copyWith(clearCurrentSong: true);
  }

  void seekTo(Duration position) => _handler.seek(position);
  void fastForwardBy(int seconds) => _handler.fastForwardBy(seconds);
  void rewindBy(int seconds) => _handler.rewindBy(seconds);
  
  void playNext(SongModel song) {
    _handler.playNext(song);
    state = state.copyWith(queue: _handler.songQueue);
  }

  void addToQueue(SongModel song) {
    _handler.addToQueue(song);
    state = state.copyWith(queue: _handler.songQueue);
  }

  void skipNext() => _handler.skipToNext();
  void skipPrev() => _handler.skipToPrevious();
  void setSpeed(double speed) => _handler.setSpeed(speed);
}

final playerControllerProvider = StateNotifierProvider<PlayerController, PlayerStateData>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return PlayerController(handler, ref);
});
