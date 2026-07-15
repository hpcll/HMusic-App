import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/player/widgets/duration_format.dart';

void main() {
  test('formats sub-hour durations as m:ss', () {
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(minutes: 3, seconds: 9)), '3:09');
    expect(formatDuration(const Duration(minutes: 12, seconds: 40)), '12:40');
  });

  test('formats hour-plus durations as h:mm:ss', () {
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  test('clamps negatives to zero', () {
    expect(formatDuration(const Duration(seconds: -5)), '0:00');
  });
}
