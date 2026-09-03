import 'dart:async';

import 'package:flutter/material.dart';

// 开场一条时间轴，四幕都从同一个 controller 上按 Interval 切。关键节奏：
// **分幕重叠，而且内容要在运动中显形完毕**——字标、标语、发现区在同一
// 个刚体位移里一起上移；标语和发现区都在上移途中追着浮出，落定的那一
// 刻整页已经齐了。若把内容淡入排到落定之后，用户看到的就是「图标标语
// 都齐了 → 停一拍 → 服务器状态突然弹出来」（本版修复的反馈）。
//   0 → 600ms    字标在**屏幕正中**淡入；
//   600 → 850ms  定住不动（这个停顿就是"不着急"的来源）；
//   850 → 1350ms 整体推到锚点（视口 18%），easeInOutCubic 起步收尾都软；
//   850 → 1300ms 标语随上移同步淡入——与字标同组同程，落定前显形完毕；
//   900 → 1350ms 发现区淡入——比标语慢半拍、同样**在落定那一刻完成**，
//                不留给落定后任何「弹出来」的瞬间；
//   1350 → 1600ms 只有页脚注脚收尾；
//   1700ms       整段结束——接续成功也要等到这里才跳页。
class ConnectionOpening {
  ConnectionOpening({required TickerProvider vsync, required bool play})
    : controller = AnimationController(
        vsync: vsync,
        duration: total,
        value: play ? 0 : 1,
      ) {
    markFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0, _markFadeEnd, curve: Curves.easeOut),
    );
    // 从正中推到锚点：0 = 还在正中，1 = 已就位。easeInOutCubic 起步和收尾
    // 都软，中段快——像被"送"上去，不是弹上去。
    lift = CurvedAnimation(
      parent: controller,
      curve: const Interval(_liftStart, _liftEnd, curve: Curves.easeInOutCubic),
    );
    sloganFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(_sloganStart, _sloganEnd, curve: Curves.easeOut),
    );
    contentFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(_contentStart, _contentEnd, curve: Curves.easeOut),
    );
    if (play) {
      unawaited(controller.forward().whenComplete(finish));
    }
  }

  static const Duration total = Duration(milliseconds: 1700);
  static const double _markFadeEnd = 600 / 1700;
  static const double _liftStart = 850 / 1700;
  static const double _liftEnd = 1350 / 1700;
  static const double _sloganStart = 850 / 1700;
  static const double _sloganEnd = 1300 / 1700;
  static const double _contentStart = 900 / 1700;
  static const double _contentEnd = 1350 / 1700;

  final AnimationController controller;

  /// 第 1 幕：字标淡入。
  late final Animation<double> markFade;

  /// 第 2 幕：字标从屏幕正中移到锚点（0 = 正中，1 = 就位）。
  late final Animation<double> lift;

  /// 第 3 幕之一：标语淡入。
  late final Animation<double> sloganFade;

  /// 第 3 幕之二：发现区 / 页脚注脚淡入。
  late final Animation<double> contentFade;

  // 开场走完（或压根没放）后完成，接续跳页要等它。
  final Completer<void> done = Completer<void>();

  // 第 3 幕之前不渲染任何发现/表单控件。
  bool get contentReady => controller.value >= _contentStart;

  // 字标落位之后才允许出现接续说明：还在正中/半路时它就在锚点下方冒出来，
  // 两者会叠在一起。
  bool get landed => lift.value >= 1;

  // 页面先走一步（用户返回、路由被替换）时也要放行等待者，否则那个 await
  // 永远悬着。
  void finish() {
    if (!done.isCompleted) done.complete();
  }

  void dispose() {
    finish();
    controller.dispose();
  }
}
