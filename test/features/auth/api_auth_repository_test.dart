import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/network/api_client.dart';
import 'package:hmusic/core/security/token_store.dart';
import 'package:hmusic/features/auth/data/api_auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

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
  late _MemoryTokenStore tokenStore;
  late ApiAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    apiClient = _MockApiClient();
    tokenStore = _MemoryTokenStore();
    repository = ApiAuthRepository(
      apiClient: apiClient,
      tokenStore: tokenStore,
    );
  });

  test('stores token after login', () async {
    when(
      () => apiClient.postMap(
        '/auth/login',
        authenticated: false,
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => <String, Object?>{
        'user': <String, Object?>{'id': 'u1', 'username': 'hupc'},
        'accessToken': 'token-1',
      },
    );

    final session = await repository.login(
      username: 'hupc',
      password: 'password',
    );

    expect(session.user.username, 'hupc');
    expect(tokenStore.value, 'token-1');
  });

  test('clears stale token when status is unauthenticated', () async {
    tokenStore.value = 'stale';
    when(() => apiClient.getMap('/auth/status')).thenAnswer(
      (_) async => <String, Object?>{
        'initialized': true,
        'authenticated': false,
      },
    );

    final status = await repository.status();

    expect(status.authenticated, isFalse);
    expect(tokenStore.value, isNull);
  });
}
