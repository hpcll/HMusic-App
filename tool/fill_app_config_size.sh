#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG="app-config.json"
COMMIT=0
PUSH=0
VERSION=""

usage() {
  cat >&2 <<'EOF'
用法: tool/fill_app_config_size.sh [选项] [版本号]

把 Release 上 Android 各包的字节数写回 app-config.json：通用包写 apkUrl/apkSize，
三个分架构包写进 apks（App 的退路按本机架构挑，避免通用包版本号更小被安卓判降级）。
版本号缺省取 pubspec.yaml 的 version（不含 +N 构建号）。

选项:
  --commit   改完直接提交
  --push     提交并推送（隐含 --commit）
  -h, --help 显示本帮助

退出码:
  0  已写入
  3  Release 上还没有这一版完整的 APK（发布流水线没跑完）
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --commit) COMMIT=1 ;;
    --push) COMMIT=1; PUSH=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "未知选项: $1" >&2; usage; exit 2 ;;
    *) VERSION="$1" ;;
  esac
  shift
done

if [ -z "$VERSION" ]; then
  VERSION="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' pubspec.yaml | head -n 1)"
fi
[ -n "$VERSION" ] || { echo "无法确定版本号：pubspec.yaml 里没有 version，也没有传入参数" >&2; exit 1; }

TAG="v${VERSION}"

# 发布仓库只认 app_version.dart 里的常量，避免脚本和 App 各写一份。
REPO="$(sed -nE "s/^const String kAppReleaseRepo = '([^']+)'.*/\1/p" lib/core/app_version.dart | head -n 1)"
[ -n "$REPO" ] || { echo "无法从 lib/core/app_version.dart 读到 kAppReleaseRepo" >&2; exit 1; }

# 从 Release 直链取大小，而不是走 api.github.com：未认证 API 只有 60 次/小时，
# 共享出口很容易打满；而且 release 资源本来就有稳定的直链。
# GitHub 先回 302 再回 200，只有最后那一段 200 的 content-length 才是文件大小。
probe_size() {
  curl -sIL --max-time 30 "$1" | awk '
    BEGIN { IGNORECASE = 1; code = ""; len = "" }
    /^HTTP\// { code = $2; len = "" }
    /^content-length:/ { gsub(/\r/, "", $2); len = $2 }
    END { if (code == 200 && len ~ /^[0-9]+$/ && len + 0 > 1000) print len }
  '
}

asset_url() { printf 'https://github.com/%s/releases/download/%s/%s' "$REPO" "$TAG" "$1"; }

echo "版本: ${TAG}"

# 四个包由同一个 job 产出，要么都在要么都不在。缺任何一个就不写：只填一半会让
# 对应架构的设备退回通用包，而那正是要避免的降级。
UNIVERSAL_NAME="hmusic-${VERSION}-android.apk"
UNIVERSAL_SIZE="$(probe_size "$(asset_url "$UNIVERSAL_NAME")")"

ABIS=(arm64-v8a armeabi-v7a x86_64)
SPLIT_SIZES=()
MISSING=0
for abi in "${ABIS[@]}"; do
  size="$(probe_size "$(asset_url "hmusic-${VERSION}-android-${abi}.apk")")"
  SPLIT_SIZES+=("$size")
  [ -z "$size" ] && MISSING=1
done

if [ -z "$UNIVERSAL_SIZE" ] || [ "$MISSING" = "1" ]; then
  for i in "${!ABIS[@]}"; do
    echo "  ${ABIS[$i]}: ${SPLIT_SIZES[$i]:-还没出}"
  done
  echo "  通用包: ${UNIVERSAL_SIZE:-还没出}"
  echo "跳过：Release 上这一版的 APK 还没齐，等流水线跑完再执行一次即可。" >&2
  exit 3
fi

echo "  通用包: ${UNIVERSAL_SIZE}"
for i in "${!ABIS[@]}"; do
  echo "  ${ABIS[$i]}: ${SPLIT_SIZES[$i]}"
done

SPLIT_ARGS=()
for i in "${!ABIS[@]}"; do
  SPLIT_ARGS+=("${ABIS[$i]}" "$(asset_url "hmusic-${VERSION}-android-${ABIS[$i]}.apk")" "${SPLIT_SIZES[$i]}")
done

python3 - "$CONFIG" "$TAG" "$UNIVERSAL_SIZE" \
  "$(asset_url "$UNIVERSAL_NAME")" "${SPLIT_ARGS[@]}" <<'PY'
import json, sys

path, tag = sys.argv[1], sys.argv[2]
universal_size, universal_url = int(sys.argv[3]), sys.argv[4]
split_args = sys.argv[5:]

apks = [
    {"abi": split_args[i], "url": split_args[i + 1], "size": int(split_args[i + 2])}
    for i in range(0, len(split_args), 3)
]

with open(path, encoding="utf-8") as fh:
    config = json.load(fh)

before = json.dumps(
    {k: config.get(k) for k in ("latestVersion", "apkUrl", "apkSize", "apks")},
    sort_keys=True,
    ensure_ascii=False,
)

config["latestVersion"] = tag
config["apkUrl"] = universal_url
config["apkSize"] = universal_size
config["apks"] = apks

after = json.dumps(
    {k: config.get(k) for k in ("latestVersion", "apkUrl", "apkSize", "apks")},
    sort_keys=True,
    ensure_ascii=False,
)

with open(path, "w", encoding="utf-8") as fh:
    json.dump(config, fh, ensure_ascii=False, indent=2)
    fh.write("\n")

if before == after:
    print("app-config.json 无变化（这些字段本来就是对的）")
else:
    print("已更新 app-config.json：")
    print(f"  latestVersion: {tag}")
    print(f"  apkSize: {universal_size}（通用包）")
    for apk in apks:
        print(f"  apks[{apk['abi']}]: {apk['size']}")
PY

if [ "$COMMIT" = "1" ]; then
  if git diff --quiet -- "$CONFIG"; then
    echo "没有改动，跳过提交。"
  else
    git add "$CONFIG"
    git commit -m "release: fill the ${TAG} apk size in app-config"
    echo "已提交。"
    if [ "$PUSH" = "1" ]; then
      git push
      echo "已推送。"
    fi
  fi
else
  echo
  echo "下一步：git add ${CONFIG} && git commit -m 'release: fill the ${TAG} apk size in app-config'"
fi
