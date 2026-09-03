import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/search/data/api_search_repository.dart';
import 'package:hmusic/features/search/data/search_repository.dart';
import 'package:hmusic/features/search/models/search_result.dart';
import 'package:hmusic/features/search/views/search_page.dart';

class _EmptySearchRepository implements SearchRepository {
  const _EmptySearchRepository();

  @override
  Future<SearchResult> search(String query) async => const SearchResult(
    query: '',
    page: 1,
    limit: 20,
    total: 0,
    tracks: <HMusicTrack>[],
  );
}

// 用户反馈：搜索结果页底部的手势条没沉浸。窄屏 push 形态此前把 body 整个包在
// SafeArea 里（bottom 默认 true），列表视口停在手势条上沿——内容滚不到胶囊后面，
// 那条带子成了死白边；更糟的是 SafeArea 会把 bottom padding 从子树 MediaQuery 里
// 摘掉，列表自己算的「32 + 环境 padding」反而归零。底缘必须交给列表自己让位
//（同队列页 bottom: false 的纪律）。
void main() {
  testWidgets('窄屏搜索页：列表铺到屏幕底缘，手势条高度算进列表留白', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.padding = const FakeViewPadding(bottom: 16);
    tester.view.viewPadding = const FakeViewPadding(bottom: 16);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(
            const _EmptySearchRepository(),
          ),
        ],
        child: const MaterialApp(home: SearchPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 视口铺到屏幕底缘（沉浸）。
    expect(tester.getRect(find.byType(ListView)).bottom, 800.0);
    // 让位由列表底部留白承担：32 呼吸 + 手势条 16。
    final padding = tester
        .widget<ListView>(find.byType(ListView))
        .padding
        ?.resolve(TextDirection.ltr);
    expect(padding?.bottom, 48.0);
  });
}
