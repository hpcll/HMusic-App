import 'package:json_annotation/json_annotation.dart';

import 'auth_user.dart';

part 'auth_session.g.dart';

@JsonSerializable(explicitToJson: true)
class AuthSession {
  const AuthSession({required this.user, required this.accessToken});

  factory AuthSession.fromJson(Map<String, Object?> json) =>
      _$AuthSessionFromJson(json);

  final AuthUser user;
  final String accessToken;

  Map<String, Object?> toJson() => _$AuthSessionToJson(this);
}
