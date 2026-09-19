#!/usr/bin/env node
/**
 * Google AI Studio 官方 Gemini API 测试脚本
 * 用法: node test_gemini_official.mjs <YOUR_API_KEY>
 */

const apiKey = process.argv[2] || process.env.GEMINI_API_KEY;

if (!apiKey) {
  console.log(`
[使用说明]
请前往 Google AI Studio 免费获取 API Key：https://aistudio.google.com/
获取后运行：
  node test_gemini_official.mjs AIzaSy...
`);
  process.exit(1);
}

const model = 'gemini-1.5-flash'; // 可切换为 gemini-1.5-pro 或 gemini-2.0-flash
const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

console.log(`\n===> 正在连接 Google AI Studio 官方 API (${model})...\n`);

async function testAPI() {
  const startTime = Date.now();
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text: "请用一句话证明你能正常响应，并说明你是什么模型。" }]
          }
        ]
      })
    });

    const data = await res.json();
    const elapsed = Date.now() - startTime;

    if (!res.ok) {
      console.error(`[请求失败] HTTP ${res.status}:`, JSON.stringify(data, null, 2));
      return;
    }

    const reply = data.candidates?.[0]?.content?.parts?.[0]?.text;
    console.log(`[测试成功] 耗时: ${elapsed}ms`);
    console.log(`[模型回复]:\n${reply}\n`);
    console.log(`[Token 统计]:`, data.usageMetadata || '未返回');
  } catch (err) {
    console.error(`[网络异常] 无法连接到 Google 官方端点:`, err.message);
    console.log(`提示: 请确保当前终端环境具备能够正常访问 Google 的网络代理。`);
  }
}

testAPI();
