import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';

// 冷启动接续提示（AnimatedSwitcher 的 splash 分支）。接续说明始终占位、只改
// 透明度：门槛到了才淡入，布局不动——否则品牌块会在它出现时被顶着往上跳。
class ConnectionRestoreHint extends StatelessWidget {
  const ConnectionRestoreHint({required this.visible, super.key});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Center(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
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
    );
  }
}

// 页脚注脚：hairline + 衬线小字，给页面一个落点，不再「悬在半空」。输入框
// 聚焦时让位（hidden=true 直接不渲染），避免和手动表单挤在一起。
// 信号由页面层传（地址输入框的 FocusNode）：不能在内部读 viewInsets——
// Scaffold 收缩 body 时会把 viewInsets 从 body 子树的 MediaQuery 里摘掉，
// 内部读恒为 0；也不能在页面层登记 viewInsets 依赖——Android 键盘动画期间
// insets 逐帧上报，整页每帧重建，键盘动画会抖。焦点事件只在点击瞬间发生。
//
// 它压在滚动视图之上，所以整块必须对手势透明：hairline 是 ColoredBox（默认
// HitTestBehavior.opaque），文字是 RenderParagraph（hitTestSelf 恒为 true），
// 不挡的话从注脚这一带往上拖是滑不动页面的。
class ConnectionFootnote extends StatelessWidget {
  const ConnectionFootnote({
    required this.opacity,
    required this.hidden,
    super.key,
  });

  final Animation<double> opacity;

  // 键盘弹起时由页面层通知隐藏。
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;
    return IgnorePointer(
      child: FadeTransition(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 4, 40, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(height: 1, color: palette.lineSoft),
              const SizedBox(height: 14),
              Text(
                '你的音乐，在你的服务器上',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoSerifSC',
                  fontSize: 11.5,
                  letterSpacing: 1.5,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
