import '../../network/api_failure.dart';
import '../mi_direct_session.dart';
import 'mi_passport_http.dart';
import 'mi_passport_result.dart';
import 'mi_web_auth_policy.dart';
import 'mi_web_verifier.dart';

/// 网页的 STS 回调由专属传输消费一次，不让 WebView 先访问后再重放。
class MiPassportWebExchange {
  const MiPassportWebExchange(this.http);
  final MiPassportHttp http;

  Future<MiPassportResult?> finish(
    MiWebAuthResult result, {
    required Future<MiPassportResult> Function(String, String)
    exchangePassToken,
    required bool Function() isCurrent,
  }) async {
    final callback = result.callbackUri;
    if (callback != null) MiPassportHttp.stsUri(callback.toString());
    if (!isCurrent()) return null;
    final existing = _session(result.serviceCookies, result.accountCookies);
    if (existing != null) return MiPassportAuthenticated(existing);
    final userId = result.accountCookies['userId'];
    final passToken = result.accountCookies['passToken'];
    if (userId != null && passToken != null) {
      try {
        // 沿用旧 HMusic：优先使用网页已取得的凭据，避免重放一次性回调。
        return await exchangePassToken(userId, passToken);
      } on ApiFailure {
        if (callback == null) rethrow;
      }
    }
    if (!isCurrent()) return null;
    return MiPassportAuthenticated(await exchange(result));
  }

  Future<MiDirectSession> exchange(MiWebAuthResult result) async {
    final callback = result.callbackUri;
    final uri = callback == null
        ? null
        : MiPassportHttp.stsUri(callback.toString());
    final existing = _session(result.serviceCookies, result.accountCookies);
    if (existing != null) return existing;
    if (uri == null) throw missingCredentials;
    final response = await http.request(
      uri,
      userAgent: MiWebAuthPolicy.userAgent,
    );
    var credentials = {
      for (final cookie in MiPassportHttp.responseCookies(response.headers))
        if (cookie.value.isNotEmpty && cookie.maxAge != 0)
          cookie.name: cookie.value,
    };
    if (_session(credentials, result.accountCookies) == null) {
      try {
        final body = MiPassportHttp.decode(response.data);
        if (body['code'] == null || body['code'] == 0) {
          credentials = {
            ...credentials,
            for (final key in ['userId', 'serviceToken', 'ssecurity'])
              if (body[key] is String) key: body[key] as String,
          };
        }
      } on ApiFailure {
        // STS 也可能只有 Set-Cookie，不能把其 HTML 响应当作登录数据。
      }
    }
    return _session(credentials, result.accountCookies) ??
        (throw missingCredentials);
  }

  MiDirectSession? _session(
    Map<String, String> credentials,
    Map<String, String> account,
  ) {
    final userId = credentials['userId'] ?? account['userId'];
    final token = credentials['serviceToken'];
    if (userId == null || userId.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return MiDirectSession(
      userId: userId,
      serviceToken: token,
      ssecurity: credentials['ssecurity'],
      passToken: account['userId'] == userId ? account['passToken'] : null,
    );
  }

  static const missingCredentials = ApiFailure(
    kind: ApiFailureKind.invalidResponse,
    code: 'MI_DIRECT_WEB_CREDENTIALS_MISSING',
    message: '小米尚未返回有效登录结果，请重新完成验证',
  );
}
