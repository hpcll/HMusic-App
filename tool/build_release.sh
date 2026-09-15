#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGET="${1:-android}"
VERSION="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml | head -n 1)"
[ -n "$VERSION" ] || { echo "无法从 pubspec.yaml 读取版本号" >&2; exit 1; }

case "$TARGET" in
  android|ios-unsigned|macos-adhoc|linux) ;;
  *) echo "用法: $0 [android|ios-unsigned|macos-adhoc|linux]" >&2; exit 2 ;;
esac

# 安卓构建号的下界。统号之后构建号就是 versionCode（见 android/app/build.gradle.kts 里
# versionCodeOverride 那段注释），而历史最高值是 0.1.8 的 x86_64 分架构包：芯片基数 4 * 1000
# 加构建号 8，等于 4008。已经装了它的设备只接受 >= 4008 的新包，否则点更新只会看到一句
# 「应用未安装」。这个前提一破，编出来的包老用户装不上，所以放在构建之前查——没必要先花
# 十几分钟编译再告知。
MIN_ANDROID_VERSION_CODE=4009
BUILD_NUMBER=""
if [ "$TARGET" = "android" ]; then
  BUILD_NUMBER="$(sed -nE 's/^version:.*\+([0-9]+).*/\1/p' pubspec.yaml | head -n 1)"
  [ -n "$BUILD_NUMBER" ] || { echo "pubspec.yaml 的 version 里没有 +构建号" >&2; exit 1; }
  if [ "$BUILD_NUMBER" -lt "$MIN_ANDROID_VERSION_CODE" ]; then
    echo "安卓构建号是 $BUILD_NUMBER，低于下界 $MIN_ANDROID_VERSION_CODE" >&2
    echo "已经装了 0.1.8 分架构包（最高 4008）的用户会升不上来，pubspec.yaml 的构建号要往上跳" >&2
    exit 1
  fi
fi

flutter clean
flutter pub get

DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

SUMS_FILE="$DIST_DIR/hmusic-${VERSION}-SHA256SUMS.txt"

# 一版一个校验文件，不再给每个包配一个 .sha256 边车（Release 资产从 14 条降到 8 条）。
# 同一次构建会依次登记多个产物，所以按文件名 upsert：先剔掉同名旧行再追加，重跑不留
# 重复行。行格式与 sha256sum 一致，用户可以直接 `sha256sum -c` / `shasum -a 256 -c`。
hash_file() {
  local name
  name="$(basename "$1")"
  local line
  if command -v sha256sum >/dev/null 2>&1; then
    line="$(cd "$DIST_DIR" && sha256sum "$name")"
  else
    line="$(cd "$DIST_DIR" && shasum -a 256 "$name")"
  fi
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/hmusic-sums.XXXXXX")"
  if [ -f "$SUMS_FILE" ]; then
    awk -v drop="$name" '$NF != drop' "$SUMS_FILE" > "$tmp"
  fi
  printf '%s\n' "$line" >> "$tmp"
  LC_ALL=C sort -k 2 "$tmp" > "$SUMS_FILE"
  rm -f "$tmp"
}

if [ "$TARGET" = "ios-unsigned" ]; then
  flutter build ios --release --no-codesign

  APP_PATH="$ROOT_DIR/build/ios/iphoneos/Runner.app"
  [ -d "$APP_PATH" ] || { echo "iOS 构建未生成 Runner.app" >&2; exit 1; }
  if codesign -d "$APP_PATH" >/dev/null 2>&1; then
    echo "iOS 构建结果意外带有签名，请勿发布为 unsigned IPA" >&2
    exit 1
  fi
  if [ -e "$APP_PATH/_CodeSignature" ] || [ -e "$APP_PATH/embedded.mobileprovision" ]; then
    echo "iOS 主 App 中存在签名或描述文件，请勿发布为 unsigned IPA" >&2
    exit 1
  fi

  STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hmusic-ipa.XXXXXX")"
  trap 'rm -rf "$STAGING_DIR"' EXIT
  mkdir -p "$STAGING_DIR/Payload"
  cp -R "$APP_PATH" "$STAGING_DIR/Payload/HMusic.app"

  IPA="$DIST_DIR/hmusic-${VERSION}-ios-unsigned.ipa"
  rm -f "$IPA"
  (cd "$STAGING_DIR" && zip -qry "$IPA" Payload)
  hash_file "$IPA"
  printf 'iOS 未签名 IPA 已写入 %s\n' "$IPA"
  exit 0
fi

