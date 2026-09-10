part of 'about_section.dart';

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
