import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_client.dart';
import '../../data/services/auth_api_service.dart';
import '../../data/repositories/user_repository.dart';

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  final client = ApiClient();
  return AuthApiService(client);
});

class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => token != null && user != null && !user!.isGuest;
  bool get isGuest => user?.isGuest ?? true;

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Ref _ref;

  AuthNotifier(this._api, this._ref) : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final userJson = await _storage.read(key: 'auth_user');

      if (token != null && userJson != null) {
        final user = UserModel.fromJson(jsonDecode(userJson));
        state = AuthState(token: token, user: user);
        debugPrint('👤 [AUTH RESTORED] Logged in as: ${user.name} (${user.email})');
      } else {
        // Fallback to guest
        await continueAsGuest();
      }
    } catch (e) {
      debugPrint('⚠️ [AUTH RESTORE ERROR] $e');
      await continueAsGuest();
    }
  }

  Future<bool> signup(String email, String password, String name) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _api.signup(email: email, password: password, name: name);
      await _storage.write(key: 'auth_token', value: res.token);
      await _storage.write(key: 'auth_user', value: jsonEncode(res.user.toJson()));
      state = AuthState(token: res.token, user: res.user, isLoading: false);

      // Refresh favorites & history from Firestore for this user
      _ref.read(favoritesProvider.notifier).loadFavorites();
      _ref.read(historyProvider.notifier).loadHistory();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _api.login(email: email, password: password);
      await _storage.write(key: 'auth_token', value: res.token);
      await _storage.write(key: 'auth_user', value: jsonEncode(res.user.toJson()));
      state = AuthState(token: res.token, user: res.user, isLoading: false);

      // Refresh favorites & history from Firestore for this user
      _ref.read(favoritesProvider.notifier).loadFavorites();
      _ref.read(historyProvider.notifier).loadHistory();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> continueAsGuest() async {
    try {
      final res = await _api.guestAuth();
      await _storage.write(key: 'auth_token', value: res.token);
      await _storage.write(key: 'auth_user', value: jsonEncode(res.user.toJson()));
      state = AuthState(token: res.token, user: res.user);
    } catch (_) {
      const guest = UserModel(uid: 'guest_local', name: 'Guest Listener', isGuest: true);
      state = const AuthState(user: guest);
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'auth_user');
    await continueAsGuest();
    _ref.read(favoritesProvider.notifier).loadFavorites();
    _ref.read(historyProvider.notifier).loadHistory();
  }
}

final authControllerProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(authApiServiceProvider);
  return AuthNotifier(api, ref);
});
