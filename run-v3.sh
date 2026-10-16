#!/usr/bin/env bash
# 完整版 V3 本地开发实例启动脚本
# 公开服务骨架直接 `node server.js` 即可，无需使用本脚本；
# 以下内容针对私有完整版（.env、学习通会话）保留作参考。
#
# 与 run-local.sh 的区别：本脚本会**显式关闭学习通自动登录**。
# 原因：.env 里 CX_AUTO_LOGIN=true，本地一起服务就会立刻拿真实账号去登录学习通。
#      学习通会话可能是单会话的，从本机 IP 登录有可能把生产服务器那条会话顶掉。
#      所以本地开发一律 CX_AUTO_LOGIN=false，需要真实数据就用 data-test/ 里的快照。
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

# 下面这些**必须**在 source .env 之后再覆盖
export PORT="${LOCAL_PORT:-3399}"
export HOST="127.0.0.1"
export DATA_DIR="$(pwd -W 2>/dev/null || pwd)/data-test"
export APP_TOKEN="${APP_TOKEN:-your_app_token}"
export TZ="Asia/Shanghai"

# ★ 关键：本地绝不自动登录学习通，避免顶掉生产会话
export CX_AUTO_LOGIN="false"
export CX_SYNC_INTERVAL_MIN="0"

mkdir -p "$DATA_DIR"

echo "[run-v3] PORT=$PORT  DATA_DIR=$DATA_DIR  TZ=$TZ  CX_AUTO_LOGIN=$CX_AUTO_LOGIN"

exec "${NODE_BIN:-node}" server.js
