import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';

class SettingsMenuRow extends StatelessWidget {
  const SettingsMenuRow({
    required this.icon,
    required this.label,
    required this.summary,
    required this.active,
    required this.badged,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label, summary;
  final bool active, badged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = active ? palette.background : palette.textStrong;
    final muted = active
        ? palette.background.withValues(alpha: .72)
        : palette.muted;
    return Material(
      color: active ? palette.textStrong : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active
                      ? palette.background.withValues(alpha: .1)
                      : palette.panelSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badged) ...[
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
