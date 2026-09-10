import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../models/library_view_state.dart';

// 上传进度条（当前文件名 + 剩余计数）。
class LibraryUploadBanner extends StatelessWidget {
  const LibraryUploadBanner({required this.state, super.key});

  final LibraryViewState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            state.uploadRemaining > 0
                ? '正在上传 ${state.uploadingName}（还剩 ${state.uploadRemaining} 个）'
                : '正在上传 ${state.uploadingName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: context.palette.muted),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: state.uploadProgress <= 0 ? null : state.uploadProgress,
          ),
        ],
      ),
    );
  }
}
