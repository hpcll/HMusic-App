import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(notice)));
      ref.read(chartsViewModelProvider.notifier).clearNotice();
    });
    final isWall = ref.watch(chartsViewModelProvider.select((s) => s.isWall));
    return isWall ? const ChartsWall() : const ChartDetailView();
  }
}
