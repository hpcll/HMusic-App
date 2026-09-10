import 'dart:async';
import 'dart:io';

import 'package:hmusic/core/direct/auth/mi_web_cookie_bridge.dart';
import 'package:hmusic/core/direct/auth/mi_web_login_prefill.dart';
import 'package:hmusic/features/direct_auth/data/direct_verification_driver.dart';

class FakeVerificationCookies implements MiWebCookies {
  Map<String, String> accountValues = {}, serviceValues = {};
  Completer<void>? preparing;
  Completer<Map<String, String>>? reading;
  bool failPreparation = false;
  int preparations = 0, clears = 0, accountReads = 0;

  @override
  Future<void> prepare(Uri url, List<Cookie> cookies) async {
    preparations++;
    if (failPreparation) throw StateError('fixture preparation failure');
    await preparing?.future;
  }

  @override
  Future<Map<String, String>> account() async {
    accountReads++;
    return await reading?.future ?? accountValues;
  }

  @override
  Future<Map<String, String>> service(Uri uri) async => serviceValues;

  @override
  Future<void> clear() async {
    clears++;
  }
}

class FakeVerificationDriver implements DirectVerificationDriver {
  final loads = <Uri>[];
  int reloads = 0, stops = 0;
  bool fills = true;
  Completer<bool>? filling;
  final filledAccounts = <String>[];
  @override
  Future<bool> fillLogin(MiWebLoginPrefill prefill) async {
    filledAccounts.add(prefill.account);
    return await filling?.future ?? fills;
  }

  @override
  Future<void> load(Uri uri) async {
    loads.add(uri);
  }

  @override
  Future<void> reload() async {
    reloads++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}
