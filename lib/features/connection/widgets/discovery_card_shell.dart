import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../app/theme/hmusic_radii.dart';

// 发现区内嵌的服务器小卡：panel 白底 + 10 圆角 + 极微投影，**无边框**
// （用户反馈边框去掉）——嵌在灰底发现面里读作白色浮块，分离靠底色差。
// 投影沿用设计系统 --shadow（0 1px 2px 4%），比 hairline 更轻。
class DiscoveryCardShell extends StatelessWidget {
  const DiscoveryCardShell({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HMusicRadii.small),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: context.palette.panel,
        borderRadius: BorderRadius.circular(HMusicRadii.small),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}
