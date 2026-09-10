import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

// 对齐 UIKit onScrollDown：向下滚收起、向上滚展开；横滑不影响底栏。
class ScrollMinimizeListener extends StatelessWidget {
  const ScrollMinimizeListener({
    required this.onMinimized,
    required this.child,
    super.key,
  });

  final ValueChanged<bool> onMinimized;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0 ||
            notification.metrics.axis != Axis.vertical) {
          return false;
        }
        if (notification is UserScrollNotification) {
          if (notification.direction == ScrollDirection.forward) {
            onMinimized(false);
          } else if (notification.direction == ScrollDirection.reverse &&
              notification.metrics.maxScrollExtent >
                  notification.metrics.minScrollExtent) {
            onMinimized(true);
          }
        } else if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          // 半像素容差吸收 ballistic 归位的浮点残差；不可滚动页面的橡皮筋
          // 回弹结束也落在这里，松手即恢复展开。
          if (notification.metrics.extentBefore < 0.5) onMinimized(false);
        }
        return false;
      },
      child: child,
    );
  }
}
