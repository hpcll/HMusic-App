import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
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
    final palette = context.palette;
    if (state.groupsLoading && state.groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final Widget list;
    if (state.groups.isEmpty) {
      list = LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Text('曲库里还没有曲目', style: TextStyle(color: palette.muted)),
              ),
            ),
          ],
        ),
      );
    } else {
      final unknownLabel = switch (state.section) {
        LibrarySection.artists => '未知歌手',
        LibrarySection.albums => '未知专辑',
        _ => '根目录',
      };
      list = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: 4,
          bottom: 12 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: state.groups.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final group = state.groups[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            title: Text(
              group.name.isEmpty ? unknownLabel : group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${group.count} 首',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: palette.muted,
                ),
              ],
            ),
            onTap: () => notifier.openGroup(group.name),
          );
        },
      );
    }
    return RefreshIndicator.adaptive(
      onRefresh: notifier.loadGroups,
      child: list,
    );
  }
}
