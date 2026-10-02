import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../../data/services/music_api_service.dart';
import '../theme/app_theme.dart';

class NetworkState {
  final bool isOnline;
  final bool isChecking;
  final bool isDismissed;

  const NetworkState({
    this.isOnline = true,
    this.isChecking = false,
    this.isDismissed = false,
  });

  NetworkState copyWith({
    bool? isOnline,
    bool? isChecking,
    bool? isDismissed,
  }) {
    return NetworkState(
      isOnline: isOnline ?? this.isOnline,
      isChecking: isChecking ?? this.isChecking,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}

class NetworkStatusNotifier extends StateNotifier<NetworkState> {
  final ApiClient _client;
  Timer? _pollingTimer;

  NetworkStatusNotifier(this._client) : super(const NetworkState()) {
    checkConnection();
    _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) => checkConnection());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<bool> checkConnection() async {
    if (state.isChecking) return state.isOnline;
    state = state.copyWith(isChecking: true);

    try {
      final res = await _client.dio.get(
        '/health',
        options: Options(receiveTimeout: const Duration(seconds: 3), sendTimeout: const Duration(seconds: 3)),
      );
      final online = res.statusCode == 200;
      state = state.copyWith(
        isOnline: online,
        isChecking: false,
        isDismissed: online ? false : state.isDismissed,
      );
      return online;
    } catch (_) {
      state = state.copyWith(isOnline: false, isChecking: false);
      return false;
    }
  }

  void reportFailure() {
    if (state.isOnline) {
      state = state.copyWith(isOnline: false, isDismissed: false);
    }
  }

  void reportSuccess() {
    if (!state.isOnline) {
      state = state.copyWith(isOnline: true, isDismissed: false);
    }
  }

  void dismissBanner() {
    state = state.copyWith(isDismissed: true);
  }
}

final networkStatusProvider = StateNotifierProvider<NetworkStatusNotifier, NetworkState>((ref) {
  final client = ref.watch(apiClientProvider);
  return NetworkStatusNotifier(client);
});

/// Floating Offline Warning Banner placed above Mini Player Bar
class OfflineBanner extends ConsumerWidget {
  final VoidCallback? onReconnected;

  const OfflineBanner({super.key, this.onReconnected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netState = ref.watch(networkStatusProvider);

    // If online or user dismissed the banner, hide it
    if (netState.isOnline || netState.isDismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1515), // Deep dark red/crimson
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No Internet Connection',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),

          // Refresh / Retry button
          if (netState.isChecking)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.accentColor),
              label: const Text('Retry', style: TextStyle(fontSize: 12, color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final reconnected = await ref.read(networkStatusProvider.notifier).checkConnection();
                if (reconnected && onReconnected != null) {
                  onReconnected!();
                }
              },
            ),

          const SizedBox(width: 4),

          // Close / Dismiss button
          GestureDetector(
            onTap: () => ref.read(networkStatusProvider.notifier).dismissBanner(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: Colors.white54, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
