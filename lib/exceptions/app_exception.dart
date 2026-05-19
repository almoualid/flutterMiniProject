// lib/exceptions/app_exception.dart

class AppException implements Exception {
  final String message;
  final String code;
  final dynamic originalError;

  AppException({
    required this.message,
    required this.code,
    this.originalError,
  });

  @override
  String toString() {
    return 'AppException[$code]: $message${originalError != null ? ' ($originalError)' : ''}';
  }
}
