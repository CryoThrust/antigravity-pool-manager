with open("/Users/yohanes/antigravity-switcher/index.html", "r", encoding="utf-8") as f:
    html = f.read()

# 添加 switch CSS
switch_css = '''
    /* macOS Native Switch */
    .mac-switch {
      position: relative;
      display: inline-block;
      width: 36px;
      height: 20px;
      flex-shrink: 0;
    }
    .mac-switch input { opacity: 0; width: 0; height: 0; }
    .mac-slider {
      position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0;
      background-color: rgba(255, 255, 255, 0.2);
      transition: .18s ease-in-out;
      border-radius: 20px;
      border: 1px solid var(--mac-border-subtle);
    }
    .mac-slider:before {
      position: absolute; content: ""; height: 16px; width: 16px; left: 1px; bottom: 1px;
      background-color: white;
      transition: .18s ease-in-out;
      border-radius: 50%;
      box-shadow: 0 1px 3px rgba(0,0,0,0.4);
    }
    input:checked + .mac-slider {
      background-color: var(--apple-green);
      border-color: rgba(48, 209, 88, 0.4);
    }
    input:checked + .mac-slider:before {
      transform: translateX(16px);
    }
'''
html = html.replace("@keyframes fadeIn {", switch_css + "\n    @keyframes fadeIn {")

# 添加 无感自动化守护中心 卡片
automation_card = '''
      <!-- 无感自动化守护中心 -->
      <div class="mac-card">
        <div class="mac-card-header">
          <span class="mac-card-title">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            无感自动化守护中心 (Silent Automation Engine)
          </span>
          <span class="mac-card-subtitle">后台常驻守护 · 毫秒级无感生效</span>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr 1.2fr; gap: 12px;">
          <div class="stat-tile" style="padding: 10px 12px;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <span class="stat-label">Token 永不掉线</span>
              <span class="window-title-badge"><span class="pulse-dot"></span> 自动续期</span>
            </div>
            <div style="font-size: 11px; color: var(--mac-text-secondary); margin-top: 4px; line-height: 1.4;">
              钥匙串凭证到期前 15 分钟后台自动静默换发新 Token，无感保活
            </div>
          </div>

          <div class="stat-tile" style="padding: 10px 12px;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <span class="stat-label">号池额度静默同步</span>
              <span class="window-title-badge" style="background: rgba(10, 132, 255, 0.14); color: var(--apple-blue); border-color: rgba(10, 132, 255, 0.25);">每 3 分钟</span>
            </div>
            <div style="font-size: 11px; color: var(--mac-text-secondary); margin-top: 4px; line-height: 1.4;">
              直连 Google Cloud 专有端点后台自动拉取全部小号实时独立额度
            </div>
          </div>

          <div class="stat-tile" style="padding: 10px 12px;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <span class="stat-label">额度耗尽自动切号 (Auto Failover)</span>
              <label class="mac-switch">
                <input type="checkbox" id="autoSwitchToggle" onchange="toggleAutoSwitch(this)" checked>
                <span class="mac-slider"></span>
              </label>
            </div>
            <div style="font-size: 11px; color: var(--mac-text-secondary); margin-top: 4px; line-height: 1.4;">
              当前小号 5h 额度耗尽 (≤2%) 时，后台自动轮转至号池额度最高账号
            </div>
          </div>
        </div>
      </div>
'''
html = html.replace("<!-- 当前会话实时 Token 看板 -->", automation_card + "\n      <!-- 当前会话实时 Token 看板 -->")

# 添加 JS 逻辑
js_logic = '''
    async function toggleAutoSwitch(checkbox) {
      try {
        const res = await fetch('/api/toggle-auto-switch', { method: 'POST' });
        const data = await res.json();
        checkbox.checked = data.autoSwitch;
        showNotice(data.autoSwitch ? '已启用「额度耗尽自动无感切号」' : '已停用「额度耗尽自动切号」', true);
      } catch (e) {
        showNotice('切换设置失败: ' + e.message);
      }
    }
'''
html = html.replace("async function loadData() {", js_logic + "\n    async function loadData() {")

html = html.replace("renderPool(data.pool);", "renderPool(data.pool);\n        if (typeof data.autoSwitch !== 'undefined') { const t = document.getElementById('autoSwitchToggle'); if (t) t.checked = data.autoSwitch; }")

with open("/Users/yohanes/antigravity-switcher/index.html", "w", encoding="utf-8") as f:
    f.write(html)

print("HTML Patched.")
