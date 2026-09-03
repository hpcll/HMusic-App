import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../data/lan_server_scanner.dart';
import '../models/connection_view_state.dart';
import '../views/connection_opening.dart';
import 'connection_chrome.dart';
import 'connection_content.dart';

// 字标显示高度。第 1 幕要把它摆到屏幕正中，得知道它自己多高。跟着
// BrandWordmark 的标准尺寸走：启动预热解码的就是这个高度（BrandWordmark.warmUp），
// 自己另写一个数字就等于预热落空、开场第 1 幕又变回淡入空盒子。
const double _kWordmarkHeight = BrandWordmark.standardSize;

// 开场三幕 + 页面本体。品牌区与发现/手输区共用同一条时间轴
// （ConnectionOpening），各幕按自己的 Interval 取值，靠一个 AnimatedBuilder
// 驱动重建。
class ConnectionScenes extends StatelessWidget {
  const ConnectionScenes({
    required this.opening,
    required this.viewportHeight,
    required this.restoring,
    required this.restoreHintArmed,
    required this.state,
    required this.addressController,
    required this.addressFocus,
    required this.connectingBase,
    required this.onConnectDiscovered,
    required this.onRescan,
    required this.onSubmitManual,
    super.key,
  });

  final ConnectionOpening opening;

  // 键盘免疫的视口高度（页面层在 Scaffold 之上量好传入）。锚点/上升位移只以
  // 它为基准，绝不用 body constraints——键盘弹起时 body 被 Scaffold 逐帧
  // 收缩，拿它算几何就等于把整列内容跟着键盘往上甩。constraints 只用于
  // 滚动区本身。
  final double viewportHeight;

  // 冷启动接续/恢复中（页面侧的外部状态部分）。是否只显示品牌还要叠加开场
  // 进度（!opening.contentReady），后者在 builder 里逐帧合并——挂在外层 build
  // 会定格在某一帧，开场走完后 splash 收不回去。
  final bool restoring;

  // 「正在连接上次的服务器…」的延迟门槛是否已过；最终可见性还要叠加
  // 「字标已落位」（opening.landed），同样在 builder 里逐帧合并。
  final bool restoreHintArmed;

  final ConnectionViewState state;
  final TextEditingController addressController;

  // 手动表单地址输入框的焦点：页面层靠它驱动注脚让位（见 _ConnectionPageState）。
  final FocusNode addressFocus;

  final Uri? connectingBase;
  final ValueChanged<DiscoveredServer> onConnectDiscovered;
  final VoidCallback onRescan;
  final VoidCallback onSubmitManual;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // 品牌块钉在视口固定高度处，不跟着内容一起被重新居中——若整列 Center，
    // 开场只有品牌时列很矮，发现区一出现列变高、居中重算，字标就被顶着
    // 往上挪一截。
    // 视口 18% 处：字标的最终落点，读作"上三分之一"的开场位。夹在
    // 24~180 之间——矮屏（横屏、开键盘）不把内容顶到折叠线以下，大屏
    // 也不至于飘太高。内容再高也只是可滚，这个位置始终不变。
    final double anchorTop = (viewportHeight * 0.18).clamp(24.0, 180.0);
    // 第 1 幕把字标画在屏幕正中：从锚点往下推这么多，就正好居中。
    // 只动 transform 不动布局——布局槽位从第一帧就在终点，全程零
    // 重排，下方内容不会被推来推去。
    final double liftDistance =
        (viewportHeight - _kWordmarkHeight) / 2 - anchorTop;

    // 整列内容的几何只依赖键盘免疫的 viewportHeight，不碰 body 约束：键盘
    // 动画期间 Scaffold 逐帧收缩 body，凡是依赖当前约束的东西都会每帧重跑
    // 一次（此前这里是 LayoutBuilder + 跟着 body 走的最小高度，键盘每帧
    // 都把整棵列重排一遍——那是用户反馈的"抖动"的最后一份来源）。
    final Widget content = Padding(
      // 底部多留 96：给压在视口底缘的注脚让位，矮屏滚到底
      // 时最后的控件不会贴在注脚文字下面。
      padding: EdgeInsets.fromLTRB(40, anchorTop, 40, 96),
      // 只横向居中，纵向必须顶对齐：用 Center 的话内容一变高，
      // 剩余空间的纵向居中又会把品牌块推上去，等于没改。
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: AnimatedBuilder(
            animation: opening.controller,
            builder: (context, _) {
              // 动画驱动的判断都在这里逐帧求值：开场没走完不渲染
              // 发现/表单控件；字标落位之后才允许出现接续说明（还在
              // 正中/半路时会和说明叠在一起）。
              final bool splash = restoring || !opening.contentReady;
              // 刚体上升：整列（品牌 + 标语 + 发现区）罩在同一个
              // transform 里一起上移。第 1 幕只有字标在正中可见，
              // 其余成员跟组占位但各自透明；上移途中标语、状态区分幕
              // 淡入。因为只有这一个位移，任何两块内容都不会逆行相撞
              // （上一版标语随图标升、状态区在原地淡入，两者必然相交）。
              return Transform.translate(
                offset: Offset(0, (1 - opening.lift.value) * liftDistance),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 第 1 幕：字标在屏幕正中淡入。字标本身含 H（字形
                    // 双竖笔）+ Music 连读，不另写 "HMusic" 文字。
                    Opacity(
                      opacity: opening.markFade.value,
                      child: const Center(
                        child: BrandWordmark(size: _kWordmarkHeight),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 第 3 幕之一：标语随行淡入。副标题是品牌 slogan——
                    // 一句轻轻的搭话，不解释产品、不重复品牌名。衬线 +
                    // 加宽字距 = 扉页题句的声调。
                    Opacity(
                      opacity: opening.sloganFade.value,
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
                    const SizedBox(height: 44),
                    // 发现/手输区随整列一起上移、随 contentFade 显形；
                    // 内部 splash → content 仍走 AnimatedSwitcher 交叉
                    // 淡化：控件不是「啪」地出现，而是接着字标落位的
                    // 那口气显形。
                    Opacity(
                      opacity: opening.contentFade.value,
                      child: AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: splash
                            ? ConnectionRestoreHint(
                                key: const ValueKey<String>('splash'),
                                visible: restoreHintArmed && opening.landed,
                              )
                            : ConnectionContent(
                                key: const ValueKey<String>('content'),
                                state: state,
                                addressController: addressController,
                                addressFocus: addressFocus,
                                connectingBase: connectingBase,
                                onConnectDiscovered: onConnectDiscovered,
                                onRescan: onRescan,
                                onSubmitManual: onSubmitManual,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    // 滚动区最小高度取恒定的 viewportHeight：键盘弹起时视口变矮而内容不变，
    // 多出来的那段正好是让位需要的滚动余量（键盘高度减手势条），且列的约束
    // 一帧都不变——键盘动画期间没有重建、没有重排，只有滚动偏移在动。
    //
    // 整列再包一层 RepaintBoundary：内容自成一层后，让位/滚动的每一帧只是把
    // 这一层按新偏移合成一次，既不用重跑整列的 paint，栅格结果也能被引擎的
    // raster cache 留住（缓存键忽略整数平移）。没有它，每帧都要把品牌图、
    // 衬线标语、发现卡和表单整屏重绘重栅一遍——Impeller 关掉回退 Skia 的
    // 机型上，那就是键盘动画和滚动的掉帧来源。
    return SingleChildScrollView(
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewportHeight),
          child: content,
        ),
      ),
    );
  }
}
