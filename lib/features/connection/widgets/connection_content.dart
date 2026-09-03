import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../app/theme/hmusic_radii.dart';
import '../data/lan_server_scanner.dart';
import '../models/connection_view_state.dart';
import 'discovered_server_list.dart';
import 'server_address_form.dart';

// 发现/手输区本体（连接页 AnimatedSwitcher 的 content 分支）。
//
// 骨架恒定：发现卡（panel 卡 + 定高）→ 20 → 手动表单。手动表单永远可见，
// 不再折叠成「手动输入地址」链接——此前扫描中/空态/有结果三副结构互跳，
// 表单跟着上下蹿（用户反馈「下面的 UI 会根据有没有服务器变化」）。
// 现在三态只在发现卡内部换内容，卡与表单一个像素都不动。
//
// 层次：纸面底 → 发现卡（panel）→ 服务器小卡（panel-2）；
// 扫描中/空态是卡内居中的两三行轻量文字。
class ConnectionContent extends StatelessWidget {
  const ConnectionContent({
    required this.state,
    required this.addressController,
    required this.addressFocus,
    required this.connectingBase,
    required this.onConnectDiscovered,
    required this.onRescan,
    required this.onSubmitManual,
    super.key,
  });

  final ConnectionViewState state;
  final TextEditingController addressController;

  // 手动表单地址输入框的焦点：页面层靠它驱动注脚让位（见 _ConnectionPageState）。
  final FocusNode addressFocus;

  // 正在连接的发现卡片：只给它转菊花，其余保持箭头。
  final Uri? connectingBase;
  final ValueChanged<DiscoveredServer> onConnectDiscovered;
  final VoidCallback onRescan;
  final VoidCallback onSubmitManual;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Widget manualForm = ServerAddressForm(
      controller: addressController,
      focusNode: addressFocus,
      isConnecting: state.isConnecting,
      errorMessage: state.errorMessage,
      onSubmit: onSubmitManual,
    );

    return Column(
      key: const ValueKey<String>('content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 发现面：与下方输入框同一材质（灰底 panel-2、无描边、radius 14，
        // 设计系统 .input 的 App 形态）——两个可交互区读作同一表单家族，
        // 靠底色差而非边框分层。定高（内边距 + kDiscoveryHeight ≈ 160）：
        // 结果多时只在面内滚动，不把下方表单往下推。
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelSecondary,
            borderRadius: BorderRadius.circular(HMusicRadii.input),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: DiscoveredServerList.kDiscoveryHeight,
              child: DiscoveredServerList(
                discovering: state.discovering || !state.discoverCompleted,
                servers: state.discovered,
                enabled: !state.isConnecting,
                connectingBase: connectingBase,
                onConnect: onConnectDiscovered,
                onRescan: onRescan,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 手动表单：次要路径但永远在场——扫不到时不用先点链接展开，地址
        // 已存时回填直接可见。
        manualForm,
      ],
    );
  }
}
