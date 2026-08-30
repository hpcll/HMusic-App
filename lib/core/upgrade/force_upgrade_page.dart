import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/hmusic_palette.dart';
import '../../features/connection/views/connection_page.dart';
import '../../features/settings/data/api_update_repository.dart';
import '../app_version.dart';
import 'upgrade_gate.dart';

// 全屏强制升级页：门控命中后由 router redirect 押到这里，无返回路径。
// 服务端要求的门可「更换服务器」绕开（连兼容的旧服务端）；远程配置的门只能升级。
class ForceUpgradePage extends ConsumerWidget {
  const ForceUpgradePage({super.key});

  static const String path = '/force-upgrade';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final gate = ref.watch(upgradeGateProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.system_update_alt_rounded,
                  size: 48,
                  color: palette.accent,
                ),
                const SizedBox(height: 20),
                Text(
                  '需要升级 HMusic',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: palette.textStrong,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  gate.fromServer
                      ? '连接的服务端要求 App 不低于 v${gate.requiredVersion}'
                            '（当前 v$kAppVersion）。升级后即可继续使用。'
                      : '当前版本 v$kAppVersion 已停止支持，'
                            '请升级到 v${gate.requiredVersion} 或更新版本。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: palette.muted,
                  ),
                ),
                if (gate.notice != null && gate.notice!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    gate.notice!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: palette.mutedStrong,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => unawaited(_download(ref, gate)),
                  child: const Text('去下载新版本'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () =>
                      unawaited(ref.read(upgradeGateProvider.notifier).check()),
                  child: const Text('我已升级，重新检测'),
                ),
                if (gate.fromServer) ...<Widget>[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      ref.read(upgradeGateProvider.notifier).reset();
                      context.go(ConnectionPage.switchPath);
                    },
                    child: const Text('更换服务器'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 下载页优先级：远程配置指定 → 最新 Release 页 → 仓库 Releases 列表兜底。
  Future<void> _download(WidgetRef ref, UpgradeGateState gate) async {
    var url = gate.downloadUrl;
    if (url == null || url.isEmpty) {
      try {
        url =
            (await ref.read(updateRepositoryProvider).latestAppRelease())?.url;
      } catch (_) {
        url = null;
      }
    }
    url ??= 'https://github.com/$kAppReleaseRepo/releases';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
