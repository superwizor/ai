#!/usr/bin/env node
// Puppeteer screenshot helper for evidence/ captures.
//
// Why this exists: `chrome --headless --window-size=375,812 --screenshot`
// doesn't reliably emulate mobile viewport — it shoots at a desktop CSS
// width and just crops to the window size. Puppeteer's setViewport() with
// isMobile/deviceScaleFactor produces real mobile layouts.
//
// Usage: node scripts/snap.mjs <url> <out-dir> [feature-id]
//   e.g. node scripts/snap.mjs http://localhost:3000/ evidence/slice-2/nextjs-scaffold home
//
// Captures three breakpoints (mobile/tablet/desktop) per call.
// Outputs <out-dir>/<feature-id>-{mobile,tablet,desktop}.png

import puppeteer from "puppeteer";
import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const [, , url, outDir, prefix = "home"] = process.argv;
if (!url || !outDir) {
  console.error("Usage: node scripts/snap.mjs <url> <out-dir> [prefix]");
  process.exit(2);
}

const sizes = [
  { name: "mobile",  width: 375,  height: 812,  isMobile: true,  deviceScaleFactor: 2 },
  { name: "tablet",  width: 768,  height: 1024, isMobile: true,  deviceScaleFactor: 2 },
  { name: "desktop", width: 1280, height: 800,  isMobile: false, deviceScaleFactor: 1 },
];

const absOut = resolve(outDir);
await mkdir(absOut, { recursive: true });

const browser = await puppeteer.launch({
  headless: "new",
  args: ["--no-sandbox"],
});

try {
  for (const s of sizes) {
    const page = await browser.newPage();
    await page.setViewport({
      width: s.width,
      height: s.height,
      isMobile: s.isMobile,
      deviceScaleFactor: s.deviceScaleFactor,
      hasTouch: s.isMobile,
    });
    await page.goto(url, { waitUntil: "networkidle0", timeout: 30000 });
    const path = `${absOut}/${prefix}-${s.name}.png`;
    await page.screenshot({ path, fullPage: false });
    console.log(`✓ ${path} (${s.width}x${s.height})`);
    await page.close();
  }
} finally {
  await browser.close();
}
