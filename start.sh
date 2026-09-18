#!/bin/bash
echo "========================================================"
echo "  ANTIGRAVITY POOL MANAGER (macOS / Linux WebUI 控制台)"
echo "========================================================"
echo ""

if ! command -v node &> /dev/null; then
    echo "[错误] 未检测到 Node.js，请先安装 Node.js 18+ (https://nodejs.org)"
    exit 1
fi

echo "正在启动控制台服务并在浏览器打开..."
(sleep 1 && open http://localhost:3999 2>/dev/null || xdg-open http://localhost:3999 2>/dev/null) &
node server.mjs
