# 贡献指南

感谢参与 HMusic。提交代码前请先阅读 `docs/01-architecture.md`、`docs/10-engineering-standards.md` 和
相关功能文档，保持 View -> ViewModel -> Repository 的依赖方向。

## 本地环境

- Flutter stable，Dart SDK 满足 `pubspec.yaml` 的约束
- Android Studio/Xcode 按目标平台配置完成
- HMusic-Server 在本机或局域网运行

## 验证命令

```bash
flutter pub get
dart format .
flutter analyze
flutter test
```

提交前四条命令都应通过。发布包使用 `tool/build_release.sh` 的 `android`、`ios-unsigned`、
`macos-adhoc`、`linux` 目标；Windows 使用 `tool/build_windows_release.ps1`。每个目标都必须在对应操作系统上构建。

不要提交 `.dart_tool/`、`build/`、密钥、证书、`android/key.properties` 或 Flutter 生成的插件注册文件。
问题报告请附目标平台、Flutter 版本、复现步骤和脱敏日志；不要上传 token、密码或完整签名 URL。

## Pull Request

每个 PR 聚焦一个问题，描述行为变化和验证结果。涉及 API、鉴权、后台播放、商店合规或数据存储时，必须
同时更新对应文档和测试。未经用户明确要求，维护者不会在贡献流程中自动合并或发布版本。
