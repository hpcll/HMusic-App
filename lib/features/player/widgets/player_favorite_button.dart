import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../../../shared/widgets/hmusic_toast.dart';
import '../view_models/favorites_view_model.dart';

// 收藏态玫红对齐 web .ctrl-fav.active(#e0245e)；青绿纪律只属于「正在播放」，
// 收藏语义单独用此色，明暗主题同值（web 亦不分）。
const Color _kFavoriteActive = Color(0xFFE0245E);

// 播放控制行的「喜欢」按钮：空心/实心心形 = 是否在「我喜欢的音乐」歌单。
// 挂载时拉一次收藏快照；切歌不重拉（快照按曲目键判重即可）。
class PlayerFavoriteButton extends ConsumerStatefulWidget {
  const PlayerFavoriteButton({required this.track, super.key});

  final HMusicTrack? track;

  @override
  ConsumerState<PlayerFavoriteButton> createState() =>
      _PlayerFavoriteButtonState();
}

class _PlayerFavoriteButtonState extends ConsumerState<PlayerFavoriteButton> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(favoritesViewModelProvider.notifier).load(),
      ),
    );
  }

  Future<void> _toggle(HMusicTrack track) async {
    try {
      await ref.read(favoritesViewModelProvider.notifier).toggle(track);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      showHMusicToast(context, HMusicNotice.error(failure.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesViewModelProvider);
    final track = widget.track;
    final active =
        ref.read(favoritesViewModelProvider.notifier).itemFor(track) != null;
    return IconButton(
      tooltip: active ? '从「我喜欢的音乐」移除' : '加入「我喜欢的音乐」',
      icon: Icon(
        active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: active ? _kFavoriteActive : null,
      ),
      onPressed: track == null || favorites.busy
          ? null
          : () => unawaited(_toggle(track)),
    );
  }
}
