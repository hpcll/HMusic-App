import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/settings/data/direct_settings_repository.dart';
import 'package:hmusic/features/settings/models/direct_options.dart';
import 'package:hmusic/features/settings/models/server_config.dart';

import '../../core/playback/support/direct_fixture.dart';

void main() {
  late DirectFixture f;
  late DirectSettingsRepository repository;
  setUp(() async {
    f = DirectFixture();
    await f.init();
    repository = DirectSettingsRepository(f.store, account: f.account);
  });
  tearDown(() => f.dispose());

  test(
    'settings summaries reflect the direct account, selected device and enabled sources',
    () async {
      await f.devices.select('speaker');
      await f.store.update(
        'sources',
        (data) => data['plugins'] = [
          {'id': 'a', 'enabled': true},
          {'id': 'b', 'enabled': false},
        ],
      );
      final summary = await repository.loadSummary();
      expect(summary.mi, '已登录');
      expect(summary.devices, '测试音箱');
      expect(summary.sources, '2 个音源 · 1 个启用');
    },
  );

  test(
    'saving speaker options normalizes models while preserving manual tracks',
    () async {
      await repository.patchConfig(
        manualTracks: [
          const ManualTrack(title: '保留曲目', url: 'https://audio.example/a.mp3'),
        ],
      );
      await repository.saveOptions(
        const DirectOptions(
          config: ServerConfig(
            serverName: '本机直连',
            defaultQuality: '320k',
            searchStrategy: 'qqFirst',
            resolveStrategy: 'originalFirst',
            extraPlayMusicModels: [' l20a ', 'L20A', 'X20C'],
          ),
          qqDirect: true,
          proxyHost: '192.168.1.9',
        ),
      );
      final options = await repository.getOptions();
      expect(options.config.extraPlayMusicModels, ['L20A', 'X20C']);
      expect(options.config.manualTracks.single.title, '保留曲目');
      expect(options.qqDirect, isTrue);
      expect(options.proxyHost, '192.168.1.9');
    },
  );

  test(
    'invalid model entries fail without replacing a previously saved configuration',
    () async {
      await repository.patchConfig(extraPlayMusicModels: ['L20A']);
      await expectLater(
        repository.patchConfig(extraPlayMusicModels: ['bad model']),
        throwsA(isA<ApiFailure>()),
      );
      expect((await repository.getConfig()).extraPlayMusicModels, ['L20A']);
    },
  );
}
