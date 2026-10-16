#!/usr/bin/env bash
# ============================================================
#  一键部署到自己的服务器（Debian / Ubuntu）
#
#  用法（在服务器上以 root 执行，或在前面加 sudo）：
#      bash deploy/install.sh
#
#  脚本会做：
#    1. 装 Node 22（用 NodeSource 源）
#    2. 把项目放到 /opt/chaoxing-workbench
#    3. 生成 .env（首次会让你填账号密码）
#    4. 装 playwright + Chromium（解锁「深度解析」）
#    5. 注册 systemd 服务并启动
#
#  注意：本脚本面向私有完整版部署。公开仓库只含服务骨架，
#  不含业务代码；仅运行骨架时可跳过第 3、4 步。
#
#  重跑是安全的：已存在的 .env / data 不会被覆盖。
# ============================================================
set -euo pipefail

APP_DIR=${APP_DIR:-/opt/chaoxing-workbench}
SVC=chaoxing-workbench
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '\033[1;34m[deploy]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[deploy] %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "请用 root 运行（或 sudo bash deploy/install.sh）"

# ---------- 1. Node ----------
if command -v node >/dev/null 2>&1 && [ "$(node -v | sed 's/v\([0-9]*\).*/\1/')" -ge 18 ]; then
  log "已检测到 Node $(node -v)，跳过安装"
else
  log "安装 Node 22 ..."
  apt-get update -qq
  apt-get install -y -qq curl ca-certificates gnupg
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y -qq nodejs
fi

# ---------- 2. 拷贝代码 ----------
log "部署到 $APP_DIR ..."
mkdir -p "$APP_DIR"
if [ "$SRC_DIR" != "$APP_DIR" ]; then
  # 用 rsync 保留 data/ 和 .env，不覆盖已有配置
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude node_modules --exclude '.git' --exclude 'data' --exclude '.env' \
      "$SRC_DIR"/ "$APP_DIR"/
  else
    apt-get install -y -qq rsync
    rsync -a --exclude node_modules --exclude '.git' --exclude 'data' --exclude '.env' \
      "$SRC_DIR"/ "$APP_DIR"/
  fi
fi
mkdir -p "$APP_DIR/data"

# ---------- 3. .env ----------
if [ ! -f "$APP_DIR/.env" ]; then
  log "生成 $APP_DIR/.env"
  read -rp "学习通手机号: " CX_PHONE_IN || true
  read -rsp "学习通密码: " CX_PASSWORD_IN || true; echo
  cat > "$APP_DIR/.env" <<EOF
PORT=3000
HOST=127.0.0.1
DATA_DIR=$APP_DIR/data
TZ=Asia/Shanghai
# APP_TOKEN=请改为一个长随机口令

CX_PHONE=${CX_PHONE_IN:-}
CX_PASSWORD=${CX_PASSWORD_IN:-}
CX_AUTO_LOGIN=true
CX_SYNC_INTERVAL_MIN=30

STEPFUN_KEY=your_stepfun_api_key
STEPFUN_BASE=https://api.stepfun.com/step_plan/v1
STEPFUN_MODEL=step-5-preview

BROWSER_MODE=1
BROWSER_TIMEOUT=25000
EOF
  chmod 600 "$APP_DIR/.env"
else
  log "$APP_DIR/.env 已存在，保留不覆盖"
fi

# ---------- 4. 依赖 + 浏览器内核 ----------
cd "$APP_DIR"
log "安装依赖 ..."
npm install --omit=dev --no-audit --no-fund

if ! grep -q '^BROWSER_MODE=0' .env 2>/dev/null; then
  log "安装 Playwright + Chromium（解锁深度解析，约 300MB，慢是正常的）..."
  npm install playwright --no-audit --no-fund --ignore-scripts
  npx playwright install --with-deps chromium
else
  log ".env 里 BROWSER_MODE=0，跳过浏览器内核"
fi

# ---------- 5. systemd ----------
log "注册 systemd 服务 ..."
sed "s#/opt/chaoxing-workbench#$APP_DIR#g" deploy/chaoxing-workbench.service > /etc/systemd/system/$SVC.service
systemctl daemon-reload
systemctl enable "$SVC" >/dev/null
systemctl restart "$SVC"
sleep 3

if systemctl is-active --quiet "$SVC"; then
  log "服务已启动 ✅"
  log "本机自测： curl -s http://127.0.0.1:3000/api/health"
  echo
  echo "  下一步（强烈建议）：挂域名 + HTTPS"
  echo "    1) 编辑 deploy/nginx.conf.example 里的 server_name，拷到 /etc/nginx/sites-available/$SVC"
  echo "    2) ln -s /etc/nginx/sites-available/$SVC /etc/nginx/sites-enabled/ && nginx -t && systemctl reload nginx"
  echo "    3) certbot --nginx -d 你的域名"
  echo
  echo "  看日志： journalctl -u $SVC -f"
else
  die "服务没起来，看日志： journalctl -u $SVC -n 80 --no-pager"
fi
