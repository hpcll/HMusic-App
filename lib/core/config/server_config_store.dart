abstract interface class ServerConfigStore {
  Future<Uri?> read();

  Future<void> write(Uri serverBase);

  Future<void> clear();
}
