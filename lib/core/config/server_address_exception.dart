class ServerAddressException implements Exception {
  const ServerAddressException(this.message);

  final String message;

  @override
  String toString() => message;
}
