import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../data/lan_server_scanner.dart';

// 发现区（连接页主角）：自动发现已是连接主路径，卡片按设计系统 .card 规格
// （panel + hairline + radius 10 + 轻投影）承载「点选即连」；扫描态/空态只占
// 一行 muted 文案，不抢构图。「重新扫描」挂标签行右端，换 Wi-Fi 不用重启。
class DiscoveredServerList extends StatelessWidget {
  const DiscoveredServerList({
    required this.discovering,
    required this.servers,
    required this.enabled,
    required this.onConnect,
    required this.onRescan,
    this.connectingBase,
    super.key,
  });

  final bool discovering;
  final List<DiscoveredServer> servers;
  final bool enabled;
  final ValueChanged<DiscoveredServer> onConnect;
  final VoidCallback onRescan;

  // 正在连接的那台（页面本地状态）：只给它转菊花，其余保持箭头。
  final Uri? connectingBase;

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
                  color: palette.muted,
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
        if (servers.isEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            discovering ? '正在寻找局域网内的 HMusic Server…' : '未发现服务器，输入地址连接',
            style: TextStyle(fontSize: 12.5, color: palette.muted),
          ),
        ],
        for (final server in servers) ...<Widget>[
          const SizedBox(height: 10),
          _ServerCard(
            server: server,
            enabled: enabled,
            connecting: server.base == connectingBase,
            onTap: () => onConnect(server),
          ),
        ],
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
    return Material(
      color: palette.panel,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(10),
            // --shadow：0 1px 2px 4%，卡片同款克制投影。
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.panelSecondary,
                    borderRadius: BorderRadius.circular(8),
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
                if (connecting)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: palette.muted,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: palette.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
