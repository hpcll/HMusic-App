import 'dart:convert';

import '../../async/serial_executor.dart';
import '../../network/api_failure.dart';
import '../../storage/key_value_store.dart';

/// 直连非敏感数据独立命名空间；修改从最新磁盘快照开始，防止并发收藏丢失。
class DirectLocalStore {
  DirectLocalStore(this._preferences);

  final KeyValueStore _preferences;
  final SerialExecutor _writes = SerialExecutor();

  Future<Map<String, Object?>> read(String section) =>
      _writes.run(() => _read(section));

  Future<T> update<T>(
    String section,
    T Function(Map<String, Object?> value) edit,
  ) => _writes.run(() async {
    final value = await _read(section);
    final result = edit(value);
    await _preferences.setString(
      'hmusic.direct.v1.$section',
      jsonEncode(value),
    );
    return result;
  });

  Future<Map<String, Object?>> _read(String section) async {
    final text = await _preferences.getString('hmusic.direct.v1.$section');
    if (text == null) return {};
    try {
      final value = jsonDecode(text);
      if (value is Map<String, Object?>) return value;
    } on FormatException {
      // 损坏数据不能静默重置，否则下一次写操作会覆盖用户的歌单。
    }
    throw const ApiFailure(
      kind: ApiFailureKind.invalidResponse,
      code: 'DIRECT_STORAGE_INVALID',
      message: '无法读取直连本地数据，请保留数据并重试',
    );
  }
}
