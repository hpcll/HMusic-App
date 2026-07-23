import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/models/hmusic_track.dart';

// 下载音质选择 sheet（对齐 web openDownloadPicker）：从搜索行下载钮唤起，
// 点选音质即发起下载。曲目自带 qualities 就用它，否则给标准四档兜底。
// 「服务器默认」= 不传 quality，交服务端按运行配置的 defaultQuality 下。
const List<String> _standardQualities = <String>[
  '128k',
  '320k',
  'flac',
  'hires',
];

const Map<String, String> _qualityLabels = <String, String>{
  '128k': '标准 128k',
  '320k': '高品 320k',
  'flac': '无损 FLAC',
  'hires': 'Hi-Res',
};

// 返回用户选中的音质；选「服务器默认」返回空字符串；取消返回 null。
Future<String?> showDownloadQualitySheet(
  BuildContext context,
  HMusicTrack track,
) {
  final qualities = track.qualities.isNotEmpty
      ? track.qualities
      : _standardQualities;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final palette = context.palette;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
              child: Text(
                '下载到服务器',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: palette.muted),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              visualDensity: VisualDensity.compact,
              title: const Text('服务器默认音质'),
              onTap: () => Navigator.of(context).pop(''),
            ),
            for (final quality in qualities)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                visualDensity: VisualDensity.compact,
                title: Text(_qualityLabels[quality] ?? quality),
                onTap: () => Navigator.of(context).pop(quality),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
