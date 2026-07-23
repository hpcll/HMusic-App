import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/platform_shell/method_channel_platform_shell_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventChannel = EventChannel('test/platform_shell/events');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
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
}
