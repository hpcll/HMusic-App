import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';
import '../../app/theme/hmusic_radii.dart';
import 'hmusic_cover.dart';

// 全站曲目行原子，对齐 web .track-row：
// flex gap:13 / padding:10 12 / radius-sm / 底部 line-soft 分隔 / 44 封面 + 信息 + 尾部操作。
// 复用方：搜索结果、榜单详情、歌单详情、队列、统计 Top 歌。
// 榜单/队列的排名或序号通过 leading 传入；playCount 等青绿计数通过 subtitleAccent 传入。
class HMusicTrackRow extends StatelessWidget {
  const HMusicTrackRow({
    required this.title,
    this.subtitle,
    this.subtitleAccent,
    this.coverUrl,
    this.leading,
    this.titleTrailing,
    this.actions = const <Widget>[],
    this.onTap,
    this.highlight = false,
    this.showDivider = true,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    super.key,
  });

  final String title;
  final String? subtitle;

  // 追加在副标题后、以品牌青绿显示的文本（如榜单播放次数 " · 123 次"）。
  final String? subtitleAccent;
  final String? coverUrl;

  // 行首插槽：榜单排名（chart-rank）或队列序号（queue-index）。
  final Widget? leading;

  // 标题右侧小徽标（如已下载角标）。
  final Widget? titleTrailing;
  final List<Widget> actions;
  final VoidCallback? onTap;

  // 队列当前曲：标题与序号转青绿（对齐 .queue-current）。
  final bool highlight;
  final bool showDivider;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    final title = Text(
      this.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: highlight ? palette.accent : palette.textStrong,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: palette.lineSoft))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HMusicRadii.small),
          onTap: onTap,
          child: Padding(
            padding: contentPadding,
            child: Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: 13),
                ],
                HMusicCover(url: coverUrl),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(child: title),
                          if (titleTrailing != null) titleTrailing!,
                        ],
                      ),
                      if (subtitle != null || subtitleAccent != null)
                        _Subtitle(text: subtitle, accent: subtitleAccent),
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var i = 0; i < actions.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 6),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({this.text, this.accent});

  final String? text;
  final String? accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = TextStyle(fontSize: 12.5, color: palette.muted);
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          if (text != null) TextSpan(text: text),
          if (accent != null)
            TextSpan(
              text: accent,
              style: TextStyle(color: palette.accent),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}
