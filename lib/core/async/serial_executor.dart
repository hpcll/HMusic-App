/// 同一状态所有者的写操作排队；失败只结束本次操作，不阻塞后续命令。
class SerialExecutor {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
