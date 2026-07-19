import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';

// 搜索输入：灰底胶囊 + 放大镜前缀，对齐 Apple Music 搜索框形态——无边框、
// 无独立搜索按钮，键盘搜索键/Enter 提交（docs/05「Enter 触发主操作」）。
// 主题层表单已统一为灰底无描边圆角款；搜索框在此基础上保持全胶囊半径，
// 是表单族里最圆的一档。搜索中的进度反馈由结果区 spinner 承担，这里只挡
// 重复提交；焦点可见性由光标承担，不加 focus 描边。
class SearchInput extends StatelessWidget {
  const SearchInput({
    required this.controller,
    required this.isSearching,
    required this.onSearch,
    super.key,
  });

  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const capsule = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '搜索歌曲或歌手',
        prefixIcon: Icon(Icons.search_rounded, color: palette.muted),
        filled: true,
        fillColor: palette.panelSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: capsule,
        enabledBorder: capsule,
        focusedBorder: capsule,
      ),
      onSubmitted: (_) {
        if (!isSearching) onSearch();
      },
    );
  }
}
