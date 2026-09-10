import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/infrastructure_providers.dart';
import 'auth/mi_passport_client.dart';
import 'auth/mi_passport_http.dart';
import 'auth/mi_web_cookie_bridge.dart';
import 'auth/mi_web_verifier.dart';
import 'mi_direct_account_repository.dart';
import 'mi_direct_session_store.dart';
import 'mi_mina_client.dart';

final miDirectSessionStoreProvider = Provider<MiDirectSessionStore>(
  (_) => SecureMiDirectSessionStore(),
);

final miMinaClientProvider = Provider<MiMinaClient>((ref) {
  final client = MiMinaClient();
  ref.onDispose(client.close);
  return client;
});

final miWebVerifierProvider = Provider<MiWebVerifier>(
  (_) => const UnavailableMiWebVerifier(),
);

final miWebCookiesProvider = Provider<MiWebCookies>((_) => MiWebCookieBridge());

final miPassportClientProvider = Provider<MiPassportClient>((ref) {
  final client = MiPassportClient(
    http: MiPassportHttp(),
    preferences: ref.watch(keyValueStoreProvider),
    webVerifier: ref.watch(miWebVerifierProvider),
  );
  ref.onDispose(client.close);
  return client;
});

final miDirectAccountRepositoryProvider = Provider<MiDirectAccountRepository>(
  (ref) => MiDirectAccountRepository(
    client: ref.watch(miMinaClientProvider),
    store: ref.watch(miDirectSessionStoreProvider),
    passport: ref.watch(miPassportClientProvider),
  ),
);
