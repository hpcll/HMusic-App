import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/app_version.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../../../shared/widgets/hmusic_dialog.dart';
import '../../models/app_update.dart';
import '../../models/update_state.dart';
import '../../view_models/app_download_view_model.dart';
import '../../view_models/update_view_model.dart';

// 关于与更新：服务端版本检查/一键升级 + App 自身新版检查。
// App 新版在 Android 直装渠道走 App 内下载 + 进度条 + 交系统安装器；
// 其余平台（iOS/桌面/商店版）仍旧跳浏览器。
class AboutSectionView extends ConsumerStatefulWidget {
  const AboutSectionView({super.key});

  @override
  ConsumerState<AboutSectionView> createState() => _AboutSectionViewState();
}

class _AboutSectionViewState extends ConsumerState<AboutSectionView> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(updateViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateViewModelProvider);
    final notifier = ref.read(updateViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ServerCard(state: state, notifier: notifier),
        const SizedBox(height: 14),
        _AppCard(state: state, notifier: notifier),
      ],
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.state, required this.notifier});

  final UpdateState state;
  final UpdateViewModel notifier;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final update = state.serverUpdate;
    return HMusicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _VersionRow(
            title: 'HMusic Server',
            version: state.serverVersion.isEmpty
                ? '未知'
                : 'v${state.serverVersion}',
            trailing: OutlinedButton(
              onPressed: state.checkingServer || state.upgrading
                  ? null
                  : () => unawaited(notifier.checkServer()),
              child: Text(state.checkingServer ? '检查中…' : '检查更新'),
            ),
          ),
          if (state.upgrading) ...<Widget>[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 10),
            Text(
              '正在升级，服务端会短暂重启，请勿断电…',
              style: TextStyle(fontSize: 13, color: palette.muted),
            ),
          ] else if (update != null && update.hasUpdate) ...<Widget>[
            const SizedBox(height: 14),
            Divider(height: 1, color: palette.lineSoft),
            const SizedBox(height: 14),
            Text(
              '发现新版本 ${update.latest}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.textStrong,
              ),
            ),
            if (update.notes != null && update.notes!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                update.notes!,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: palette.muted,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (update.canSelfUpdate)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () => unawaited(_confirmUpgrade(context)),
                  child: const Text('立即升级'),
                ),
              )
            else
              Text(
                update.deployMode == 'docker'
                    ? '这台服务端还没有升级守护（旧版 Docker 部署）：在宿主机进入安装'
                          '目录执行一次 bash install.sh --update，之后就能在这里一键升级。'
                    : '当前部署方式不支持一键升级，请参考 README 手动更新。',
                style: TextStyle(fontSize: 12.5, color: palette.muted),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmUpgrade(BuildContext context) async {
    final ok = await showHMusicDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('升级服务端'),
        content: const Text('服务端将下载新版并自动重启，期间播放控制会短暂不可用。继续吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('开始升级'),
          ),
        ],
      ),
    );
    if (ok ?? false) await notifier.upgradeServer();
  }
}

class _AppCard extends ConsumerWidget {
  const _AppCard({required this.state, required this.notifier});

  final UpdateState state;
  final UpdateViewModel notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final release = state.appRelease;
    final hasUpdate = release != null && release.hasUpdateOver(kAppVersion);
    final download = ref.watch(appDownloadViewModelProvider);
    // App 内直装的条件：Android 直装渠道 + Release 里真有 APK 资产。
    // 不满足就退回跳浏览器（iOS 走 App Store、桌面各自的包、商店版交给商店）。
    final canInstall =
        canSelfInstallApp && (release?.apkUrl?.isNotEmpty ?? false);
    return HMusicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _VersionRow(
            title: 'HMusic App',
            version: 'v$kAppVersion',
            trailing: OutlinedButton(
              onPressed: state.checkingApp || download.busy
                  ? null
                  : () => unawaited(notifier.checkApp()),
              child: Text(state.checkingApp ? '检查中…' : '检查更新'),
            ),
          ),
          if (hasUpdate) ...<Widget>[
            const SizedBox(height: 14),
            Divider(height: 1, color: palette.lineSoft),
            const SizedBox(height: 14),
            Text(
              '发现新版本 ${release.version}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.textStrong,
              ),
            ),
            if (release.notes != null && release.notes!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                release.notes!,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: palette.muted,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (download.stage == AppDownloadStage.downloading)
              _DownloadProgress(
                state: download,
                notifier: ref.read(appDownloadViewModelProvider.notifier),
              )
            else if (download.stage == AppDownloadStage.installing)
              Text(
                '已下载完成，按系统弹窗里的「安装」继续',
                style: TextStyle(fontSize: 12.5, color: palette.muted),
              )
            else ...<Widget>[
              if (download.error != null) ...<Widget>[
                Text(
                  download.error!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: canInstall
                      ? () => unawaited(
                          ref
                              .read(appDownloadViewModelProvider.notifier)
                              .downloadAndInstall(release),
                        )
                      : () => unawaited(_openDownload(release)),
                  child: Text(canInstall ? '下载并安装' : '去下载'),
                ),
              ),
            ],
          ],
          // 网盘退路常驻：下载直链在 github.com，没梯子的用户「查得到、下不来」
          //（检查更新那一路有 Gitee 镜像绕开，下载没有）。链接由 app-config.json
          // 下发、内置常量兜底，所以网络最差时它也在。
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => unawaited(_openUrl(state.netdiskUrl)),
              child: Text(
                '从网盘下载（国内直连，含各平台安装包）',
                style: TextStyle(fontSize: 12.5, color: palette.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDownload(AppReleaseInfo release) =>
      _openUrl(release.url ?? '');

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

// 下载进度：有 content-length 就走确定进度 + 「x.x / y.y MB」，没有就走
// 不确定条（服务端不给长度时不假装知道百分比）。
class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.state, required this.notifier});

  final AppDownloadState state;
  final AppDownloadViewModel notifier;

  static String _mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final progress = state.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LinearProgressIndicator(value: progress, minHeight: 2),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                progress == null
                    ? '正在下载…'
                    : '正在下载 ${_mb(state.received)} / ${_mb(state.total)} MB'
                          '（${(progress * 100).round()}%）',
                style: TextStyle(fontSize: 12.5, color: palette.muted),
              ),
            ),
            TextButton(onPressed: notifier.cancel, child: const Text('取消')),
          ],
        ),
      ],
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.title,
    required this.version,
    required this.trailing,
  });

  final String title;
  final String version;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: palette.textStrong,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '当前版本 $version',
                style: TextStyle(fontSize: 13, color: palette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }
}
