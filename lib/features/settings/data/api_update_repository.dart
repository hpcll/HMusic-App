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
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
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
  ApiUpdateRepository({required ApiClient apiClient, required Dio github})
    : _apiClient = apiClient,
      _github = github;

  final ApiClient _apiClient;
  final Dio _github;

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
      return AppReleaseInfo(
        version: version,
        notes: body['body'] == null ? null : '${body['body']}',
        url: body['html_url'] == null ? null : '${body['html_url']}',
      );
    } on DioException catch (error) {
      // 404 = 仓库还没发布 Release（或暂未公开），视为「没有更新渠道」而非报错。
      if (error.response?.statusCode == 404) return null;
      throw ApiFailure(
        kind: ApiFailureKind.offline,
        statusCode: error.response?.statusCode,
        code: 'APP_UPDATE_CHECK_FAILED',
        message: '无法连接 GitHub 检查 App 更新（网络不通或超时）',
      );
    }
  }

  // 远程配置镜像序列：GitHub raw 主源 + jsDelivr CDN 兜底（大陆网络下
  // raw 常不可达）。任一成功即用，全部失败按无配置处理（门控放行）。
  static const List<String> _remoteConfigMirrors = <String>[
    'https://raw.githubusercontent.com/$kAppReleaseRepo/main/app-config.json',
    'https://fastly.jsdelivr.net/gh/$kAppReleaseRepo@main/app-config.json',
  ];

  @override
  Future<AppRemoteConfig?> remoteAppConfig() async {
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
