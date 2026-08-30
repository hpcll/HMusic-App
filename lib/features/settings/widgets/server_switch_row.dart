import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../connection/views/connection_page.dart';

// 设置菜单的「更换服务器」入口：换网后不重启 App 也能回连接页重扫/改地址。
// 只导航不清会话——connect() 落定新地址时才决定是否清 token（换服才清）。
class SettingsServerSwitchRow extends StatelessWidget {
  const SettingsServerSwitchRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: TextButton.icon(
          onPressed: () => context.go(ConnectionPage.switchPath),
          icon: const Icon(Icons.lan_rounded, size: 16),
          label: const Text('更换服务器'),
          style: TextButton.styleFrom(foregroundColor: context.palette.muted),
        ),
      ),
    );
  }
}
