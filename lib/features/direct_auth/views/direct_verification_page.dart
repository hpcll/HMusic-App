import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/direct/auth/mi_web_verifier.dart';
import '../view_models/direct_verification_view_model.dart';
import '../widgets/direct_verification_web_view.dart';

class DirectVerificationPage extends ConsumerStatefulWidget {
  const DirectVerificationPage({super.key, required this.request});
  static const path = '/direct/verification';
  final MiWebAuthRequest request;

  @override
  ConsumerState<DirectVerificationPage> createState() =>
      _DirectVerificationPageState();
}

class _DirectVerificationPageState
    extends ConsumerState<DirectVerificationPage> {
  bool _popScheduled = false;

  @override
  Widget build(BuildContext context) {
    final provider = directVerificationViewModelProvider(widget.request);
    final state = ref.watch(provider);
    final vm = ref.read(provider.notifier);
    if (state.closed && !_popScheduled) {
      _popScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          context.pop(state.result);
        }
      });
    }
    return PopScope(
      canPop: state.closed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) vm.cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('小米账号验证'),
          leading: IconButton(
            tooltip: '关闭验证',
            icon: const Icon(Icons.close),
            onPressed: vm.cancel,
          ),
          actions: [
            IconButton(
              tooltip: '重新加载',
              icon: const Icon(Icons.refresh),
              onPressed: state.loading ? null : vm.retry,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!state.closed)
                DirectVerificationWebView(request: widget.request),
              if (state.loading)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(),
                ),
              if (state.errorMessage != null)
                Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.errorMessage!),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: vm.retry,
                            child: const Text('重新加载'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
