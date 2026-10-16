#!/usr/bin/env bash
# 完整版本地测试实例启动脚本（Windows / Git Bash）
# 公开服务骨架直接 `node server.js` 即可，无需使用本脚本；
# 以下内容针对私有完整版（.env、学习通会话、本机网关）保留作参考。
#
# 为什么单独写一个：
#   私有完整版 server.js 的配置是「环境变量 > config.json > 默认值」，**不会自动读 .env**；
#   公开骨架只有「环境变量 > 默认值」，直接 node server.js 即可。
#   直接 `node server.js` 会落到 PORT=3000、DATA_DIR=<项目>/data，
#   既和测试脚本里写死的 3399 对不上，又会把测试数据混进正式目录。
#
# 用法：
#   bash run-local.sh              # 前台跑，Ctrl-C 退出
#   bash run-local.sh &            # 后台跑
#   改端口：PORT=3400 bash run-local.sh
#
# 登录学习通/模型 Key 这些从 .env 读（.env 不进仓库）。
set -euo pipefail
cd "$(dirname "$0")"

# .env 里的值作为「默认值」source 进来；下面的 export 会覆盖需要改的几项
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

# 注意：.env 里的 PORT=3210 / DATA_DIR=/var/lib/... 是**生产**值，
# 这里必须无条件盖掉 —— 用 ${PORT:-3399} 是错的，.env 已经把它设上了，
# 结果本地实例会悄悄起在生产端口上（踩过一次）。
export PORT="${LOCAL_PORT:-3399}"
export HOST="${HOST:-127.0.0.1}"
# 测试数据落在 data-test/，绝不碰 data/（仓库存量）和生产的 /var/lib/study-workbench
export DATA_DIR="${LOCAL_DATA_DIR:-$(pwd -W 2>/dev/null || pwd)/data-test}"
export APP_TOKEN="${APP_TOKEN:-your_app_token}"

# 时区：生产服务器是 UTC，本地是东八区 —— 不对齐的话，
# 「课表/待办算得对不对」在本地永远看不出问题（本地本来就恰好是对的），
# 一到线上就整天错 8 小时。这里显式对齐，和 systemd 单元里的设置保持一致。
export TZ="${WORKBENCH_TZ:-Asia/Shanghai}"

mkdir -p "$DATA_DIR"

echo "[run-local] PORT=$PORT  DATA_DIR=$DATA_DIR  APP_TOKEN=${APP_TOKEN}  TZ=$TZ"
echo "[run-local] 教务网关需要自己连过来（它主动长轮询 POST /api/jw/agent/poll）"

exec "${NODE_BIN:-node}" server.js
