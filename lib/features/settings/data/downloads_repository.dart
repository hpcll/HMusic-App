import '../../../core/models/hmusic_track.dart';
import '../models/download_record.dart';

// 本地下载仓库（对齐 web DownloadsSection）：列表 + 删除 + 重试。
// 下载进行中由 view_model 每 3s 轮询列表，仓库本身无状态。
abstract interface class DownloadsRepository {
  // 已下载/下载中列表，按创建时间倒序（服务端已排好）。
  Future<List<DownloadRecord>> list();

  // 发起下载（搜索页触发）：quality 省略时服务端用默认音质。
  Future<void> start(HMusicTrack track, {String? quality});

  // 删除本地文件和记录。
  Future<void> remove(String id);

  // 重新下载（复用失败记录的 track 快照）。
  Future<void> retry(HMusicTrack track);
}
