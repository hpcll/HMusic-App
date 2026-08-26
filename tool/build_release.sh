#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGET="${1:-android}"
VERSION="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml | head -n 1)"
[ -n "$VERSION" ] || { echo "无法从 pubspec.yaml 读取版本号" >&2; exit 1; }

case "$TARGET" in
  android) ;;
  *) echo "用法: $0 android" >&2; exit 2 ;;
esac

flutter clean
flutter pub get

if [ "${HMUSIC_REQUIRE_RELEASE_SIGNING:-}" = "true" ] && [ ! -f android/key.properties ]; then
  echo "正式构建需要 android/key.properties 和 release keystore" >&2
  exit 1
fi

# Flutter 在部分版本中会把 integration_test 的开发插件写入 release 注册文件。
# 该文件是生成物，删除后由 release 构建重新生成正确的插件列表。
rm -f android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java

DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

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

hash_file "$APK"
hash_file "$AAB"
printf '发布产物已写入 %s\n' "$DIST_DIR"
