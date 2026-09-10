import '../mi_direct_session.dart';

sealed class MiPassportResult {
  const MiPassportResult();
}

class MiPassportAuthenticated extends MiPassportResult {
  const MiPassportAuthenticated(this.session);
  final MiDirectSession session;
}

enum MiChallengeKind { captcha, identity }

class MiPassportChallenge extends MiPassportResult {
  const MiPassportChallenge({required this.kind, required this.url});
  final MiChallengeKind kind;
  final Uri url;

  @override
  String toString() => 'MiPassportChallenge(${kind.name})';
}
