import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';

class LibrarySearchField extends StatelessWidget {
  const LibrarySearchField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '搜索曲库…',
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: context.palette.muted,
        ),
      ),
    );
  }
}
