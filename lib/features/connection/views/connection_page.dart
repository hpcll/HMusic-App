import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/startup/app_opening.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../auth/views/auth_page.dart';
import '../data/lan_server_scanner.dart';
import '../view_models/connection_view_model.dart';
import '../widgets/discovered_server_list.dart';
import '../widgets/server_address_form.dart';

// 字标显示高度。第 1 幕要把它摆到屏幕正中，得知道它自己多高。
const double _kWordmarkHeight = 56;

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

class _ConnectionPageState extends ConsumerState<ConnectionPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _addressController = TextEditingController();

  // 手动表单是否被用户主动展开；展开后不再收起（链接消失，状态单向）。
  bool _manualExpanded = false;

  // 正在连接的发现卡片，只给它转菊花。
  Uri? _connectingBase;

  // 冷启动接续这一程只显示品牌，不显示任何「查找服务器」的东西。必须在
  // initState 同步置位：接续排在 microtask 里，state.restoring 要等下一轮
  // 才为真，中间那一两帧会把「正在寻找局域网内的服务器」闪出来。
  bool _booting = false;

  // 接续慢了才解释自己。局域网接续通常几百毫秒就完了，一上来就甩菊花 +
  // 「正在连接上次的服务器…」，那一闪反而像出了错；等过了这个门槛还没好，
  // 才有必要告诉用户在等什么。
  static const Duration _hintDelay = Duration(milliseconds: 700);
  Timer? _hintTimer;
  bool _showRestoreHint = false;

  // 开场一条时间轴，三幕都从它身上按 Interval 切（clearshot 的开屏也是单个
  // controller + Interval 分幕）：
  //   0 → 700ms      字标在**屏幕正中**淡入；
  //   700 → 1000ms   定住不动（这个停顿就是"不着急"的来源）；
  //   1000 → 1520ms  推到它该在的位置（视口 18% 的锚点）；
  //   1520 → 1820ms  标语淡入（接住落位）；
  //   1700ms 起      下方发现区淡入，与标语略微错开；
  //   1900ms         整段结束——接续成功也要等到这里才跳页。
  static const Duration _openingTotal = Duration(milliseconds: 1900);
  static const double _markFadeEnd = 700 / 1900;
  static const double _liftStart = 1000 / 1900;
  static const double _liftEnd = 1520 / 1900;
  static const double _sloganEnd = 1820 / 1900;
  static const double _contentStart = 1700 / 1900;

  late final AnimationController _opening;
  late final Animation<double> _markFade;
  late final Animation<double> _lift;
  late final Animation<double> _sloganFade;

  // 开场走完（或压根没放）后完成，接续跳页要等它。
  final Completer<void> _openingDone = Completer<void>();

  @override
  void initState() {
    super.initState();
    // 系统开了"减少动效"就不放开场——这里必须读 platformDispatcher 而不是
    // MediaQuery：initState 里拿不到 MediaQuery，而放不放开场决定了
    // controller 的初值，不能等到 build 再补。
    final bool reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    // 开场只属于冷启动那一程：更换服务器（autoResume=false）不放，同一进程里
    // 再次回到这一页也不放（热启动语义，见 AppOpening）。
    final bool playOpening =
        widget.autoResume &&
        !reduceMotion &&
        ref.read(appOpeningProvider).claim();

    _opening = AnimationController(
      vsync: this,
      duration: _openingTotal,
      value: playOpening ? 0 : 1,
    );
    _markFade = CurvedAnimation(
      parent: _opening,
      curve: const Interval(0, _markFadeEnd, curve: Curves.easeOut),
    );
    // 从正中推到锚点：0 = 还在正中，1 = 已就位。easeInOutCubic 起步和收尾
    // 都软，中段快——像被"送"上去，不是弹上去。
    _lift = CurvedAnimation(
      parent: _opening,
      curve: const Interval(_liftStart, _liftEnd, curve: Curves.easeInOutCubic),
    );
    _sloganFade = CurvedAnimation(
      parent: _opening,
      curve: const Interval(_liftEnd, _sloganEnd, curve: Curves.easeOut),
    );

    if (playOpening) {
      unawaited(_opening.forward().whenComplete(_finishOpening));
    } else {
      _finishOpening();
    }

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
          // 接续快过开场时也要把开场走完再跳：半路切页，上一页已就位的字标和
          // 下一页还在动的字标叠着交叉淡入，就是"最后一下出现重影"。
          await _openingDone.future;
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

  void _finishOpening() {
    if (!_openingDone.isCompleted) _openingDone.complete();
  }

  @override
  void dispose() {
    // 页面先走一步（用户返回、路由被替换）时也要放行等待者，否则那个 await
    // 永远悬着。
    _finishOpening();
    _opening.dispose();
    _hintTimer?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    ref.listen(connectionViewModelProvider, (previous, next) {
      if (_addressController.text.isEmpty && next.suggestedAddress.isNotEmpty) {
        _addressController.text = next.suggestedAddress;
      }
    });
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        // 品牌块钉在视口固定高度处，不跟着内容一起被重新居中——若整列 Center，
        // 开场只有品牌时列很矮，发现卡片一出现列变高、居中重算，字标就被顶着
        // 往上挪一截（用户看到的「icon 加文字往上位移了一点」）。
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // 视口 18% 处：字标的最终落点，读作"上三分之一"的开场位。夹在
            // 24~180 之间——矮屏（横屏、开键盘）不把内容顶到折叠线以下，大屏
            // 也不至于飘太高。内容再高也只是可滚，这个位置始终不变。
            final double anchorTop = (constraints.maxHeight * 0.18).clamp(
              24.0,
              180.0,
            );
            // 第 1 幕把字标画在屏幕正中：从锚点往下推这么多，就正好居中。
            // 只动 transform 不动布局——布局槽位从第一帧就在终点，全程零重排，
            // 下方内容不会被推来推去。
            final double liftDistance =
                (constraints.maxHeight - _kWordmarkHeight) / 2 - anchorTop;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(40, anchorTop, 40, 40),
                  // 只横向居中，纵向必须顶对齐：用 Center 的话内容一变高，
                  // 剩余空间的纵向居中又会把品牌块推上去，等于没改。
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: AnimatedBuilder(
                        animation: _opening,
                        builder: (context, _) =>
                            _body(context, palette, liftDistance),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 三幕开场 + 页面本体。所有随开场变化的东西都在这里读 animation 值，外层
  // 靠一个 AnimatedBuilder 驱动重建。
  Widget _body(BuildContext context, HMusicPalette palette, double lift) {
    final state = ref.watch(connectionViewModelProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // 「扫过且一无所获」→ 手动表单自动展开；尚未扫过/扫描中/有结果都收起，
    // 保持构图干净、首帧不闪表单。
    final scanning = state.discovering || !state.discoverCompleted;
    final showForm = _manualExpanded || (!scanning && state.discovered.isEmpty);
    // 第 3 幕之前不渲染任何发现/表单控件；接续中同样只留品牌。
    final bool contentReady = _opening.value >= _contentStart;
    final splash = _booting || state.restoring || !contentReady;
    // 字标落位之后才允许出现接续说明：还在正中/半路时它就在锚点下方冒出来，
    // 两者会叠在一起。
    final bool landed = _lift.value >= 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 第 1 幕：字标在屏幕正中淡入。第 2 幕：位移收回到 0，被"送"到锚点。
        Opacity(
          opacity: _markFade.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _lift.value) * lift),
            // 字标本身含 H（字形双竖笔）+ Music 连读，不另写 "HMusic" 文字。
            child: const Center(child: BrandWordmark(size: _kWordmarkHeight)),
          ),
        ),
        const SizedBox(height: 20),
        // 第 3 幕之一：标语接住落位。副标题是品牌 slogan——一句轻轻的搭话，
        // 不解释产品、不重复品牌名。衬线 + 加宽字距 = 扉页题句的声调。
        Opacity(
          opacity: _sloganFade.value,
          child: Text(
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
        const SizedBox(height: 52),
        // 开场 → 发现/手输的切换走淡入淡出：控件不是「啪」地出现，而是接着
        // 字标落位的那口气显形。
        AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: splash
              ? Center(
                  key: const ValueKey<String>('splash'),
                  // 接续这一句始终占位、只改透明度：门槛到了才淡入，布局不动
                  // ——否则品牌块会在它出现时被顶着往上跳。
                  child: AnimatedOpacity(
                    opacity: (_showRestoreHint && landed) ? 1 : 0,
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
                          style: TextStyle(fontSize: 13, color: palette.muted),
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
                                  textStyle: const TextStyle(fontSize: 12.5),
                                ),
                                child: const Text('手动输入地址'),
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ],
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
