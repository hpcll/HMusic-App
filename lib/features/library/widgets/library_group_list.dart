import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_collection_artwork.dart';
import '../models/library_view_state.dart';
import '../view_models/library_view_model.dart';

// 歌手/专辑聚合列表：名称 + 曲目数，点击进组内曲目。空名归「未知」。
class LibraryGroupList extends StatelessWidget {
  const LibraryGroupList({
    required this.state,
    required this.notifier,
    super.key,
  });

  final LibraryViewState state;
  final LibraryViewModel notifier;

  @override
  Widget build(BuildContext context) {
    if (state.groups.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Center(
            child: state.groupsLoading
                ? const CircularProgressIndicator()
                : Text(
                    '曲库里还没有曲目',
                    style: TextStyle(color: context.palette.muted),
                  ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.only(top: 4),
      sliver: SliverList.separated(
        itemCount: state.groups.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: _groupTile,
      ),
    );
  }

  Widget _groupTile(BuildContext context, int index) {
    final group = state.groups[index];
    final label = group.name.isEmpty
        ? switch (state.section) {
            LibrarySection.artists => '未知歌手',
            LibrarySection.albums => '未知专辑',
            _ => '根目录',
          }
        : group.name;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: HMusicCollectionArtwork(
        identity: '${state.section.name}:${group.name}',
        label: label,
        size: 44,
        icon: switch (state.section) {
          LibrarySection.artists => Icons.person_rounded,
          LibrarySection.albums => Icons.album_rounded,
          _ => Icons.folder_rounded,
        },
      ),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${group.count} 首',
            style: TextStyle(fontSize: 12.5, color: context.palette.muted),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.palette.muted,
          ),
        ],
      ),
      onTap: () => notifier.openGroup(group.name),
    );
  }
}
