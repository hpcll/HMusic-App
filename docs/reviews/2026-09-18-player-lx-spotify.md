# 2026-09-18：LX / Spotify / 纯播放器接续验收

## 范围与状态

接续会话 `01a0b03c-5942-7c42-9149-55fe4031dcdf`，保留原工作树及已有文档改动。
仅修改 HMusic-App；HMusic-Server 工作树仍干净。没有提交、推送、发布或修改版本号。

- Android LX：锁定的 flutter_js 0.8.7 缺失 `jsSetMemoryLimit` 导出；Android 专用适配调用
  `JS_SetMemoryLimit`，在用户脚本执行前施加 64 MB 限制，失败关闭引擎。Apple 仍使用 JSC。
- 纯播放器：免两侧登录、仅本机播放，首次进入本机音源设置，冷启动进入榜单；复用直连本地
  音源/队列/收藏/歌单/进度/统计，不新建数据副本。Server 保持独立。不会读取小米凭据，
  旧音箱目标不会被恢复为当前输出；旧选择仍留给直连使用。
- 切换能力校验前移：不支持纯播放器时不暂停音箱，不清媒体状态。商店版不允许本地模式。
- Spotify：8 秒总预算、超时取消、明确网络错误；公开榜单元数据持久缓存一天，过期刷新失败
  显示保存日期，网络恢复替换旧数据。预览片段不当整曲，不引入个人账号功能。
- 关于页：网盘下载为带图标的描边按钮，最小高度 48，iOS 保留隐藏策略。

## 自动化门禁

执行 Flutter 命令时仅在子进程移除代理变量，并设置 `NO_PROXY=*`，防止测试 VM WebSocket
被代理拦截；没有修改用户系统代理配置。

| 检查 | 结果 | `build/verification/` 证据 |
|---|---|---|
| `dart format .` | 596 文件，最终 0 差异 | `resume-format.log` |
| `flutter analyze --no-pub` | No issues found | `resume-analyze.log` |
| `flutter test --no-pub --reporter expanded` | 650 通过 / 4 商店专项跳过 | `resume-tests.log` |
| StoreEdition 指定测试 | 5 通过 / 4 普通版跳过 | `resume-store-tests.log` |
| Server `npm run typecheck` | 通过 | `resume-server-typecheck.log` |
| Server `npm test` | 22 文件 / 146 测试通过 | `resume-server-tests.log` |
| `git diff --check` | 通过 | 终端复核 |
| Android 正常入口 ARM64 debug APK | 构建、安装、启动通过 | `resume-main-build.log` |

新增/扩充测试覆盖：纯播放器无凭据播放与 ended 推进、旧音箱状态转本机、进度冷恢复、
真实 provider 路由往返、无本机能力拒绝、首次入口与持久模式恢复、大字号设置裁剪、商店门禁。
已有新增 Spotify 测试覆盖请求取消、缓存损坏、重启、离线保存日期、恢复刷新和详情提示。

StoreEdition 命令：

```sh
flutter test --no-pub --reporter expanded --dart-define=HMUSIC_STORE_EDITION=true \
  test/core/playback/store_edition_direct_test.dart \
  test/features/connection/direct_entry_test.dart
```

## Android 原生验收

环境：API 36 ARM64 模拟器。

1. `integration_test/lx_runtime_test.dart` 三项通过：QuickJS bootstrap、80 MB ArrayBuffer 被
   64 MB 限制拒绝后仍可求值、HTTP/Buffer/MD5/AES/timer/Promise、独立 isolate 初始化与返回。
2. 原有 Pixel_9_Pro AVD 的第二个测试包安装失败，提示 `INSTALL_FAILED_INSUFFICIENT_STORAGE`。
   未擦除或清理原 AVD；停止本轮启动的模拟器，在 `build/verification/avd/` 创建独立测试 AVD。
3. `integration_test/direct_audio_test.dart` 在独立 AVD 上通过：真实 LX → HTTP 代理 →
   AudioService/just_audio，验证进度、暂停/seek/恢复、自动下一曲、单曲循环和切模式停止。
   音频为测试生成 WAV、LX 为受控脚本，不冒充真实音乐订阅播放或真人听感验收。
4. 最后重建 `lib/main.dart` 正常 APK，覆盖测试入口并启动；手动 UI 点“免登录，使用纯播放器”
   进入本机音源设置。强制结束进程再启动直接进入榜单，没有服务器或小米登录页。
5. 新 AVD 未预置缓存，正常 App 实网加载 Spotify Global Top 50 的前三首元数据及封面，
   同时网易热歌榜显示内容；仅证明该时点与该网络可用，不保证其他网络或全部 Spotify 榜单。

证据：

- `resume-android.log`：LX 三项通过及后续音频安装空间失败（保留原始失败，不隐藏）。
- `resume-audio-android.log`：独立 AVD 音频集成 `HMUSIC_DIRECT_AUDIO_RESULT=PASS`。
- `resume-player-sources.png` / `.xml`：正常 App 首次纯播放器音源设置。
- `resume-player-cold.png` / `.xml`：进程重启后榜单、Spotify 实网 Top3 与网易内容。
- 两张截图已查看，无本轮页面溢出；不等同完整跨平台视觉验收。

正常测试 APK（**debug 签名，不是发布包**）：

