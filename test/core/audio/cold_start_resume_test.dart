import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

import '../playback/support/direct_fixture.dart';
import 'support/audio_fixture.dart';

void main() {
  test('重建仓库和播放器后保留暂停位置，显式播放重新装载音源', () async {
    final preferences = MemoryKeyValueStore();
    final before = DirectFixture(preferences: preferences);
    final first = AudioFixture(before.playback);
    await before.init();
    await first.handler.playTrack(directTrack('saved', duration: 225000));
    await first.handler.seek(const Duration(milliseconds: 97350));
    await first.handler.pause();
    await first.handler.disposeHandler();
    await before.dispose();

    final after = DirectFixture(preferences: preferences);
    final restored = AudioFixture(after.playback);
    addTearDown(restored.handler.disposeHandler);
    addTearDown(after.dispose);
    await restored.handler.ensureServerState();

    expect(restored.player.loads, isEmpty);
    expect(restored.player.playing, isFalse);
    expect(restored.handler.effectivePosition.inMilliseconds, 97350);
    expect(
      restored.handler.playbackState.value.updatePosition.inMilliseconds,
      97350,
    );
    expect(restored.handler.mediaItem.valueOrNull?.id, 'wy:saved');

    await restored.handler.play();
    expect(restored.player.loads, hasLength(1));
    expect(restored.player.position.inMilliseconds, 97350);
    expect(restored.player.playing, isTrue);
    expect(after.resolver.requests, ['wy:saved']);
  });

  test('恢复曲目的解析请求未完成时立即发布加载状态', () async {
    final direct = DirectFixture();
    final audio = AudioFixture(direct.playback);
    addTearDown(audio.handler.disposeHandler);
    addTearDown(direct.dispose);
    await direct.init();
    await audio.handler.playTrack(directTrack('saved'));
    await audio.handler.pause();
    final gate = direct.resolver.gate = Completer<void>();
    final resuming = audio.handler.play();
    await pumpEventQueue();
    try {
      expect(
        audio.handler.playbackState.value.processingState,
        AudioProcessingState.loading,
      );
    } finally {
      gate.complete();
      await resuming;
    }
    expect(audio.player.playing, isTrue);
    expect(
      audio.handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
  });
}
