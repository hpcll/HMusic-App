import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VerificationWebViewPlatform extends InAppWebViewPlatform {
  int creations = 0;
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    creations++;
    return _WebView(params);
  }
}

class _WebView extends PlatformInAppWebViewWidget {
  _WebView(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('web-content'));
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      throw UnsupportedError('Widget layout fixture has no native controller');
  @override
  void dispose() {}
}
