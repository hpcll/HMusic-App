# 07 - 路线图与验收

> 阶段以可验证结果命名，不按页面数量虚报进度。P0 详细门禁见 09。

## P0 - 契约与最小纵切

产出：Flutter 工程可运行，Android/iOS 完成连接、鉴权、搜索与本机后台播放最小闭环。

- [x] 技术栈定案 Flutter，清理 Tauri 脚手架
- [x] 审计 Server/App，统一架构和音频文档
- [x] 冻结 Feature-first MVVM、文件拆分和依赖准入规范
- [x] Server `queueIndex` schema/test 已修复；客户端队列点播可直接发送 `queueIndex`
- [x] 生成五平台 Flutter 工程，`flutter analyze/test` 通过
- [x] 按 MVVM 补齐 connection/auth/player/search/queue 最小纵切，单文件和依赖门禁通过
- [x] server base 规范化、`/system/info` 探活、setup/login/401 基础路径
- [x] Track/Playback/Queue/Auth 核心 DTO 与 ApiClient 完整覆盖（Queue DTO + queue 仓库/门禁测试补齐）
- [~] 搜索 -> 本机点播 -> pause/seek -> local-report -> ended 下一曲完整 UI 验收
      （代码链路齐全；iOS 26.5 模拟器已跑通连接+鉴权搜索集成测试；真机 ended 待设备开发者模式开启）
- [x] iOS 编译修复：NativeGlassShellChannel.swift 登记进 Xcode 工程；Info.plist 补 UIBackgroundModes=audio
- [x] Android 后台播放前置：AudioServiceActivity + 前台媒体服务/媒体按钮清单声明
- [x] 真服务器集成测试（integration_test/live_server_test.dart）：macOS ✓、iOS 26.5 模拟器 ✓（system/info + 鉴权搜索）
- [x] streamUrl host 重绑定覆盖 `127.0.0.1` 返回值
- [~] iOS 27 Swift/SwiftUI NativeGlassShell 最小 spike：底栏 + mini player + intent 通道
      （Dart 侧 PlatformShellController intent 派发 + Swift 通道契约补齐；修复 EventChannel 首帧
       `ready/layoutChanged` 早于类型监听建立而丢失、导致误用 Flutter 回退壳的问题，并补事件重放
       回归测试；iOS 27 真机已完成玻璃 dock 与内容折射镜像验收；展开态已替换为原生
       `UITabBarController`；统一系统 Dock frame 的 window/local 坐标，按真实底缘与左右边界
       对齐收缩圆钮，并修复初始化选择回调抢路由、首次布局需点击才稳定的问题；iOS 26.5
       模拟器冷启动已验收；原生 Tab controller 改为全屏宿主、由 UIKit 自行处理底部安全区，
       系统可见 platter frame 用于收缩态底缘对齐，修复选中/未选中标题基线错位与底缘裁切；
       tab intent 已完成前轮真机验收；mini player
       折射和旧 iOS 回退仍待真机验收）
- [ ] Android AdaptiveGlassSurface spike：High/Medium/Off 三档和滚动性能
- [ ] Android/iOS 真机前后台与锁屏最小验收
- [x] 冻结 App Store 首发功能边界、Demo Server 方案和公网 HTTPS/LAN HTTP 策略（ADR-0003）
- [x] 冻结 App Store 产品定位：NAS/家庭服务器个人音乐库客户端

## P1 - 核心播放器

- [~] 播放页封面、元数据、进度、音量、模式（已落地：封面自适应矮屏、实时进度条、模式循环切换；染色歌词条未做）
- [ ] iOS 原生玻璃播放控制面板；Android 同构 Flutter 玻璃控制面板
- [ ] 独立沉浸歌词页与同步滚动
- [x] 队列点播、删除、清空、换模式，命令串行无竞态（一步 queueIndex 点播）
- [~] 本机与小米音箱设备切换（已落地遥控语义：点歌/playAll 跟随所选设备不再劫持回本机、
      Server playUrl 换目标先掐停旧音箱、目标为远端时本机 player 静默且 5s 轮询驱动状态回读、
      播放页按钮/进度/mediaItem 取服务端权威态、音箱音量走 `/playback/volume`
      拖动结束提交；自动连播已改由 Server 播放看门狗自轮询保障（C-12，2026-07-18），
      App 退后台不再停摆；播放页已有遥控标识（设备状态行）+ 音量行尾输出钮 +
      设备选择 sheet（docs/04 屏 2）；待真机 + 真音箱验收）
