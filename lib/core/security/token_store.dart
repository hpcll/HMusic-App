abstract interface class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}
