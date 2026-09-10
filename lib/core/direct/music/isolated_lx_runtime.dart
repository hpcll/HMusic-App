import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '../../network/api_failure.dart';
import 'direct_music_http.dart';
import 'lx_runtime.dart';
import 'platform_track_mapper.dart';

/// 每个插件使用独立 isolate，JS/网络不占 UI，主端超时后取消后续结果。
class IsolatedLxRuntime implements LxRuntime {
  IsolatedLxRuntime({this.timeout = const Duration(seconds: 25)});
  final Duration timeout;
  final _ready = Completer<Map<String, List<String>>>();
  final Map<String, Completer<Object?>> _pending = {};
  Isolate? _isolate;
  ReceivePort? _events;
  SendPort? _commands;
  Timer? _shutdownTimer;
  int _sequence = 0;
  bool _closed = false, _started = false;

  @override
  Future<Map<String, List<String>>> start(
    String code, {
    required String name,
  }) async {
    if (_closed || _started) throw _failure;
    _started = true;
    final ready = _ready.future.timeout(
      timeout,
      onTimeout: () {
        close();
        throw _failure;
      },
    );
    unawaited(ready.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    try {
      final bootstrap = await rootBundle.loadString('assets/lx/runtime.js');
      if (_closed) throw _failure;
      final events = _events = ReceivePort();
      events.listen(_receive);
      _isolate = await Isolate.spawn(
        _runWorker,
        (events.sendPort, bootstrap, code, name),
        onError: events.sendPort,
        onExit: events.sendPort,
        errorsAreFatal: true,
      );
      if (_closed) _isolate?.kill(priority: Isolate.immediate);
      return await ready;
    } catch (_) {
      close();
      throw _failure;
    }
  }

  void _receive(Object? event) {
    if (_closed) {
      if (event == null || (event is Map && event['closed'] == true)) {
        _finishClose();
      }
      return;
    }
    if (event is! Map) {
      close();
      return;
    }
    final message = musicMap(event);
    if (message['port'] case final SendPort port) _commands = port;
    if (message['sources'] case final Map<Object?, Object?> sources) {
      if (!_ready.isCompleted) {
        _ready.complete(
          sources.map(
            (key, value) => MapEntry('$key', (value as List).cast<String>()),
          ),
        );
      }
    }
    if (message['failed'] == true) {
      close();
      return;
    }
    final pending = _pending.remove('${message['id']}');
    if (pending == null) return;
    if (message['error'] == true) {
      pending.completeError(_failure);
    } else {
      pending.complete(message['value']);
    }
  }

  @override
  Future<Object?> request(
    String source,
    String action,
    Map<String, Object?> info,
  ) async {
    if (_closed || _commands == null || !_ready.isCompleted) throw _failure;
    final id = '${++_sequence}', pending = Completer<Object?>();
    _pending[id] = pending;
    final result = pending.future.timeout(
      timeout,
      onTimeout: () {
        close();
        throw _failure;
      },
    );
    _commands!.send({
      'id': id,
      'source': source,
      'action': action,
      'info': info,
    });
    try {
      return await result;
    } finally {
      _pending.remove(id);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    // 正常关闭先由 worker 释放 JSC/HTTP 原生资源；不响应时才终止 isolate。
    _commands?.send({'close': true});
    if (_events != null) {
      _shutdownTimer = Timer(const Duration(seconds: 1), () {
        _isolate?.kill(priority: Isolate.immediate);
        _finishClose();
      });
    }
    if (_started && !_ready.isCompleted) _ready.completeError(_failure);
    for (final pending in _pending.values) {
      pending.completeError(_failure);
    }
    _pending.clear();
  }

  void _finishClose() {
    _shutdownTimer?.cancel();
    _events?.close();
    _events = null;
    _commands = null;
    _isolate = null;
  }

  static const _failure = ApiFailure(
    kind: ApiFailureKind.server,
    code: 'DIRECT_LX_FAILED',
    message: '音源加载或解析失败，请检查插件或重试',
  );
}

Future<void> _runWorker((SendPort, String, String, String) start) async {
  final (events, bootstrap, code, name) = start;
  final commands = ReceivePort();
  final http = DirectMusicHttp();
  final runtime = FlutterLxRuntime(http, bootstrap: () async => bootstrap);
  final finished = Completer<void>();
  var closed = false;
  void close() {
    if (closed) return;
    closed = true;
    runtime.close();
    http.close();
    commands.close();
    events.send({'closed': true});
    finished.complete();
  }

  Future<void> request(Map<String, Object?> message) async {
    try {
      final value = await runtime.request(
        '${message['source']}',
        '${message['action']}',
        musicMap(message['info']),
      );
      if (!closed) events.send({'id': message['id'], 'value': value});
    } catch (_) {
      if (!closed) events.send({'id': message['id'], 'error': true});
    }
  }

  commands.listen((event) {
    final message = musicMap(event);
    if (message['close'] == true) {
      close();
    } else if (!closed) {
      unawaited(request(message));
    }
  });
  events.send({'port': commands.sendPort});
  try {
    final sources = await runtime.start(code, name: name);
    if (!closed) events.send({'sources': sources});
    await finished.future;
  } catch (_) {
    if (!closed) events.send({'failed': true});
  } finally {
    close();
  }
}
