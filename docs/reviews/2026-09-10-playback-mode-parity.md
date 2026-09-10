# 2026-09-10 歌词、冷启动续播与模式切换复核

本次针对歌词页播控显示、强制退出后继续播放无响应，以及直连/服务器模式往返切换。
只修改 HMusic-App；旧 HMusic、HMusic-client-hmusic-server 和 HMusic-Server 作为只读参考。

## 对照与修复

| 场景 | 对照事实与本次处理 |
| --- | --- |
| 歌词播控 | 原 HMusic 独立歌词页保留居中的大播放键与前后切歌间距。当前页统一复用播放器控制，主键使用 72，控制行最大宽 300；初始化保留按钮和加载反馈。 |
| 直接打开歌词页 | 旧实现由播放页发起歌词请求，绕过播放页时无法加载。本次让歌词 VM 直接订阅活动曲目，按请求序号和模式代数拒绝迟到歌词。 |
| 冷启动进度 | 仓库中的曲目、队列和 97.35 秒快照完整，空 AudioPlayer 的 0 覆盖了显示。装载前使用仓库位置，恢复 MediaItem 和系统媒体进度；没有装载的播放器不回写零进度。 |
| 点击后无反馈 | 解析尚未返回时没有原生装载事件。本次从播放命令开始就发布 loading，成功或失败统一结束该状态。 |
| 解析成功但不可播 | 已保存歌曲的 320k 地址返回 403 空音频；同曲 128k 返回 206。回退原先只处理插件抛错，忽略了不可播放的地址。本次在候选返回前探测，沿音质、插件、匹配平台依次回退。 |
| 模式切换进度 | 原 HMusic 暂停旧策略并保留两种模式缓存。当前切换改为暂停并立即保存本机进度，再释放播放器；退出账号继续执行 stop，不把两种操作混为一谈。 |
| 音箱重复指令 | Handler 已控制目标后，资源关闭不再重复发送暂停/停止；Handler 未观察到的直连目标仍由仓库处理。 |
| 切换时状态订阅 | 模式通知可能先于 Handler 清理完成，直接读缓存会取得旧曲目，随后停在空状态。状态订阅先经过 Handler 命令队列，切换完成后读取目标仓库。 |
| 切回 Server | 正常模式返回使用 `/connect` 自动接续保存的连接；`/connect?switch=1` 只用于明确更换服务器。 |
| 不重播开场时卡住 | `ConnectionOpening(play: false)` 未完成 `done`，导致接续成功后仍无限等待。本次补齐不播放动画的完成通知，覆盖同一进程内切回 Server。 |
| 旧服务器离线 | 本机已经暂停时允许离开离线/超时的旧 Server，并提示进度未同步。音箱暂停没有确认成功时保留旧模式及凭据，避免误报已停止。 |

来源包括旧版 `presentation/providers/playback_provider.dart` 的 `_handleModeSwitch`、
`data/services/song_resolver_service.dart`、`audio_proxy_server.dart` 和独立歌词页。
现版继续使用 Feature-first MVVM、单一 AudioHandler 和各模式独立仓库，不迁移旧版全局状态或明文凭据。

## 音频根因证据

只使用设备保存的播放、队列和音源诊断副本，未把小米账号凭据放入测试。
源脚本、完整签名地址和诊断副本均不进入正式资源。

- 保存曲目为 `Always Online / 林俊杰`，队列及当前指针一致；保存位置 97350 ms。
- 320k 候选通过本机代理、原版完整请求头、不带 Referer、无 Range 请求均返回 403 空正文。
- 同曲 QQ 128k、匹配的酷我/网易云 320k 候选均返回 206，正文为 MP3。
- 因而本次故障由不可播候选短路回退引起；没有用改 UA 掩盖失败，也没有更改用户的默认音质。
- 探测发出 `Range: bytes=0-0`，使用播放代理相同请求头，只读首个非空块后关闭。
  每个候选最多 5 秒，计入现有总计 45 秒解析预算；403、空正文和 HTML/JSON 错误页继续回退。

原始脱敏诊断：[音质对照](../../build/verification/direct-saved-quality-probe.log)。

## 验证

