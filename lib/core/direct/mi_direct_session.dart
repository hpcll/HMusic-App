/// 仅用于 micoapi 的会话，不含密码，不与 Server token 共用存储键。
class MiDirectSession {
  MiDirectSession({
    required this.userId,
    required this.serviceToken,
    this.ssecurity,
    this.passToken,
  }) {
    if (!_cookieValue(userId) || !_cookieValue(serviceToken)) {
      throw const FormatException('小米会话字段无效');
    }
  }

  factory MiDirectSession.fromJson(Map<String, dynamic> json) {
    if (json['userId'] is! String || json['serviceToken'] is! String) {
      throw const FormatException('小米会话缺少必要字段');
    }
    return MiDirectSession(
      userId: json['userId'] as String,
      serviceToken: json['serviceToken'] as String,
      ssecurity: json['ssecurity'] as String?,
      passToken: json['passToken'] as String?,
    );
  }

  final String userId;
  final String serviceToken;
  final String? ssecurity;
  final String? passToken;

  String get cookie => 'serviceToken=$serviceToken; userId=$userId';

  Map<String, Object?> toJson() => {
    'userId': userId,
    'serviceToken': serviceToken,
    if (ssecurity != null) 'ssecurity': ssecurity,
    if (passToken != null) 'passToken': passToken,
  };

  static bool _cookieValue(String value) =>
      value.isNotEmpty && !RegExp(r'[\x00-\x20\x7f;,]').hasMatch(value);

  @override
  String toString() => 'MiDirectSession(redacted)';
}
