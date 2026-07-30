import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/hmusic_toast.dart';
import '../view_models/charts_view_model.dart';
import '../widgets/chart_detail.dart';
import '../widgets/charts_wall.dart';

// 榜单页（应用首页）：卡片墙 ↔ 详情同页切换，对齐 web charts.js。
// 外壳提供 Scaffold/mini/导航，本页只渲染内容。
class ChartsPage extends ConsumerStatefulWidget {
  const ChartsPage({super.key});

  static const String path = '/charts';

  @override
  ConsumerState<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends ConsumerState<ChartsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(chartsViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chartsViewModelProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      showHMusicToast(context, notice);
      ref.read(chartsViewModelProvider.notifier).clearNotice();
    });
    final isWall = ref.watch(chartsViewModelProvider.select((s) => s.isWall));
    // 详情是页内二级态：系统返回先收回卡片墙，而不是冒泡到壳层退出/切主页
    //（拦截期间 Android 14+ 预测性返回动画停用，代价可接受）。
    return PopScope(
      canPop: isWall,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(chartsViewModelProvider.notifier).back();
      },
      // 墙 ↔ 详情原为硬切换（同帧跳变，观感像坏了）；改 220ms 淡入 + 1.5% 上浮
      //（同 mini player 显隐档），入出双向共用一条曲线；减动效直切。
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: isWall ? const ChartsWall() : const ChartDetailView(),
      ),
    );
  }
}
