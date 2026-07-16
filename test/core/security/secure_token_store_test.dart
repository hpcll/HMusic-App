import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/security/secure_token_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late SecureTokenStore store;

  setUp(() {
    storage = _MockStorage();
    store = SecureTokenStore(storage: storage);
  });

  test('read 只碰一次钥匙串，之后走内存缓存', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => 'tok-1');

    expect(await store.read(), 'tok-1');
    expect(await store.read(), 'tok-1');
    verify(() => storage.read(key: any(named: 'key'))).called(1);
  });

  test('缓存命中后钥匙串锁定（-25308）不影响读取', () async {
    var calls = 0;
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async {
      calls++;
      if (calls > 1) {
        throw PlatformException(code: '-25308', message: '钥匙串已锁定');
      }
      return 'tok-1';
    });

    expect(await store.read(), 'tok-1');
    // 第二次若再碰钥匙串会抛；缓存命中所以安然返回。
    expect(await store.read(), 'tok-1');
  });

  test('write 同步更新缓存，read 不再回源', () async {
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    await store.write('tok-2');
    expect(await store.read(), 'tok-2');
    verifyNever(() => storage.read(key: any(named: 'key')));
  });

  test('clear 清缓存也清持久层', () async {
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    await store.write('tok-3');
    await store.clear();
    expect(await store.read(), isNull);
    verify(() => storage.delete(key: any(named: 'key'))).called(1);
  });
}
