import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/playback/playback_mode.dart';
import '../../core/playback/playback_mode_controller.dart';
import '../../features/library/view_models/library_view_model.dart';
import '../../features/library/widgets/library_view.dart';
import '../../features/playlists/view_models/playlists_view_model.dart';
import '../../features/playlists/views/playlists_page.dart';
import '../../shared/widgets/hmusic_icon_button.dart';
import '../../shared/widgets/view_title.dart';
import '../theme/hmusic_palette.dart';

enum _LibraryTab { playlists, nas }

// app 层组合两类内容；业务仍分别由歌单与 NAS feature 持有。
class MusicLibraryPage extends ConsumerStatefulWidget {
  const MusicLibraryPage({super.key});

  static const String path = '/playlists';

  @override
  ConsumerState<MusicLibraryPage> createState() => _MusicLibraryPageState();
}

class _MusicLibraryPageState extends ConsumerState<MusicLibraryPage> {
  _LibraryTab _tab = _LibraryTab.playlists;
  bool _nasVisited = false;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(playbackModeProvider) == PlaybackMode.direct) {
      return const PlaylistsPage();
    }
    final inPlaylist = _tab == _LibraryTab.playlists;
    final detailOpen = ref.watch(
      playlistsViewModelProvider.select((state) => state.detail != null),
    );
    final groupOpen = ref.watch(
      libraryViewModelProvider.select((state) => state.activeGroup != null),
    );
    final inDetail = inPlaylist ? detailOpen : groupOpen;
    return PopScope(
      canPop: !inDetail,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !inDetail) return;
        if (inPlaylist) {
          unawaited(ref.read(playlistsViewModelProvider.notifier).backToList());
        } else {
          ref.read(libraryViewModelProvider.notifier).closeGroup();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!(inPlaylist && detailOpen)) _header(context),
          Expanded(
            // 两个分段保留自己的滚动位置、搜索输入及进行中的上传；首次进入才加载 NAS。
            child: IndexedStack(
              index: _tab.index,
              children: <Widget>[
                const PlaylistsPage(embedded: true),
                if (_nasVisited)
                  const LibraryView(embedded: true)
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16 + MediaQuery.paddingOf(context).top,
        16,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: ViewTitle('曲库')),
              HMusicIconButton(
                icon: Icons.bar_chart_rounded,
                tooltip: '听歌统计',
                onPressed: () => context.go('/stats'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<_LibraryTab>(
            style: _segmentStyle(context),
            segments: const <ButtonSegment<_LibraryTab>>[
              ButtonSegment(value: _LibraryTab.playlists, label: Text('歌单')),
              ButtonSegment(value: _LibraryTab.nas, label: Text('NAS 歌曲')),
            ],
            selected: <_LibraryTab>{_tab},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => setState(() {
              FocusScope.of(context).unfocus();
              _tab = selection.single;
              if (_tab == _LibraryTab.nas) _nasVisited = true;
            }),
          ),
        ],
      ),
    );
  }

  ButtonStyle _segmentStyle(BuildContext context) {
    final palette = context.palette;
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? palette.textStrong
            : palette.panelSecondary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? palette.background
            : palette.textStrong;
      }),
      side: WidgetStatePropertyAll(BorderSide(color: palette.line)),
    );
  }
}
