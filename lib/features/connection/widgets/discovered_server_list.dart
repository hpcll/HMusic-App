import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../app/theme/hmusic_radii.dart';
import '../data/lan_server_scanner.dart';

// 发现区（连接页主角）：自动发现是连接主路径，卡片按设计系统 .card 规格
// （panel + hairline + card 圆角 + 轻投影）承载「点选即连」。
//
// 三个状态共用同一块卡片形状，构图不塌：
//   扫描中 → 卡片里一行「菊花 + 正在寻找」，居中；
//   一无所获 → 卡片里图标 + 一句说明 + 重新扫描；
//   有结果 → 「附近的服务器」标签行（右端挂重新扫描）+ 若干服务器卡片。
// 之前扫描态/空态只有裸文字挂在居中的品牌块下面，左对齐、无容器，看着像没做完。
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
    if (servers.isEmpty) {
      return _StatusCard(
        discovering: discovering,
        enabled: enabled,
        onRescan: onRescan,
      );
    }

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
                  color: palette.accent,
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

// 还没有结果时的那块卡片。扫描中和一无所获共用一个外框，只换里面的内容——
// 换状态时卡片不会消失重建，构图稳。
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.discovering,
    required this.enabled,
    required this.onRescan,
  });

  final bool discovering;
  final bool enabled;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 圆形托底里的图标/菊花：扫描中用品牌青绿转圈，停下来用灰色图标。
            // 尺寸固定，两态互换时卡片高度不跳。
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.panelSecondary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: discovering
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.accent,
                      ),
                    )
                  : Icon(
                      Icons.wifi_tethering_off_rounded,
                      size: 20,
                      color: palette.muted,
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              discovering ? '正在寻找局域网内的服务器' : '没有发现服务器',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.textStrong,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              discovering ? '手机和服务器需要在同一个 Wi-Fi 下' : '确认在同一个 Wi-Fi，或在下面手动输入地址',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: palette.muted,
              ),
            ),
            if (!discovering) ...<Widget>[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: enabled ? onRescan : null,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('重新扫描'),
                style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 设计系统 .card：panel 底 + hairline 描边 + 14 圆角 + 0 1px 2px 4% 投影。
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.panel,
      borderRadius: BorderRadius.circular(HMusicRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(HMusicRadii.card),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: child,
        ),
      ),
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
    return _CardShell(
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
