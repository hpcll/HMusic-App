import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/direct/auth/mi_direct_login_result.dart';
import '../../../core/direct/auth/mi_passport_result.dart';
import '../../../core/direct/auth/mi_web_login_prefill.dart';
import '../../../core/direct/direct_session_providers.dart';
import '../../../core/direct/mi_direct_providers.dart';
import '../../../core/direct/mi_direct_session.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/playback/playback_mode_controller.dart';
import '../models/direct_login_state.dart';

final directLoginViewModelProvider =
    NotifierProvider<DirectLoginViewModel, DirectLoginState>(
      DirectLoginViewModel.new,
    );

class DirectLoginViewModel extends Notifier<DirectLoginState> {
  int _generation = 0;

  @override
  DirectLoginState build() {
    ref.watch(playbackModeProvider);
    final repository = ref.watch(miDirectAccountRepositoryProvider);
    ref.onDispose(() {
      _generation++;
      unawaited(repository.cancelLogin().catchError((Object _) {}));
    });
    return const DirectLoginState();
  }

  Future<void> restore() {
    if (state.busy) return Future<void>.value();
    state = const DirectLoginState();
    return _run((generation) async {
      final account = await ref
          .read(miDirectAccountRepositoryProvider)
          .restore();
      if (_current(generation)) {
        if (account != null) {
          ref.read(directSessionControllerProvider).markValid();
        }
        state = DirectLoginState(account: account);
      }
    });
  }

  Future<void> login({
    required String account,
    required String password,
    String? captchaCode,
  }) => _run((generation) async {
    final result = await ref
        .read(miDirectAccountRepositoryProvider)
        .loginPassword(
          account: account,
          password: password,
          captchaCode: captchaCode,
        );
    await _apply(result, generation);
  });

  Future<void> importSession({
    required String userId,
    required String serviceToken,
  }) => _run((generation) async {
    final session = MiDirectSession(
      userId: userId.trim(),
      serviceToken: serviceToken.trim(),
    );
    final account = await ref
        .read(miDirectAccountRepositoryProvider)
        .importSession(session);
    if (_current(generation)) {
      ref.read(directSessionControllerProvider).markValid();
      state = DirectLoginState(account: account);
    }
  });

  Future<void> importPassToken({
    required String userId,
    required String passToken,
  }) => _run((generation) async {
    final result = await ref
        .read(miDirectAccountRepositoryProvider)
        .loginPassToken(userId: userId.trim(), passToken: passToken.trim());
    await _apply(result, generation);
  });

  Future<void> refreshCaptcha() => _run((generation) async {
    final challenge = state.challenge;
    if (challenge == null || challenge.kind != MiChallengeKind.captcha) return;
    // 刷新会更新验证码 Cookie；失败时不能继续展示已失效的上一张图片。
    state = DirectLoginState(busy: true, challenge: challenge);
    final bytes = await ref
        .read(miDirectAccountRepositoryProvider)
        .captchaImage(challenge);
    if (_current(generation)) {
      state = DirectLoginState(challenge: challenge, captchaImage: bytes);
    }
  });

  Future<void> _apply(MiDirectLoginResult result, int generation) async {
    if (!_current(generation)) return;
    switch (result) {
      case MiDirectLoginAuthenticated(:final account):
        ref.read(directSessionControllerProvider).markValid();
        state = DirectLoginState(account: account);
      case MiDirectLoginChallenge(:final challenge):
        state = DirectLoginState(busy: true, challenge: challenge);
        if (challenge.kind == MiChallengeKind.captcha) {
          final bytes = await ref
              .read(miDirectAccountRepositoryProvider)
              .captchaImage(challenge);
          if (_current(generation)) {
            state = DirectLoginState(challenge: challenge, captchaImage: bytes);
          }
        } else {
          state = DirectLoginState(challenge: challenge);
        }
    }
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  Future<void> openVerification({String account = '', String password = ''}) =>
      _run((generation) async {
        final challenge = state.challenge;
        if (challenge?.kind != MiChallengeKind.identity) return;
        final prefill = account.trim().isEmpty || password.isEmpty
            ? null
            : MiWebLoginPrefill(account: account, password: password);
        try {
          final result = await ref
              .read(miDirectAccountRepositoryProvider)
              .verifyWeb(challenge!, prefill: prefill);
          if (result != null) await _apply(result, generation);
        } finally {
          prefill?.clear();
        }
      });

  Future<void> cancel() async {
    ++_generation;
    final repository = ref.read(miDirectAccountRepositoryProvider);
    state = const DirectLoginState();
    await repository.cancelLogin();
  }

  Future<void> _run(Future<void> Function(int generation) action) async {
    if (state.busy) return;
    final generation = ++_generation;
    state = DirectLoginState(
      busy: true,
      account: state.account,
      challenge: state.challenge,
      captchaImage: state.captchaImage,
    );
    try {
      await action(generation);
    } catch (error) {
      if (!_current(generation)) return;
      state = DirectLoginState(
        account: state.account,
        challenge: state.challenge,
        captchaImage: state.captchaImage,
        errorMessage: error is ApiFailure ? error.message : '小米登录未完成，请重试',
      );
    } finally {
      if (_current(generation) && state.busy) {
        state = DirectLoginState(
          account: state.account,
          challenge: state.challenge,
          captchaImage: state.captchaImage,
          errorMessage: state.errorMessage,
        );
      }
    }
  }
}
