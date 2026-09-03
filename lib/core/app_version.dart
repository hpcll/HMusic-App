// App 自身版本号，「关于与更新」页展示与新版比对用。
// 与 pubspec.yaml 的 version 保持一致（test/core/app_version_test.dart 机械校验）。
// pubspec 里 `+N` 是构建号（Android versionCode / iOS CFBundleVersion），每次发版递增，
// 不属于版本号本身，这里不带。
const String kAppVersion = '0.1.7';

// App 发布仓库（GitHub Releases 检查更新指向这里）。
const String kAppReleaseRepo = 'hpcll/HMusic-App';

// Gitee 镜像仓库（大陆免翻墙的 app-config.json 主源；由 sync-gitee.yml 同步）。
const String kAppGiteeRepo = 'hpc1997/HMusic-App';

// 网盘下载入口（夸克，/HMusic 整个目录，永久有效、无提取码）。
//
// 为什么要硬编码一份：检查更新能走 Gitee 镜像绕开 GitHub，但下载地址指的是
// github.com——没梯子的用户「查得到、下不来」。这条链接是那种情况下的退路，
// 而恰恰在网络最差时连 app-config.json 都可能拉不到，所以内置一份兜底。
// app-config.json 里的 netdiskUrl 优先于它（换链接不用发新版）。
const String kNetdiskDownloadUrl = 'https://pan.quark.cn/s/c6534914a56b';
