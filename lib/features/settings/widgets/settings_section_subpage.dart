import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/back_link.dart';

// 窄屏设置子页骨架：页头（返回键 + 居中衬线标题，对齐 web .section-head）+ 内容。
// 子页是设置页内的二级态而非 push 路由，PopScope 把系统返回接成「回菜单」，
// 与页头返回键同一条路，不再冒泡到壳层退出 App（docs/05 §5 返回契约）。
class SettingsSectionSubpage extends StatelessWidget {
  const SettingsSectionSubpage({
    required this.title,
    required this.onBack,
    required this.child,
    super.key,
  });

  final String title;

  // 回菜单页（含摘要刷新）；系统返回与 BackLink 共用。
  final VoidCallback onBack;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8 + MediaQuery.paddingOf(context).top,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              BackLink(label: '设置', onTap: onBack),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textStrong,
                    ),
                  ),
                ),
              ),
              // 右占位与左返回键平衡，标题保持视觉居中。
              const SizedBox(width: 64),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