回归覆盖：冷恢复位置与媒体元数据、解析加载态、403/空音频/HTML 候选回退、平台匹配、
插件回退、探测超时与模式取消、直接歌词订阅和迟到请求、宽窄屏播控，以及两模式往返、
离线旧后端、音箱暂停失败、无开场动画时自动接续 Server。

| 检查 | 本轮结果 |
| --- | --- |
| `flutter test --no-pub` | 625 项通过，3 项商店专项在普通构建跳过 |
| StoreEdition 专项 | 3 项通过；该构建跳过 2 项普通直连入口测试 |
| `flutter analyze --no-pub` | 无问题 |
| `dart format .` | 590 个 Dart 文件，最终 0 个修改 |
| 文件规模与 `git diff --check` | 本轮文件满足各层行数限制，无空白错误 |
| iOS 原生复验 | 合成音频的暂停/seek/自动下一曲/单曲循环/切换停止，与真实保存曲目的歌词续播，两项均通过 |
| 正常 iOS Release | `lib/main.dart` 构建成功，36.1 MB；签名深度校验通过 |

[完整测试](../../build/verification/playback-mode-full-tests.log) ·
[静态分析](../../build/verification/playback-mode-analyze.log) ·
[原生复验](../../build/verification/playback-native-final.log)

### iOS 原生播放器与歌词按钮

iOS 26.5 模拟器，最终复验 2026-09-10 04:03 UTC：使用设备保存的真实曲目和 LX 插件，
从歌词页点击播放，原生位置从 97350 ms 前进到 97544 ms；播放器为 ready/playing，
音频返回 206，通知列表为空。点击暂停成功。歌词与 72 主键截图已核对。

- [设备结果](../../build/verification/simulator/hmusic-cold-resume-and-lyrics-result.json)
- [歌词页截图](../../build/verification/simulator/hmusic-lyrics-after-resume.png)

### 实际终止进程并重新启动

`integration_test/cold_resume_process_app.dart` 使用正式 SharedPreferencesAsync 通道，
测试键带独立命名空间；源与播放状态不读写用户业务键。每轮指定新的 `HMUSIC_RESTART_RUN`。
首次进程等待正式 Handler 的周期回写，然后从外部终止正在播放的 App；重启同一安装包，
从磁盘快照恢复并执行续播。没有用内存仓库重建代替进程重启。

iOS 26.5 模拟器，2026-09-10 03:18–03:19 UTC：

- 首次进程 PID 17889，终止前处于播放状态。
- 重启后 PID 18083，从平台存储恢复 172344 ms，启动时未自动播放。
- 原生续播成功，暂停后位置 172498 ms，无错误通知。

[终止前结果](../../build/verification/simulator/hmusic-process-resume-before-termination.json) ·
[重启结果](../../build/verification/simulator/hmusic-process-resume-result.json)

## 保留的边界

- 音箱暂停失败不照搬旧版忽略错误的方式；保留原模式并显示可重试错误。
- Server 保留权威队列和播放态，直连使用独立本地数据；不混写两侧凭据、设备和偏好。
- 旧模式的迟到响应/401、迟到歌词、已排队的旧媒体命令及 ended 仍由代数和串行队列隔离。
- 原版 CDN 请求头与 HTTPS 升级策略存在其他差异；本次对同一地址对拍已排除其作为此故障的原因，
  没有扩大为未经验证的全平台 URL 改写。
- 当前实体 iPhone 离线，尚未安装本轮正常包，也未完成本轮真机后台、锁屏与实体音箱验收。
  模拟器结果不替代这些门禁；之前轮次的真机通过记录不计作本轮新增代码的验收。

## 正常包与安装状态

`build/ios/iphoneos/Runner.app` 为本轮正常 Release 主程序。构建后遇到 Xcode 增量产物的
外层资源签名未更新，使用既有开发身份保留标识和 entitlement 重新签名，随后
`codesign --verify --deep --strict` 通过。构建配置确认入口为 `lib/main.dart`，不含诊断
曲目定义、诊断输出目录、重启用例标识或 StoreEdition 覆盖。

实体 iPhone 的安装尝试返回 CoreDevice 1011（设备不可达），未覆盖手机上之前的正常版本。
模拟器已重新构建、安装并启动正常 `lib/main.dart`，不继续停留在验证入口。
待设备恢复连接后，安装此正常包并补真机强制退出续播、后台/锁屏及真实音箱验证。
