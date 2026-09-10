import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/search/widgets/download_quality_sheet.dart';

void main() {
  testWidgets('小屏二倍字号的下载音质面板可滚到末项并返回选择', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);
    String? quality;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                quality = await showDownloadQualitySheet(
                  context,
                  const HMusicTrack(
                    id: 'wy:long',
                    source: 'wy',
                    sourceTrackId: 'long',
                    title: '一个很长很长的歌曲名称用来检查下载面板',
                    artist: '歌手',
                  ),
                );
              },
              child: const Text('下载'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('下载'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('保存到已连接的服务器'), findsOneWidget);
    await tester.ensureVisible(find.text('Hi-Res'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hi-Res'));
    await tester.pumpAndSettle();
    expect(quality, 'hires');
    expect(tester.takeException(), isNull);
  });
}
