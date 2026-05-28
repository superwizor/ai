import { chromium } from "@playwright/test";

const URL = "https://superwizor.web.app/pl/register/therapist/";
const email = `probe-${Date.now()}@example.com`;
const password = "Probe1234TestSecret";

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext();
const page = await ctx.newPage();

const consoleMsgs = [];
page.on("console", (msg) => consoleMsgs.push({ type: msg.type(), text: msg.text() }));

const responses = [];
page.on("requestfinished", async (req) => {
  const url = req.url();
  if (!/(identitytoolkit|identity-svc|billing-svc|clinical-svc)/.test(url)) return;
  try {
    const res = await req.response();
    let body = "";
    try {
      body = (await res?.text()) ?? "";
    } catch {}
    let postData = "";
    try {
      postData = req.postData() ?? "";
    } catch {}
    responses.push({
      method: req.method(),
      status: res?.status() ?? 0,
      url,
      request_body: postData.slice(0, 600),
      response_body: body.slice(0, 600),
    });
  } catch (e) {
    responses.push({ url, error: String(e) });
  }
});

await page.goto(URL, { waitUntil: "networkidle" });

// Wait for the modality dropdown to populate from clinical-svc.ListModalities
// (now fetched client-side post-mount). Options arrive ~150ms after first
// paint; bail out at 10s with a hard error so we don't submit a half-loaded
// form silently.
await page.waitForFunction(
  () => document.querySelectorAll("#modality option").length > 1,
  { timeout: 10000 },
);

await page.fill("#email", email);
await page.fill("#password", password);
await page.fill("#firstName", "Probe");
await page.fill("#lastName", "Tester");
// Value is a UUID now (from ListModalities RPC); pick by visible label.
// Polish label for CBT is "Poznawczo-behawioralna (CBT)".
// Pick the CBT option by reading its UUID value (label match isn't a
// regex-aware operator in Playwright; do an in-page query instead).
const cbtValue = await page.locator('#modality option', { hasText: /CBT/i }).first().getAttribute("value");
await page.locator("#modality").selectOption(cbtValue);
await page.locator("#tos").check();
await page.getByRole("button", { name: /załóż konto/i }).click();

let outcome = "timeout";
try {
  await Promise.race([
    page.waitForURL(/verify-email/i, { timeout: 25000 }).then(() => { outcome = "success"; }),
    page.locator('p[role="alert"]').filter({ hasText: /\S/ }).first().waitFor({ timeout: 25000, state: "visible" }).then(() => { outcome = "error_banner"; }),
  ]);
} catch {}
await page.waitForTimeout(2500);

const errorBanners = await page.locator('p[role="alert"], .text-magma').allTextContents();

console.log(JSON.stringify({
  email_used: email,
  url_after_submit: page.url(),
  outcome,
  error_banners: errorBanners.map((t) => t.trim()).filter(Boolean),
  console_errors: consoleMsgs.filter((m) => m.type === "error").map((m) => m.text.slice(0, 200)),
  network: responses,
}, null, 2));

await browser.close();
