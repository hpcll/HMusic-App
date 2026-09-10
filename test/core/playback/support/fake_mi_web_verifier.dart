import 'dart:async';
import 'dart:io';

import 'package:hmusic/core/direct/auth/mi_web_login_prefill.dart';
import 'package:hmusic/core/direct/auth/mi_web_verifier.dart';

class FakeMiWebVerifier implements MiWebVerifier {
  MiWebAuthResult? result;
  Completer<MiWebAuthResult?>? pending;
  List<Cookie> seeded = [];
  int opens = 0;

  @override
  Future<MiWebAuthResult?> open({
    required Uri url,
    required List<Cookie> cookies,
    MiWebLoginPrefill? prefill,
  }) {
    opens++;
    seeded = cookies;
    return pending?.future ?? Future.value(result);
  }

  @override
  Future<void> cancel() async {
    if (pending != null && !pending!.isCompleted) pending!.complete(null);
  }
}