`build/app/outputs/flutter-apk/app-debug.apk`

上述首次正常包 SHA256：`37bc0925c0afd015d4c9d3f80429f3e843fe4ef90868cfec2c56a8d95e381b22`。
该路径随后由下方首页推荐管理版本覆盖，当前校验值见追加记录。

构建命令：

```sh
flutter build apk --no-pub --debug --target-platform android-arm64 --target lib/main.dart
```

## 用户追加：首页推荐管理

新增 `ChartHomePreferences` / store / 独立 ViewModel，使用本机键 `hmusic.charts.home.v1`，
不涉及 Server API 或配置。首页精选统一混排个人与公开榜，可单独关闭、开启非默认榜单、
拖动排序、恢复默认；保存才提交，取消丢弃草稿。目录中暂时缺席的 ID 保留偏好，商店目录
仍由既有能力过滤。首页不再预取隐藏榜单；平台分类保留完整目录和个人常听入口。
预览逻辑拆至 `charts_previews.dart`，避免 ChartsViewModel 超过 280 行。

验证：全仓 **655 通过 / 4 跳过**（`home-all-tests.log`），榜单专项 **81 通过**；
`flutter analyze --no-pub` 无问题（`home-analyze.log`），`dart format .` **603 文件 / 0 差异**。
新增 5 项测试覆盖默认/开关/排序/缺席 ID、冷恢复前过滤预取、分类可达、持久化损坏降级、
360px 普通/两倍字号弹窗保存与取消。Android ARM64 正常入口 debug APK 重新构建成功
（`home-main-build.log`），未再做本次新增拖动交互的真机验收。

当前 APK：`build/app/outputs/flutter-apk/app-debug.apk`（debug，非发布包）。
SHA256：`f99fbc4d00a26bfc65579fd5fdb2f17be26471c431afd9a35e0e68010a35cb8c`。

## 再追加：至少保留一项与纯播放器入口裁剪

- 推荐编辑器禁用最后一项开关，保存层拒绝零项；旧偏好全关或当前目录减少时，展示首个
  可用榜单，不改写其他模式的隐藏偏好。平台分类标签本身仍全部保留，管理粒度是推荐榜单。
- 纯播放器隐藏手机/桌面 `PlayerOutputButton`，状态行不再打开设备列表；`/outputs` 路由
  回榜单，避免原生 intent 绕过 UI。系统耳机/蓝牙输出仍由系统管理，不冒充新增投放能力。
- 入口及完整保留/隐藏表记录于 docs/04；在线纯播放器不承诺手机离线下载或文件扫描。
- 全量 **657 通过 / 4 跳过**，静态检查无问题，格式检查和 diff 检查通过；日志为
  `player-boundary-tests.log`、`player-boundary-analyze.log`、`player-boundary-format.log`。
- Android 真机（25019PNF3C / Android 17）：最新 `0.1.9+4009` arm64 Release 使用原签名覆盖安装成功，
  保留既有数据；启动后实际显示榜单与 Spotify 公开内容，推荐管理弹窗在 2 倍字号下无溢出。
  另以 Release integration APK 实机运行直连音频测试，日志 `HMUSIC_DIRECT_AUDIO_RESULT=PASS`，
  暂停/seek/下一曲/单曲循环链路通过。设备日志中的 SystemUI 资源异常不属于 HMusic 进程；HMusic
  进程无 Flutter/AndroidRuntime 错误。
- macOS：Release universal 构建通过，`hmusic.app` 本地临时签名后安装到 `~/Applications/HMusic.app`
  并成功启动；`lipo` 确认 arm64 + x86_64，代码签名校验通过，榜单首页截图和无障碍树已保存。
  本轮只验证启动/UI，不宣称 macOS 真实曲目播放通过。
- iOS 真机：`flutter build ios --release` 代码编译完成，但签名/安装被阻塞：Xcode 报
  `No Accounts` 及没有匹配 `com.hupc.hmusic` 的 provisioning profile。当前 Mac 的证书钥匙串
  有 Apple Development 身份，但 Xcode 未登录对应开发者账号；未修改签名配置、未绕过安全校验，
  也没有把 iPhone 真机标成通过。
- iOS：使用本机 API 26.5 模拟器运行 `lx_runtime_test.dart`（平台不适用用例跳过）和
  `direct_audio_test.dart`，结果 `3 passed / 1 skipped`；这只能证明 iOS Simulator 集成链路，
  不能替代 iPhone 真机安装/后台/锁屏验收。
- 当前新增限制尚未重新制作 Android 主界面截图以外的发布包；Android/macOS 现场包和 iOS unsigned
  构建证据均在 `build/verification/install-20260918/`。

## 未关闭边界

- 本轮未连接 Android/iOS 真机；后台、锁屏 30 分钟、中断、真实小米账号/音箱仍待验收。
- 用户实际第三方 LX 订阅的当前曲目可用性未在本轮复验；引擎和受控音频链路通过不能承诺所有音源。
- Spotify 只做了 Global Top 50 实网 UI 观察；断网恢复以自动化测试覆盖，非各地区网络保证。
- 文件规模历史问题 `mi_account_view_model.dart` 未改动，未扩大本任务为无关重构。
- 未发布 release；已有 Adreno/Impeller 真机发布门禁仍有效。
