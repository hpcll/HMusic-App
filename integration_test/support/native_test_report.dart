import 'dart:convert';
import 'dart:io';

/// 原生 AOT 测试可从 App 临时目录取回结果，不依赖 VM/mDNS 或系统日志转发。
class NativeTestReport {
  const NativeTestReport(this.name);
  final String name;

  static String get outputDirectory {
    const configured = String.fromEnvironment('HMUSIC_TEST_OUTPUT_DIR');
    return configured.isEmpty ? Directory.systemTemp.path : configured;
  }

  Future<void> write(String status, [Object? details]) async {
    await Directory(outputDirectory).create(recursive: true);
    await File('$outputDirectory/hmusic-$name-result.json').writeAsString(
      jsonEncode({
        'status': status,
        'time': DateTime.now().toUtc().toIso8601String(),
        if (details != null) 'details': details,
      }),
      flush: true,
    );
  }
}
