// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthSession _$AuthSessionFromJson(Map<String, dynamic> json) => AuthSession(
  user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  accessToken: json['accessToken'] as String,
);

Map<String, dynamic> _$AuthSessionToJson(AuthSession instance) =>
    <String, dynamic>{
      'user': instance.user.toJson(),
      'accessToken': instance.accessToken,
    };
