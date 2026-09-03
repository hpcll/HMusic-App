import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// App 自更新（直装渠道）：把 Release 里的 APK 下到自家缓存目录，再交系统安装器。
// 只有 Android 走这条路——iOS 得走 App Store/TestFlight，桌面走各自的包，
// 那些平台仍旧跳浏览器（见 about_section 的 _AppCard）。
//
// 下载用 dio（已是项目依赖）而不是另找下载库：进度就是 onReceiveProgress，
// 断点续传这类需求现在没有，装包 25MB 量级重下一遍比维护续传状态便宜。
// 装包路径由原生侧给（cacheDir/updates），与 AndroidManifest 里 FileProvider
// 暴露的目录严格对应。
final Provider<ApkUpdater> apkUpdaterProvider = Provider<ApkUpdater>(
  (ref) => ApkUpdater(dio: Dio()),
);

// 自更新是否可用：非 Android、或商店版（商店渠道自己更新）都不可用。
bool get apkSelfUpdateSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class ApkUpdater {
  ApkUpdater({required Dio dio, MethodChannel? channel})
    : _dio = dio,
      _channel = channel ?? const MethodChannel('hmusic/apk_installer');

  final Dio _dio;
  final MethodChannel _channel;

  // 「安装未知应用」是否已授权（Android 8+ 才有这个开关）。
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  // 把用户送到系统的「安装未知应用」开关页。
  Future<void> requestInstallPermission() =>
      _channel.invokeMethod<void>('requestPermission');

  // 下载 APK，返回落地路径。[onProgress] 的两个参数是已收/总字节，
  // 服务端不给 content-length 时总字节为 -1（UI 退回不确定进度）。
  Future<String> download({
    required String url,
    required String version,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await _channel.invokeMethod<String>('cacheDir');
    if (dir == null || dir.isEmpty) {
      throw const ApkUpdateFailure('拿不到缓存目录，无法下载');
    }
    final updates = Directory('$dir/updates');
    await updates.create(recursive: true);
    // 同名文件先清掉：上次下崩留下的半截包会被安装器当成损坏的 APK。
    final path = '${updates.path}/hmusic-$version.apk';
    final file = File(path);
    if (file.existsSync()) await file.delete();
    try {
      await _dio.download(
        url,
        path,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      if (file.existsSync()) await file.delete();
      if (CancelToken.isCancel(error)) throw const ApkUpdateCancelled();
      throw ApkUpdateFailure('下载失败：${error.message ?? error.type.name}');
    }
    return path;
  }

  // 交系统安装器（用户还要在系统弹窗里按一次「安装」）。
  Future<void> install(String path) =>
      _channel.invokeMethod<void>('install', <String, Object?>{'path': path});
}

class ApkUpdateFailure implements Exception {
  const ApkUpdateFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApkUpdateCancelled implements Exception {
  const ApkUpdateCancelled();
}
