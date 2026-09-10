import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/mi_direct_account_repository.dart';
import 'package:hmusic/core/direct/mi_direct_device.dart';
import 'package:hmusic/core/direct/mi_direct_session.dart';
import 'package:hmusic/core/direct/mi_direct_session_store.dart';
import 'package:hmusic/core/direct/mi_mina_client.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements MiMinaClient {}

class _Store extends Mock implements MiDirectSessionStore {}

void main() {
  final session = MiDirectSession(userId: '1', serviceToken: 'fixture');
  late _Client client;
  late _Store store;
  late MiDirectAccountRepository repository;

  setUp(() {
    client = _Client();
    store = _Store();
    repository = MiDirectAccountRepository(client: client, store: store);
    when(() => store.read()).thenAnswer((_) async => session);
    when(() => store.write(session)).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});
  });

  test(
    'valid account without speakers can still be imported for local playback',
    () async {
      when(
        () => client.devices(session),
      ).thenAnswer((_) async => <MiDirectDevice>[]);
      final result = await repository.importSession(session);
      expect(result.devices, isEmpty);
      verifyInOrder([
        () => client.devices(session),
        () => store.write(session),
      ]);
    },
  );

  test('failed import does not overwrite the saved account', () async {
    when(() => client.devices(session)).thenThrow(
      const ApiFailure(kind: ApiFailureKind.offline, message: 'offline'),
    );
    await expectLater(
      repository.importSession(session),
      throwsA(isA<ApiFailure>()),
    );
    verifyNever(() => store.write(session));
  });

  for (final expired in [true, false]) {
    test('restore clears only confirmed expiry: $expired', () async {
      when(() => client.devices(session)).thenThrow(
        ApiFailure(
          kind: expired ? ApiFailureKind.unauthorized : ApiFailureKind.offline,
          code: expired
              ? 'MI_DIRECT_SESSION_EXPIRED'
              : 'MI_DIRECT_REQUEST_FAILED',
          message: 'fixture failure',
        ),
      );
      await expectLater(repository.restore(), throwsA(isA<ApiFailure>()));
      if (expired) {
        verify(() => store.clear()).called(1);
      } else {
        verifyNever(() => store.clear());
      }
    });
  }
}
