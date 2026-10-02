import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';

class UserSettings {
  final int seekDurationSeconds;
  final String accentColor;
  final String audioQuality;
  final String language;
  final String region;

  const UserSettings({
    this.seekDurationSeconds = 10,
    this.accentColor = 'Emerald Green',
    this.audioQuality = 'High Quality',
    this.language = 'Hindi, Punjabi, English',
    this.region = 'IN',
  });

  UserSettings copyWith({
    int? seekDurationSeconds,
    String? accentColor,
    String? audioQuality,
    String? language,
    String? region,
  }) {
    return UserSettings(
      seekDurationSeconds: seekDurationSeconds ?? this.seekDurationSeconds,
      accentColor: accentColor ?? this.accentColor,
      audioQuality: audioQuality ?? this.audioQuality,
      language: language ?? this.language,
      region: region ?? this.region,
    );
  }

  Map<String, dynamic> toJson() => {
    'seekDurationSeconds': seekDurationSeconds,
    'accentColor': accentColor,
    'audioQuality': audioQuality,
    'language': language,
    'region': region,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    seekDurationSeconds: json['seekDurationSeconds'] is int
        ? json['seekDurationSeconds'] as int
        : int.tryParse(json['seekDurationSeconds']?.toString() ?? '10') ?? 10,
    accentColor: json['accentColor'] as String? ?? 'Emerald Green',
    audioQuality: json['audioQuality'] as String? ?? 'High Quality',
    language: json['language'] as String? ?? 'Hindi, Punjabi, English',
    region: json['region'] as String? ?? 'IN',
  );
}

class SettingsController extends StateNotifier<UserSettings> {
  final Ref _ref;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _storageKey = 'ak_user_settings_v1';

  SettingsController(this._ref) : super(const UserSettings()) {
    _initSettings();
  }

  Future<void> _initSettings() async {
    try {
      final cached = await _storage.read(key: _storageKey);
      if (cached != null) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        state = UserSettings.fromJson(decoded);
        debugPrint('⚙️ [SETTINGS] Loaded from offline storage: ${state.seekDurationSeconds}s seek');
      }
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Failed to read offline storage: $e');
    }

    await syncWithCloud();
  }

  Future<void> syncWithCloud() async {
    final auth = _ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return;

    try {
      final client = ApiClient();
      final res = await client.dio.get('/user/settings');
      if (res.data is Map && res.data['data'] != null) {
        final cloudSettings = UserSettings.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
        state = cloudSettings;
        await _persistLocal(state);
        debugPrint('☁️ [SETTINGS] Synced from cloud: ${state.seekDurationSeconds}s seek');
      }
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Cloud sync error: $e');
    }
  }

  Future<void> _persistLocal(UserSettings settings) async {
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(settings.toJson()));
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Persist local error: $e');
    }
  }

  Future<void> _pushToCloud(UserSettings settings) async {
    final auth = _ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return;

    try {
      final client = ApiClient();
      await client.dio.put('/user/settings', data: settings.toJson());
      debugPrint('☁️ [SETTINGS] Saved to cloud');
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Cloud save error: $e');
    }
  }

  Future<void> setSeekDuration(int seconds) async {
    final updated = state.copyWith(seekDurationSeconds: seconds > 0 ? seconds : 10);
    state = updated;
    await _persistLocal(updated);
    await _pushToCloud(updated);
  }

  Future<void> setAccentColor(String colorName) async {
    final updated = state.copyWith(accentColor: colorName);
    state = updated;
    await _persistLocal(updated);
    await _pushToCloud(updated);
  }

  Future<void> setAudioQuality(String quality) async {
    final updated = state.copyWith(audioQuality: quality);
    state = updated;
    await _persistLocal(updated);
    await _pushToCloud(updated);
  }

  Future<void> setLanguage(String language) async {
    final updated = state.copyWith(language: language);
    state = updated;
    await _persistLocal(updated);
    await _pushToCloud(updated);
  }
}

final settingsControllerProvider = StateNotifierProvider<SettingsController, UserSettings>((ref) {
  return SettingsController(ref);
});