if [ "$TARGET" = "macos-adhoc" ]; then
  [ "$(uname -s)" = "Darwin" ] || { echo "macOS 包只能在 macOS 上构建" >&2; exit 1; }

  flutter build macos --release --config-only
  MACOS_BUILD_DIR="$ROOT_DIR/build/macos"
  xcodebuild \
    -workspace "$ROOT_DIR/macos/Runner.xcworkspace" \
    -scheme Runner \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$MACOS_BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' \
    DEVELOPMENT_TEAM='' \
    PROVISIONING_PROFILE_SPECIFIER='' \
    -quiet build

  APP_PATH="$MACOS_BUILD_DIR/Build/Products/Release/hmusic.app"
  [ -d "$APP_PATH" ] || { echo "macOS 构建未生成 hmusic.app" >&2; exit 1; }
  lipo "$APP_PATH/Contents/MacOS/hmusic" -verify_arch arm64 x86_64

  STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hmusic-macos.XXXXXX")"
  trap 'rm -rf "$STAGING_DIR"' EXIT
  ditto "$APP_PATH" "$STAGING_DIR/HMusic.app"
  codesign --force --deep --sign - "$STAGING_DIR/HMusic.app"
  codesign --verify --deep --strict "$STAGING_DIR/HMusic.app"

  ARCHIVE="$DIST_DIR/hmusic-${VERSION}-macos-universal.dmg"
  rm -f "$ARCHIVE"
  # dmg 根目录里放一个「应用程序」软链：用户挂载后把 HMusic.app 拖过去就装好了。
  # 软链和 App 同级、不在包内，codesign --deep 不会顺着它走出去。
  ln -s /Applications "$STAGING_DIR/Applications"
  # 显式指定 HFS+：hdiutil 的默认文件系统跟着 macOS 版本变（新系统上是 APFS），
  # 而 HFS+ 映像在所有还能跑本 App 的系统上都挂得开，别让构建机版本决定这件事。
  hdiutil create -volname "HMusic ${VERSION}" -srcfolder "$STAGING_DIR" \
    -fs HFS+ -ov -format UDZO "$ARCHIVE"
  hdiutil verify "$ARCHIVE"
  hash_file "$ARCHIVE"
  printf 'macOS universal ad-hoc dmg 已写入 %s\n' "$ARCHIVE"
  exit 0
fi

if [ "$TARGET" = "linux" ]; then
  [ "$(uname -s)" = "Linux" ] || { echo "Linux 包只能在 Linux 上构建" >&2; exit 1; }

  flutter build linux --release
  BUNDLE_PATH="$ROOT_DIR/build/linux/x64/release/bundle"
  [ -x "$BUNDLE_PATH/hmusic" ] || { echo "Linux 构建未生成 hmusic" >&2; exit 1; }

  STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hmusic-linux.XXXXXX")"
  trap 'rm -rf "$STAGING_DIR"' EXIT
  mkdir -p "$STAGING_DIR/HMusic"
  cp -R "$BUNDLE_PATH/." "$STAGING_DIR/HMusic/"

  # Flutter Linux 不会把桌面启动图标放进 bundle；复用已生成的 macOS 方形图标，
  # 让便携包运行时也能显示品牌图标。
  LINUX_ICON="$ROOT_DIR/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
  [ -f "$LINUX_ICON" ] || { echo "Linux 包图标不存在: $LINUX_ICON" >&2; exit 1; }
  cp "$LINUX_ICON" "$STAGING_DIR/HMusic/hmusic.png"
  cp "$ROOT_DIR/linux/packaging/hmusic.desktop" "$STAGING_DIR/HMusic/hmusic.desktop"

  ARCHIVE="$DIST_DIR/hmusic-${VERSION}-linux-x64.tar.gz"
  rm -f "$ARCHIVE"
  tar -C "$STAGING_DIR" -czf "$ARCHIVE" HMusic
  hash_file "$ARCHIVE"
  printf 'Linux x64 便携包已写入 %s\n' "$ARCHIVE"
  exit 0
fi

if [ "${HMUSIC_REQUIRE_RELEASE_SIGNING:-}" = "true" ] && [ ! -f android/key.properties ]; then
  echo "正式构建需要 android/key.properties 和 release keystore" >&2
  exit 1
fi

# 构建一律不能带 --no-pub：只有 pub 步骤会重新生成各平台的插件注册文件
#（flutter_tools 的 regeneratePlatformSpecificToolingIfApplicable 在 --no-pub 下直接 return），
# 而 release 模式下的这次重新生成正好会剔除 integration_test 这类 dev 依赖插件——
# 也就是说 dev 插件混进 release 注册表这件事，交给 pub 自己就解决了，不需要手删文件。
flutter build apk --release
# 分架构包：App 内自更新只下本机那一份（25MB 上下，通用包是 61MB）。资产名里的
# 架构标记就是 App 侧挑包的依据（api_update_repository._pickApkAsset），改名要同步。
# 通用包仍然要出：手动下载、以及挑不到本机架构时的回落。
flutter build apk --release --split-per-abi
flutter build appbundle --release

