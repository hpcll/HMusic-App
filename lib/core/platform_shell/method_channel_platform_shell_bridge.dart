import 'dart:async';

import 'package:flutter/services.dart';

import 'platform_shell_bridge.dart';

class MethodChannelPlatformShellBridge implements PlatformShellBridge {
  MethodChannelPlatformShellBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel(_methodName),
       _eventChannel = eventChannel ?? const EventChannel(_eventName);

  static const String _methodName = 'com.hupc.hmusic/platform_shell';
  static const String _eventName = 'com.hupc.hmusic/platform_shell/events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Stream<ShellReady> get readyEvents => _events
      .where((event) => event['type'] == 'ready')
      .map(
        (event) => ShellReady(
          capabilities:
              (event['capabilities'] as List<Object?>?)
                  ?.whereType<String>()
                  .toList() ??
              const <String>[],
        ),
      );

  @override
  Stream<ShellIntent> get intents => _events
      .where((event) => event['type'] == 'intent')
      .map(
        (event) => (_parseIntent(event['intent'] as String?), event['value']),
      )
      .where((pair) => pair.$1 != null)
      .map((pair) => ShellIntent(pair.$1!, pair.$2 as String?));

  @override
  Stream<ShellLayout> get layoutChanges => _events
      .where((event) => event['type'] == 'layoutChanged')
      .map(
        (event) => ShellLayout(
          topInset: (event['topInset'] as num?)?.toDouble() ?? 0,
          bottomInset: (event['bottomInset'] as num?)?.toDouble() ?? 0,
        ),
      );

  // 单例广播流：ready/layout/intent 三路订阅共享一条原生 EventChannel 订阅。
  // 若做成 getter 每次新建流，多个 listener 会在原生侧反复 onListen 互相顶掉 sink。
  late final Stream<Map<String, Object?>> _events = _eventChannel
      .receiveBroadcastStream()
      .where((Object? event) => event is Map<Object?, Object?>)
      .cast<Map<Object?, Object?>>()
      .map((event) => Map<String, Object?>.from(event));

  @override
  Future<void> configure({
    required bool darkMode,
    required bool reduceMotion,
    required bool reduceTransparency,
  }) {
    return _methodChannel
        .invokeMethod<void>('shell.configure', <String, Object?>{
          'version': 1,
          'darkMode': darkMode,
          'reduceMotion': reduceMotion,
          'reduceTransparency': reduceTransparency,
        });
  }

  @override
  Future<void> updateNavigation({
    required String selectedTab,
    required String title,
    required bool canGoBack,
  }) {
    return _methodChannel.invokeMethod<void>(
      'shell.updateNavigation',
      <String, Object?>{
        'selectedTab': selectedTab,
        'title': title,
        'canGoBack': canGoBack,
      },
    );
  }

  @override
  Future<void> updateNowPlaying({
    required String? trackId,
    required String? title,
    required String? artist,
    required String? artworkUrl,
    required bool playing,
  }) {
    return _methodChannel
        .invokeMethod<void>('shell.updateNowPlaying', <String, Object?>{
          'trackId': trackId,
          'title': title,
          'artist': artist,
          'artworkUrl': artworkUrl,
          'playing': playing,
        });
  }

  @override
  Future<void> updateLayout({
    required bool showTabBar,
    required bool showMiniPlayer,
  }) {
    return _methodChannel.invokeMethod<void>(
      'shell.updateLayout',
      <String, Object?>{
        'showTabBar': showTabBar,
        'showMiniPlayer': showMiniPlayer,
      },
    );
  }

  @override
  Future<void> updateScroll({required bool minimized}) {
    return _methodChannel.invokeMethod<void>(
      'shell.updateScroll',
      <String, Object?>{'minimized': minimized},
    );
  }

  ShellIntentType? _parseIntent(String? value) {
    for (final type in ShellIntentType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
