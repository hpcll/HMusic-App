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
  Stream<ShellIntentType> get intents => _events
      .where((event) => event['type'] == 'intent')
      .map((event) => event['intent'] as String?)
      .map(_parseIntent)
      .where((intent) => intent != null)
      .cast<ShellIntentType>();

  @override
  Stream<ShellLayout> get layoutChanges => _events
      .where((event) => event['type'] == 'layoutChanged')
      .map(
        (event) => ShellLayout(
          topInset: (event['topInset'] as num?)?.toDouble() ?? 0,
          bottomInset: (event['bottomInset'] as num?)?.toDouble() ?? 0,
        ),
      );

  Stream<Map<String, Object?>> get _events {
    return _eventChannel
        .receiveBroadcastStream()
        .where((Object? event) => event is Map<Object?, Object?>)
        .cast<Map<Object?, Object?>>()
        .map((event) => Map<String, Object?>.from(event));
  }

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

  ShellIntentType? _parseIntent(String? value) {
    for (final type in ShellIntentType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
