import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/hmusic_track.dart';
import '../../../shared/widgets/view_title.dart';
import '../view_models/search_view_model.dart';
import '../widgets/search_input.dart';
import '../widgets/search_result_list.dart';

// 搜索页（底栏 tab 分支内容）：外壳提供 Scaffold/mini/导航，本页只渲染内容。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  static const String path = '/search';

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
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(notice)));
      ref.read(searchViewModelProvider.notifier).clearNotice();
    });
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: <Widget>[
        const ViewTitle('搜索'),
        const SizedBox(height: 16),
        SearchInput(
          controller: _searchController,
          isSearching: state.isSearching,
          onSearch: _search,
        ),
        if (state.errorMessage != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            state.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.isSearching) ...<Widget>[
          const SizedBox(height: 36),
          const Center(child: CircularProgressIndicator()),
        ] else if (state.hasSearched && state.tracks.isEmpty) ...<Widget>[
          const SizedBox(height: 36),
          const Center(child: Text('没有找到结果')),
        ] else if (state.tracks.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          SearchResultList(
            tracks: state.tracks,
            playingTrackId: state.playingTrackId,
            onPlay: _play,
            onEnqueue: _enqueue,
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
}
