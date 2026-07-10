#!/usr/bin/env bash
# 从 HMusic-Server/web 同步前端到 src/，客户端专属的 src/native/ 不受影响。
# UI 事实源永远是 HMusic-Server/web —— 改 UI 去那边改，再跑本脚本同步回来。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_WEB="${1:-$HERE/../HMusic-Server/web}"
DEST="$HERE/src"

if [[ ! -f "$SERVER_WEB/index.html" ]]; then
  echo "找不到 HMusic-Server/web（试了：${SERVER_WEB}）" >&2
  echo "用法：bash scripts/sync-web.sh [/path/to/HMusic-Server/web]" >&2
  exit 1
fi

echo "同步 ${SERVER_WEB} → ${DEST}（保留 src/native/）"
mkdir -p "$DEST"
rsync -a --delete --exclude 'native/' "$SERVER_WEB/" "$DEST/"

# 幂等注入 native 引导脚本：客户端专属增强的唯一入口，浏览器环境自动失活。
INDEX="$DEST/index.html"
if ! grep -q 'src/native/boot.js\|/native/boot.js' "$INDEX"; then
  # 在 main.js 的 module script 之后插入 boot.js
  perl -0pi -e 's{(<script type="module" src="/app/main.js"></script>)}{$1\n    <script type="module" src="/native/boot.js"></script>}' "$INDEX"
  echo "已注入 native/boot.js 引导"
fi

echo "完成。src/native/ 未改动。"
