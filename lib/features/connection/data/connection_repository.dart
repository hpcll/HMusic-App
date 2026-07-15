import '../models/connection_result.dart';

abstract interface class ConnectionRepository {
  Future<String?> loadSavedAddress();

  Future<ConnectionResult> connect(String input);
}
