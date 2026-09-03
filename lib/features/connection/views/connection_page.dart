import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/startup/app_opening.dart';
import '../../auth/views/auth_page.dart';
import '../data/lan_server_scanner.dart';
import '../view_models/connection_view_model.dart';
import '../widgets/connection_chrome.dart';
import '../widgets/connection_scenes.dart';
import 'connection_opening.dart';

// 连接页信息层级（题句式纸面）：品牌区 → 发现区（自动发现是主路径，点选即连；
// 扫描中只是轻量状态行，卡片留给真实内容）→ 手动表单（次要路径，默认折叠成
// ghost 链接）→ 页脚注脚（hairline + 衬线小字，页面因此「落地」）。
// 页面只管状态生命周期与路由；布局几何与三幕开场在 ConnectionScenes，
// 时间轴在 ConnectionOpening。
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
    with TickerProviderStateMixin {
  final TextEditingController _addressController = TextEditingController();

  // 手动表单地址输入框的焦点：注脚的让位信号。不用 viewInsets 做依赖——
  // body 里被 Scaffold 摘掉读不到；在页面层读则要登记 viewInsets 依赖，
  // 键盘动画期间 insets 逐帧上报，等于整页每帧重建。焦点只在点击瞬间变化。
  final FocusNode _addressFocus = FocusNode();

  // 键盘让位不在这一层做：Scaffold 随键盘收缩 body（resizeToAvoidBottomInset
  // 默认开），Android 端引擎已把 IME 的每一帧位置同步成 viewInsets，滚动区
  // 逐帧变矮；TextField 自带的 showOnScreen 用 scrollPadding 把输入框连同
  // 下方的连接按钮一起抬到键盘上方（见 ServerAddressForm）。早期版本在
  // 这里手写过垫层 + 逐帧滚动 + 原生 WindowInsetsAnimation 桥，全是为了绕开
  // 当时内容子树随 body 逐帧重建的掉帧；重建根因修掉后这些机制只剩副作用。

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

  late final ConnectionOpening _opening;

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
    _opening = ConnectionOpening(vsync: this, play: playOpening);

    _addressFocus.addListener(_onAddressFocusChanged);
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
          await _opening.done.future;
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

  @override
  void dispose() {
    _opening.dispose();
    _hintTimer?.cancel();
    _addressFocus.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // 注脚随焦点显隐（见 build 里的 ConnectionFootnote）。
  void _onAddressFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // 键盘免疫的视口高度：在 Scaffold 之上量，键盘开合不改变它。注意用
    // viewPadding 而不是 padding——键盘弹出时 padding.bottom 会被清零
    // （insets 蚕食 padding），viewPadding 是硬件遮挡，恒定不变；拿 padding
    // 算几何，键盘升起那几帧锚点会被推着走。注脚的让位信号另见 _addressFocus。
    final double viewportHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewPaddingOf(context).vertical;
    final state = ref.watch(connectionViewModelProvider);
    ref.listen(connectionViewModelProvider, (previous, next) {
      if (_addressController.text.isEmpty && next.suggestedAddress.isNotEmpty) {
        _addressController.text = next.suggestedAddress;
      }
    });
    return Scaffold(
      backgroundColor: palette.background,
      // 底部走 SafeArea 的 padding：手势条在场时让开它，键盘升起后系统把
      // padding.bottom 清零，滚动区一直贴到键盘上缘——用恒定的 viewPadding
      // 会在键盘上方留一条手势条高的空白。
      body: SafeArea(
        // 注脚压在底缘、不占布局高度：开场几何（正中/18% 锚点）始终以完整
        // 视口为基准，不会被注脚挤偏；矮屏滚到底时注脚叠在内容之上也无伤
        // （只是 hairline + 一行小字），键盘弹起时注脚自身让位。
        child: Stack(
          children: <Widget>[
            ConnectionScenes(
              opening: _opening,
              viewportHeight: viewportHeight,
              restoring: _booting || state.restoring,
              restoreHintArmed: _showRestoreHint,
              state: state,
              addressController: _addressController,
              addressFocus: _addressFocus,
              connectingBase: state.isConnecting ? _connectingBase : null,
              onConnectDiscovered: _connectDiscovered,
              onRescan: () =>
                  ref.read(connectionViewModelProvider.notifier).discover(),
              onSubmitManual: _connect,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ConnectionFootnote(
                opacity: _opening.contentFade,
                hidden: _addressFocus.hasFocus,
              ),
            ),
          ],
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
