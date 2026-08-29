import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../auth/views/auth_page.dart';
import '../data/lan_server_scanner.dart';
import '../view_models/connection_view_model.dart';
import '../widgets/discovered_server_list.dart';
import '../widgets/server_address_form.dart';

// 连接页信息层级：自动发现是主路径——「附近的服务器」卡片紧随品牌区，点选
// 即连；手动表单是次要路径，默认折叠成一条 ghost 链接，只有扫描结束一无所获
// 时才自动展开（首次部署/mDNS 与扫段都不可达的场景）。错误行统一放两区之间，
// 卡片连接失败和手动连接失败共用一个落点。
class ConnectionPage extends ConsumerStatefulWidget {
  const ConnectionPage({super.key});

  static const String path = '/connect';

  @override
  ConsumerState<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<ConnectionPage> {
  final TextEditingController _addressController = TextEditingController();

  // 手动表单是否被用户主动展开；展开后不再收起（链接消失，状态单向）。
  bool _manualExpanded = false;

  // 正在连接的发现卡片，只给它转菊花。
  Uri? _connectingBase;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(() async {
        final notifier = ref.read(connectionViewModelProvider.notifier);
        // 先尝试接续上次的服务器：成功就直接进登录页（token 有效会再自动放行到
        // 首页），用户开 App 不需要每次重新点服务器、更不该重新登录。
        if (await notifier.resumeSaved()) {
          if (mounted) context.go(AuthPage.path);
          return;
        }
        // 没存过地址或连不上（换网、服务端没开）：开屏自动扫描本网段，点选即连。
        unawaited(notifier.discover());
      }),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionViewModelProvider);
    ref.listen(connectionViewModelProvider, (previous, next) {
      if (_addressController.text.isEmpty && next.suggestedAddress.isNotEmpty) {
        _addressController.text = next.suggestedAddress;
      }
    });
    final palette = context.palette;
    // 「扫过且一无所获」→ 手动表单自动展开；尚未扫过/扫描中/有结果都收起，
    // 保持构图干净、首帧不闪表单。
    final scanning = state.discovering || !state.discoverCompleted;
    final showForm = _manualExpanded || (!scanning && state.discovered.isEmpty);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // 底边距大于顶边距：内容重心略高于几何中心（视觉居中），大窗不显下坠。
            padding: const EdgeInsets.fromLTRB(40, 48, 40, 96),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 居中构图：品牌块（完整字标 + 副标题）与内容块拉开大段距离，
                  // 分组呼吸感是这页的关键——间距均匀就会「挤成一坨」。
                  // 字标本身含 H（字形双竖笔）+ Music 连读，不再另写 "HMusic"。
                  const Center(child: BrandWordmark(size: 56)),
                  const SizedBox(height: 20),
                  // 副标题是品牌 slogan：一句轻轻的搭话，不解释产品、不重复品牌名。
                  // 衬线 + 加宽字距 = 扉页题句的声调；mutedStrong 保证可读但不抢字标。
                  Text(
                    '今天想听点什么',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      letterSpacing: 3,
                      color: palette.mutedStrong,
                    ),
                  ),
                  const SizedBox(height: 52),
                  if (state.restoring)
                    // 接续上次服务器的过场：只留一句话 + 菊花。这里若照常渲染
                    // 发现卡片/手动表单，开屏就会闪一下「附近的服务器」再跳走。
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.mutedStrong,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '正在连接上次的服务器…',
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...<Widget>[
                    DiscoveredServerList(
                      discovering: scanning,
                      servers: state.discovered,
                      enabled: !state.isConnecting,
                      connectingBase: state.isConnecting
                          ? _connectingBase
                          : null,
                      onConnect: _connectDiscovered,
                      onRescan: () => ref
                          .read(connectionViewModelProvider.notifier)
                          .discover(),
                    ),
                    if (state.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        state.errorMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    // 手动区显隐走 220ms easeOut 尺寸过渡（docs/05 chrome 同词汇）。
                    AnimatedSize(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: showForm
                          ? ServerAddressForm(
                              controller: _addressController,
                              isConnecting: state.isConnecting,
                              onSubmit: _connect,
                            )
                          : Center(
                              child: TextButton(
                                onPressed: state.isConnecting
                                    ? null
                                    : () => setState(
                                        () => _manualExpanded = true,
                                      ),
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.muted,
                                  textStyle: const TextStyle(fontSize: 12.5),
                                ),
                                child: const Text('手动输入地址'),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final success = await ref
        .read(connectionViewModelProvider.notifier)
        .connect(_addressController.text);
    if (success && mounted) context.go(AuthPage.path);
  }

  // 点选发现结果 = 回填输入框 + 走既有连接链路（持久化/换服清 token 都在其中）。
  Future<void> _connectDiscovered(DiscoveredServer server) async {
    setState(() => _connectingBase = server.base);
    _addressController.text = server.base.toString();
    await _connect();
    if (mounted) setState(() => _connectingBase = null);
  }
}
