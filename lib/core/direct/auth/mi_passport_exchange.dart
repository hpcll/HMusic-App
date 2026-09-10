import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../network/api_failure.dart';
import '../mi_direct_session.dart';
import 'mi_passport_http.dart';
import 'mi_passport_result.dart';

class MiPassportExchange {
  const MiPassportExchange(this.http);
  final MiPassportHttp http;

  Future<MiPassportResult> finish(Map<String, dynamic> data) async {
    final identity = data['notificationUrl'];
    final captcha = data['captchaUrl'];
    if (identity is String && identity.isNotEmpty) {
      return MiPassportChallenge(
        kind: MiChallengeKind.identity,
        url: MiPassportHttp.accountUri(identity),
      );
    }
    if (captcha is String && captcha.isNotEmpty) {
      final url = MiPassportHttp.accountUri(captcha);
      return MiPassportChallenge(
        // sign.location 通常是 /fe/service/login 网页，不是图片验证码地址。
        kind: url.path == '/pass/getCode'
            ? MiChallengeKind.captcha
            : MiChallengeKind.identity,
        url: url,
      );
    }
    if (data['code'] != 0) throw MiPassportHttp.invalidResponse;
    final userId = data['userId']?.toString();
    final security = data['ssecurity'];
    final nonce = data['nonce'];
    final location = data['location'];
    final passToken = data['passToken'];
    if (userId == null ||
        userId.isEmpty ||
        security is! String ||
        security.isEmpty ||
        location is! String ||
        (passToken != null && passToken is! String) ||
        (nonce is! int && nonce is! String)) {
      throw MiPassportHttp.invalidResponse;
    }

    final sign = base64Encode(
      sha1.convert(utf8.encode('nonce=$nonce&$security')).bytes,
    );
    final uri = MiPassportHttp.stsUri(location);
    final exchangeUri = uri.replace(
      queryParameters: {
        ...uri.queryParametersAll,
        'clientSign': [sign],
      },
    );
    final response = await http.request(exchangeUri);
    // STS 的 token 通常在 302 响应头；无需访问其外部跳转目标。
    String? token;
    for (final cookie in MiPassportHttp.responseCookies(response.headers)) {
      if (cookie.name == 'serviceToken' &&
          cookie.value.isNotEmpty &&
          cookie.maxAge != 0) {
        token = cookie.value;
      }
    }
    if (token == null) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        code: 'MI_DIRECT_STS_TOKEN_MISSING',
        message: '小米登录尚未返回有效会话，请重试',
      );
    }
    return MiPassportAuthenticated(
      MiDirectSession(
        userId: userId,
        serviceToken: token,
        ssecurity: security,
        passToken: passToken as String?,
      ),
    );
  }
}
