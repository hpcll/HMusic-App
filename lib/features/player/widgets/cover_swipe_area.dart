import 'package:flutter/material.dart';

// 播放页封面左右滑切歌（docs/05 手势表）：阈值 60px，80ms 轻微跟手。
// 只识别手势并派发命令，不做本地乐观切曲——曲目更替由服务端权威响应驱动。
class CoverSwipeArea extends StatefulWidget {
  const CoverSwipeArea({
    required this.child,
    required this.onNext,
    required this.onPrevious,
    super.key,
  });

  final Widget child;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  State<CoverSwipeArea> createState() => _CoverSwipeAreaState();
}

class _CoverSwipeAreaState extends State<CoverSwipeArea> {
  // docs/05：位移判定阈值 60px。
  static const double _threshold = 60;
  // 轻微跟手：视觉位移带阻尼并封顶，封面不离场、不与切曲 cross-fade 打架。
  static const double _followDamping = 0.35;
  static const double _maxFollow = 32;

  double _dragDx = 0; // 判定用累计位移（不封顶，与视觉位移分账）
  double _follow = 0; // 视觉跟手位移

  void _onUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
    setState(() {
      _follow = (_dragDx * _followDamping).clamp(-_maxFollow, _maxFollow);
    });
  }

  void _onEnd(DragEndDetails details) {
    final dragged = _dragDx;
    _reset();
    if (dragged.abs() < _threshold) return;
    if (dragged < 0) {
      widget.onNext();
    } else {
      widget.onPrevious();
    }
  }

  void _reset() {
    _dragDx = 0;
    setState(() => _follow = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // opaque：确保整块封面（含图片空白区）都可起手势。
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: _reset,
      child: AnimatedContainer(
        // 拖拽中即时跟手；松手 80ms 回弹（docs/05）。
        duration: _follow == 0
            ? const Duration(milliseconds: 80)
            : Duration.zero,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(_follow, 0, 0),
        child: widget.child,
      ),
    );
  }
}
