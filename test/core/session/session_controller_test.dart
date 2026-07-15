import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/session/session_controller.dart';

void main() {
  late SessionController controller;

  setUp(() => controller = SessionController());
  tearDown(() => controller.dispose());

  test('invalidate notifies once and is idempotent', () {
    var count = 0;
    controller.addListener(() => count++);

    controller.invalidate();
    expect(controller.isInvalid, isTrue);
    expect(count, 1);

    // 重复 401 不再重复通知，避免多请求重复弹窗/导航。
    controller.invalidate();
    expect(controller.isInvalid, isTrue);
    expect(count, 1);
  });

  test('markValid clears the flag and notifies only when it was invalid', () {
    var count = 0;
    controller.addListener(() => count++);

    // 没失效时 markValid 是空操作，不触发通知。
    controller.markValid();
    expect(controller.isInvalid, isFalse);
    expect(count, 0);

    controller.invalidate();
    controller.markValid();
    expect(controller.isInvalid, isFalse);
    expect(count, 2);
  });
}
