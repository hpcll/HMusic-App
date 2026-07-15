import 'package:flutter/material.dart';

import '../../../core/models/hmusic_track.dart';

class PlayerCover extends StatelessWidget {
  const PlayerCover({required this.track, super.key});

  final HMusicTrack? track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = track?.coverUrl;
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: url == null
              ? _fallback(scheme)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback(scheme),
                ),
        ),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: 72, color: scheme.onSurfaceVariant),
    );
  }
}
