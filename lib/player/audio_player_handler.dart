import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../core/config/app_constants.dart';
import '../core/network/api_client.dart';
import '../data/models/song_model.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final List<SongModel> _songQueue = [];
  int _currentIndex = -1;
  bool _isLoadingNextRadio = false;

  AudioPlayer get player => _player;
  List<SongModel> get songQueue => List.unmodifiable(_songQueue);
  int get currentIndex => _currentIndex;

  AudioPlayerHandler() {
    _initStreams();
  }

  void _initStreams() {
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
            MediaAction.play,
            MediaAction.pause,
            MediaAction.playPause,
            MediaAction.stop,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
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

    _player.playerStateStream.listen((state) {
      debugPrint('🎧 [PLAYER STATE] Playing: ${state.playing}, State: ${state.processingState}');
      if (state.processingState == ProcessingState.completed) {
        skipToNext();
      }
    });

    // Auto-fetch radio recommendations when near end of queue
    _player.positionStream.listen((pos) {
      final dur = _player.duration;
      if (dur != null && dur.inSeconds > 0) {
        if (dur.inSeconds - pos.inSeconds <= 20 && _currentIndex == _songQueue.length - 1) {
          _fetchRadioAutoplay();
        }
      }
    });
  }

  Future<void> _fetchRadioAutoplay() async {
    if (_isLoadingNextRadio || _currentIndex < 0 || _currentIndex >= _songQueue.length) return;
    _isLoadingNextRadio = true;
    try {
      final currentSong = _songQueue[_currentIndex];
      debugPrint('📻 [RADIO AUTOPLAY] Fetching related tracks for: "${currentSong.title}"');
      final client = ApiClient();
      final excludeIds = _songQueue.map((s) => s.id).toList();
      final res = await client.dio.post('/queue/next', data: {
        'currentSongId': currentSong.id,
        'excludeIds': excludeIds,
        'limit': 10,
      });
      if (res.data is Map && res.data['data'] is Map && res.data['data']['songs'] is List) {
        final list = res.data['data']['songs'] as List;
        for (final item in list) {
          if (item is Map) {
            final songId = item['songId']?.toString() ?? item['id']?.toString() ?? '';
            final title = item['title']?.toString() ?? '';
            if (songId.isNotEmpty && title.isNotEmpty && !_songQueue.any((q) => q.id == songId)) {
              _songQueue.add(
                SongModel(
                  id: songId,
                  title: title,
                  artist: item['artist']?.toString() ?? 'Various Artists',
                  album: item['album']?.toString() ?? 'AK Music',
                  durationSeconds: item['duration'] is int ? item['duration'] as int : 0,
                  thumbnailUrl: item['thumbnail']?.toString(),
                ),
              );
            }
          }
        }
        debugPrint('📻 [RADIO AUTOPLAY] Queue expanded to ${_songQueue.length} tracks');
      }
    } catch (e) {
      debugPrint('⚠️ [RADIO AUTOPLAY ERROR] $e');
    } finally {
      playbackState.add(playbackState.value.copyWith(queueIndex: _currentIndex));
      _isLoadingNextRadio = false;
    }
  }

  Future<void> playSong(SongModel song, {List<SongModel>? playlist}) async {
    try {
      if (playlist != null && playlist.isNotEmpty) {
        _songQueue.clear();
        _songQueue.addAll(playlist);
        _currentIndex = _songQueue.indexWhere((s) => s.id == song.id);
        if (_currentIndex == -1) {
          _songQueue.insert(0, song);
          _currentIndex = 0;
        }
      } else {
        _currentIndex = _songQueue.indexWhere((s) => s.id == song.id);
        if (_currentIndex == -1) {
          _songQueue.add(song);
          _currentIndex = _songQueue.length - 1;
        }
      }

      final streamUrl = '${AppConstants.baseUrl}/stream/${song.id}?apiKey=${AppConstants.apiKey}';
      debugPrint('🎵 [STREAM START] Song: "${song.title}" | ID: ${song.id} | Queue Index: $_currentIndex/${_songQueue.length}');
      debugPrint('🔗 [STREAM URL] $streamUrl');

      mediaItem.add(
        MediaItem(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album ?? 'AK Music',
          duration: song.durationSeconds > 0 ? Duration(seconds: song.durationSeconds) : null,
          artUri: (song.thumbnailUrl ?? song.highResThumbnail) != null ? Uri.tryParse(song.thumbnailUrl ?? song.highResThumbnail!) : null,
        ),
      );

      // 1. Immediately signal buffering & playing intent
      playbackState.add(
        playbackState.value.copyWith(
          playing: true,
          processingState: AudioProcessingState.buffering,
        ),
      );

      // 2. Load and stream audio buffer
      await _player.setUrl(streamUrl);
      _player.play();
      if (_songQueue.length <= 1 || _currentIndex >= _songQueue.length - 2) {
        _fetchRadioAutoplay();
      }
      debugPrint('▶️ [STREAM PLAYING] Audio buffer streaming actively!');
    } catch (e) {
      debugPrint('❌ [STREAM ERROR] Failed to play audio: $e');
      playbackState.add(
        playbackState.value.copyWith(
          playing: false,
          errorMessage: 'Stream playback error: $e',
          processingState: AudioProcessingState.error,
        ),
      );
    }
  }


  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        if (_player.playing) {
          await pause();
        } else {
          await play();
        }
        break;
      case MediaButton.next:
        await skipToNext();
        break;
      case MediaButton.previous:
        await skipToPrevious();
        break;
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

  Future<void> fastForwardBy(int seconds) async {
    final current = _player.position;
    final maxDur = _player.duration ?? (current + Duration(seconds: seconds));
    final target = current + Duration(seconds: seconds);
    await seek(target > maxDur ? maxDur : target);
  }

  Future<void> rewindBy(int seconds) async {
    final current = _player.position;
    final target = current - Duration(seconds: seconds);
    await seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Future<void> skipToNext() async {
    if (_currentIndex + 1 < _songQueue.length) {
      _currentIndex++;
      await playSong(_songQueue[_currentIndex]);
    } else {
      await _fetchRadioAutoplay();
      if (_currentIndex + 1 < _songQueue.length) {
        _currentIndex++;
        await playSong(_songQueue[_currentIndex]);
      }
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

  /// Inserts a song directly as "Next to Play" in the queue
  void playNext(SongModel song) {
    if (_songQueue.isEmpty || _currentIndex < 0) {
      playSong(song);
      return;
    }
    // Remove if already in queue to avoid duplicate
    _songQueue.removeWhere((s) => s.id == song.id);
    final insertIdx = (_currentIndex + 1).clamp(0, _songQueue.length);
    _songQueue.insert(insertIdx, song);
    playbackState.add(playbackState.value.copyWith(queueIndex: _currentIndex));
    debugPrint('⏭️ [PLAY NEXT] Inserted "${song.title}" at index $insertIdx');
  }

  /// Appends a song to the end of the playback queue
  void addToQueue(SongModel song) {
    if (_songQueue.isEmpty || _currentIndex < 0) {
      playSong(song);
      return;
    }
    if (!_songQueue.any((s) => s.id == song.id)) {
      _songQueue.add(song);
      playbackState.add(playbackState.value.copyWith(queueIndex: _currentIndex));
      debugPrint('➕ [ADD TO QUEUE] Appended "${song.title}" (Queue size: ${_songQueue.length})');
    }
  }

}
