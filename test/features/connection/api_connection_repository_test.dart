import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/config/server_config_store.dart';
import 'package:hmusic/core/network/api_client.dart';
import 'package:hmusic/core/security/token_store.dart';
import 'package:hmusic/features/connection/data/api_connection_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MemoryServerConfigStore implements ServerConfigStore {
  Uri? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<Uri?> read() async => value;

  @override
  Future<void> write(Uri serverBase) async => value = serverBase;
}

class _MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}

void main() {
  late _MockApiClient apiClient;
  late _MemoryServerConfigStore configStore;
  late _MemoryTokenStore tokenStore;
  late ApiConnectionRepository repository;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://127.0.0.1:8090'));
  });

  setUp(() {
    apiClient = _MockApiClient();
    configStore = _MemoryServerConfigStore();
    tokenStore = _MemoryTokenStore();
    repository = ApiConnectionRepository(
      apiClient: apiClient,
      serverConfigStore: configStore,
      tokenStore: tokenStore,
    );
  });

  test('probes and persists a compatible server', () async {
    when(
      () => apiClient.getMap(
        '/system/info',
        serverBase: any(named: 'serverBase'),
        authenticated: false,
      ),
    ).thenAnswer(
      (_) async => <String, Object?>{
        'name': 'HMusic Server',
        'version': '0.1.0',
        'apiVersion': 'v1',
      },
    );

    final result = await repository.connect('192.168.1.10:8090');

    expect(result.serverBase.toString(), 'http://192.168.1.10:8090');
    expect(configStore.value, result.serverBase);
  });

  test('clears token when switching servers', () async {
    configStore.value = Uri.parse('http://192.168.1.2:8090');
    tokenStore.value = 'old-token';
    when(
      () => apiClient.getMap(
        '/system/info',
        serverBase: any(named: 'serverBase'),
        authenticated: false,
      ),
    ).thenAnswer(
      (_) async => <String, Object?>{
        'name': 'HMusic Server',
        'version': '0.1.0',
        'apiVersion': 'v1',
      },
    );

    await repository.connect('http://192.168.1.3:8090');

    expect(tokenStore.value, isNull);
  });
}
