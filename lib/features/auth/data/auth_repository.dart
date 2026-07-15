import '../models/auth_session.dart';
import '../models/auth_status.dart';

abstract interface class AuthRepository {
  Future<AuthStatus> status();

  Future<AuthSession> login({
    required String username,
    required String password,
  });

  Future<AuthSession> setup({
    required String username,
    required String password,
  });
}
