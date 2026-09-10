import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/platform/client_playback_capabilities.dart';
import 'package:hmusic/features/player/view_models/device_picker_view_model.dart';
import 'package:hmusic/features/player/widgets/device_picker_sheet.dart';
import 'package:hmusic/features/player/widgets/mini_player.dart';
import 'package:hmusic/features/settings/data/api_devices_repository.dart';
import 'package:hmusic/features/settings/models/hmusic_device.dart';
import 'package:hmusic/features/settings/view_models/devices_view_model.dart';
import 'package:hmusic/features/settings/widgets/sections/devices_section.dart';

import 'support/playback_ui_fixture.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    test('$platform：设备选择 VM 与设置 VM 都在请求前拒绝本机', () async {
      final repository = UiDevicesRepository();
      var handlerRequested = false;
      final container = ProviderContainer(
        overrides: [
          clientPlaybackCapabilitiesProvider.overrideWithValue(
            ClientPlaybackCapabilities.forPlatform(platform),
          ),
          devicesRepositoryProvider.overrideWithValue(repository),
          hmusicAudioHandlerProvider.overrideWith((ref) {
            handlerRequested = true;
            return Completer<HMusicAudioHandler>().future;
          }),
        ],
      );
      addTearDown(container.dispose);
      const local = HMusicDevice(
        id: 'local-browser',
        name: '本机播放',
        type: 'browser',
      );
      expect(
        await container
            .read(devicePickerViewModelProvider.notifier)
            .select(local),
        isFalse,
      );
      await container.read(devicesViewModelProvider.notifier).select(local);
      expect(repository.selections, isEmpty);
      expect(handlerRequested, isFalse);
      expect(
        container.read(devicePickerViewModelProvider).error,
        ClientPlaybackCapabilities.localPlaybackUnavailableReason,
      );
      expect(
        container.read(devicesViewModelProvider).notice?.message,
        ClientPlaybackCapabilities.localPlaybackUnavailableReason,
      );
    });
  }

  testWidgets('不支持本机时 sheet 与设置显示原因，仍保留音箱入口', (tester) async {
    final fixture = PlaybackUiFixture(localSupported: false);
    addTearDown(fixture.handler.disposeHandler);
    await fixture.pump(
      tester,
      const DevicePickerSheet(),
      size: const Size(360, 640),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
    final local = find.widgetWithText(ListTile, '本机播放').first;
    expect(tester.widget<ListTile>(local).onTap, isNull);
    expect(
      find.text(ClientPlaybackCapabilities.localPlaybackUnavailableReason),
      findsOneWidget,
    );
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, '客厅音箱')).onTap,
      isNotNull,
    );
    await fixture.pump(
      tester,
      const SingleChildScrollView(child: DevicesSectionView()),
      size: const Size(360, 640),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(
      find.text(ClientPlaybackCapabilities.localPlaybackUnavailableReason),
      findsOneWidget,
    );
    expect(find.text('客厅音箱'), findsOneWidget);
  });

  testWidgets('共享 Server 已选本机：mini 禁用播放，曲目信息仍可见', (tester) async {
    final fixture = PlaybackUiFixture(
      state: uiPlayback(deviceId: 'local-browser'),
      localSupported: false,
    );
    addTearDown(fixture.handler.disposeHandler);
    await fixture.pump(
      tester,
      const MiniPlayer(capsule: true),
      size: const Size(360, 640),
    );
    final play = find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          widget.tooltip ==
              ClientPlaybackCapabilities.localPlaybackUnavailableReason,
    );
    expect(tester.widget<IconButton>(play).onPressed, isNull);
    expect(find.text(uiTrack.title).hitTestable(), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(fixture.controller.calls, isEmpty);
  });
}
