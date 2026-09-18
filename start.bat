@echo off
chcp 65001 > nul
echo ========================================================
echo   ANTIGRAVITY POOL MANAGER (Windows WebUI 控制台)
echo ========================================================
echo.
echo 正在检查 Node.js 环境...
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [错误] 未检测到 Node.js，请先安装 Node.js 18+ (https://nodejs.org)
    pause
    exit /b 1
)

echo 正在启动控制台服务并在浏览器打开...
start http://localhost:3999
node server.mjs
pause
