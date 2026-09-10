import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/player/widgets/player_target_volume.dart';

import 'support/playback_ui_fixture.dart';

void main() {
  testWidgets('音箱拖动只预览，松手只提交最后值', (tester) async {
    final fixture = PlaybackUiFixture();
    addTearDown(fixture.handler.disposeHandler);
    await fixture.pump(tester, PlayerTargetVolume(state: uiPlayback()));
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeStart!(.6);
    slider.onChanged!(.7);
    slider.onChanged!(.85);
    await tester.pump();
    expect(fixture.controller.deviceVolumes, isEmpty);
    expect(fixture.controller.localVolumes, isEmpty);
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(.85);
    await tester.pump();
    expect(fixture.controller.deviceVolumes, [85]);
  });

  testWidgets('本机拖动连续提交，不调用远端音量', (tester) async {
    final fixture = PlaybackUiFixture(
      state: uiPlayback(deviceId: 'local-browser'),
    );
    addTearDown(fixture.handler.disposeHandler);
    await fixture.pump(
      tester,
      PlayerTargetVolume(state: fixture.handler.serverState),
    );
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeStart!(.75);
    slider.onChanged!(.4);
    slider.onChanged!(.3);
    slider.onChangeEnd!(.3);
    await tester.pump();
    expect(fixture.controller.localVolumes, [.4, .3]);
    expect(fixture.controller.deviceVolumes, isEmpty);
  });

  testWidgets('切设备清掉旧拖动态，禁用本机不发送音量', (tester) async {
    final fixture = PlaybackUiFixture(localSupported: false);
    addTearDown(fixture.handler.disposeHandler);
    final state = ValueNotifier(uiPlayback());
    addTearDown(state.dispose);
    await fixture.pump(
      tester,
      ValueListenableBuilder(
        valueListenable: state,
        builder: (context, value, _) => PlayerTargetVolume(state: value),
      ),
    );
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeStart!(.6);
    slider.onChanged!(.95);
    state.value = uiPlayback(deviceId: 'speaker-2', volume: 20);
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, .2);
    state.value = uiPlayback(deviceId: 'local-browser');
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(fixture.controller.deviceVolumes, isEmpty);
    expect(fixture.controller.localVolumes, isEmpty);
  });
}
