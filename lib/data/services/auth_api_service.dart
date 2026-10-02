import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';

class UserModel {
  final String uid;
  final String? email;
  final String name;
  final bool isGuest;

  const UserModel({
    required this.uid,
    this.email,
    required this.name,
    this.isGuest = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'],
      name: json['name'] ?? 'User',
      isGuest: json['isGuest'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'name': name,
    'isGuest': isGuest,
  };
}

class AuthResponse {
  final String token;
  final UserModel user;

  const AuthResponse({required this.token, required this.user});
}

class AuthApiService {
  final ApiClient _client;

  AuthApiService(this._client);

  /// Register new user with email & password (saved to Firestore)
  Future<AuthResponse> signup({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          'name': name,
        },
      );
      final data = response.data;
      if (data is Map && data['data'] != null) {
        final inner = Map<String, dynamic>.from(data['data'] as Map);
        final token = inner['token'] as String;
        final user = UserModel.fromJson(Map<String, dynamic>.from(inner['user'] as Map));
        return AuthResponse(token: token, user: user);
      }
      throw Exception('Unexpected response format');
    } catch (e) {
      debugPrint('❌ [AUTH SIGNUP ERROR] $e');
      rethrow;
    }
  }

  /// Sign in with email & password (verified from Firestore)
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      final data = response.data;
      if (data is Map && data['data'] != null) {
        final inner = Map<String, dynamic>.from(data['data'] as Map);
        final token = inner['token'] as String;
        final user = UserModel.fromJson(Map<String, dynamic>.from(inner['user'] as Map));
        return AuthResponse(token: token, user: user);
      }
      throw Exception('Unexpected response format');
    } catch (e) {
      debugPrint('❌ [AUTH LOGIN ERROR] $e');
      rethrow;
    }
  }

  /// Guest session
  Future<AuthResponse> guestAuth([String? deviceId]) async {
    try {
      final response = await _client.dio.post(
        '/auth/guest',
        data: {'deviceId': deviceId},
      );
      final data = response.data;
      if (data is Map && data['data'] != null) {
        final inner = Map<String, dynamic>.from(data['data'] as Map);
        final token = inner['token'] as String;
        final user = UserModel.fromJson(Map<String, dynamic>.from(inner['user'] as Map));
        return AuthResponse(token: token, user: user);
      }
      throw Exception('Unexpected response format');
    } catch (e) {
      debugPrint('❌ [AUTH GUEST ERROR] $e');
      rethrow;
    }
  }
}
