import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/library_view_state.dart';
import '../view_models/library_view_model.dart';
import 'library_browser_header.dart';
import 'library_group_list.dart';
import 'library_toolbar.dart';
import 'library_track_list.dart';

// 可嵌入曲库根页的 NAS 内容，分组/搜索/分页仍由现有 VM 持有。
class LibraryView extends ConsumerStatefulWidget {
  const LibraryView({this.onBack, this.embedded = false, super.key});

  final VoidCallback? onBack;
  final bool embedded;

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  // 文件选择器打不开（权限/entitlement）这类 VM 管不到的失败，就地内联显示。
  String? _pickerError;

  @override
  void initState() {
    super.initState();
    final state = ref.read(libraryViewModelProvider);
    _searchController.text = state.query;
    if (state.status == LibraryStatus.idle) {
      unawaited(
        Future<void>.microtask(
          () => ref.read(libraryViewModelProvider.notifier).load(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
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
      if (mounted) setState(() => _pickerError = '无法打开文件选择器：$error');
      return;
    }
    if (result == null) return;
    if (mounted) setState(() => _pickerError = null);
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
    ref.listen(
      libraryViewModelProvider.select(
        (state) => (state.section, state.activeGroup),
      ),
      (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }),
    );

    return RefreshIndicator.adaptive(
      onRefresh: () =>
          state.showsGroups ? notifier.loadGroups() : notifier.load(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical &&
              !ref.read(libraryViewModelProvider).showsGroups &&
              notification.metrics.extentAfter < 400) {
            unawaited(notifier.loadMore());
          }
          return false;
        },
        // 工具、检索与结果共同滚动，短视口也能将操作滚到常驻播放区上方。
        child: CustomScrollView(
          key: const PageStorageKey<String>('nas-browser'),
          controller: _scrollController,
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: LibraryBrowserHeader(
                state: state,
                notifier: notifier,
                searchController: _searchController,
                onQueryChanged: _onQueryChanged,
                pickerError: _pickerError,
                toolbar: LibraryToolbar(
                  state: state,
                  embedded: widget.embedded,
                  onBack: widget.onBack,
                  onUpload: () => _pickAndUpload(notifier),
                  onScan: notifier.scan,
                ),
              ),
            ),
            if (state.showsGroups)
              LibraryGroupList(state: state, notifier: notifier)
            else
              LibraryTrackList(state: state, notifier: notifier),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 12 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
