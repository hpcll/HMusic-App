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

把 Release 上 Android 通用包的字节数写回 app-config.json 的 apkSize。
版本号缺省取 pubspec.yaml 的 version（不含 +N 构建号）。

选项:
  --commit   改完直接提交
  --push     提交并推送（隐含 --commit）
  -h, --help 显示本帮助

退出码:
  0  已写入
  3  Release 上还没有这个包（发布流水线没跑完）
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
ASSET="hmusic-${VERSION}-android.apk"

# 发布仓库只认 app_version.dart 里的常量，避免脚本和 App 各写一份。
REPO="$(sed -nE "s/^const String kAppReleaseRepo = '([^']+)'.*/\1/p" lib/core/app_version.dart | head -n 1)"
[ -n "$REPO" ] || { echo "无法从 lib/core/app_version.dart 读到 kAppReleaseRepo" >&2; exit 1; }

URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"

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

echo "版本: ${TAG}"
echo "资源: ${URL}"

SIZE=""
for attempt in 1 2 3; do
  SIZE="$(probe_size "$URL")"
  [ -n "$SIZE" ] && break
  echo "  第 ${attempt} 次探测：资源还不在（发布流水线可能还在构建）"
  [ "$attempt" -lt 3 ] && sleep 10
done

if [ -z "$SIZE" ]; then
  echo "跳过：Release 上还没有 ${ASSET}，等流水线跑完再执行一次即可。" >&2
  exit 3
fi

echo "大小: ${SIZE} bytes"

python3 - "$CONFIG" "$TAG" "$URL" "$SIZE" <<'PY'
import json, sys

path, tag, url, size = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

with open(path, encoding="utf-8") as fh:
    config = json.load(fh)

before = (config.get("latestVersion"), config.get("apkUrl"), config.get("apkSize"))
config["latestVersion"] = tag
config["apkUrl"] = url
config["apkSize"] = size

with open(path, "w", encoding="utf-8") as fh:
    json.dump(config, fh, ensure_ascii=False, indent=2)
    fh.write("\n")

after = (config["latestVersion"], config["apkUrl"], config["apkSize"])
if before == after:
    print("app-config.json 无变化（三个字段本来就是对的）")
else:
    print("已更新 app-config.json：")
    for key, old, new in zip(("latestVersion", "apkUrl", "apkSize"), before, after):
        if old != new:
            print(f"  {key}: {old!r} -> {new!r}")
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
