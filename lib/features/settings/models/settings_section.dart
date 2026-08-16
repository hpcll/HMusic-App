// 设置中心的子页（对齐 web SECTION_COMPONENTS 的 key 集合；about 为 App 独有）。
enum SettingsSection {
  mi('小米账号'),
  devices('播放设备'),
  sources('LX 音源插件'),
  downloads('本地下载'),
  tracks('手工曲目'),
  config('运行配置'),
  diag('链路诊断'),
  security('修改密码'),
  about('关于与更新');

  const SettingsSection(this.label);

  final String label;
}
