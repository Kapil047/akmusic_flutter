class AppException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  AppException(this.message, {this.code, this.statusCode});

  @override
  String toString() => 'AppException(code: $code, statusCode: $statusCode, message: $message)';
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.statusCode});
}

class DecryptionException extends AppException {
  DecryptionException(super.message, {super.code = 'ERR_DECRYPTION'});
}

class RateLimitException extends AppException {
  RateLimitException(super.message, {super.code = 'ERR_RATE_LIMIT', super.statusCode = 429});
}
