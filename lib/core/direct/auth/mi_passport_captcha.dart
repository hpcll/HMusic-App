import 'dart:typed_data';

import '../../network/api_failure.dart';
import 'mi_passport_http.dart';

/// 图片验证码单独处理跳转与内容校验，不能把登录 HTML 交给图片解码器。
class MiPassportCaptcha {
  const MiPassportCaptcha(this._http);
  final MiPassportHttp _http;

  Future<Uint8List> load(Uri uri) async {
    uri = MiPassportHttp.accountUri(uri.toString());
    for (var redirects = 0; redirects <= 3; redirects++) {
      final response = await _http.request(uri, bytes: true);
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value('location');
        if (location == null || redirects == 3) throw invalidImage;
        // 每次跳转都重新检查 Passport 域名，Cookie 仍由同一个登录会话管理。
        uri = MiPassportHttp.accountUri(uri.resolve(location).toString());
        continue;
      }
      final bytes = response.data;
      if (response.statusCode != 200 ||
          bytes is! List<int> ||
          bytes.length > 2 * 1024 * 1024 ||
          !_isImage(bytes)) {
        throw invalidImage;
      }
      return Uint8List.fromList(bytes);
    }
    throw invalidImage;
  }

  // 小米实际返回 application/octet-stream 的 JPEG，不能仅按 Content-Type 拒绝。
  bool _isImage(List<int> bytes) {
    bool starts(List<int> signature, [int offset = 0]) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    return starts([0xff, 0xd8, 0xff]) ||
        starts([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) ||
        starts('GIF87a'.codeUnits) ||
        starts('GIF89a'.codeUnits) ||
        starts('BM'.codeUnits) ||
        (starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8));
  }

  static const invalidImage = ApiFailure(
    kind: ApiFailureKind.invalidResponse,
    code: 'MI_DIRECT_CAPTCHA_INVALID_IMAGE',
    message: '验证码图片加载失败，请换一张重试',
  );
}
