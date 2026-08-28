import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_config_store.dart';
import '../config/shared_preferences_server_config_store.dart';
import '../network/api_client.dart';
import '../security/secure_token_store.dart';
import '../security/token_store.dart';
import '../session/session_providers.dart';
import '../storage/key_value_store.dart';
import '../storage/preferences_key_value_store.dart';

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

// 全 App 共用一个键值存储：降级状态（DataStore → legacy → 内存）也因此只需
// 发现一次，服务器地址、升级缓存、本机音量三处不必各踩一遍坏通道。
final Provider<KeyValueStore> keyValueStoreProvider = Provider<KeyValueStore>((
  ref,
) {
  return createPreferencesKeyValueStore();
});

final Provider<ServerConfigStore> serverConfigStoreProvider =
    Provider<ServerConfigStore>((ref) {
      return SharedPreferencesServerConfigStore(
        preferences: ref.watch(keyValueStoreProvider),
      );
    });

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>((ref) {
  return SecureTokenStore();
});

// ApiClient 持有 401 回调；SessionController 触发后由 app_router 的
// refreshListenable 统一跳登录页，避免每个 ViewModel 各自监听。
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(sessionControllerProvider);
  // sessionGuard（停本机音频副作用）由 HMusicApp 根部激活，不在这里 watch：
  // 否则 guard 进入 audioHandler 依赖链，其监听器反读 audioHandler 会成环。
  return ApiClient(
    dio: ref.watch(dioProvider),
    serverConfigStore: ref.watch(serverConfigStoreProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    onUnauthorized: () async => session.invalidate(),
  );
});
