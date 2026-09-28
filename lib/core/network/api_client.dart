import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../config/app_constants.dart';
import '../crypto/crypto_service.dart';
import 'app_exception.dart';

class ApiClient {
  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _guestToken;

  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: AppConstants.connectTimeoutSeconds),
        receiveTimeout: const Duration(seconds: AppConstants.receiveTimeoutSeconds),
        headers: {
          'x-api-key': AppConstants.apiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  Future<String> _getOrGenerateGuestToken() async {
    if (_guestToken != null) return _guestToken!;
    String? token = await _storage.read(key: 'guest_token');
    if (token == null || token.isEmpty) {
      token = const Uuid().v4();
      await _storage.write(key: 'guest_token', value: token);
    }
    _guestToken = token;
    return token;
  }

  void _setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 1. Add Guest Bearer token for user-specific endpoints
          if (options.path.contains('/user')) {
            final token = await _getOrGenerateGuestToken();
            options.headers['Authorization'] = 'Bearer $token';
          }

          // 2. Encrypt outgoing body if present (except raw stream/download)
          if (options.data != null &&
              !options.path.contains('/stream') &&
              !options.path.contains('/download')) {
            try {
              options.data = await CryptoService.encryptPayload(options.data);
            } catch (e) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: AppException('Failed to encrypt request payload: $e'),
                ),
              );
            }
          }

          return handler.next(options);
        },
        onResponse: (response, handler) async {
          final data = response.data;
          // Decrypt if server flagged as encrypted
          if (data is Map && data['encrypted'] == true && data['data'] != null) {
            try {
              final payload = data['data']['payload'] as String;
              final iv = data['data']['iv'] as String;
              final authTag = data['data']['authTag'] as String;

              final decrypted = await CryptoService.decryptPayload(
                payloadBase64: payload,
                ivBase64: iv,
                authTagBase64: authTag,
              );

              response.data = decrypted;
            } catch (e) {
              return handler.reject(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  error: DecryptionException('Failed to decrypt response: $e'),
                ),
              );
            }
          }

          return handler.next(response);
        },
        onError: (DioException error, handler) {
          if (error.response?.statusCode == 429) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: RateLimitException('Too many requests. Please wait.'),
              ),
            );
          }
          return handler.next(error);
        },
      ),
    );
  }
}
