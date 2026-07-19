import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/player/data/api_lyric_repository.dart';
import 'package:hmusic/features/player/data/lyric_repository.dart';
import 'package:hmusic/features/player/models/hmusic_lyric.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';
import 'package:hmusic/features/player/views/player_page.dart';
import 'package:hmusic/features/player/widgets/lyric_strip.dart';
import 'package:hmusic/features/settings/data/api_devices_repository.dart';
import 'package:hmusic/features/settings/data/devices_repository.dart';
import 'package:hmusic/features/settings/models/hmusic_device.dart';

// 染色歌词条会触发 ensureLyric → lyricRepository，测试里换成无歌词的假实现，
// 避免走 apiClient → SharedPreferences 平台通道（测试环境未初始化）。
class _FakeLyricRepository implements LyricRepository {
  const _FakeLyricRepository();

  @override
  Future<HMusicLyric> fetchLyric(HMusicTrack track) async {
    return const HMusicLyric();
  }
}

HMusicPlaybackState _state({
  HMusicTrack? track,
  String deviceId = 'local-browser',
  String? deviceName,
}) => HMusicPlaybackState(
  sessionId: 'default',
  state: PlaybackStatus.playing,
  positionMs: 42000,
  durationMs: 231000,
  volume: 60,
  playMode: PlayMode.listLoop,
  queueIndex: 0,
  queueLength: 1,
  seekEnabled: true,
  updatedAt: 0,
  deviceId: deviceId,
  deviceName: deviceName,
  track: track,
);

// 设备 sheet 的假仓库：只服务列表展示，select 不在 widget 测试覆盖范围
//（完整切换语义见 device_picker_test）。
class _FakeDevicesRepository implements DevicesRepository {
  const _FakeDevicesRepository();

  @override
  Future<List<HMusicDevice>> getDevices() async => const <HMusicDevice>[
    HMusicDevice(
      id: 'local-browser',
      name: '本机播放',
      type: 'browser',
      isOnline: true,
    ),
    HMusicDevice(
      id: 'speaker-1',
      name: '客厅音箱',
      type: 'L06A',
      isDefault: true,
      isOnline: true,
    ),
  ];

  @override
  Future<int> refresh() => throw UnimplementedError();

  @override
  Future<HMusicPlaybackState> select(String deviceId) =>
      throw UnimplementedError();

  @override
  Future<void> probe(String deviceId) => throw UnimplementedError();
}

const HMusicTrack _track = HMusicTrack(
  id: 'tx:1',
  source: 'tx',
  sourceTrackId: '1',
  title: '晴天',
  artist: '周杰伦',
);

Future<void> _pump(WidgetTester tester, HMusicPlaybackState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serverPlaybackStateProvider.overrideWith((ref) => Stream.value(state)),
        livePositionProvider.overrideWith(
          (ref) => Stream.value(const Duration(seconds: 42)),
        ),
        // 挂起的 handler：控制区渲染占位，页面其余部分不依赖平台通道。
        hmusicAudioHandlerProvider.overrideWith(
          (ref) => Completer<HMusicAudioHandler>().future,
        ),
        // 无歌词假仓库：避开 apiClient → SharedPreferences 平台通道。
        lyricRepositoryProvider.overrideWithValue(const _FakeLyricRepository()),
        devicesRepositoryProvider.overrideWithValue(
          const _FakeDevicesRepository(),
        ),
      ],
      child: const MaterialApp(home: PlayerPage()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('renders track title, artist and progress labels', (
    tester,
  ) async {
    await _pump(tester, _state(track: _track));

    expect(find.text('晴天'), findsOneWidget);
    expect(find.text('周杰伦'), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget);
    expect(find.text('3:51'), findsOneWidget);
  });

  testWidgets('shows empty hint when nothing is playing', (tester) async {
    await _pump(tester, _state());

    expect(find.text('还没有在播放的歌曲'), findsOneWidget);
  });

  testWidgets('wide layout renders two-pane player with lyrics pane', (
    tester,
  ) async {
    // ≥1024 走桌面双栏：左封面舞台（状态点行）+ 右歌词栏（假仓库无歌词 → 占位）。
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, _state(track: _track));

    expect(find.text('晴天'), findsOneWidget);
    // 状态行：playing + deviceId 无名 → 「正在播放」。
    expect(find.textContaining('正在播放'), findsWidgets);
    // 右栏歌词占位（假仓库返回空歌词）。
    expect(find.text('暂无歌词'), findsOneWidget);
    // 窄屏专属的染色歌词条不出现在桌面双栏。
    expect(find.byType(LyricStrip), findsNothing);
  });

  testWidgets('遥控模式：歌手名下显示设备状态行，可与输出钮共存', (tester) async {
    await _pump(
      tester,
      _state(track: _track, deviceId: 'speaker-1', deviceName: '客厅音箱'),
    );

    expect(find.text('正在播放 · 客厅音箱'), findsOneWidget);
    expect(find.byIcon(Icons.speaker_group_rounded), findsOneWidget);
  });

  testWidgets('本机播放：不占设备状态行，输出钮仍在（本机切音箱的入口）', (tester) async {
    await _pump(tester, _state(track: _track));

    expect(find.textContaining('正在播放 ·'), findsNothing);
    expect(find.byIcon(Icons.speaker_group_rounded), findsOneWidget);
  });

  testWidgets('点输出钮弹设备 sheet：标题 + 设备列表 + 当前设备勾选', (tester) async {
    await _pump(
      tester,
      _state(track: _track, deviceId: 'speaker-1', deviceName: '客厅音箱'),
    );

    await tester.tap(find.byIcon(Icons.speaker_group_rounded));
    // LyricStrip 的 Ticker 永不静止,不能 pumpAndSettle,定长推帧过 sheet 动画。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('播放设备'), findsOneWidget);
    expect(find.text('本机播放'), findsOneWidget);
    expect(find.text('客厅音箱'), findsOneWidget);
    // isDefault 勾选标记。
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
