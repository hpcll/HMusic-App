import 'dart:typed_data';

import 'package:flutter/material.dart';

class DirectCaptchaImage extends StatelessWidget {
  const DirectCaptchaImage({
    super.key,
    required this.bytes,
    required this.loading,
  });

  final Uint8List? bytes;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final image = bytes;
    return Semantics(
      label: '小米图片验证码',
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : image == null
            ? const Center(child: Text('验证码未加载，请点击下方重试'))
            : Image.memory(
                image,
                height: 64,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('验证码图片无法显示，请换一张重试')),
              ),
      ),
    );
  }
}
