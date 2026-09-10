part of 'about_section.dart';

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
