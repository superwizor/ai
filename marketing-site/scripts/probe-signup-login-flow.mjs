// Full E2E probe: marketing-site signup → Flutter web login → therapist
// console hydrated.
//
// Steps:
//   1. Open marketing-site /pl/register/therapist/, fill the form, submit.
//      Pass-fail = server CreateUser + UpdateProfile both 200 + we land
//      on /verify-email/.
//   2. Skip the click-the-link email-verification gate (no inbox in CI;
//      Firebase Auth lets unverified accounts sign in, so the login still
//      works — gating happens client-side, downstream of login).
//   3. Open Flutter web at superwizor-app.web.app, type creds into the
//      semantic <input> nodes Flutter exposes for screen-readers, click
//      the login button.
//   4. Verify we leave the login screen (semantic tree no longer has the
//      "password" input) and capture a screenshot of the resulting view.
//
// Output: a JSON summary on stdout. Screenshots dropped under
//   evidence/e2e-signup-login/<step>.png

import { chromium } from "@playwright/test";
import { mkdir } from "node:fs/promises";

const MARKETING_URL = "https://superwizor.web.app/pl/register/therapist/";
const FLUTTER_URL = "https://superwizor-app.web.app/";
const EVIDENCE = "./evidence/e2e-signup-login";
await mkdir(EVIDENCE, { recursive: true });

const email = `e2e-${Date.now()}@example.com`;
const password = "ProbePassword123!";

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext();
const log = (k, v) => console.log(JSON.stringify({ step: k, ...v }));

async function signup() {
  const page = await ctx.newPage();
  const respLog = [];
  page.on("requestfinished", async (req) => {
    const url = req.url();
    if (!/(identity-svc|clinical-svc|identitytoolkit)/.test(url)) return;
    try {
      const res = await req.response();
      respLog.push({ method: req.method(), status: res?.status() ?? 0, url: url.split("/").slice(-2).join("/") });
    } catch {}
  });

  await page.goto(MARKETING_URL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => document.querySelectorAll("#modality option").length > 1, { timeout: 10000 });
  await page.fill("#email", email);
  await page.fill("#password", password);
  await page.fill("#firstName", "E2E");
  await page.fill("#lastName", "Probe");
  const cbtValue = await page.locator("#modality option", { hasText: /CBT/i }).first().getAttribute("value");
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
  await page.screenshot({ path: `${EVIDENCE}/01-signup-done.png`, fullPage: true });
  const banners = await page.locator('p[role="alert"]').allTextContents();
  await page.close();

  return { outcome, banners, requests: respLog, final_url: page.url() };
}

async function loginToFlutter() {
  const page = await ctx.newPage();
  const consoleErrors = [];
  page.on("console", (m) => { if (m.type() === "error") consoleErrors.push(m.text().slice(0, 250)); });
  const pageErrors = [];
  page.on("pageerror", (e) => pageErrors.push(String(e).slice(0, 250)));
  const respLog = [];
  page.on("requestfinished", async (req) => {
    const url = req.url();
    if (!/(identity-svc|clinical-svc|billing-svc|identitytoolkit)/.test(url)) return;
    try {
      const res = await req.response();
      respLog.push({ method: req.method(), status: res?.status() ?? 0, url: url.split("/").slice(-2).join("/") });
    } catch {}
  });

  await page.goto(FLUTTER_URL, { waitUntil: "load", timeout: 45000 });
  // Flutter web boots async — Firebase + asset fonts take ~5-8s. Wait
  // for the accessibility-enable placeholder which Flutter injects on
  // every web target as the first semantics node.
  await page.locator("flt-semantics-placeholder").waitFor({ timeout: 30000 });
  // Click it to switch Flutter into accessibility mode — this is what
  // promotes the offscreen widget tree into real DOM <input> /
  // <button role> nodes that Playwright can interact with. Without
  // this step Flutter only paints into the canvas and there's no DOM
  // to grab.
  // The placeholder is 1×1px at (-1, -1) — outside the viewport. A
  // normal click times out; trigger it via JS instead.
  await page.evaluate(() => {
    const el = document.querySelector("flt-semantics-placeholder");
    if (el) (el).click();
  });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${EVIDENCE}/02-flutter-loaded.png`, fullPage: true });

  // Wait for the login screen's email field to materialise in the
  // semantic tree. Flutter exposes TextField widgets as <input>.
  await page.locator("input").first().waitFor({ timeout: 15000 });
  const inputCount = await page.locator("input").count();
  await page.screenshot({ path: `${EVIDENCE}/03-flutter-pre-fill.png`, fullPage: true });

  // Attempt the login. We know the order: first input = email, second = password.
  let outcome = "no_inputs_found";
  if (inputCount >= 2) {
    await page.locator("input").nth(0).fill(email);
    await page.locator("input").nth(1).fill(password);
    // Find the submit button by accessible name (the login button).
    // Flutter materialises buttons with role="button" + aria-label.
    const loginBtn = page.getByRole("button").filter({ hasText: /zaloguj|log.?in/i });
    if (await loginBtn.count() > 0) {
      await loginBtn.first().click();
    } else {
      // Fallback: hit enter
      await page.locator("input").nth(1).press("Enter");
    }
    await page.waitForTimeout(6000);
    await page.screenshot({ path: `${EVIDENCE}/04-flutter-after-login.png`, fullPage: true });

    const passwordStillVisible = await page.locator("input[type='password']").count();
    outcome = passwordStillVisible === 0 ? "logged_in" : "still_on_login";
  }

  await page.close();
  return { outcome, input_count: inputCount, console_errors: consoleErrors, page_errors: pageErrors, requests: respLog };
}

const signupResult = await signup();
log("signup", signupResult);

const loginResult = await loginToFlutter();
log("login", loginResult);

await browser.close();
console.log(JSON.stringify({
  account_email: email,
  signup_outcome: signupResult.outcome,
  login_outcome: loginResult.outcome,
  evidence_dir: EVIDENCE,
}, null, 2));
