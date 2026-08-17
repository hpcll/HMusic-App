// App 自身版本号，「关于与更新」页展示与新版比对用。
// 与 pubspec.yaml 的 version 保持一致（test/core/app_version_test.dart 机械校验）。
const String kAppVersion = '0.1.0';

// App 发布仓库（GitHub Releases 检查更新指向这里）。
const String kAppReleaseRepo = 'hpcll/HMusic-App';

// Gitee 镜像仓库（大陆免翻墙的 app-config.json 主源；由 sync-gitee.yml 同步）。
const String kAppGiteeRepo = 'hpc1997/HMusic-App';