# 插件注册文件是 Android 端的生命线，缺了它 FlutterEngine 只打一行 warning 继续跑：
# 包能装能开机、能连服务端、能拉列表，但所有插件通道都不存在——点播报
# MissingPluginException(... audio_service.client.methods)、安全存储和本地键值存储
# 静默失效（0.1.2/0.1.3 线上那三个「重新登录/连接报错/无法播放」都是这一个原因）。
# 构建后机械校验一次，别再让它静默漏出去。
REGISTRANT="android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
[ -f "$REGISTRANT" ] || { echo "缺少 $REGISTRANT：release 包不会注册任何插件" >&2; exit 1; }
for plugin_class in AudioServicePlugin JustAudioPlugin AudioSessionPlugin \
  FlutterSecureStoragePlugin SharedPreferencesPlugin BonsoirPlugin; do
  grep -q "$plugin_class" "$REGISTRANT" || {
    echo "插件注册文件缺少 $plugin_class" >&2
    exit 1
  }
done
if grep -q "integration_test" "$REGISTRANT"; then
  echo "dev 依赖插件 integration_test 进入了 release 注册文件" >&2
  exit 1
fi
# 注册文件对了还要确认真的编进了包：只有生成的注册表里才有这行日志文案。
# 用 grep -c 读完整个流，别用 grep -q——它命中即退出，unzip 吃到 SIGPIPE 会在
# pipefail 下把整条管道判成失败，好包也会被误判。
REGISTRANT_HITS="$(unzip -p build/app/outputs/flutter-apk/app-release.apk "classes*.dex" \
  | grep -ac "Error registering plugin audio_service" || true)"
if [ "$REGISTRANT_HITS" -lt 1 ]; then
  echo "APK 中没有 GeneratedPluginRegistrant，插件通道全部缺失" >&2
  exit 1
fi

SIGNING_SUFFIX=""
if [ ! -f android/key.properties ]; then
  SIGNING_SUFFIX="-unsigned"
fi
APK="$DIST_DIR/hmusic-${VERSION}-android${SIGNING_SUFFIX}.apk"
AAB="$DIST_DIR/hmusic-${VERSION}-android${SIGNING_SUFFIX}.aab"
cp build/app/outputs/flutter-apk/app-release.apk "$APK"
cp build/app/outputs/bundle/release/app-release.aab "$AAB"

hash_file "$APK"
hash_file "$AAB"

# 分架构包：flutter 的产物名是 app-<abi>-release.apk，转成发布名
# hmusic-<版本>-android-<abi>[-unsigned].apk（abi 段保留 arm64-v8a/armeabi-v7a/
# x86_64 原样，App 侧按「-<abi>.」或「-<abi>-」定位，不会把 x86 和 x86_64 搞混）。
for abi in arm64-v8a armeabi-v7a x86_64; do
  SPLIT_SRC="build/app/outputs/flutter-apk/app-${abi}-release.apk"
  [ -f "$SPLIT_SRC" ] || { echo "缺少分架构包 $SPLIT_SRC" >&2; exit 1; }
  SPLIT_APK="$DIST_DIR/hmusic-${VERSION}-android-${abi}${SIGNING_SUFFIX}.apk"
  cp "$SPLIT_SRC" "$SPLIT_APK"
  hash_file "$SPLIT_APK"
done

# 四个安卓包必须同号，而且必须等于 pubspec 里的构建号——也就是 Flutter 的 ABI 版本号改写
# 确实被 android/app/build.gradle.kts 的 versionCodeOverride 掰回来了。不同号时，装过
# 分架构包的设备收到通用包会被安卓按降级拒装，只报一句「应用未安装」。（下界校验在构建前
# 已经做过，见文件开头。）Flutter 哪天换了版本号的算法，这里会直接炸，而不是把互相装不上的
# 包静默发出去。
VERSION_CODES=""
APK_COUNT=0
for apk in "$DIST_DIR"/hmusic-"${VERSION}"-android*.apk; do
  VERSION_CODES="$VERSION_CODES $(python3 "$ROOT_DIR/tool/apk_version_code.py" "$apk")"
  APK_COUNT=$((APK_COUNT + 1))
done
[ "$APK_COUNT" -eq 4 ] || {
  echo "安卓包应有 4 个（通用 + 3 个分架构），实际 $APK_COUNT 个" >&2
  exit 1
}
for code in $VERSION_CODES; do
  [ "$code" = "$BUILD_NUMBER" ] || {
    echo "安卓包的 versionCode 与 pubspec 构建号不一致：包是$VERSION_CODES，构建号是 $BUILD_NUMBER" >&2
    echo "检查 android/app/build.gradle.kts 的 versionCodeOverride 是否还在生效" >&2
    exit 1
  }
done
printf '四个安卓包 versionCode 一致：%s\n' "$BUILD_NUMBER"

printf '发布产物已写入 %s\n' "$DIST_DIR"
