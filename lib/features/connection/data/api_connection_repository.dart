import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/server_address_policy.dart';
import '../../../core/config/server_config_store.dart';
import '../../../core/models/server_info.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../../../core/security/token_store.dart';
import '../models/connection_result.dart';
import 'connection_repository.dart';

final Provider<ConnectionRepository> connectionRepositoryProvider =
    Provider<ConnectionRepository>((ref) {
      return ApiConnectionRepository(
        apiClient: ref.watch(apiClientProvider),
        serverConfigStore: ref.watch(serverConfigStoreProvider),
        tokenStore: ref.watch(tokenStoreProvider),
      );
    });

class ApiConnectionRepository implements ConnectionRepository {
  const ApiConnectionRepository({
    required ApiClient apiClient,
    required ServerConfigStore serverConfigStore,
    required TokenStore tokenStore,
  }) : _apiClient = apiClient,
       _serverConfigStore = serverConfigStore,
       _tokenStore = tokenStore;

  final ApiClient _apiClient;
  final ServerConfigStore _serverConfigStore;
  final TokenStore _tokenStore;

  @override
  Future<ConnectionResult> connect(String input) async {
    final candidate = ServerAddressPolicy.normalize(input);
    final payload = await _apiClient.getMap(
      '/system/info',
      serverBase: candidate,
      authenticated: false,
    );
    final info = ServerInfo.fromJson(payload);
    if (info.name != 'HMusic Server' || info.apiVersion != 'v1') {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: '这个地址不是兼容的 HMusic Server',
      );
    }

    final previous = await _serverConfigStore.read();
    if (previous != null && previous != candidate) await _tokenStore.clear();
    await _serverConfigStore.write(candidate);
    return ConnectionResult(serverBase: candidate, serverInfo: info);
  }

  @override
  Future<String?> loadSavedAddress() async {
    return (await _serverConfigStore.read())?.toString();
  }
}
