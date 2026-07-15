// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthStatus _$AuthStatusFromJson(Map<String, dynamic> json) => AuthStatus(
  initialized: json['initialized'] as bool,
  authenticated: json['authenticated'] as bool,
  user: json['user'] == null
      ? null
      : AuthUser.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AuthStatusToJson(AuthStatus instance) =>
    <String, dynamic>{
      'initialized': instance.initialized,
      'authenticated': instance.authenticated,
      'user': instance.user?.toJson(),
    };
