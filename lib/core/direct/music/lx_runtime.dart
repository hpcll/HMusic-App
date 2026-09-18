import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';

import '../../network/api_failure.dart';
import 'direct_music_http.dart';
import 'lx_crypto_bridge.dart';
import 'lx_http_bridge.dart';
import 'lx_javascript_engine.dart';
import 'platform_track_mapper.dart';

abstract interface class LxRuntime {
  Future<Map<String, List<String>>> start(String code, {required String name});
  Future<Object?> request(
    String source,
    String action,
    Map<String, Object?> info,
  );
  void close();
}

class FlutterLxRuntime implements LxRuntime {
  FlutterLxRuntime(DirectMusicHttp http, {Future<String> Function()? bootstrap})
    : _http = LxHttpBridge(http),
      _bootstrap =
          bootstrap ?? (() => rootBundle.loadString('assets/lx/runtime.js'));
  final LxHttpBridge _http;
  final Future<String> Function() _bootstrap;
  final LxCryptoBridge _crypto = LxCryptoBridge();
  final Map<String, Completer<Object?>> _requests = {};
  final Map<String, Timer> _timers = {};
  final Completer<Map<String, List<String>>> _ready = Completer();
  JavascriptRuntime? _engine;
  int _sequence = 0;
  bool _closed = false;
  bool _started = false;

  @override
  Future<Map<String, List<String>>> start(
    String code, {
    required String name,
  }) async {
    if (_started || _closed) throw _failure;
    _started = true;
    final ready = _ready.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw _failure,
    );
    unawaited(ready.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    try {
      final bootstrap = await _bootstrap();
      if (_closed) throw _failure;
      _engine = createLxJavascriptEngine();
      _engine!.onMessage('ConsoleLog', (_) {});
      _engine!.onMessage(
        'HMusicLx',
        (Object? data) => _message(musicMap(data)),
      );
      _evaluate(bootstrap);
      _evaluate(
        '__hmusicStart(${jsonEncode({'name': name, 'version': '1.0.0', 'rawScript': code})});',
      );
      _evaluate(code);
    } catch (_) {
      if (!_ready.isCompleted) _ready.completeError(_failure);
    }
    return ready;
  }

  Object? _message(Map<String, Object?> data) {
    if (_closed) return null;
    final id = '${data['id']}';
    switch (data['type']) {
      case 'crypto':
        return _crypto.call(
          '${data['operation']}',
          (data['args'] as List<Object?>),
        );
      case 'init':
        if (_ready.isCompleted) return null;
        final declaration = musicMap(data['data']);
        final sources = musicMap(declaration['sources']);
        final result = <String, List<String>>{};
        for (final entry in sources.entries) {
          final source = musicMap(entry.value);
          final actions = source['actions'];
          if (actions is List<Object?> && actions.contains('musicUrl')) {
            result[entry.key] =
                (source['qualitys'] as List<Object?>? ?? ['128k'])
                    .whereType<String>()
                    .toList();
          }
        }
        if (declaration['status'] == false || result.isEmpty) {
          _ready.completeError(_failure);
        } else {
          _ready.complete(result);
        }
      case 'http':
        unawaited(
          _requestHttp(id, '${data['url']}', musicMap(data['options'])),
        );
      case 'cancelHttp':
        _http.cancel(id);
      case 'timer':
        _timers[id] = Timer(
          Duration(milliseconds: musicInt(data['delay']) ?? 0),
          () {
            _timers.remove(id);
            if (!_closed) {
              try {
                _evaluate('__hmusicTimer(${jsonEncode(id)});');
              } catch (_) {
                /* 脚本失败由请求超时归并。 */
              }
            }
          },
        );
      case 'cancelTimer':
        _timers.remove(id)?.cancel();
      case 'result':
        final pending = _requests.remove(id);
        if (data['error'] == null) {
          pending?.complete(data['value']);
        } else {
          pending?.completeError(_failure);
        }
    }
    return null;
  }

  Future<void> _requestHttp(
    String id,
    String url,
    Map<String, Object?> options,
  ) async {
    Object? response;
    String? error;
    try {
      response = await _http.request(id, url, options);
    } catch (_) {
      error = '音源网络请求失败';
    }
    if (_closed) return;
    try {
      _evaluate(
        '__hmusicHttp(${jsonEncode(id)}, ${jsonEncode(error)}, ${jsonEncode(response)});',
      );
    } catch (_) {
      /* 由对应解析请求返回失败或超时。 */
    }
  }

  @override
  Future<Object?> request(
    String source,
    String action,
    Map<String, Object?> info,
  ) async {
    if (_closed || _engine == null) throw _failure;
    final id = '${++_sequence}';
    final pending = Completer<Object?>();
    _requests[id] = pending;
    final result = pending.future.timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw _failure,
    );
    try {
      try {
        _evaluate(
          '__hmusicRequest(${jsonEncode(id)}, ${jsonEncode(source)}, ${jsonEncode(action)}, ${jsonEncode(info)});',
        );
      } catch (_) {
        if (!pending.isCompleted) pending.completeError(_failure);
      }
      return await result;
    } finally {
      _requests.remove(id);
    }
  }

  void _evaluate(String code) {
    if (_closed || _engine!.evaluate(code).isError) throw _failure;
    _engine!.executePendingJob();
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (_started && !_ready.isCompleted) _ready.completeError(_failure);
    _http.close();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    for (final request in _requests.values) {
      request.completeError(_failure);
    }
    _requests.clear();
    final engine = _engine;
    if (engine != null) {
      JavascriptRuntime.channelFunctionsRegistered.remove(
        engine.getEngineInstanceId(),
      );
      engine.dispose();
    }
  }

  static const _failure = ApiFailure(
    kind: ApiFailureKind.server,
    code: 'DIRECT_LX_FAILED',
    message: '音源加载或解析失败，请检查插件配置后重试',
  );
}
