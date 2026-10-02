import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/player_controller.dart';

class SleepTimerState {
  final bool isActive;
  final int remainingSeconds;

  const SleepTimerState({this.isActive = false, this.remainingSeconds = 0});
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  final Ref _ref;
  Timer? _timer;

  SleepTimerNotifier(this._ref) : super(const SleepTimerState());

  void setTimer(int minutes) {
    cancelTimer();
    if (minutes <= 0) return;

    state = SleepTimerState(isActive: true, remainingSeconds: minutes * 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 1) {
        cancelTimer();
        // Pause audio playback smoothly
        final controller = _ref.read(playerControllerProvider.notifier);
        final playerState = _ref.read(playerControllerProvider);
        if (playerState.isPlaying) {
          controller.togglePlay();
        }
      } else {
        state = SleepTimerState(isActive: true, remainingSeconds: state.remainingSeconds - 1);
      }
    });
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    state = const SleepTimerState(isActive: false, remainingSeconds: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  return SleepTimerNotifier(ref);
});
