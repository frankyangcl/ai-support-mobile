enum ApiErrorType { network, timeout, server, invalidResponse }

class ApiException implements Exception {
  const ApiException(this.message, {required this.type, this.statusCode});

  final String message;
  final ApiErrorType type;
  final int? statusCode;

  @override
  String toString() => message;
}
