import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/direct/auth/mi_web_auth_policy.dart';
import '../../../core/direct/auth/mi_web_verifier.dart';
import '../data/direct_verification_driver.dart';
import '../view_models/direct_verification_view_model.dart';

/// 原生视图只负责展示和转发事件，Cookie 与结果判定由验证 VM/数据适配器负责。
class DirectVerificationWebView extends ConsumerWidget {
  const DirectVerificationWebView({super.key, required this.request});
  final MiWebAuthRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(directVerificationViewModelProvider(request).notifier);
    PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        userAgent: MiWebAuthPolicy.userAgent,
        useShouldOverrideUrlLoading: true,
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: false,
        supportMultipleWindows: false,
        sharedCookiesEnabled: false,
        isInspectable: false,
      ),
      onWebViewCreated: (controller) =>
          vm.attach(InAppVerificationDriver(controller)),
      shouldOverrideUrlLoading: (_, action) async =>
          await vm.navigate(
            action.request.url?.uriValue,
            mainFrame: action.isForMainFrame,
          )
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL,
      onLoadStart: (_, _) => vm.loading(),
      onLoadStop: (_, url) => vm.loaded(url?.uriValue),
      onUpdateVisitedHistory: (_, url, _) => vm.visited(url?.uriValue),
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame == true &&
            error.type != WebResourceErrorType.CANCELLED) {
          vm.failed();
        }
      },
      onReceivedHttpError: (_, request, _) {
        if (request.isForMainFrame == true) vm.failed();
      },
      onWebContentProcessDidTerminate: (_) => vm.failed(),
      onCreateWindow: (_, _) async => false,
      onPermissionRequest: (_, request) async => PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      ),
    );
  }
}
