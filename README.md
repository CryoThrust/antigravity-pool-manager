# Antigravity Pool Manager 🚀

> **Google Antigravity 多账号算力聚合号池与智能无感调度中心**  
> 专为解决 Antigravity 额度限制打造，支持多账号聚合、实时配额大盘看板、Token 消耗审计、静默自动续期及额度见底自动切号。支持 **macOS（原生桌面端 + WebUI）** 与 **Windows（WebUI）** 全平台兼容。

---

## ✨ 核心特性

- 📊 **算力汇总仪表盘 (Power BI / Azure 极简工业美学)**:
  - 实时展示号池 5H 可用额度均值、周度可用总容量、可用账号数及全局累计 Token 交互统计。
- 🔄 **直连 Google Cloud 专有接口**:
  - 无需切换当前登录态，后台可直接并行查询号池内所有账号的实时 Gemini / Claude 配额及重置倒计时。
- 🛡️ **三层无感静默守护 (Silent Automation)**:
  - **无感自动续期**: 本地凭据到期前 15 分钟静默换新。即使电脑关机数天，开机后自动瞬间唤醒刷新，账号永不失效。
  - **周期配额探测**: 每 3 分钟自动探测号池状态并更新。
  - **额度见底自动切号 (Auto Failover)**: 活跃账号 5H 额度 ≤ 2% 时，毫秒级无感轮转至最高额度小号。
- 📈 **Token 交互审计日志**:
  - 精确统计历次对话的 Prompt 内容、步骤数与 Token 单次消耗，支持时间线筛选（全部 / 今天 / 昨天 / 最近 7 天）。
- 💻 **全平台通用**:
  - **Windows**: 一键双击 `start.bat` 即可启动 WebUI 控制台并自动打开浏览器。
  - **macOS**: 支持一键双击 `start.sh` WebUI，或通过原生桌面端 `/Applications/Antigravity Manager.app` 运行（支持沉浸式标题栏拖拽）。

---

## 🚀 快速开始

### 前置要求
- **Node.js 18.0 或更高版本** ([https://nodejs.org](https://nodejs.org))

### 1. Windows 用户运行
直接双击运行项目根目录下的 **`start.bat`**，或在 PowerShell / CMD 中执行：
```bat
start.bat
```
浏览器将自动弹出控制台：`http://localhost:3999`。

### 2. macOS / Linux 用户运行
直接双击运行 **`start.sh`**，或在终端中执行：
```bash
./start.sh
```
或者使用 npm 启动：
```bash
npm start
```

### 3. macOS 原生桌面端构建（可选）
如果您喜欢独立的 macOS 桌面应用程序窗口（自带窗口拖拽与系统菜单栏）：
```bash
bash scripts/build_app.sh
```
构建完成后可在 `/Applications/Antigravity Manager.app` 直接打开使用。

---

## ⚙️ 架构与安全设计

1. **凭证持久化与本地安全**:
   - 授权账号信息与 Refresh Token 保存在本机用户目录的 `~/.antigravity_pool/accounts.json`。
   - 所有通信均在本机 Localhost（端口 `3999` 与 OAuth 回调端口 `51121`）与 Google 官方 API 之间进行，**绝不上报任何第三方服务器**。
2. **账号持久性保障**:
   - Google OAuth 采用双 Token 机制，保存的 Refresh Token 具备长期有效性。无论电脑关机或重启，服务唤醒时均会自动向 Google 端点换取最新的 Access Token，无需重复登录。

---

## 📄 开源许可证
MIT License
