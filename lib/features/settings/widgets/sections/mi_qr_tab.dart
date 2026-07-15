import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/audio/models/hmusic_playback_state.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../../../shared/widgets/state_dot.dart';
import '../../models/mi_account_state.dart';
import '../../view_models/mi_account_view_model.dart';

// 扫码通道（主推）：idle 引导 → pending 二维码 + 倒计时 → success/expired/failed。
// loginUrl 本地渲染成二维码（qr_flutter），米家 APP 扫码即登录，无需短信。
class MiQrTab extends ConsumerWidget {
  const MiQrTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(miAccountViewModelProvider);
    final notifier = ref.read(miAccountViewModelProvider.notifier);

    return HMusicCard(
      child: Center(
        child: switch (state.qrStage) {
          MiQrStage.idle => _idle(context, notifier),
          MiQrStage.loading => Text(
            '正在生成二维码…',
            style: TextStyle(color: palette.muted),
          ),
          MiQrStage.pending => _pending(context, state, notifier),
          MiQrStage.success => _success(context),
          MiQrStage.expired => _failedOrExpired(context, state, notifier),
          MiQrStage.failed => _failedOrExpired(context, state, notifier),
        },
      ),
    );
  }

  Widget _idle(BuildContext context, MiAccountViewModel notifier) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '用手机「米家」APP 扫码即可登录，无需短信验证码。',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.muted, height: 1.6),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => notifier.startQr(),
          child: const Text('生成二维码'),
        ),
      ],
    );
  }

  Widget _pending(
    BuildContext context,
    MiAccountState state,
    MiAccountViewModel notifier,
  ) {
    final palette = context.palette;
    final url = state.qrSession?.loginUrl ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 白底二维码框，对齐 web .qr-box：210 见方、白底、细边、圆角。
        Container(
          width: 210,
          height: 210,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.line),
          ),
          child: QrImageView(
            data: url,
            version: QrVersions.auto,
            backgroundColor: Colors.white,
            // 二维码用纯黑保证任何主题下扫码对比度，不跟随墨色 token。
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const StateDot(PlaybackStatus.paused),
            const SizedBox(width: 6),
            Text(
              '等待扫码 · 打开「米家」APP 扫一扫',
              style: TextStyle(fontSize: 13.5, color: palette.text),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${state.qrRemain} 后过期',
              style: TextStyle(fontSize: 13, color: palette.muted),
            ),
            TextButton(
              onPressed: () => notifier.startQr(),
              child: const Text('重新生成'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _success(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 青绿表达「刚刚登录成功」这件正在发生的事，符合 accent 铁律。
        Text(
          '登录成功',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: palette.accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '设备已自动刷新，可去「播放设备」选默认音箱。',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.muted, height: 1.6),
        ),
      ],
    );
  }

  Widget _failedOrExpired(
    BuildContext context,
    MiAccountState state,
    MiAccountViewModel notifier,
  ) {
    final palette = context.palette;
    final expired = state.qrStage == MiQrStage.expired;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          expired ? '二维码已过期' : '失败：${state.qrMessage ?? ''}',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.muted, height: 1.6),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => notifier.startQr(),
          child: const Text('重新生成'),
        ),
        if (!expired) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '多次失败可改用「账号密码」通道。',
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
        ],
      ],
    );
  }
}
