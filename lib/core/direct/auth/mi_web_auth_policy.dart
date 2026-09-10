import 'mi_passport_http.dart';

abstract final class MiWebAuthPolicy {
  // 沿用旧 HMusic 的移动网页登录标识，避免桌面版页面或 SDK 专属跳转。
  static const userAgent =
      'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36';

  static bool isAuthEnd(Uri? uri) =>
      isAccount(uri) && uri!.path == '/pass/serviceLoginAuth2/end';
  static bool isAccount(Uri? uri) {
    if (uri == null) return false;
    try {
      MiPassportHttp.accountUri(uri.toString().split('#').first);
      return uri.hasAuthority && uri.host == 'account.xiaomi.com';
    } catch (_) {
      return false;
    }
  }

  static bool isCallback(Uri? uri) {
    if (uri == null) return false;
    try {
      MiPassportHttp.stsUri(uri.toString());
      return true;
    } catch (_) {
      return false;
    }
  }
}
