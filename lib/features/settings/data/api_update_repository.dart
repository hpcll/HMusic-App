import 'dart:ffi' show Abi;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_version.dart';
import '../../../core/models/server_info.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/app_update.dart';

final Provider<UpdateRepository> updateRepositoryProvider =
    Provider<UpdateRepository>((ref) {
      return ApiUpdateRepository(
        apiClient: ref.watch(apiClientProvider),
        // GitHub 是外部主机，不走 ApiClient（铁律 3 只约束发往 Server 的请求；
        // ApiClient 会强制拼 serverBase + /api/v1 前缀，对外部 API 不适用）。
        github: Dio(
          BaseOptions(
            // 15s 而不是 8s：走代理/VPN 到 api.github.com 的握手常在 10s 上下，
            // 8s 会把「慢」误报成「不通」（用户反馈挂了 VPN 也说网络不通）。
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            responseType: ResponseType.json,
            headers: <String, Object?>{
              'accept': 'application/vnd.github+json',
              'user-agent': 'hmusic-app/$kAppVersion',
            },
          ),
        ),
      );
    });

abstract class UpdateRepository {
  // 公开接口（无鉴权）：升级期间轮询服务端是否已带新版本号回来。
  Future<String> serverVersion();

  // 公开接口：服务端版本 + 最低 App 版本要求（强制升级门用）。
  Future<ServerInfo> serverInfo();

  Future<ServerUpdateInfo> checkServer();

  Future<void> triggerServerUpdate();

  // App 自身最新 Release；仓库还没发布过任何 Release 时返回 null。
  Future<AppReleaseInfo?> latestAppRelease();

  // 仓库里的远程配置（多镜像尝试，全挂返回 null——门控按「无配置」放行）。
  Future<AppRemoteConfig?> remoteAppConfig();
}

class ApiUpdateRepository implements UpdateRepository {
  ApiUpdateRepository({
    required ApiClient apiClient,
    required Dio github,
    String? abiTag,
  }) : _apiClient = apiClient,
       _github = github,
       _abiTag = abiTag ?? _currentAbiTag();

  final ApiClient _apiClient;
  final Dio _github;

  // 本机 ABI 在资产名里的写法（arm64 / armeabi / x86_64 / x86）：Release 里同时
  // 有分架构包和通用包时挑对应的那个，能把自更新的下载量从 60MB 级压到 25MB 级。
  // 目前发布流水线只出通用包，这一支等于空转（挑不到就退通用包）。
  final String _abiTag;

  static String _currentAbiTag() => switch (Abi.current()) {
    Abi.androidArm64 => 'arm64',
    Abi.androidArm => 'armeabi',
    Abi.androidX64 => 'x86_64',
    Abi.androidIA32 => 'x86',
    _ => '',
  };

  @override
  Future<String> serverVersion() async {
    final info = await _apiClient.getMap('/system/info', authenticated: false);
    return '${info['version'] ?? ''}';
  }

  @override
  Future<ServerInfo> serverInfo() async {
    return ServerInfo.fromJson(
      await _apiClient.getMap('/system/info', authenticated: false),
    );
  }

  @override
  Future<ServerUpdateInfo> checkServer() async {
    return ServerUpdateInfo.fromJson(await _apiClient.getMap('/system/update'));
  }

  @override
  Future<void> triggerServerUpdate() async {
    await _apiClient.postMap('/system/update');
  }

  @override
  Future<AppReleaseInfo?> latestAppRelease() async {
    try {
      final response = await _github.get<Map<String, Object?>>(
        'https://api.github.com/repos/$kAppReleaseRepo/releases/latest',
      );
      final body = response.data ?? const <String, Object?>{};
      final version = '${body['tag_name'] ?? body['name'] ?? ''}'.trim();
      if (version.isEmpty) return null;
      final apk = _pickApkAsset(body['assets']);
      return AppReleaseInfo(
        version: version,
        notes: body['body'] == null ? null : '${body['body']}',
        url: body['html_url'] == null ? null : '${body['html_url']}',
        apkUrl: apk == null ? null : '${apk['browser_download_url']}',
        apkSize: apk == null ? null : (apk['size'] as num?)?.toInt(),
      );
    } on DioException catch (error) {
      // 404 = 仓库还没发布 Release（或暂未公开），视为「没有更新渠道」而非报错。
      if (error.response?.statusCode == 404) return null;
      // GitHub API 不通时退到 app-config.json：那份文件有三个镜像 + 服务端中转
      // （见 remoteAppConfig），大陆不翻墙也能读到，只要发版时把 latestVersion/
      // apkUrl 填进去，这里就能照常给出新版信息。
      final fallback = await _releaseFromRemoteConfig();
      if (fallback != null) return fallback;
      throw ApiFailure(
        kind: ApiFailureKind.offline,
        statusCode: error.response?.statusCode,
        code: 'APP_UPDATE_CHECK_FAILED',
        message: _githubFailureMessage(error),
      );
    }
  }

