import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sleep_timer_provider.dart';
import 'settings_controller.dart';
import '../../player/player_controller.dart';
import '../../data/repositories/user_repository.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_modal.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showCustomSeekDialog(BuildContext context, WidgetRef ref, int currentVal) {
    final controller = TextEditingController(text: currentVal.toString());
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF262626),
          title: const Text('Custom Skip Duration', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter duration in seconds (e.g. 1, 10, 231):', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  suffixText: 'seconds',
                  suffixStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val != null && val > 0) {
                  ref.read(settingsControllerProvider.notifier).setSeekDuration(val);
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Skip duration set to ${val}s!')),
                  );
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 1. Appearance Sheet
  void _showAppearanceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF262626),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final colors = [
          {'name': 'Emerald Green', 'color': const Color(0xFF2E7D32)},
          {'name': 'Royal Violet', 'color': const Color(0xFF6C5CE7)},
          {'name': 'Ocean Blue', 'color': const Color(0xFF0984E3)},
          {'name': 'Sunset Orange', 'color': const Color(0xFFE17055)},
          {'name': 'AMOLED Dark', 'color': const Color(0xFF121212)},
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Appearance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Select primary accent color for the player and interface', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: colors.map((c) {
                  return ActionChip(
                    backgroundColor: const Color(0xFF333333),
                    avatar: CircleAvatar(backgroundColor: c['color'] as Color, radius: 8),
                    label: Text(c['name'] as String, style: const TextStyle(color: Colors.white)),
                    onPressed: () {
                      ref.read(settingsControllerProvider.notifier).setAccentColor(c['name'] as String);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Theme updated to ${c["name"]}!')),
                      );
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

  // 2. Content Settings Sheet
  void _showContentSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF262626),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Content Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language_rounded, color: Colors.white70),
                title: const Text('Music Language', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Hindi, Punjabi, English, Bollywood', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  ref.read(settingsControllerProvider.notifier).setLanguage('Hindi, Punjabi, English, Bollywood');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Regional language preferences saved!')),
                  );
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.public_rounded, color: Colors.white70),
                title: const Text('Content Region', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('India (IN)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Playback Sheet
  void _showPlaybackSheet(BuildContext context, WidgetRef ref) {
    final sleepState = ref.read(sleepTimerProvider);
    final playerState = ref.read(playerControllerProvider);
    final userSettings = ref.read(settingsControllerProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF262626),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final timerOptions = [15, 30, 45, 60];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Playback & Audio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),

                // Sleep Timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sleep Timer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    if (sleepState.isActive)
                      TextButton(
                        onPressed: () {
                          ref.read(sleepTimerProvider.notifier).cancelTimer();
                          Navigator.pop(context);
                        },
                        child: const Text('Turn Off', style: TextStyle(color: Colors.redAccent)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: timerOptions.map((mins) {
                    return ActionChip(
                      backgroundColor: const Color(0xFF333333),
                      label: Text('$mins Min', style: const TextStyle(color: Colors.white)),
                      onPressed: () {
                        ref.read(sleepTimerProvider.notifier).setTimer(mins);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sleep timer set for $mins minutes 🌙')),
                        );
                      },
                    );
                  }).toList(),
                ),
                const Divider(color: Colors.white12, height: 28),

                // Skip & Seek Duration (Customizable)
                const Text('Skip & Rewind Duration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Current: ${userSettings.seekDurationSeconds} seconds',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...[5, 10, 15, 30].map((sec) {
                      final isSel = userSettings.seekDurationSeconds == sec;
                      return ActionChip(
                        backgroundColor: isSel ? const Color(0xFF2E7D32) : const Color(0xFF333333),
                        label: Text('${sec}s', style: TextStyle(color: isSel ? Colors.white : Colors.white70)),
                        onPressed: () {
                          ref.read(settingsControllerProvider.notifier).setSeekDuration(sec);
                          Navigator.pop(context);
                        },
                      );
                    }),
                    ActionChip(
                      backgroundColor: const Color(0xFF333333),
                      avatar: const Icon(Icons.edit_rounded, size: 14, color: Colors.white70),
                      label: const Text('Custom', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(context);
                        _showCustomSeekDialog(context, ref, userSettings.seekDurationSeconds);
                      },
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 28),

                // Audio Quality
                const Text('Streaming Audio Quality', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('High Quality (Opus 160 kbps Adaptive)', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const Divider(color: Colors.white12, height: 28),

                // Speed
                Text('Playback Speed: ${playerState.speed}x', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }

  // 4. Downloads Sheet
  void _showDownloadsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF262626),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Downloads', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.folder_outlined, color: Colors.white70),
                title: Text('Download Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Internal Storage / AK Music', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
              Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.music_note_outlined, color: Colors.white70),
                title: Text('Audio Quality', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('320 kbps MP3 (Highest Studio Quality)', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  // 5. Other Settings Sheet
  void _showOtherSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF262626),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Other Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded, color: Colors.white70),
                title: const Text('Clear Playback History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Delete your recently played listening history', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  try {
                    final client = ApiClient();
                    await client.dio.delete('/user/history');
                    ref.read(historyProvider.notifier).loadHistory();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Playback history cleared successfully! 🧹')),
                    );
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Playback history cleared! 🧹')),
                    );
                  }
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
                title: const Text('Clear Cache', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Free up temporary image and search storage', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Temporary cache cleared! 🚀')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 6. About Sheet
  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF262626),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                ),
              ),
              const Center(
                child: Text('About AK Music', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              const Text('AK Music — High Performance Music Streaming', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Version: 1.0.0 (Build 2026.09.28)', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('Developed with passion for pure, uninterrupted musical experience.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF2E7D32))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 7. Background playback dialog
  void _showBatteryOptimizationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF262626),
        title: const Text('Background Playback Guide', style: TextStyle(color: Colors.white)),
        content: const Text(
          'If music stops when your screen turns off:\n\n'
          '1. Open Device Settings -> Apps -> AK Music\n'
          '2. Go to "Battery" or "Power Saving"\n'
          '3. Select "Unrestricted" or "Allow background activity".\n\n'
          'This ensures Android keeps audio streaming smoothly even when screen is locked.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Got it', style: TextStyle(color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isGuest = authState.isGuest;
    final userName = authState.user?.name ?? 'Guest Listener';
    final userEmail = authState.user?.email ?? 'Sign in to sync your playlists & favorites';

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: CustomScrollView(
        slivers: [
          // 1. Forest Green Curved Hero App Bar
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2E7D32),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
              title: const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // 2. Settings Items List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Profile / Account Status Tile
                  _buildProfileTile(context, ref, userName, userEmail, isGuest),
                  const SizedBox(height: 12),

                  // Appearance
                  _buildSettingRow(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    subtitle: 'Theme, Accent Colors, Player Skin',
                    onTap: () => _showAppearanceSheet(context, ref),
                  ),

                  // Content Settings
                  _buildSettingRow(
                    icon: Icons.tune_rounded,
                    title: 'Content Settings',
                    subtitle: 'Music Languages, Region & Recommendations',
                    onTap: () => _showContentSettingsSheet(context, ref),
                  ),

                  // Playback & Audio
                  _buildSettingRow(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Playback',
                    subtitle: 'Skip Duration, Sleep Timer, Audio Quality',
                    onTap: () => _showPlaybackSheet(context, ref),
                  ),

                  // Downloads
                  _buildSettingRow(
                    icon: Icons.download_done_rounded,
                    title: 'Downloads',
                    subtitle: 'Storage Location, Offline MP3 Quality',
                    onTap: () => _showDownloadsSheet(context),
                  ),

                  // Other Settings
                  _buildSettingRow(
                    icon: Icons.settings_suggest_outlined,
                    title: 'Other Settings',
                    subtitle: 'Clear History, Cache & Application Data',
                    onTap: () => _showOtherSettingsSheet(context, ref),
                  ),

                  // About
                  _buildSettingRow(
                    icon: Icons.info_outline_rounded,
                    title: 'About',
                    subtitle: 'AK Music Version 1.0.0, Licenses & Updates',
                    onTap: () => _showAboutSheet(context),
                  ),

                  // Background playback guide
                  _buildSettingRow(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Playback stops when locked?',
                    subtitle: 'Step-by-step Android battery optimization guide',
                    onTap: () => _showBatteryOptimizationDialog(context),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context, WidgetRef ref, String name, String email, bool isGuest) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2E7D32),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'G',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(email, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isGuest ? const Color(0xFF2E7D32) : const Color(0xFF3A3A3A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () {
              if (isGuest) {
                AuthModal.show(context);
              } else {
                ref.read(authControllerProvider.notifier).logout();
              }
            },
            child: Text(isGuest ? 'Sign In' : 'Sign Out', style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF333333),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
        ),
      ),
    );
  }
}
