import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/core/storage/preferences_key_value_store.dart';

// 复刻线上症状：原生侧通道没有处理器时 pigeon 抛的就是这个。
PlatformException _channelError(String method) {
  return PlatformException(
    code: 'channel-error',
    message:
        'Unable to establish connection on channel: '
        '"dev.flutter.pigeon.shared_preferences_android.'
        'SharedPreferencesAsyncApi.$method.data_store".',
  );
}

class _RecordingStore implements KeyValueStore {
  _RecordingStore({this.failure});

  final Object? failure;
  final List<String> calls = <String>[];
  final MemoryKeyValueStore _values = MemoryKeyValueStore();

  // 故意异步抛：真实的通道故障也是 await 之后才回来的，同步抛会让并发用例
  // 退化成串行，测不出「两次调用各推一格」的竞态。
  Future<void> _maybeFail() async {
    if (failure != null) throw failure!;
  }

  @override
  Future<String?> getString(String key) async {
    calls.add('getString');
    await _maybeFail();
    return _values.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    calls.add('setString');
    await _maybeFail();
    return _values.setString(key, value);
  }

  @override
  Future<double?> getDouble(String key) async {
    calls.add('getDouble');
    await _maybeFail();
    return _values.getDouble(key);
  }

  @override
  Future<void> setDouble(String key, double value) async {
    calls.add('setDouble');
    await _maybeFail();
    return _values.setDouble(key, value);
  }

  @override
  Future<void> remove(String key) async {
    calls.add('remove');
    await _maybeFail();
    return _values.remove(key);
  }
}

void main() {
  test('首选后端可用时不碰后面的后端', () async {
    final primary = _RecordingStore();
    final secondary = _RecordingStore();
    final store = FallbackKeyValueStore(<KeyValueStore>[primary, secondary]);

    await store.setString('k', 'v');

    expect(await store.getString('k'), 'v');
    expect(secondary.calls, isEmpty);
    expect(store.activeBackend, same(primary));
  });

  test('首选后端抛 channel-error 时降级到次选并写进去', () async {
    final primary = _RecordingStore(failure: _channelError('setString'));
    final secondary = _RecordingStore();
    final store = FallbackKeyValueStore(<KeyValueStore>[primary, secondary]);

    await store.setString('hmusic.serverBase', 'http://192.168.0.198:6650');

    expect(
      await secondary.getString('hmusic.serverBase'),
      'http://192.168.0.198:6650',
    );
    expect(store.activeBackend, same(secondary));
  });

  test('降级只发生一次，之后不再重试坏掉的后端', () async {
    final primary = _RecordingStore(failure: _channelError('getString'));
    final secondary = _RecordingStore();
    final store = FallbackKeyValueStore(<KeyValueStore>[primary, secondary]);

    await store.getString('k');
    await store.setString('k', 'v');
    await store.getString('k');

    expect(primary.calls, <String>['getString']);
    expect(secondary.calls, <String>['getString', 'setString', 'getString']);
  });

  test('两级 preferences 都不可用时退到内存，读写照旧不抛', () async {
    final store = FallbackKeyValueStore(<KeyValueStore>[
      _RecordingStore(failure: _channelError('getString')),
      _RecordingStore(failure: MissingPluginException('no impl')),
      MemoryKeyValueStore(),
    ]);

    await store.setDouble('hmusic.localVolume', 0.4);

    expect(await store.getDouble('hmusic.localVolume'), 0.4);
    expect(await store.getString('missing'), isNull);
  });

  test('SharedPreferencesAsync 构造抛 StateError 也算平台故障', () async {
    final secondary = _RecordingStore();
    final store = FallbackKeyValueStore(<KeyValueStore>[
      _RecordingStore(failure: StateError('platform instance must be set')),
      secondary,
    ]);

    await store.setString('k', 'v');

    expect(await secondary.getString('k'), 'v');
  });

  test('并发调用同时撞坏通道时不会跳过中间那层', () async {
    // 开屏就是这个形状：读服务器地址和读本机音量几乎同时发出。
    final secondary = _RecordingStore();
    final store = FallbackKeyValueStore(<KeyValueStore>[
      _RecordingStore(failure: _channelError('getString')),
      secondary,
      MemoryKeyValueStore(),
    ]);

    await Future.wait(<Future<void>>[
      store.setString('hmusic.serverBase', 'http://192.168.0.198:6650'),
      store.setDouble('hmusic.localVolume', 0.5),
    ]);

    expect(store.activeBackend, same(secondary));
    expect(await secondary.getString('hmusic.serverBase'), isNotNull);
    expect(await secondary.getDouble('hmusic.localVolume'), 0.5);
  });

  test('非平台故障照原样抛出，不吞业务错误', () async {
    final store = FallbackKeyValueStore(<KeyValueStore>[
      _RecordingStore(failure: FormatException('坏值')),
      _RecordingStore(),
    ]);

    await expectLater(store.getString('k'), throwsFormatException);
  });

  test('最后一层抛错时如实冒泡', () async {
    final store = FallbackKeyValueStore(<KeyValueStore>[
      _RecordingStore(failure: _channelError('getString')),
      _RecordingStore(failure: _channelError('getString')),
    ]);

    await expectLater(
      store.getString('k'),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'channel-error'),
      ),
    );
  });
}
