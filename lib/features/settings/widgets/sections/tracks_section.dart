import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../../../shared/widgets/hmusic_icon_button.dart';
import '../../view_models/tracks_view_model.dart';
import 'settings_field.dart';

// 手工曲目子页：列表 + 添加表单（标题/歌手/URL）。对齐 web TracksSection。
class TracksSectionView extends ConsumerStatefulWidget {
  const TracksSectionView({super.key});

  @override
  ConsumerState<TracksSectionView> createState() => _TracksSectionViewState();
}

class _TracksSectionViewState extends ConsumerState<TracksSectionView> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _artist = TextEditingController();
  final TextEditingController _url = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(tracksViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final ok = await ref
        .read(tracksViewModelProvider.notifier)
        .add(title: _title.text, artist: _artist.text, url: _url.text);
    if (ok && mounted) {
      _title.clear();
      _artist.clear();
      _url.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(tracksViewModelProvider);
    final notifier = ref.read(tracksViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!state.loaded)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text('加载中…', style: TextStyle(color: palette.muted)),
            ),
          )
        else if (state.tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text('还没有手工曲目', style: TextStyle(color: palette.muted)),
            ),
          )
        else ...<Widget>[
          HMusicCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < state.tracks.length; i++)
                  _TrackRow(
                    title: state.tracks[i].title,
                    subtitle: state.tracks[i].artist ?? state.tracks[i].url,
                    showDivider: i != state.tracks.length - 1,
                    onRemove: state.busy ? null : () => notifier.removeAt(i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        HMusicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SettingsCardTitle('添加曲目'),
              const SizedBox(height: 12),
              SettingsField(
                label: '标题',
                child: TextField(controller: _title),
              ),
              const SizedBox(height: 12),
              SettingsField(
                label: '歌手（可选）',
                child: TextField(controller: _artist),
              ),
              const SizedBox(height: 12),
              SettingsField(
                label: '音频 URL',
                child: TextField(
                  controller: _url,
                  decoration: const InputDecoration(
                    hintText: 'https://example.com/song.mp3',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: state.busy ? null : () => unawaited(_add()),
                  child: const Text('添加曲目'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 手工曲目行：无封面（不是搜索结果），标题 + 歌手/URL + 删除键。
class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.title,
    required this.subtitle,
    required this.showDivider,
    this.onRemove,
  });

  final String title;
  final String subtitle;
  final bool showDivider;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: palette.lineSoft))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.textStrong,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: palette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HMusicIconButton(
              icon: Icons.close_rounded,
              tooltip: '删除',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
