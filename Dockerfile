# ============================================================
#  个人工作台 —— 自托管镜像
#
#  本 Dockerfile 按私有完整版的需求编写（浏览器内核层供完整版使用）。
#  公开服务骨架不需要浏览器，建议用：
#      docker build --build-arg WITH_BROWSER=0 -t workbench .
#
#  完整版构建（含 Chromium，约 1GB）：
#      docker build -t workbench .
# ============================================================
FROM node:22-bookworm-slim

ARG WITH_BROWSER=1

ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    DATA_DIR=/data \
    BROWSER_MODE=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

WORKDIR /app

# ---------- 依赖 ----------
# 项目本体是零依赖的（纯 node:http），所以这里只装可选能力：
# playwright → 「深度解析」用的真实浏览器内核
COPY package.json ./
RUN set -eux; \
    npm install --omit=dev --no-audit --no-fund --ignore-scripts; \
    if [ "$WITH_BROWSER" = "1" ]; then \
      npm install playwright --no-audit --no-fund --ignore-scripts; \
      npx playwright install --with-deps chromium; \
      chmod -R a+rX /ms-playwright; \
    fi; \
    npm cache clean --force

# ---------- 应用代码 ----------
COPY . .

# 数据目录（state.json / session.json）单独挂卷，容器重建不丢数据
RUN mkdir -p /data && chown -R node:node /data /app

USER node
EXPOSE 3000
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
