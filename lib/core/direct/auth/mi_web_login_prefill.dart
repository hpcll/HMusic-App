/// 仅在一次验证过程中转交表单输入；不参与状态持久化或日志输出。
class MiWebLoginPrefill {
  MiWebLoginPrefill({required String account, required String password})
    : _account = account.trim(),
      _password = password;

  String _account;
  String _password;
  String get account => _account;
  String get password => _password;
  bool get isEmpty => _account.isEmpty || _password.isEmpty;

  void clear() {
    _account = '';
    _password = '';
  }

  @override
  String toString() => 'MiWebLoginPrefill(redacted)';
}
