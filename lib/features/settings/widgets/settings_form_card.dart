import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';

class SettingsFormCard extends StatelessWidget {
  const SettingsFormCard({
    required this.title,
    required this.child,
    this.description,
    super.key,
  });
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) => HMusicCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.palette.textStrong,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.palette.muted,
            ),
          ),
        ],
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}
