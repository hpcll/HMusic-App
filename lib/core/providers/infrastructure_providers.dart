import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_config_store.dart';
import '../config/shared_preferences_server_config_store.dart';
import '../network/api_client.dart';
import '../security/secure_token_store.dart';
import '../security/token_store.dart';
import '../session/session_providers.dart';

final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ),
  );
});

final Provider<ServerConfigStore> serverConfigStoreProvider =
    Provider<ServerConfigStore>((ref) {
      return SharedPreferencesServerConfigStore();
    });

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>((ref) {
  return SecureTokenStore();
});

// ApiClient 持有 401 回调；SessionController 触发后由 app_router 的
// refreshListenable 统一跳登录页，避免每个 ViewModel 各自监听。
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(sessionControllerProvider);
  // 读取 sessionGuard 确保停止本机音频的副作用被订阅。
  ref.watch(sessionGuardProvider);
  return ApiClient(
    dio: ref.watch(dioProvider),
    serverConfigStore: ref.watch(serverConfigStoreProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    onUnauthorized: () async => session.invalidate(),
  );
});
