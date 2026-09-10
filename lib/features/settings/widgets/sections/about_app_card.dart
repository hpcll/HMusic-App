part of 'about_section.dart';

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
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    // App 内直装的条件：Android 直装渠道 + Release 里真有 APK 资产。
    // 不满足就退回跳浏览器（iOS 走 App Store 链接、桌面各自的包、商店版交给商店）。
    final canInstall =
        canSelfInstallApp && (release?.apkUrl?.isNotEmpty ?? false);
    // iOS 的下载出口只有 App Store；没上架（iosUrl 空）就不给按钮，只说明。
    final iosStoreUrl = state.iosUrl;
    final showStoreButton = isIos && iosStoreUrl.isNotEmpty;
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
              if (isIos && !showStoreButton)
                Text(
                  'iOS 版通过 App Store / TestFlight 分发，上架后在这里更新。',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: canInstall
                        ? () => unawaited(
                            ref
                                .read(appDownloadViewModelProvider.notifier)
                                .downloadAndInstall(release),
                          )
                        : () => unawaited(_openDownload(release, iosStoreUrl)),
                    child: Text(
                      canInstall
                          ? '下载并安装'
                          : showStoreButton
                          ? '去 App Store 更新'
                          : '去下载',
                    ),
                  ),
                ),
            ],
          ],
          // 网盘退路常驻：下载直链在 github.com，没梯子的用户「查得到、下不来」
          //（检查更新那一路有 Gitee 镜像绕开，下载没有）。链接由 app-config.json
          // 下发、内置常量兜底，所以网络最差时它也在。iOS 例外——网盘里是
          // APK/ipa 装包，装不上 iPhone，露出来只会误导。
          if (!isIos) ...<Widget>[
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
        ],
      ),
    );
  }

  // 下载出口：iOS 有 App Store 链接时直达商店，否则落回 Release 页面。
  Future<void> _openDownload(AppReleaseInfo release, String iosUrl) =>
      _openUrl(iosUrl.isNotEmpty ? iosUrl : release.url ?? '');

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
