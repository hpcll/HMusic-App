import 'package:json_annotation/json_annotation.dart';

import 'auth_user.dart';

part 'auth_status.g.dart';

@JsonSerializable(explicitToJson: true)
class AuthStatus {
  const AuthStatus({
    required this.initialized,
    required this.authenticated,
    this.user,
  });

  factory AuthStatus.fromJson(Map<String, Object?> json) =>
      _$AuthStatusFromJson(json);

  final bool initialized;
  final bool authenticated;
  final AuthUser? user;

  Map<String, Object?> toJson() => _$AuthStatusToJson(this);
}
