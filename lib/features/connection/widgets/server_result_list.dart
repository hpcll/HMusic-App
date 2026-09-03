import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../app/theme/hmusic_radii.dart';
import '../data/lan_server_scanner.dart';
import 'discovery_card_shell.dart';

// 有发现结果时的列表：标签行固定在顶部，卡片超过定高就只在这块区域内滚动，
// 不把下方的手输区往下推。卡片即「点选即连」的主路径。
class ServerResultList extends StatelessWidget {
  const ServerResultList({
    required this.discovering,
    required this.servers,
    required this.enabled,
    required this.connectingBase,
    required this.onConnect,
    required this.onRescan,
    super.key,
  });

  final bool discovering;
  final List<DiscoveredServer> servers;
  final bool enabled;
  final Uri? connectingBase;
  final ValueChanged<DiscoveredServer> onConnect;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '附近的服务器',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: palette.mutedStrong,
                ),
              ),
            ),
            if (discovering)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: palette.mutedStrong,
                ),
              )
            else
              TextButton(
                onPressed: enabled ? onRescan : null,
                style: TextButton.styleFrom(
                  foregroundColor: palette.mutedStrong,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12.5),
                ),
                child: const Text('重新扫描'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: servers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final server = servers[index];
              return _ServerCard(
                server: server,
                enabled: enabled,
                connecting: server.base == connectingBase,
                onTap: () => onConnect(server),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.server,
    required this.enabled,
    required this.connecting,
    required this.onTap,
  });

  final DiscoveredServer server;
  final bool enabled;
  final bool connecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // 嵌套层：发现面是 panel-2 灰底，服务器小卡是 panel 白色浮块；图标底
    // 回到灰，纸面 → 灰面 → 白卡 → 图标四层不重样，分离靠底色差不靠描边。
    return DiscoveryCardShell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.panelSecondary,
                borderRadius: BorderRadius.circular(HMusicRadii.small),
              ),
              child: Icon(
                Icons.dns_rounded,
                size: 18,
                color: palette.mutedStrong,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    server.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${server.base.host}:${server.base.port}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: palette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 「正在连接这台」是当下正在发生的动作，青绿即时反馈符合铁律。
            if (connecting)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: palette.accent,
                ),
              )
            else
              Icon(Icons.arrow_forward_rounded, size: 16, color: palette.muted),
          ],
        ),
      ),
    );
  }
}
