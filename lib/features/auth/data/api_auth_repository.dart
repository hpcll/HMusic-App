import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../../../core/security/token_store.dart';
import '../models/auth_session.dart';
import '../models/auth_status.dart';
import 'auth_repository.dart';

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      return ApiAuthRepository(
        apiClient: ref.watch(apiClientProvider),
        tokenStore: ref.watch(tokenStoreProvider),
      );
    });

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository({
    required ApiClient apiClient,
    required TokenStore tokenStore,
  }) : _apiClient = apiClient,
       _tokenStore = tokenStore;

  final ApiClient _apiClient;
  final TokenStore _tokenStore;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) {
    return _submit('/auth/login', username, password);
  }

  @override
  Future<AuthSession> setup({
    required String username,
    required String password,
  }) {
    return _submit('/auth/setup', username, password);
  }

  @override
  Future<AuthStatus> status() async {
    final payload = await _apiClient.getMap('/auth/status');
    final status = AuthStatus.fromJson(payload);
    if (!status.authenticated && await _tokenStore.read() != null) {
      await _tokenStore.clear();
    }
    return status;
  }

  Future<AuthSession> _submit(
    String path,
    String username,
    String password,
  ) async {
    final payload = await _apiClient.postMap(
      path,
      authenticated: false,
      body: <String, Object?>{'username': username, 'password': password},
    );
    final session = AuthSession.fromJson(payload);
    await _tokenStore.write(session.accessToken);
    return session;
  }
}
