#!/bin/bash
set -e

APP_NAME="Antigravity Manager"
APP_BUNDLE="/Applications/${APP_NAME}.app"
SRC_DIR="/Users/yohanes/antigravity-switcher"

echo "==> 正在编译 Swift 原生宿主程序..."
swiftc -O -framework Cocoa -framework WebKit \
  "${SRC_DIR}/app/main.swift" \
  -o "${SRC_DIR}/app/AntigravityManagerBinary"

echo "==> 准备构建 macOS 应用程序包: ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "==> 拷贝可执行文件与图标..."
cp "${SRC_DIR}/app/AntigravityManagerBinary" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${SRC_DIR}/app/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "==> 写入 Info.plist..."
cat << 'PLIST' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>Antigravity Manager</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.manager</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Antigravity Manager</string>
    <key>CFBundleDisplayName</key>
    <string>Antigravity 账号管理</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> 刷新 macOS 启动服务缓存..."
xattr -c "${APP_BUNDLE}" 2>/dev/null || true

echo "==> 构建成功！应用已部署至: ${APP_BUNDLE}"
