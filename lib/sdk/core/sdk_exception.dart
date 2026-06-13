// lib/sdk/core/sdk_exception.dart

class SdkException implements Exception {
  final String message;

  const SdkException(this.message);

  @override
  String toString() => message;
}