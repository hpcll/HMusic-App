import 'download_record.dart';

// 本地下载子页状态（对齐 web DownloadsSection）。列表 + 进行中轮询由 view_model 驱动。
class DownloadsState {
  const DownloadsState({
    this.items = const <DownloadRecord>[],
    this.loaded = false,
    this.actingId = '',
    this.notice,
  });

  final List<DownloadRecord> items;
  final bool loaded;

  // 正在删除/重试的记录 id，防连点。
  final String actingId;
  final String? notice;

  // 有排队/下载中的记录时才继续 3s 轮询。
  bool get hasActive => items.any((d) => d.isActive);

  DownloadsState copyWith({
    List<DownloadRecord>? items,
    bool? loaded,
    String? actingId,
    String? notice,
    bool clearNotice = false,
  }) {
    return DownloadsState(
      items: items ?? this.items,
      loaded: loaded ?? this.loaded,
      actingId: actingId ?? this.actingId,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}
