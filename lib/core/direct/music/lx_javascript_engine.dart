import 'dart:ffi';
import 'dart:io';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/javascriptcore/jscore_runtime.dart';
import 'package:flutter_js/quickjs/ffi.dart' show JSRuntime, runtimeOpaques;

const _memoryLimit = 64 * 1024 * 1024;

JavascriptRuntime createLxJavascriptEngine() {
  if (Platform.isIOS || Platform.isMacOS) return JavascriptCoreRuntime();
  if (!Platform.isAndroid) {
    return QuickJsRuntime2(
      timeout: 5000,
      memoryLimit: _memoryLimit,
      hostPromiseRejectionHandler: (_) {},
    );
  }

  // flutter_js 0.8.7 的 Android 库未导出 jsSetMemoryLimit 包装，
  // 但提供 QuickJS 原生函数。创建后、运行用户脚本前设置同样的 64 MB 上限。
  // 构造是同步的，runtimeOpaques 属于当前 isolate，只会新增本次的句柄。
  final existing = runtimeOpaques.keys.toSet();
  final engine = QuickJsRuntime2(
    timeout: 5000,
    hostPromiseRejectionHandler: (_) {},
  );
  try {
    final runtime = runtimeOpaques.keys
        .where((key) => !existing.contains(key))
        .single;
    DynamicLibrary.open('libfastdev_quickjs_runtime.so').lookupFunction<
      Void Function(Pointer<JSRuntime>, Size),
      void Function(Pointer<JSRuntime>, int)
    >('JS_SetMemoryLimit')(runtime, _memoryLimit);
    return engine;
  } catch (_) {
    JavascriptRuntime.channelFunctionsRegistered.remove(
      engine.getEngineInstanceId(),
    );
    engine.dispose();
    rethrow;
  }
}
