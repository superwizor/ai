// Broad page crawl: walk the public site, fetch each route, follow
// any same-origin links found in <a href> attributes, and check
// every response for HTTP errors + JS console errors. Output is a
// short report.

import { chromium } from "@playwright/test";

const ORIGIN = "https://superwizor.web.app";
const SEEDS = [
  "/",
  "/pl/",
  "/en/",
  "/pl/pricing/",
  "/en/pricing/",
  "/pl/register/therapist/",
  "/en/register/therapist/",
  "/pl/register/organization/",
  "/en/register/organization/",
  "/pl/legal/terms/",
  "/pl/legal/privacy/",
  "/pl/legal/dpa/",
  "/en/legal/terms/",
];

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext();
const visited = new Set();
const results = [];

async function visit(pathname) {
  if (visited.has(pathname)) return;
  visited.add(pathname);
  const page = await ctx.newPage();
  const consoleErrors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text().slice(0, 200));
  });
  const responseStatuses = new Map();
  page.on("response", (res) => {
    try {
      const u = new URL(res.url());
      if (u.origin === ORIGIN) responseStatuses.set(u.pathname, res.status());
    } catch {}
  });
  let title = "";
  let mainStatus = 0;
  let outboundLinks = [];
  try {
    const resp = await page.goto(ORIGIN + pathname, { waitUntil: "networkidle", timeout: 20000 });
    mainStatus = resp?.status() ?? 0;
    title = await page.title();
    outboundLinks = await page.$$eval("a[href]", (as) =>
      Array.from(as).map((a) => a.getAttribute("href") || "").filter(Boolean),
    );
  } catch (e) {
    results.push({ pathname, status: 0, error: String(e).slice(0, 200) });
    await page.close();
    return;
  }
  results.push({
    pathname,
    status: mainStatus,
    title: title.slice(0, 80),
    console_errors: consoleErrors,
    same_origin_404s: Array.from(responseStatuses.entries())
      .filter(([, s]) => s >= 400)
      .map(([p, s]) => `${s} ${p}`),
  });
  // Recurse same-origin
  for (const href of outboundLinks) {
    try {
      const url = href.startsWith("/")
        ? new URL(ORIGIN + href)
        : new URL(href);
      if (url.origin === ORIGIN && !visited.has(url.pathname)) {
        await visit(url.pathname);
      }
    } catch {}
  }
  await page.close();
}

for (const s of SEEDS) await visit(s);
await browser.close();

const broken = results.filter((r) => r.status >= 400 || r.console_errors.length > 0 || r.same_origin_404s?.length > 0);
const ok = results.filter((r) => !broken.includes(r));

console.log(JSON.stringify({
  total_visited: results.length,
  ok_count: ok.length,
  broken_count: broken.length,
  broken,
  ok_paths: ok.map((r) => `${r.status} ${r.pathname} — ${r.title}`),
}, null, 2));
