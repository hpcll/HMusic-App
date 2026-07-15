import 'package:json_annotation/json_annotation.dart';

part 'auth_user.g.dart';

@JsonSerializable()
class AuthUser {
  const AuthUser({required this.id, required this.username});

  factory AuthUser.fromJson(Map<String, Object?> json) =>
      _$AuthUserFromJson(json);

  final String id;
  final String username;

  Map<String, Object?> toJson() => _$AuthUserToJson(this);
}
