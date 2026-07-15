import '../../../core/models/server_info.dart';

class ConnectionResult {
  const ConnectionResult({required this.serverBase, required this.serverInfo});

  final Uri serverBase;
  final ServerInfo serverInfo;
}
