import 'package:flutter/material.dart';

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
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: '搜索歌曲或歌手',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: isSearching ? null : onSearch,
          child: Text(isSearching ? '搜索中…' : '搜索'),
        ),
      ],
    );
  }
}
