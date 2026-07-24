import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/hmusic_track.dart';
import '../../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../../../shared/widgets/hmusic_toast.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/search_view_state.dart';
import '../view_models/search_view_model.dart';
import '../widgets/download_quality_sheet.dart';
import '../widgets/search_input.dart';
import '../widgets/search_result_list.dart';

// 搜索页。双路由（与 player/queue 同款分流）：
//   /search 顶级 push → 窄屏全屏覆盖（AppBar 带返回、输入框自动聚焦），
//   入口在榜单页头搜索胶囊——窄屏 dock 不再单设搜索 tab；
//   /search-tab 桌面 shell 分支 → 侧栏常驻 tab，保留原大标题页头形态。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  static const String path = '/search';
  static const String tabPath = '/search-tab';

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchViewModelProvider);
    ref.listen(searchViewModelProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      showHMusicToast(context, notice);
      ref.read(searchViewModelProvider.notifier).clearNotice();
    });
    // maybeOf 兜底：widget 测试直接挂 MaterialApp(home:) 时树里没有 GoRouter。
    final isTab =
        GoRouter.maybeOf(context) != null &&
        GoRouterState.of(context).matchedLocation == SearchPage.tabPath;

    // 桌面 tab 形态：大标题页头 + 输入框（与其余根页同基线）。
    if (isTab) {
      return _resultsList(
        context,
        state,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const ViewTitle('搜索'),
            const SizedBox(height: 16),
            SearchInput(
              controller: _searchController,
              isSearching: state.isSearching,
              onSearch: _search,
            ),
          ],
        ),
        topPadding: 24 + MediaQuery.paddingOf(context).top,
      );
    }

    // 窄屏 push 形态：全屏覆盖 + 返回，输入框自动聚焦即刻可打字。
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: SafeArea(
        child: _resultsList(
          context,
          state,
          header: SearchInput(
            controller: _searchController,
            isSearching: state.isSearching,
            onSearch: _search,
            autofocus: true,
          ),
          topPadding: 4,
        ),
      ),
    );
  }

  Widget _resultsList(
    BuildContext context,
    SearchViewState state, {
    required Widget header,
    required double topPadding,
  }) {
    return ListView(
      // 水平只留 4：结果行自带 12 内边距（hover/ink 出血位），4+12=16 使行内
      // 封面左缘与页头/输入框同压 16 基线；头部块自行补 12。
      // 顶/底累加环境 padding：顶部消融带与悬浮 mini/dock 之下让位，
      // 内容仍可滚到玻璃后面（scroll-under）。
      padding: EdgeInsets.fromLTRB(
        4,
        topPadding,
        4,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              if (state.errorMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        if (state.isSearching) ...<Widget>[
          const SizedBox(height: 36),
          const Center(child: CircularProgressIndicator()),
        ] else if (state.hasSearched && state.tracks.isEmpty) ...<Widget>[
          const SizedBox(height: 36),
          const Center(child: Text('没有找到结果')),
        ] else if (state.tracks.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AdaptiveGlassSurface(
              quality: resolveGlassQuality(context),
              padding: EdgeInsets.zero,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              shadow: false,
              child: SearchResultList(
                tracks: state.tracks,
                playingTrackId: state.playingTrackId,
                onPlay: _play,
                onEnqueue: _enqueue,
                onDownload: _download,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _search() {
    return ref
        .read(searchViewModelProvider.notifier)
        .search(_searchController.text);
  }

  Future<void> _play(HMusicTrack track) {
    return ref.read(searchViewModelProvider.notifier).play(track);
  }

  Future<void> _enqueue(HMusicTrack track) {
    return ref.read(searchViewModelProvider.notifier).enqueue(track);
  }

  Future<void> _download(HMusicTrack track) async {
    final quality = await showDownloadQualitySheet(context, track);
    if (quality == null || !mounted) return; // 取消
    await ref
        .read(searchViewModelProvider.notifier)
        .download(track, quality: quality.isEmpty ? null : quality);
  }
}
