// 升级相关模型：服务端 /system/update 响应 + App 自身的 GitHub Release。

// 数字段逐段比较（v 前缀无视），段数不齐补 0；与 Server 端同一口径。
bool isNewerVersion(String latest, String current) {
  List<int> parse(String value) => value
      .replaceFirst(RegExp('^v', caseSensitive: false), '')
      .split('.')
      .map((part) => int.tryParse(part.replaceAll(RegExp(r'\D.*$'), '')) ?? 0)
      .toList();
  final a = parse(latest);
  final b = parse(current);
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i += 1) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

class ServerUpdateInfo {
  const ServerUpdateInfo({
    required this.current,
    required this.latest,
    required this.hasUpdate,
    required this.canSelfUpdate,
    required this.deployMode,
    this.notes,
    this.url,
    this.updating = false,
  });

  factory ServerUpdateInfo.fromJson(Map<String, Object?> json) {
    return ServerUpdateInfo(
      current: '${json['current'] ?? ''}',
      latest: json['latest'] == null ? null : '${json['latest']}',
      hasUpdate: json['hasUpdate'] == true,
      canSelfUpdate: json['canSelfUpdate'] == true,
      deployMode: '${json['deployMode'] ?? 'unknown'}',
      notes: json['notes'] == null ? null : '${json['notes']}',
      url: json['url'] == null ? null : '${json['url']}',
      updating: json['updating'] == true,
    );
  }

  final String current;
  final String? latest;
  final bool hasUpdate;
  final bool canSelfUpdate;

  // native | docker | unknown（docker 无法容器内自升级，只给命令提示）。
  final String deployMode;
  final String? notes;
  final String? url;
  final bool updating;
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    this.notes,
    this.url,
    this.apkUrl,
    this.apkSize,
  });

  final String version;
  final String? notes;

  // Release 页面地址（不支持自更新的平台跳这里）。
  final String? url;

  // 直装用的 APK 资产直链与字节数（Android 自更新用；Release 里没有 APK
  // 资产时为空，UI 退回跳浏览器）。
  final String? apkUrl;
  final int? apkSize;

  bool hasUpdateOver(String current) => isNewerVersion(version, current);
}

// app-config.json 里的分架构 APK 条目。
//
// 为什么要单独存一份：Flutter 给分架构包改写了版本号（abi 基数 * 1000 + 构建号，
// 见 flutter_tools 的 FlutterPlugin.kt），于是通用包的版本号天生比所有分架构包小。
// 一台已经装过 arm64 包的设备（版本号 2007）再收到通用包（版本号 8）会被安卓判成
// 降级、直接拒装。退路也按本机架构挑，才既省流量又不会让版本号往回走。
class AppRemoteApk {
  const AppRemoteApk({required this.abi, required this.url, this.size});

  factory AppRemoteApk.fromJson(Map<String, Object?> json) => AppRemoteApk(
    abi: '${json['abi'] ?? ''}',
    url: '${json['url'] ?? ''}',
    size: (json['size'] as num?)?.toInt(),
  );

  // arm64-v8a / armeabi-v7a / x86_64，与资产名和 Abi.current() 的写法一致。
  final String abi;
  final String url;
  final int? size;
}

// App 仓库根的 app-config.json：不发服务端新版也能全局控制老 App 准入。
// minVersion 高于当前版本即强制升级；notice/downloadUrl 展示在强升页。
// latestVersion/apkUrl/apkSize/apks 是「检查更新」的国内退路：api.github.com 在大陆
// （乃至挂代理时）常不通，而这份文件有 Gitee/raw/jsDelivr 三镜像 + 服务端中转，
// 发版时把它们填上，App 拉不到 GitHub 也能看到新版并直装。
class AppRemoteConfig {
  const AppRemoteConfig({
    this.minVersion = '',
    this.notice,
    this.downloadUrl,
    this.latestVersion = '',
    this.apkUrl,
    this.apkSize,
    this.apks = const <AppRemoteApk>[],
    this.netdiskUrl,
    this.iosUrl,
  });

  factory AppRemoteConfig.fromJson(Map<String, Object?> json) {
    return AppRemoteConfig(
      minVersion: '${json['minVersion'] ?? ''}',
      notice: json['notice'] == null ? null : '${json['notice']}',
      downloadUrl: json['downloadUrl'] == null
          ? null
          : '${json['downloadUrl']}',
      latestVersion: '${json['latestVersion'] ?? ''}',
      apkUrl: json['apkUrl'] == null ? null : '${json['apkUrl']}',
      apkSize: (json['apkSize'] as num?)?.toInt(),
      apks: _parseApks(json['apks']),
      netdiskUrl: json['netdiskUrl'] == null ? null : '${json['netdiskUrl']}',
      iosUrl: json['iosUrl'] == null ? null : '${json['iosUrl']}',
    );
  }

  static List<AppRemoteApk> _parseApks(Object? raw) {
    if (raw is! List<Object?>) return const <AppRemoteApk>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(AppRemoteApk.fromJson)
        .where((apk) => apk.abi.isNotEmpty && apk.url.isNotEmpty)
        .toList(growable: false);
  }

  final String minVersion;
  final String? notice;
  final String? downloadUrl;

  // 最新可下版本（空 = 这份配置没带更新信息）。
  final String latestVersion;

  // 通用包（含全部架构）。老版本 App 只认这两个字段，所以保留；新版本在本机
  // 架构命中 apks 时优先用分架构包。
  final String? apkUrl;
  final int? apkSize;

  // 分架构包列表，未命中时调用方退回通用包。
  final List<AppRemoteApk> apks;

  // 本机架构对应的分架构包；没有匹配项返回 null。
  AppRemoteApk? apkFor(String abiTag) {
    if (abiTag.isEmpty) return null;
    for (final apk in apks) {
      if (apk.abi == abiTag) return apk;
    }
    return null;
  }

  // 网盘下载入口（没梯子时的退路；空则用内置的 kNetdiskDownloadUrl）。
  final String? netdiskUrl;

  // iOS 的更新出口（App Store / TestFlight 页面链接；空 = 还没上架，
  // iOS 端只展示说明、不给下载动作）。
  final String? iosUrl;
}
