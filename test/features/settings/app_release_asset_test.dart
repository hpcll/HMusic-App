import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/network/api_client.dart';
import 'package:hmusic/core/network/api_failure.dart';
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
  _StubAdapter(this.body, {this.status = 200, this.headers});

  final Map<String, Object?> body;
  final int status;
  final Map<String, List<String>>? headers;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      ...?headers,
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
  // 用户反馈：挂着 VPN 也报「网络不通或超时」。限流（403 + 余量 0，代理出口
  // 每小时 60 次很容易被占满）此前和断网共用一句话，改成各报各的。
  test('限流 403：报限流，不再说网络不通', () async {
    final dio = Dio()
      ..httpClientAdapter = _StubAdapter(
        <String, Object?>{'message': 'API rate limit exceeded'},
        status: 403,
        headers: <String, List<String>>{
          'x-ratelimit-remaining': <String>['0'],
        },
      );
    final apiClient = _MockApiClient();
    when(
      () => apiClient.getMap(any(), authenticated: any(named: 'authenticated')),
    ).thenThrow(Exception('no server'));
    final repository = ApiUpdateRepository(apiClient: apiClient, github: dio);

    await expectLater(
      repository.latestAppRelease(),
      throwsA(
        isA<ApiFailure>().having((f) => f.message, 'message', contains('限流')),
      ),
    );
  });

  // GitHub 不通时的国内退路：app-config.json（三镜像 + 服务端中转）里带了
  // latestVersion/apkUrl 就照常给出新版，不报错。
  test('GitHub 挂了但 app-config 带了新版信息：走退路，不报错', () async {
    final dio = Dio()
      ..httpClientAdapter = _MirrorAdapter(<String, Object?>{
        'latestVersion': 'v0.1.7',
        'apkUrl': 'https://mirror.example.com/hmusic.apk',
        'apkSize': 24000000,
        'notice': '镜像下发的说明',
      });
    final apiClient = _MockApiClient();
    when(
      () => apiClient.getMap(any(), authenticated: any(named: 'authenticated')),
    ).thenThrow(Exception('no server'));
    final repository = ApiUpdateRepository(apiClient: apiClient, github: dio);

    final release = await repository.latestAppRelease();

    expect(release?.version, 'v0.1.7');
    expect(release?.apkUrl, 'https://mirror.example.com/hmusic.apk');
    expect(release?.apkSize, 24000000);
  });
}

// releases/latest 报 500，app-config.json 镜像正常返回：复刻「GitHub API 不通、
// 但静态文件镜像可达」这一真实组合。
class _MirrorAdapter implements HttpClientAdapter {
  _MirrorAdapter(this.config);

  final Map<String, Object?> config;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.host == 'api.github.com') {
      return ResponseBody.fromString('{"message":"boom"}', 500);
    }
    return ResponseBody.fromString(
      jsonEncode(config),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
