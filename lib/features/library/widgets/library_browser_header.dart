import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/models/hmusic_notice.dart';
import '../../../shared/widgets/hmusic_inline_notice.dart';
import '../models/library_view_state.dart';
import '../view_models/library_view_model.dart';
import 'library_search_field.dart';
import 'library_upload_banner.dart';

// 浏览控件随列表一起滚动，根曲库标题由 app 层固定。
class LibraryBrowserHeader extends StatelessWidget {
  const LibraryBrowserHeader({
    required this.state,
    required this.notifier,
    required this.toolbar,
    required this.searchController,
    required this.onQueryChanged,
    this.pickerError,
    super.key,
  });

  final LibraryViewState state;
  final LibraryViewModel notifier;
  final Widget toolbar;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final String? pickerError;

  static const Map<LibrarySection, String> _sections = <LibrarySection, String>{
    LibrarySection.all: '全部',
    LibrarySection.artists: '歌手',
    LibrarySection.albums: '专辑',
    LibrarySection.folders: '文件夹',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        toolbar,
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final entry in _sections.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: state.section == entry.key,
                  onSelected: (_) => unawaited(notifier.setSection(entry.key)),
                ),
            ],
          ),
        ),
        if (!state.showsGroups)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: LibrarySearchField(
              controller: searchController,
              onChanged: onQueryChanged,
            ),
          ),
        if (state.activeGroup != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: notifier.closeGroup,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                // 空组名是合法值（根目录 / 无歌手），给个可读回退。
                label: Text(
                  state.activeGroup!.isEmpty
                      ? (state.section == LibrarySection.folders ? '根目录' : '未知')
                      : state.activeGroup!,
                ),
              ),
            ),
          ),
        if (state.isUploading) LibraryUploadBanner(state: state),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (pickerError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: HMusicInlineNotice(HMusicNotice.error(pickerError!)),
          ),
      ],
    );
  }
}
