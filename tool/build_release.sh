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

flutter clean
flutter pub get

DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

hash_file() {
  local input="$1"
  local name
  name="$(basename "$input")"
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$DIST_DIR" && sha256sum "$name" > "$name.sha256")
  else
    (cd "$DIST_DIR" && shasum -a 256 "$name" > "$name.sha256")
  fi
}

if [ "$TARGET" = "ios-unsigned" ]; then
  flutter build ios --release --no-codesign --no-pub

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

  flutter build macos --release --config-only --no-pub
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

  ARCHIVE="$DIST_DIR/hmusic-${VERSION}-macos-universal-adhoc.zip"
  rm -f "$ARCHIVE"
  ditto -c -k --sequesterRsrc --keepParent "$STAGING_DIR/HMusic.app" "$ARCHIVE"
  hash_file "$ARCHIVE"
  printf 'macOS universal ad-hoc 包已写入 %s\n' "$ARCHIVE"
  exit 0
fi

if [ "$TARGET" = "linux" ]; then
  [ "$(uname -s)" = "Linux" ] || { echo "Linux 包只能在 Linux 上构建" >&2; exit 1; }

  flutter build linux --release --no-pub
  BUNDLE_PATH="$ROOT_DIR/build/linux/x64/release/bundle"
  [ -x "$BUNDLE_PATH/hmusic" ] || { echo "Linux 构建未生成 hmusic" >&2; exit 1; }

  STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hmusic-linux.XXXXXX")"
  trap 'rm -rf "$STAGING_DIR"' EXIT
  mkdir -p "$STAGING_DIR/HMusic"
  cp -R "$BUNDLE_PATH/." "$STAGING_DIR/HMusic/"

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

# Flutter 在部分版本中会把 integration_test 的开发插件写入 release 注册文件。
# 该文件是生成物，删除后由 release 构建重新生成正确的插件列表。
rm -f android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java

flutter build apk --release --no-pub
flutter build appbundle --release --no-pub

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
printf '发布产物已写入 %s\n' "$DIST_DIR"