- [ ] 直链失效按当前曲目和位置自动恢复一次
- [ ] 冷启动展示 Server 恢复的暂停态与队列，resume 重新解析后从原位置继续

## P2 - 全功能页

- [ ] 歌单创建、导入、详情、收藏、播放全部
- [ ] 榜单卡片墙、详情、整榜播放、Apple 榜搜索匹配
- [ ] 统计图表
- [ ] 设置：账号、设备、音源、播放、服务器、安全
- [ ] App 内账户删除入口与 Server 删除语义/API
- [ ] 服务端下载：搜索页触发、状态轮询、失败重试、删除与大小展示
- [ ] 小米扫码/短信/凭据登录流程
- [ ] 深浅色、手机/平板/桌面宽度逐屏对照 Web 参考
- [ ] iOS 27 底栏/mini player/系统 sheet 全量接入，旧 iOS 回退完成（App 无常驻顶栏，顶部为滚动消融）
- [ ] Android 玻璃 chrome 全页覆盖，不玻璃化内容列表和卡片

## P3 - 移动质量

- [ ] 08 章中断矩阵 Android/iOS 真机全过
- [ ] 锁屏 30 分钟、后台播完自动下一首、系统回收边界有记录
- [ ] 封面滑动切歌、列表左滑操作、下拉刷新
- [ ] 弱网、Server 离线、切 Wi-Fi、token 失效均可恢复
- [ ] 启动、内存、耗电和音频卡顿基线
- [ ] iOS Liquid Glass 合成、Android 三档 blur 的帧时间与 GPU 基线
- [ ] Reduce Motion、Reduce Transparency、深浅色和高对比度验收
- [ ] Android 实体音量键遥控音箱 spike（MediaSession remote volume 通道）；
      iOS 无公开 API 明确不做（决议 2026-07-19，遥控音量用 App 内滑条）

## P4 - 桌面原生

- [ ] macOS/Windows/Linux 音频后端 spike 与验收
- [ ] 托盘、关窗驻留、窗口状态记忆
- [ ] 媒体键和系统“正在播放”面板
- [ ] 键盘快捷键不干扰文本输入
- [ ] 开机自启和外链打开

## P5 - 分发

- [ ] CI：Android/iOS/macOS/Windows/Linux 构建矩阵
- [ ] Android AAB、iOS archive、桌面安装包
- [ ] 签名、公证、隐私说明、局域网权限说明
- [ ] HTTPS 审核 Demo Server、审核账号、公版测试音频和 Review Notes
- [ ] 隐私政策、支持 URL、App Privacy/Data Safety、SDK privacy manifest
- [ ] 内容权利审查、商店版 LX/下载边界和发布区域决策
- [ ] TestFlight/Google closed test、账户删除、后台音频审核路径全过
- [ ] 自动升级方案按各平台能力分别确定
- [ ] README 安装、连接和故障排查

## 风险登记

| 风险 | 影响 | 对策 |
|---|---|---|
| Server 全局 `local-browser` 多客户端争用 | 状态互相覆盖 | P0 单活约束；后续设计 session/device identity |
| LAN HTTP 平台限制 | 无法连接或拉流 | P0 双真机提前验收 cleartext/ATS/local network |
| streamUrl host 为 127.0.0.1 | 手机无声 | ApiClient 统一按已连接 server base 重绑定 |
| 后台播放上下文与 UI 状态分叉 | 播完不续播、通知失真 | 唯一 AudioHandler，持有 API 能力，ended 在后台完成 |
| Server 与 App 并行演进 | 契约漂移 | 以冻结 commit 做集成测试；新端点先更新 02 再接入 |
| 桌面音频插件覆盖不齐 | 三平台体验不一致 | P4 前做 build/Range/seek spike，不提前绑定方案 |
| Flutter 与 Web 视觉漂移 | 产品不一致 | token 化 + 逐屏截图对照，不共享实现代码 |
| iOS 27 系统 API 与 Flutter 合成限制 | 原生材质无法正确采样 Flutter 背景 | P0 先做 SwiftUI overlay 真机 spike；失败时系统 material 回退 |
| Android 动态模糊耗电或掉帧 | 长列表体验变差 | chrome 共享模糊层 + High/Medium/Off 自动降级 |
| Swift 与 Flutter 状态双写 | 导航或播放状态冲突 | Swift 只展示并发 intent，Flutter 始终是业务状态源 |
