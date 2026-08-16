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
  const AppReleaseInfo({required this.version, this.notes, this.url});

  final String version;
  final String? notes;
  final String? url;

  bool hasUpdateOver(String current) => isNewerVersion(version, current);
}

// App 仓库根的 app-config.json：不发服务端新版也能全局控制老 App 准入。
// minVersion 高于当前版本即强制升级；notice/downloadUrl 展示在强升页。
class AppRemoteConfig {
  const AppRemoteConfig({this.minVersion = '', this.notice, this.downloadUrl});

  factory AppRemoteConfig.fromJson(Map<String, Object?> json) {
    return AppRemoteConfig(
      minVersion: '${json['minVersion'] ?? ''}',
      notice: json['notice'] == null ? null : '${json['notice']}',
      downloadUrl: json['downloadUrl'] == null
          ? null
          : '${json['downloadUrl']}',
    );
  }

  final String minVersion;
  final String? notice;
  final String? downloadUrl;
}
