import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import 'settings_overview.dart';

// 双栏只负责排版，选中项与表单实例继续由 SettingsPage 持有。
class SettingsWideLayout extends StatelessWidget {
  const SettingsWideLayout({
    required this.menuWidth,
    required this.menu,
    required this.sectionTitle,
    required this.child,
    this.direct = false,
    this.menuFooter,
    super.key,
  });
  final double menuWidth;
  final Widget menu, child;
  final Widget? menuFooter;
  final String sectionTitle;
  final bool direct;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      16,
      24 + MediaQuery.paddingOf(context).top,
      16,
      32 + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      SettingsOverview(direct: direct),
      const SizedBox(height: 28),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: menuWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [menu, if (menuFooter != null) menuFooter!],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sectionTitle,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textStrong,
                  ),
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ],
      ),
    ],
  );
}
