import 'package:flutter/material.dart';

// 歌单创建/导入弹窗，对齐 web Modal：标题 + 输入 + 取消/确认。
// 返回用户确认的文本；取消返回 null。import 变体用多行输入 + 提示语。
class PlaylistInputDialog extends StatefulWidget {
  const PlaylistInputDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    this.helper,
    this.multiline = false,
    super.key,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String? helper;
  final bool multiline;

  @override
  State<PlaylistInputDialog> createState() => _PlaylistInputDialogState();
}

class _PlaylistInputDialogState extends State<PlaylistInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.helper != null) ...<Widget>[
            Text(
              widget.helper!,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: widget.multiline ? 3 : 1,
            maxLines: widget.multiline ? 5 : 1,
            decoration: InputDecoration(hintText: widget.hint),
            onSubmitted: widget.multiline
                ? null
                : (_) => canConfirm ? _confirm(context) : null,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: canConfirm ? () => _confirm(context) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  void _confirm(BuildContext context) {
    Navigator.of(context).pop(_controller.text.trim());
  }
}
