// 毫秒时长格式化为 m:ss / h:mm:ss，供播放页与进度条复用。
String formatDuration(Duration duration) {
  final total = duration.isNegative ? Duration.zero : duration;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);
  final mm = hours > 0
      ? minutes.toString().padLeft(2, '0')
      : minutes.toString();
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}
