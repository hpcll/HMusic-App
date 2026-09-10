import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/mi_direct_session.dart';
import 'package:hmusic/core/direct/mi_direct_session_store.dart';
import 'package:mocktail/mocktail.dart';

class _Storage extends Mock implements FlutterSecureStorage {}

void main() {
  late _Storage storage;
  late SecureMiDirectSessionStore store;
  final session = MiDirectSession(userId: '123', serviceToken: 'test-secret');

  setUp(() {
    storage = _Storage();
    store = SecureMiDirectSessionStore(storage: storage);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  test(
    'credentials use a distinct secure key and cache subsequent reads',
    () async {
      await store.write(session);
      expect(await store.read(), same(session));
      verify(
        () => storage.write(
          key: SecureMiDirectSessionStore.key,
          value: any(named: 'value', that: contains('test-secret')),
        ),
      ).called(1);
      verifyNever(() => storage.read(key: any(named: 'key')));
      expect(session.toString(), isNot(contains('test-secret')));
    },
  );

  test(
    'logout waits for pending write before deleting persisted credentials',
    () async {
      final writeGate = Completer<void>();
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) => writeGate.future);
      final write = store.write(session);
      final clear = store.clear();
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => storage.delete(key: any(named: 'key')));
      writeGate.complete();
      await write;
      await clear;
      expect(await store.read(), isNull);
      verify(
        () => storage.delete(key: SecureMiDirectSessionStore.key),
      ).called(1);
    },
  );

  test('corrupt saved credentials require reauthentication', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => '{invalid');
    expect(await store.read(), isNull);
  });

  test('cookie header injection is rejected without echoing the secret', () {
    expect(
      () => MiDirectSession(userId: '123', serviceToken: 'secret; userId=456'),
      throwsFormatException,
    );
  });
}
