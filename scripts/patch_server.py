import re

with open("/Users/yohanes/antigravity-switcher/server.mjs", "r", encoding="utf-8") as f:
    code = f.read()

# 替换 loadPool 函数，确保带有 autoSwitch
load_pool_pattern = r'function loadPool\(\) \{[\s\S]*?return \{ accounts: \{\}, active: null \};\s*\}\s*\}'
new_load_pool = '''function loadPool() {
  ensurePoolStorage();
  try {
    const data = JSON.parse(fs.readFileSync(POOL_FILE, 'utf8'));
    if (typeof data.autoSwitch === 'undefined') data.autoSwitch = true;
    return data;
  } catch (e) {
    return { accounts: {}, active: null, autoSwitch: true };
  }
}'''
code = re.sub(load_pool_pattern, new_load_pool, code)

# 增加 switchToAccount 和 autoSilentRefreshRoutine
routine_code = '''
// 核心切号函数（供手动与无感自动调用）
async function switchToAccount(targetEmail) {
  const pool = loadPool();
  const acc = pool.accounts[targetEmail];
  if (!acc) throw new Error(`号池中未找到账号: ${targetEmail}`);

  const refreshed = await refreshToken(acc.refresh_token);
  acc.access_token = refreshed.access_token;
  if (refreshed.id_token) acc.id_token = refreshed.id_token;
  acc.expiry = refreshed.expiry;
  acc.last_updated = new Date().toISOString();

  const authData = {
    token: {
      access_token: acc.access_token,
      token_type: acc.token_type || 'Bearer',
      refresh_token: acc.refresh_token,
      expiry: acc.expiry
    },
    auth_method: 'consumer',
    id_token: acc.id_token
  };
  writeKeychain(authData);

  pool.active = targetEmail;
  savePool(pool);

  restartLanguageServer();
  return acc;
}

// 自动无感刷新与智能轮转守护进程
async function autoSilentRefreshRoutine() {
  const pool = loadPool();

  // 1. 钥匙串当前 Token 临期无感续期检测 (< 15 分钟)
  try {
    const keyData = readCurrentKeychain();
    if (keyData?.token?.refresh_token) {
      const exp = keyData.token.expiry ? new Date(keyData.token.expiry).getTime() : 0;
      const timeLeftMin = Math.round((exp - Date.now()) / 60000);
      if (timeLeftMin < 15) {
        console.log(`[无感续期] 钥匙串当前 Token 仅剩 ${timeLeftMin} 分钟，后台静默自动换新...`);
        const ref = await refreshToken(keyData.token.refresh_token);
        keyData.token.access_token = ref.access_token;
        if (ref.id_token) keyData.id_token = ref.id_token;
        keyData.token.expiry = ref.expiry;
        writeKeychain(keyData);
        console.log(`[无感续期] 钥匙串 Token 已自动无感续期至: ${ref.expiry}`);
      }
    }
  } catch (e) {
    console.error(`[无感续期] 钥匙串检测异常:`, e.message);
  }

  // 2. 号池所有小号额度后台静默拉取
  const accounts = Object.values(pool.accounts || {});
  let activeExhausted = false;
  const currentActive = pool.active;

  for (const acc of accounts) {
    try {
      const q = await fetchAccountQuotaDirect(acc);
      if (q) {
        acc.quota = q;
        acc.last_updated = new Date().toISOString();
        if (acc.email === currentActive) {
          const rem = q.gemini_5h?.remainingFraction ?? 1;
          if (rem <= 0.02) {
            activeExhausted = true;
          }
        }
      }
    } catch (e) {}
  }
  savePool(pool);

  // 3. 额度耗尽自动无感切号 (Auto Failover)
  if (pool.autoSwitch !== false && activeExhausted && accounts.length > 1) {
    const candidates = accounts
      .filter(a => a.email !== currentActive)
      .sort((a, b) => (b.quota?.gemini_5h?.remainingFraction || 0) - (a.quota?.gemini_5h?.remainingFraction || 0));

    if (candidates.length > 0 && (candidates[0].quota?.gemini_5h?.remainingFraction || 0) > 0.15) {
      const best = candidates[0];
      console.log(`[无感切号] 检测到当前账号 ${currentActive} 5h额度已耗尽 (≤2%)，自动无感切号至高额度小号: ${best.email}`);
      await switchToAccount(best.email);
    }
  }
}

// 定时启动无感守护任务 (每 3 分钟巡检一次)
setInterval(autoSilentRefreshRoutine, 3 * 60 * 1000);
setTimeout(autoSilentRefreshRoutine, 5 * 1000);
'''

# 在 restartLanguageServer 后面插入 routine_code
code = code.replace("function restartLanguageServer() {", routine_code + "\nfunction restartLanguageServer() {")

# 简化 switch 接口
switch_pattern = r'if \(url\.pathname === \'/api/switch\' && req\.method === \'POST\'\) \{[\s\S]*?return sendJSON\(\{ success: true, active: targetEmail \}\);\s*\} catch \(err\) \{\s*return sendJSON\(\{ error: err\.message \}, 500\);\s*\}\s*\}'
new_switch = '''if (url.pathname === '/api/switch' && req.method === 'POST') {
    const body = await readBody();
    const targetEmail = body.email;
    try {
      await switchToAccount(targetEmail);
      return sendJSON({ success: true, active: targetEmail });
    } catch (err) {
      return sendJSON({ error: err.message }, 500);
    }
  }

  if (url.pathname === '/api/toggle-auto-switch' && req.method === 'POST') {
    const pool = loadPool();
    pool.autoSwitch = !pool.autoSwitch;
    savePool(pool);
    return sendJSON({ success: true, autoSwitch: pool.autoSwitch });
  }'''
code = re.sub(switch_pattern, new_switch, code)

# 在 /api/status 中输出 autoSwitch 状态
code = code.replace("pool: {", "autoSwitch: pool.autoSwitch !== false,\n      pool: {")

with open("/Users/yohanes/antigravity-switcher/server.mjs", "w", encoding="utf-8") as f:
    f.write(code)

print("Patch applied successfully.")