  // 把 DioException 翻成人能照着行动的一句话。此前一律报「网络不通或超时」，
  // 于是限流（403，代理出口 IP 每小时 60 次很容易被占满）也被说成断网。
  static String _githubFailureMessage(DioException error) {
    final int? status = error.response?.statusCode;
    if (status == 403 || status == 429) {
      final remaining = error.response?.headers.value('x-ratelimit-remaining');
      if (remaining == '0') {
        return 'GitHub 接口限流：同一出口 IP 每小时 60 次，代理出口常被占满，'
            '过一会儿再试（或稍后从设置里手动下载）';
      }
      return 'GitHub 拒绝了这次请求（$status）';
    }
    if (status != null) return 'GitHub 返回 $status，稍后再试';
    return switch (error.type) {
      DioExceptionType.connectionTimeout =>
        '连接 GitHub 超时（15s）：线路慢或被拦，挂代理也可能卡在握手',
      DioExceptionType.receiveTimeout => 'GitHub 响应超时（15s）',
      DioExceptionType.sendTimeout => '请求发送超时',
      DioExceptionType.badCertificate => 'TLS 证书校验失败（可能被中间人/代理改写）',
      DioExceptionType.connectionError =>
        '连不上 GitHub：DNS 解析或线路被拦（${error.message ?? 'connection error'}）',
      _ => '检查更新失败：${error.message ?? error.type.name}',
    };
  }

  // app-config.json 里带的新版信息（发版时填）。没有 latestVersion 就当没有这条
  // 退路，让上层报 GitHub 的真实失败原因。
  Future<AppReleaseInfo?> _releaseFromRemoteConfig() async {
    try {
      final config = await remoteAppConfig();
      final version = config?.latestVersion ?? '';
      if (version.isEmpty) return null;
      return AppReleaseInfo(
        version: version,
        notes: config?.notice,
        url: config?.downloadUrl,
        apkUrl: config?.apkUrl,
        apkSize: config?.apkSize,
      );
    } catch (_) {
      return null;
    }
  }

  // Release 资产里的可直装 APK：排掉 .aab 与未签名包（装不上）。同时有分架构包
  // 和通用包时优先本机架构，否则用不带架构标记的通用包。
  Map<String, Object?>? _pickApkAsset(Object? assets) {
    if (assets is! List<Object?>) return null;
    final candidates = <Map<String, Object?>>[];
    for (final asset in assets.whereType<Map<String, Object?>>()) {
      final name = '${asset['name'] ?? ''}'.toLowerCase();
      if (!name.endsWith('.apk') || name.contains('unsigned')) continue;
      if ('${asset['browser_download_url'] ?? ''}'.isEmpty) continue;
      candidates.add(asset);
    }
    if (candidates.isEmpty) return null;
    if (_abiTag.isNotEmpty) {
      for (final asset in candidates) {
        if ('${asset['name']}'.toLowerCase().contains(_abiTag)) return asset;
      }
    }
    // 通用包：名字里不带任何架构标记的那个。
    const abis = <String>['arm64', 'armeabi', 'x86_64', 'x86'];
    for (final asset in candidates) {
      final name = '${asset['name']}'.toLowerCase();
      if (!abis.any(name.contains)) return asset;
    }
    return candidates.first;
  }

  // 远程配置镜像序列：Gitee 国内主源（大陆免翻墙；镜像仓库建好后生效，
  // 未建时 404 秒过）→ GitHub raw → jsDelivr CDN。任一成功即用，
  // 全部失败按无配置处理（配合本地粘性缓存，见 upgrade_config_store）。
  static const List<String> _remoteConfigMirrors = <String>[
    'https://gitee.com/$kAppGiteeRepo/raw/main/app-config.json',
    'https://raw.githubusercontent.com/$kAppReleaseRepo/main/app-config.json',
    'https://fastly.jsdelivr.net/gh/$kAppReleaseRepo@main/app-config.json',
  ];

  @override
  Future<AppRemoteConfig?> remoteAppConfig() async {
    // 两级配合：优先走已连接服务端的中转 /system/app-config（NAS 网络通常
    // 比手机直连 GitHub 稳，且服务端有 30min 缓存 + 旧值兜底）；未连接/
    // 旧服务端（404）/中转自己也拉不到（available=false）时退直连镜像。
    try {
      final relay = await _apiClient.getMap(
        '/system/app-config',
        authenticated: false,
      );
      if (relay['available'] == true) {
        final config = relay['config'];
        if (config is Map) {
          return AppRemoteConfig.fromJson(
            config.map((k, v) => MapEntry('$k', v as Object?)),
          );
        }
      }
    } catch (_) {
      // 没配 server base / 服务端太旧 / 不可达：直连镜像兜底。
    }
    for (final url in _remoteConfigMirrors) {
      try {
        final response = await _github.get<Object?>(url);
        final data = response.data;
        final map = data is Map<String, Object?>
            ? data
            : data is Map
            ? data.map((k, v) => MapEntry('$k', v as Object?))
            : null;
        if (map == null) continue;
        return AppRemoteConfig.fromJson(map);
      } on DioException {
        continue; // 换下一个镜像。
      }
    }
    return null;
  }
}
