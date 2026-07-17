import '../../../core/audio/models/hmusic_playback_state.dart';
import '../models/chart.dart';

// 榜单数据契约：目录、详情、整榜播放。条目解析（Apple 榜搜索匹配）属业务，放 ViewModel。
abstract interface class ChartsRepository {
  Future<List<Chart>> getCharts();

  Future<ChartDetail> getChart(String id);

  // 返回服务端开播后的权威播放状态，调用方喂给 AudioHandler 本机出声。
  Future<HMusicPlaybackState> playAll(String id, {int? startIndex});
}
