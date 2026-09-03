import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../data/lan_server_scanner.dart';
import 'server_result_list.dart';

// 发现区（连接页主角）：自动发现是主路径，「附近的服务器」点选即连。
//
// 三个状态共用**同一个定高框**（kDiscoveryHeight），切换只换内容、骨架不
// 动，下方手输区永远不会跟着上下窜（用户说的「一会大一会小」就是它）。
// 框内对齐按内容分：有结果时标签行 + 卡片顶对齐铺满；扫描中 / 空态只有
// 两三行轻量文字，**纵向居中、略偏上**——顶对齐会让两行字贴在框上沿、
// 下面留一条 ~170px 的死白，整页散成「上面一撮字、下面一个链接」。
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

  // 发现面内区固定高度（外壳另有 12 内边距）：标签行 + 一张服务器小卡整卡
  // + 下一张的露头（≈ 136）——多台服务器在面内滚动，露头本身就是「还能滚」
  // 的提示；扫描中/空态居中留白，是「还在找」的呼吸感。
  static const double kDiscoveryHeight = 136;

  final bool discovering;
  final List<DiscoveredServer> servers;
  final bool enabled;
  final ValueChanged<DiscoveredServer> onConnect;
  final VoidCallback onRescan;

  // 正在连接的那台（页面本地状态）：只给它转菊花，其余保持箭头。
  final Uri? connectingBase;

  @override
  Widget build(BuildContext context) {
    // 三态都在框内交叉淡化换内容：外壳定高不动，切换不跳（同页面的换场词汇）。
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final String phase = servers.isEmpty
        ? (discovering ? 'scanning' : 'empty')
        : 'found';
    return SizedBox(
      height: kDiscoveryHeight,
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<String>(phase),
          child: servers.isEmpty
              ? (discovering
                    ? const _ScanningStatus()
                    : Align(
                        // 卡内居中略偏上：与扫描态同一锚点，两态切换文字原地换。
                        alignment: const Alignment(0, _statusBiasY),
                        child: EmptyDiscoveryStatus(
                          enabled: enabled,
                          onRescan: onRescan,
                        ),
                      ))
              : ServerResultList(
                  discovering: discovering,
                  servers: servers,
                  enabled: enabled,
                  connectingBase: connectingBase,
                  onConnect: onConnect,
                  onRescan: onRescan,
                ),
        ),
      ),
    );
  }
}

// 扫描中 / 空态的文字块在定高框内纵向居中、略偏上：正居中会和下方的
// 「手动输入地址」挤视觉重心，偏上一点让上呼吸 > 下呼吸。
const double _statusBiasY = -0.3;

// 扫描中：菊花 + 一行状态 + 一行提示，居中紧凑。
class _ScanningStatus extends StatelessWidget {
  const _ScanningStatus();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Align(
      alignment: const Alignment(0, _statusBiasY),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 15,
                height: 15,
                // 菊花单独成层：它一转就是每帧重绘，不隔开的话整页（含
                // 品牌块、表单）跟着一起重绘——扫描往往和"点输入框弹键盘"
                // 撞在一起，那几帧的预算要留给让位。
                child: RepaintBoundary(
                  // 扫描菊花用墨色，不用品牌青绿——accent 铁律只覆盖「正在发生的
                  // 事」中少数几处，扫局域网不在其列（docs/03）。
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.mutedStrong,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '正在寻找局域网内的服务器',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.textStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '手机和服务器需要在同一个 Wi-Fi',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

// 扫完一无所获：标题 + 一行提示 + hairline 小钮「重新扫描」，在发现卡内
// 居中略偏上。与扫描态（_ScanningStatus）同一锚点，两态切换只是文字换。
class EmptyDiscoveryStatus extends StatelessWidget {
  const EmptyDiscoveryStatus({
    required this.enabled,
    required this.onRescan,
    super.key,
  });

  final bool enabled;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '没有发现服务器',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.textStrong,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '确认手机和服务器在同一个 Wi-Fi',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.5, color: palette.muted),
        ),
        const SizedBox(height: 14),
        // hairline 小丸钮：是「再做一次」的含蓄出路，不抢手动表单的主角地位；
        // 墨色 + 1px 描边，青绿按铁律不用于操作染色。
        OutlinedButton.icon(
          onPressed: enabled ? onRescan : null,
          icon: const Icon(Icons.refresh_rounded, size: 14),
          label: const Text('重新扫描'),
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.mutedStrong,
            side: BorderSide(color: palette.line),
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
