enum ApiFailureKind {
  invalidConfiguration,
  offline,
  timeout,
  unauthorized,
  server,
  invalidResponse,
  unknown,
}

class ApiFailure implements Exception {
  const ApiFailure({
    required this.kind,
    required this.message,
    this.code,
    this.statusCode,
    this.details,
  });

  final ApiFailureKind kind;
  final String message;
  final String? code;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => message;
}
