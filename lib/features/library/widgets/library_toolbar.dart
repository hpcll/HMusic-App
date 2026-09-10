import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/back_link.dart';
import '../../../shared/widgets/view_title.dart';
import '../models/library_view_state.dart';

// 工具与库内浏览分开编排，嵌入根页时不重复标题或返回栏。
class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    required this.state,
    required this.embedded,
    required this.onUpload,
    required this.onScan,
    this.onBack,
    super.key,
  });

  final LibraryViewState state;
  final bool embedded;
  final VoidCallback onUpload;
  final VoidCallback onScan;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scanning = state.scan?.isScanning ?? false;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        embedded ? 0 : 12 + MediaQuery.paddingOf(context).top,
        16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!embedded) ...<Widget>[
            if (onBack != null) BackLink(label: '返回', onTap: onBack!),
            const ViewTitle('NAS 曲库'),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: state.isUploading ? null : onUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('上传'),
              ),
              OutlinedButton.icon(
                onPressed: scanning ? null : onScan,
                icon: scanning
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.radar_rounded, size: 18),
                label: Text(scanning ? '扫描中…' : '扫描'),
              ),
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
