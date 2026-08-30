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
  const ConnectionPage({super.key, this.autoResume = true});

  static const String path = '/connect';

  // 「更换服务器」入口专用的地址：带上它就关掉冷启动接续。用户是奔着换一台来的，
  // 若照旧原样连回上一台并 go(AuthPage)，界面表现就是「转个圈又回到原来那页」，
  // 服务器永远换不掉（退出登录后也一样，接续成功照样把人弹回登录页）。
  static const String switchPath = '$path?switch=1';

  // 只有冷启动（App 打开时的初始路由）才接续上次的服务器。
  final bool autoResume;

  @override
  ConsumerState<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<ConnectionPage> {
  final TextEditingController _addressController = TextEditingController();

  // 手动表单是否被用户主动展开；展开后不再收起（链接消失，状态单向）。
  bool _manualExpanded = false;

  // 正在连接的发现卡片，只给它转菊花。
  Uri? _connectingBase;

  // 冷启动接续这一程只显示品牌，不显示任何「查找服务器」的东西。必须在
  // initState 同步置位：接续排在 microtask 里，state.restoring 要等下一轮
  // 才为真，中间那一两帧会把「正在寻找局域网内的 HMusic Server…」闪出来
  // ——用户每次开 App（无论登没登录）都先看见一次找服务器，正是这一下难看。
  bool _booting = false;

  // 接续慢了才解释自己。局域网接续通常几百毫秒就完了，一上来就甩菊花 +
  // 「正在连接上次的服务器…」，那一闪反而像出了错；等过了这个门槛还没好，
  // 才有必要告诉用户在等什么。
  static const Duration _hintDelay = Duration(milliseconds: 700);
  Timer? _hintTimer;
  bool _showRestoreHint = false;

  // 品牌渐显的节奏。开场不是"尽快让路"，是一段要走完的过场：字标先浮上来，
  // 标语错半拍跟上（对齐 clearshot 那套：1.8s 动画 + 分两拍 + 最短停留 2s）。
  static const Duration _introDuration = Duration(milliseconds: 900);

  // 开场最短停留。接续在局域网里往往两三百毫秒就回来了，回来就跳 = 动画跑到
  // 一半被切页，上一页的字标（已就位）和下一页的字标（还在上浮）叠在一起淡入
  // 淡出，看着就是"最后一下出现重影"。必须等这段走完再走人。
  static const Duration _openingHold = Duration(milliseconds: 1400);
  Timer? _openingTimer;
  bool _openingDone = false;
  late final DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _openingTimer = Timer(_openingHold, () {
      if (mounted) setState(() => _openingDone = true);
    });
    if (widget.autoResume) {
      _booting = true;
      _hintTimer = Timer(_hintDelay, () {
        if (mounted) setState(() => _showRestoreHint = true);
      });
    }
    unawaited(
      Future<void>.microtask(() async {
        final notifier = ref.read(connectionViewModelProvider.notifier);
        // 主动来换服务器：只把上次的地址回填进手输框供修改，绝不自动连回去。
        if (!widget.autoResume) {
          await notifier.loadSavedAddress();
          unawaited(notifier.discover());
          return;
        }
        // 先尝试接续上次的服务器：成功就直接进登录页（token 有效会再自动放行到
        // 首页），用户开 App 不需要每次重新点服务器、更不该重新登录。
        if (await notifier.resumeSaved()) {
          // 接续快过开场时也要把开场走完再跳：半路切页就是重影的来源。
          await _awaitOpening();
          if (mounted) context.go(AuthPage.path);
          return;
        }
        // 没存过地址或连不上（换网、服务端没开）：收起开场，自动扫描本网段。
        if (mounted) {
          _hintTimer?.cancel();
          setState(() {
            _booting = false;
            _showRestoreHint = false;
          });
        }
        unawaited(notifier.discover());
      }),
    );
  }

  // 补齐开场剩下的时间；已经走完就立即返回。
  Future<void> _awaitOpening() async {
    final Duration remaining =
        _openingHold - DateTime.now().difference(_openedAt);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  // 把总进度 t 切成一段（begin~end），段外夹到 0/1——用来错开两拍。
  double _stage(double t, double begin, double end) =>
      ((t - begin) / (end - begin)).clamp(0.0, 1.0);

  // 淡入 + 上浮收尾：纯淡入偏"贴纸"，带一点位移才像浮上来。
  Widget _rise(double t, double distance, Widget child) => Opacity(
    opacity: t,
    child: Transform.translate(
      offset: Offset(0, (1 - t) * distance),
      child: child,
    ),
  );

  @override
  void dispose() {
    _openingTimer?.cancel();
    _hintTimer?.cancel();
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // 「扫过且一无所获」→ 手动表单自动展开；尚未扫过/扫描中/有结果都收起，
    // 保持构图干净、首帧不闪表单。
    final scanning = state.discovering || !state.discoverCompleted;
    final showForm = _manualExpanded || (!scanning && state.discovered.isEmpty);
    // 开场态：只有品牌 + （慢了才出现的）一行说明，不渲染任何发现/表单控件。
    // 品牌渐显没走完也算开场，控件不插队。
    final splash =
        _booting || state.restoring || !(_openingDone || reduceMotion);
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
                  // 品牌块分两拍浮上来：字标先走，标语错半拍跟上（clearshot 的
                  // 开场也是先文字后图标两拍，比一整块同时淡入更像"呼吸"）。
                  // 只在进页时跑一次——TweenAnimationBuilder 挂载即从 0 走到 1，
                  // 之后不再重放。
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: reduceMotion ? Duration.zero : _introDuration,
                    curve: Curves.easeInOut,
                    builder: (context, t, child) {
                      final double markT = Curves.easeOut.transform(
                        _stage(t, 0, 0.7),
                      );
                      final double sloganT = Curves.easeOut.transform(
                        _stage(t, 0.35, 1),
                      );
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // 居中构图：品牌块（完整字标 + 副标题）与内容块拉开大段
                          // 距离，分组呼吸感是这页的关键——间距均匀就会「挤成一坨」。
                          // 字标本身含 H（字形双竖笔）+ Music 连读，不另写 "HMusic"。
                          _rise(
                            markT,
                            12,
                            const Center(child: BrandWordmark(size: 56)),
                          ),
                          const SizedBox(height: 20),
                          // 副标题是品牌 slogan：一句轻轻的搭话，不解释产品、不重复
                          // 品牌名。衬线 + 加宽字距 = 扉页题句的声调；mutedStrong
                          // 保证可读但不抢字标。
                          _rise(
                            sloganT,
                            8,
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
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 52),
                  // 开场 → 发现/手输的切换走淡入淡出：接续失败时控件不是「啪」
                  // 地出现，而是接着品牌浮上来的那口气显形。
                  AnimatedSwitcher(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: splash
                        ? Center(
                            key: const ValueKey<String>('splash'),
                            // 接续这一句始终占位、只改透明度：700ms 后淡入，
                            // 布局不动——否则品牌块会在它出现时被顶着往上跳。
                            child: AnimatedOpacity(
                              opacity: _showRestoreHint ? 1 : 0,
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
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
                            ),
                          )
                        : Column(
                            key: const ValueKey<String>('content'),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
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
                                duration: reduceMotion
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
                                            textStyle: const TextStyle(
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          child: const Text('手动输入地址'),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                  ),
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
