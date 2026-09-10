import 'package:flutter/material.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../settings_form_card.dart';
import 'settings_field.dart';

class DirectSpeakerOptions extends StatelessWidget {
  const DirectSpeakerOptions({
    required this.qqDirect,
    required this.onQqDirectChanged,
    required this.host,
    required this.extraModels,
    required this.enabled,
    super.key,
  });
  final bool qqDirect, enabled;
  final ValueChanged<bool> onQqDirectChanged;
  final TextEditingController host, extraModels;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SettingsFormCard(
        title: '音箱播放',
        description: '选择播放设备后，歌曲将发送到对应的小爱音箱。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('QQ 音频直接连接'),
              subtitle: const Text('直接由音箱读取 QQ 音频，遇到无声时请关闭。'),
              value: qqDirect,
              onChanged: enabled ? onQqDirectChanged : null,
            ),
            const SizedBox(height: 12),
            Text(
              '代理播放时，手机与音箱需在同一局域网。直连音箱连播需要 App 保持前台；长期无人值守播放建议使用服务器模式。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: context.palette.muted,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      HMusicCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 14),
          shape: const Border(),
          collapsedShape: const Border(),
          title: const Text('高级连接选项'),
          subtitle: const Text('局域网地址与音箱兼容型号'),
          initiallyExpanded:
              host.text.isNotEmpty || extraModels.text.isNotEmpty,
          children: [
            const SizedBox(height: 8),
            SettingsField(
              label: '本机局域网地址（可选）',
              hint: '通常留空自动选择；多网卡或无法连接时填写音箱可访问的 IPv4 地址。',
              child: TextField(
                controller: host,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autocorrect: false,
                decoration: const InputDecoration(hintText: '例如 192.168.1.10'),
              ),
            ),
            const SizedBox(height: 20),
            SettingsField(
              label: '补充音箱兼容型号',
              hint: '常见型号已适配。其他型号连接后无声时，可在此补充，多个型号用逗号分隔。',
              child: TextField(
                controller: extraModels,
                enabled: enabled,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: '例如 L20A, X20C'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
