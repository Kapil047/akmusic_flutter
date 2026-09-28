import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_constants.dart';
import 'player/audio_player_handler.dart';
import 'player/player_controller.dart';
import 'features/shell/main_shell_screen.dart';

late AudioPlayerHandler _audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Android background AudioService
  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.akmusic.channel.audio',
      androidNotificationChannelName: 'AK Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(_audioHandler),
      ],
      child: const AkMusicApp(),
    ),
  );
}

class AkMusicApp extends StatelessWidget {
  const AkMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainShellScreen(),
    );
  }
}
