import puppeteer from 'puppeteer';
import { resolve } from 'path';

const slides = [
  { html: '../scratch/slide.html', img: '../scratch/slide_preview.png' },
  { html: '../scratch/slide2.html', img: '../scratch/slide2_preview.png' }
];

const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox'] });
try {
  for (const slide of slides) {
    const url = 'file://' + resolve(slide.html);
    const outPath = resolve(slide.img);
    console.log(`Opening: ${url}`);
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
    await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 });
    await page.screenshot({ path: outPath, fullPage: false });
    console.log(`✓ Saved slide preview to ${outPath}`);
    await page.close();
  }
} finally {
  await browser.close();
}
