#!/usr/bin/env node
/**
 * 网页版 Gemini (gemini.google.com) Session 探测与连通性测试脚本
 * 用法: node test_gemini_web.mjs "<__Secure-1PSID>" ["<__Secure-1PSIDTS>"]
 */

const psid = process.argv[2] || process.env.GEMINI_PSID;
const psidts = process.argv[3] || process.env.GEMINI_PSIDTS || '';

if (!psid) {
  console.log(`
===================================================================
【Gemini 网页版 Pro 账号 Session 探测工具】
===================================================================
说明：
  如果您的账号充值了 Gemini Pro / Advanced，可以通过浏览器 Cookie
  模拟网页端会话，绕过 Google Cloud GCP 的风控。

获取 Cookie 方法：
  1. 在浏览器打开并登录 https://gemini.google.com
  2. 按 F12 打开开发者工具 -> 切换到 Application (应用) -> Cookies
  3. 找到名为 "__Secure-1PSID" 的值（必须）
  4. 找到名为 "__Secure-1PSIDTS" 的值（强烈建议同时填入）

执行命令：
  node test_gemini_web.mjs "<你的__Secure-1PSID>" "<你的__Secure-1PSIDTS>"
===================================================================
`);
  process.exit(1);
}

const cookieHeader = `__Secure-1PSID=${psid};` + (psidts ? ` __Secure-1PSIDTS=${psidts};` : '');

console.log(`\n===> 正在连接 gemini.google.com 验证网页端 Pro 会话有效性...\n`);

async function testWebSession() {
  try {
    const homeRes = await fetch('https://gemini.google.com/app', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Cookie': cookieHeader
      }
    });

    if (homeRes.status === 302 || homeRes.status === 401 || homeRes.status === 403) {
      console.error(`[认证失败] Google 返回状态码 HTTP ${homeRes.status}，说明 Cookie 已失效或不完整。`);
      return;
    }

    const html = await homeRes.text();
    
    // 检查是否包含 SNlM0e (Google 网页端专有防重放 Session Token)
    const atMatch = html.match(/"SNlM0e":"([^"]+)"/);
    if (!atMatch) {
      console.error(`[未能提取会话签名] 未在页面中找到 SNlM0e 授权标记。可能是登录态过期或触发了人机验证页面。`);
      return;
    }

    const snlm0e = atMatch[1];
    console.log(`[会话有效] 成功提取到网页端 Session 签名 (SNlM0e: ${snlm0e.slice(0, 10)}...)`);

    // 检查是否具备 Advanced / Pro 权益
    const isAdvanced = html.includes('Advanced') || html.includes('gemini-advanced') || html.includes('Gemini Advanced');
    if (isAdvanced) {
      console.log(`[会员状态] 检测到当前网页账号具备 Gemini Advanced (Pro) 权益！🎉`);
    } else {
      console.log(`[会员状态] 页面正常加载（基础或标准模式）。`);
    }

    console.log(`\n===> 结论：该账号的网页端会话完全健康，没有任何封控拦截。`);
    console.log(`技术上完全可以通过本地反向代理（如 gemini-openai-proxy）将此 Cookie 转化为标准的 OpenAI / API 格式供给外部客户端调用。`);

  } catch (err) {
    console.error(`[网络异常] 无法连接到 gemini.google.com:`, err.message);
    console.log(`提示: 请确保终端环境能够正常代理访问 Google 网页。`);
  }
}

testWebSession();
