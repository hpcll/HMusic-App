import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/brand_mark.dart';
import '../../connection/widgets/playback_mode_actions.dart';
import '../view_models/direct_login_view_model.dart';
import '../widgets/direct_credentials_form.dart';
import '../widgets/direct_password_form.dart';

class DirectLoginPage extends ConsumerStatefulWidget {
  const DirectLoginPage({super.key});
  static const path = '/direct/login';

  @override
  ConsumerState<DirectLoginPage> createState() => _DirectLoginPageState();
}

class _DirectLoginPageState extends ConsumerState<DirectLoginPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(() async {
        if (!mounted) return;
        await ref.read(directLoginViewModelProvider.notifier).restore();
        if (mounted && ref.read(directLoginViewModelProvider).account != null) {
          context.go('/search-tab');
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directLoginViewModelProvider);
    ref.listen(directLoginViewModelProvider, (_, next) {
      if (!next.busy && next.account != null) context.go('/search-tab');
    });
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: BrandWordmark(size: BrandWordmark.standardSize),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '直连模式',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('登录小米账号后直接控制音箱。歌单与音源保存在这台设备上，无需 HMusic Server。'),
                  const SizedBox(height: 24),
                  if (state.errorMessage != null) ...[
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const DirectPasswordForm(),
                  const SizedBox(height: 16),
                  const DirectCredentialsForm(),
                  const SizedBox(height: 24),
                  const PlaybackModeActions(entry: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
