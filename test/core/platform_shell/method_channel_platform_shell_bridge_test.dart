import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/platform_shell/method_channel_platform_shell_bridge.dart';
import 'package:hmusic/core/platform_shell/platform_shell_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventChannel = EventChannel('test/platform_shell/events');
  const methodChannel = MethodChannel('test/platform_shell/methods');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('replays ready and layout sent before typed listeners attach', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          eventChannel,
          MockStreamHandler.inline(
            onListen: (_, events) {
              events.success(<String, Object?>{
                'type': 'ready',
                'capabilities': <String>['bottomBar', 'miniPlayer'],
              });
              events.success(<String, Object?>{
                'type': 'layoutChanged',
                'topInset': 0.0,
                'bottomInset': 132.0,
              });
            },
          ),
        );

    final bridge = MethodChannelPlatformShellBridge(eventChannel: eventChannel);
    addTearDown(bridge.dispose);
    bridge.intents.listen((_) {});
    await pumpEventQueue();

    final ready = await bridge.readyEvents.first;
    final layout = await bridge.layoutChanges.first;

    expect(ready.capabilities, <String>['bottomBar', 'miniPlayer']);
    expect(layout.bottomInset, 132);
  });

  test('输出名称和排版字段原样过桥，输出选择事件可解析', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          calls.add(call);
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          eventChannel,
          MockStreamHandler.inline(
            onListen: (_, events) {
              events.success(<String, Object?>{
                'type': 'intent',
                'intent': 'openOutputPicker',
              });
            },
          ),
        );
    final bridge = MethodChannelPlatformShellBridge(
      eventChannel: eventChannel,
      methodChannel: methodChannel,
    );
    addTearDown(bridge.dispose);
    final intent = bridge.intents.first;
    await bridge.updateNowPlaying(
      trackId: 'track-1',
      title: '测试曲目',
      artist: '测试歌手',
      artworkUrl: null,
      playing: false,
      outputLabel: '客厅音箱',
    );
    await bridge.updateLayout(
      showTabBar: true,
      showMiniPlayer: true,
      miniPlayerHeight: 79,
      miniTitleFontSize: 28,
      miniDetailFontSize: 24,
      allowMinimize: false,
    );
    expect((await intent).type, ShellIntentType.openOutputPicker);
    expect(calls.first.method, 'shell.updateNowPlaying');
    expect((calls.first.arguments as Map)['outputLabel'], '客厅音箱');
    expect(calls.last.method, 'shell.updateLayout');
    expect(calls.last.arguments, <String, Object?>{
      'showTabBar': true,
      'showMiniPlayer': true,
      'miniPlayerHeight': 79.0,
      'miniTitleFontSize': 28.0,
      'miniDetailFontSize': 24.0,
      'allowMinimize': false,
    });
  });
}
