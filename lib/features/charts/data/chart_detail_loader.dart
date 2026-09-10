import 'dart:async';
import 'dart:collection';

import '../models/chart.dart';
import 'charts_repository.dart';

// 预览和详情共用完整页面；刷新后旧请求仍可结束，但不再写入新一代缓存。
class ChartDetailLoader {
  ChartDetailLoader(this.repository);

  final ChartsRepository repository;
  final _cache = <String, ChartDetail>{};
  final _pending = <String, Future<ChartDetail>>{};
  final _queue = Queue<_ChartRequest>();
  int _active = 0;
  int _generation = 0;

  Future<ChartDetail> read(String id) {
    final cached = _cache[id];
    if (cached != null) return Future.value(cached);
    final pending = _pending[id];
    if (pending != null) return pending;
    final generation = _generation;
    final job = _ChartRequest(id);
    late final Future<ChartDetail> request;
    request = job.completer.future
        .then((detail) {
          if (generation == _generation) _cache[id] = detail;
          return detail;
        })
        .whenComplete(() {
          _pending.removeWhere(
            (key, value) => key == id && identical(value, request),
          );
        });
    _pending[id] = request;
    _queue.add(job);
    _drain();
    return request;
  }

  // 所有入口共用限额，连续切平台、重试和打开详情也不会叠加预取并发。
  void _drain() {
    while (_active < 2 && _queue.isNotEmpty) {
      _active++;
      unawaited(_fetch(_queue.removeFirst()));
    }
  }

  Future<void> _fetch(_ChartRequest job) async {
    try {
      job.completer.complete(await repository.getChart(job.id));
    } catch (error, stack) {
      job.completer.completeError(error, stack);
    } finally {
      _active--;
      _drain();
    }
  }

  void invalidate(String id) => _cache.remove(id);

  void clear() {
    _generation++;
    _cache.clear();
    _pending.clear();
    while (_queue.isNotEmpty) {
      _queue.removeFirst().completer.completeError(StateError('榜单已刷新'));
    }
  }
}

class _ChartRequest {
  _ChartRequest(this.id);

  final String id;
  final completer = Completer<ChartDetail>();
}
