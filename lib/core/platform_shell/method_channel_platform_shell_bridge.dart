import 'dart:async';

import 'package:flutter/services.dart';

import 'platform_shell_bridge.dart';

class MethodChannelPlatformShellBridge implements PlatformShellBridge {
  MethodChannelPlatformShellBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel(_methodName),
       _eventChannel = eventChannel ?? const EventChannel(_eventName) {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: _handleEventError,
      onDone: _closeEventStreams,
    );
  }

  static const String _methodName = 'com.hupc.hmusic/platform_shell';
  static const String _eventName = 'com.hupc.hmusic/platform_shell/events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final StreamController<ShellReady> _readyController =
      StreamController<ShellReady>.broadcast();
  final StreamController<ShellIntent> _intentController =
      StreamController<ShellIntent>.broadcast();
  final StreamController<ShellLayout> _layoutController =
      StreamController<ShellLayout>.broadcast();
  late final StreamSubscription<Object?> _eventSubscription;

  ShellReady? _latestReady;
  ShellLayout? _latestLayout;

  @override
  Stream<ShellReady> get readyEvents =>
      _replayLatest(_readyController.stream, () => _latestReady);

  @override
  Stream<ShellIntent> get intents => _intentController.stream;

  @override
  Stream<ShellLayout> get layoutChanges =>
      _replayLatest(_layoutController.stream, () => _latestLayout);

  Future<void> dispose() async {
    await _eventSubscription.cancel();
    await _closeEventStreams();
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

  void _handleEvent(Object? rawEvent) {
    if (rawEvent is! Map<Object?, Object?>) return;
    final event = Map<String, Object?>.from(rawEvent);
    switch (event['type']) {
      case 'ready':
        final ready = ShellReady(
          capabilities:
              (event['capabilities'] as List<Object?>?)
                  ?.whereType<String>()
                  .toList() ??
              const <String>[],
        );
        _latestReady = ready;
        _readyController.add(ready);
      case 'layoutChanged':
        final layout = ShellLayout(
          topInset: (event['topInset'] as num?)?.toDouble() ?? 0,
          bottomInset: (event['bottomInset'] as num?)?.toDouble() ?? 0,
        );
        _latestLayout = layout;
        _layoutController.add(layout);
      case 'intent':
        final type = _parseIntent(event['intent'] as String?);
        if (type != null) {
          _intentController.add(ShellIntent(type, event['value'] as String?));
        }
    }
  }

  void _handleEventError(Object error, StackTrace stackTrace) {
    _readyController.addError(error, stackTrace);
    _intentController.addError(error, stackTrace);
    _layoutController.addError(error, stackTrace);
  }

  Future<void> _closeEventStreams() async {
    await Future.wait(<Future<void>>[
      if (!_readyController.isClosed) _readyController.close(),
      if (!_intentController.isClosed) _intentController.close(),
      if (!_layoutController.isClosed) _layoutController.close(),
    ]);
  }

  Stream<T> _replayLatest<T>(Stream<T> updates, T? Function() latest) {
    return Stream<T>.multi((controller) {
      final subscription = updates.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
      final current = latest();
      if (current != null) controller.add(current);
    }, isBroadcast: true);
  }

  ShellIntentType? _parseIntent(String? value) {
    for (final type in ShellIntentType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
