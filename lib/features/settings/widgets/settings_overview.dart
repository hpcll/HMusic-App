import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/view_title.dart';

class SettingsOverview extends StatelessWidget {
  const SettingsOverview({
    required this.direct,
    this.localOnly = false,
    super.key,
  });
  final bool direct, localOnly;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const ViewTitle('设置'),
      const SizedBox(height: 10),
      Text(
        localOnly
            ? '纯播放器 · 无需登录，导入 LX 音源即可听歌'
            : direct
            ? '本机直连 · 歌单与听歌记录保存在此设备'
            : '服务器模式 · 管理账号、音源与播放偏好',
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: context.palette.muted,
        ),
      ),
    ],
  );
}
