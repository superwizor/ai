#!/usr/bin/env node
// Full-page screenshot — single capture of the whole document height.
// Use this for evidence on long pages (landing, pricing) where the
// viewport-clip snap.mjs only catches the hero.
//
// Usage: node scripts/snap-full.mjs <url> <out-path.png> [accept-language]
// e.g.   node scripts/snap-full.mjs http://localhost:3000/ \
//          evidence/slice-2/landing-page/home-pl-full.png pl-PL

import puppeteer from "puppeteer";
import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const [, , url, outPath, acceptLanguage] = process.argv;
if (!url || !outPath) {
  console.error("Usage: node scripts/snap-full.mjs <url> <out-path.png> [accept-language]");
  process.exit(2);
}

const abs = resolve(outPath);
await mkdir(dirname(abs), { recursive: true });

const browser = await puppeteer.launch({ headless: "new", args: ["--no-sandbox"] });
try {
  const page = await browser.newPage();
  if (acceptLanguage) {
    await page.setExtraHTTPHeaders({ "Accept-Language": acceptLanguage });
  }
  // Desktop viewport — full-page snap follows the document height
  // regardless, but the layout-conscious breakpoint is the meaningful
  // dimension for evidence.
  await page.setViewport({ width: 1280, height: 800, deviceScaleFactor: 1 });
  await page.goto(url, { waitUntil: "networkidle0", timeout: 30000 });
  await page.screenshot({ path: abs, fullPage: true });
  console.log(`✓ ${abs}`);
} finally {
  await browser.close();
}
