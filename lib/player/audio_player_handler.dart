import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../core/config/app_constants.dart';
import '../data/models/song_model.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final List<SongModel> _songQueue = [];
  int _currentIndex = -1;

  AudioPlayer get player => _player;
  List<SongModel> get songQueue => List.unmodifiable(_songQueue);
  int get currentIndex => _currentIndex;

  AudioPlayerHandler() {
    _initStreams();
  }

  void _initStreams() {
    // 1. Broadcast playback state changes to Android system notification & lockscreen
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 3],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: _currentIndex >= 0 ? _currentIndex : null,
        ),
      );
    });

    // 2. Auto-play next song on completion
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  /// Plays a given song and sets it as the current track
  Future<void> playSong(SongModel song) async {
    try {
      _currentIndex = _songQueue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) {
        _songQueue.add(song);
        _currentIndex = _songQueue.length - 1;
      }

      final streamUrl = '${AppConstants.baseUrl}/stream/${song.id}?apiKey=${AppConstants.apiKey}';

      // Update system MediaItem for Android lockscreen & Bluetooth
      mediaItem.add(
        MediaItem(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album ?? 'AK Music',
          duration: song.durationSeconds > 0 ? Duration(seconds: song.durationSeconds) : null,
          artUri: song.thumbnailUrl != null ? Uri.tryParse(song.thumbnailUrl!) : null,
        ),
      );

      await _player.stop();
      await _player.setUrl(streamUrl);
      await _player.play();
    } catch (e) {
      // Stream URL retry logic on 403/410 expiry
      playbackState.add(
        playbackState.value.copyWith(
          errorMessage: 'Stream playback error: $e',
          processingState: AudioProcessingState.error,
        ),
      );
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_currentIndex + 1 < _songQueue.length) {
      _currentIndex++;
      await playSong(_songQueue[_currentIndex]);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 4) {
      await seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await playSong(_songQueue[_currentIndex]);
    }
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      AudioServiceRepeatMode.group => LoopMode.all,
    };
    await _player.setLoopMode(loopMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    await _player.setShuffleModeEnabled(enabled);
  }
}
