// Playwright config for the marketing-site E2E suite.
//
// Boots a dev server before running tests (Playwright's
// `webServer.command` waits for the port to respond). Tests live
// under `tests/e2e/`. CI runs them headless with the default
// reporter; locally you can pass --headed for debugging.

import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 30_000,
  fullyParallel: true,
  reporter: process.env.CI ? "github" : "list",
  use: {
    baseURL: "http://localhost:3000",
    // Browser locale drives navigator.languages AND the default
    // Accept-Language. Without this, Playwright Chromium ships en-US
    // and next-intl resolves the EN locale on the bare path.
    locale: "pl-PL",
    extraHTTPHeaders: {
      "Accept-Language": "pl-PL,pl;q=0.9",
    },
    trace: "on-first-retry",
  },
  webServer: {
    // Use a bash wrapper so node@20 + pnpm resolve via the project
    // .bash_profile PATH. Re-uses an already-running dev server if
    // one is up (so iterating locally doesn't spawn duplicates).
    command: "bash -lc 'pnpm dev'",
    url: "http://localhost:3000",
    timeout: 60_000,
    reuseExistingServer: !process.env.CI,
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
