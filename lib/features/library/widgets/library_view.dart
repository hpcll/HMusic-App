import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../../../shared/widgets/back_link.dart';
import '../../../shared/widgets/hmusic_toast.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/library_view_state.dart';
import '../view_models/library_view_model.dart';
import 'library_group_list.dart';
import 'library_track_list.dart';

// NAS 曲库系统视图（歌单页内同页切换，窄屏/桌面同一形态——壳的 dock/侧栏常驻）。
// 页头对齐歌单详情：BackLink + 大标题；分段「全部/歌手/专辑」聚合浏览。
class LibraryView extends ConsumerStatefulWidget {
  const LibraryView({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  static const Map<LibrarySection, String> _sections = <LibrarySection, String>{
    LibrarySection.all: '全部',
    LibrarySection.artists: '歌手',
    LibrarySection.albums: '专辑',
    LibrarySection.folders: '文件夹',
  };

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(libraryViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // 300ms 防抖：库内检索是本地 SQLite like，代价低，但也不必逐字击键请求。
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(ref.read(libraryViewModelProvider.notifier).load(query: value));
    });
  }

  // 选文件并逐个上传。iOS 只能选到「文件」形式的音频（Files App），
  // Apple Music 流媒体库受 DRM 保护导不出——系统限制，非本 App 缺陷。
  Future<void> _pickAndUpload(LibraryViewModel notifier) async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>[
          'mp3',
          'flac',
          'm4a',
          'ogg',
          'wav',
          'aac',
        ],
        allowMultiple: true,
      );
    } on Exception catch (error) {
      // 平台选择器失败（权限/entitlement 等）如实提示，不让异常裸奔成崩溃日志。
      if (mounted) {
        showHMusicToast(context, HMusicNotice.error('无法打开文件选择器：$error'));
      }
      return;
    }
    if (result == null) return;
    final files = <({String path, String name})>[
      for (final file in result.files)
        if (file.path != null) (path: file.path!, name: file.name),
    ];
    await notifier.uploadFiles(files);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryViewModelProvider);
    final notifier = ref.read(libraryViewModelProvider.notifier);
    ref.listen(libraryViewModelProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      showHMusicToast(context, notice);
      notifier.clearNotice();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _header(context, state, notifier),
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
              controller: _searchController,
              onChanged: _onQueryChanged,
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
        Expanded(
          child: state.showsGroups
              ? LibraryGroupList(state: state, notifier: notifier)
              : LibraryTrackList(state: state, notifier: notifier),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    LibraryViewState state,
    LibraryViewModel notifier,
  ) {
    final scanning = state.scan?.isScanning ?? false;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12 + MediaQuery.paddingOf(context).top,
        16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              BackLink(label: '返回', onTap: widget.onBack),
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: state.isUploading
                        ? null
                        : () => _pickAndUpload(notifier),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('上传'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: scanning ? null : notifier.scan,
                    icon: scanning
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.radar_rounded, size: 18),
                    label: Text(scanning ? '扫描中…' : '扫描'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              const ViewTitle('NAS 曲库'),
              const SizedBox(width: 10),
              Text(
                '${state.total} 首',
                style: TextStyle(fontSize: 13, color: context.palette.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
