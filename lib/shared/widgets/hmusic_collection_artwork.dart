import 'package:flutter/material.dart';

// 歌单与曲库分组的占位封面。只使用已有身份和名称，不请求详情或猜测真实专辑图片。
class HMusicCollectionArtwork extends StatelessWidget {
  const HMusicCollectionArtwork({
    required this.identity,
    required this.label,
    this.size = 68,
    this.icon = Icons.library_music_rounded,
    super.key,
  });

  final String identity;
  final String label;
  final double size;
  final IconData icon;

  // 明确的稳定散列；String.hashCode 不保证跨进程一致。
  int get _variant {
    var value = 2166136261;
    for (final unit in identity.codeUnits) {
      value = ((value ^ unit) * 16777619) & 0x7fffffff;
    }
    return value % 4;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final variant = _variant;
    final background = (dark ? _darkTones : _lightTones)[variant];
    final foreground = dark ? const Color(0xFFEAE7E2) : const Color(0xFF44413F);
    final trimmed = label.trim();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: variant.isEven ? -size * 0.4 : size * 0.5,
              top: -size * 0.4,
              child: Container(
                width: size * 1.2,
                height: size * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: size * 0.16,
                    color: foreground.withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(size * 0.24),
                child: FittedBox(
                  child: Text(
                    trimmed.isEmpty ? '♪' : trimmed.characters.first,
                    style: TextStyle(
                      fontFamily: 'NotoSerifSC',
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: size * 0.08,
              bottom: size * 0.08,
              child: Icon(icon, size: size * 0.21, color: foreground),
            ),
          ],
        ),
      ),
    );
  }

  static const _lightTones = <Color>[
    Color(0xFFEAE4DD),
    Color(0xFFE3E7EC),
    Color(0xFFE7E3E9),
    Color(0xFFE7E8E1),
  ];
  static const _darkTones = <Color>[
    Color(0xFF3D3834),
    Color(0xFF343B43),
    Color(0xFF3B3540),
    Color(0xFF393C33),
  ];
}
