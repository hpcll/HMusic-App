import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/network/api_client.dart';
import 'package:hmusic/features/settings/data/api_update_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

// GitHub releases/latest 的响应片段：直装要从 assets 里挑出那个能装的 APK。
Map<String, Object?> _release(List<Map<String, Object?>> assets) =>
    <String, Object?>{
      'tag_name': 'v0.1.6',
      'body': '修了键盘让位',
      'html_url': 'https://github.com/hpcll/HMusic-App/releases/tag/v0.1.6',
      'assets': assets,
    };

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final Map<String, Object?> body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

ApiUpdateRepository _repository(Map<String, Object?> body) {
  final dio = Dio()..httpClientAdapter = _StubAdapter(body);
  return ApiUpdateRepository(apiClient: _MockApiClient(), github: dio);
}

void main() {
  test('Release 资产里挑可直装的 APK：跳过 aab 与未签名包', () async {
    final release = await _repository(
      _release(<Map<String, Object?>>[
        <String, Object?>{
          'name': 'hmusic-0.1.6-android.aab',
          'browser_download_url': 'https://example.com/a.aab',
          'size': 1,
        },
        <String, Object?>{
          'name': 'hmusic-0.1.6-android-unsigned.apk',
          'browser_download_url': 'https://example.com/unsigned.apk',
          'size': 2,
        },
        <String, Object?>{
          'name': 'hmusic-0.1.6-android.apk',
          'browser_download_url': 'https://example.com/hmusic.apk',
          'size': 26000000,
        },
      ]),
    ).latestAppRelease();

    expect(release?.version, 'v0.1.6');
    expect(release?.apkUrl, 'https://example.com/hmusic.apk');
    expect(release?.apkSize, 26000000);
  });

  test('Release 里没有 APK 资产：apkUrl 空，UI 退回跳浏览器', () async {
    final release = await _repository(
      _release(const <Map<String, Object?>>[]),
    ).latestAppRelease();

    expect(release?.version, 'v0.1.6');
    expect(release?.apkUrl, isNull);
    expect(release?.url, contains('releases/tag/v0.1.6'));
  });
}
