import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform_shell/platform_shell_controller.dart';
import 'flutter_glass_shell.dart';
import 'top_edge_scrim.dart';

class NativeGlassBody extends StatelessWidget {
  const NativeGlassBody({
    required this.shell,
    required this.controller,
    super.key,
  });

  final StatefulNavigationShell shell;
  final PlatformShellController controller;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(bottom: controller.nativeBottomInset),
      ),
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ScrollMinimizeListener(
                onMinimized: (value) =>
                    controller.reportScroll(minimized: value),
                child: shell,
              ),
            ),
            const Positioned(top: 0, left: 0, right: 0, child: TopEdgeScrim()),
          ],
        ),
      ),
    );
  }
}
