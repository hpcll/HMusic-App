import 'package:flutter/material.dart';

import '../../../../app/theme/hmusic_palette.dart';

// 表单字段原子，对齐 web .field：标签(12.5 muted-2) + 控件 + 可选 hint(12 muted)。
class SettingsField extends StatelessWidget {
  const SettingsField({
    required this.label,
    required this.child,
    this.hint,
    super.key,
  });

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: palette.mutedStrong),
        ),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            hint!,
            style: TextStyle(fontSize: 12, color: palette.muted, height: 1.6),
          ),
        ],
      ],
    );
  }
}

// 卡内小节标题，对齐 web .card-title：14.5/600/text-strong。
class SettingsCardTitle extends StatelessWidget {
  const SettingsCardTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: context.palette.textStrong,
      ),
    );
  }
}
