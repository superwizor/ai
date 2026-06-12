// Playwright config for the marketing-site E2E suite.
//
// Boots a dev server before running tests (Playwright's
// `webServer.command` waits for the port to respond). Tests live
// under `tests/e2e/`. CI runs them headless with the default
// reporter; locally you can pass --headed for debugging.

import { defineConfig, devices } from "@playwright/test";

// Per docs/18 §13.11 the launch suite runs every happy-path spec once
// per supported locale. Playwright `projects` is the natural place to
// fan that out — each project sets its own `locale` + Accept-Language
// pair so navigator.languages and the URL routing tier resolve PL or
// EN respectively. Tests read `testInfo.project.name` to switch
// expected UI copy + URL prefix; see helpers in tests/e2e/_locales.ts.

export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 30_000,
  fullyParallel: true,
  reporter: process.env.CI ? "github" : "list",
  // Ignore the setup file — it's not used in the current config.
  testIgnore: [/\.setup\.ts$/],
  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",
  },
  webServer: {
    // Use a bash wrapper so node@20 + pnpm resolve via the project
    // .bash_profile PATH. Re-uses an already-running dev server if
    // one is up (so iterating locally doesn't spawn duplicates).
    // Note: `pnpm start` won't work with `output: export` config.
    // The dev server is used instead which has no export constraint.
    command: "bash -lc 'pnpm dev'",
    url: "http://localhost:3000",
    timeout: 60_000,
    reuseExistingServer: !process.env.CI,
  },
  projects: [
    {
      name: "chromium-pl",
      use: {
        ...devices["Desktop Chrome"],
        locale: "pl-PL",
        extraHTTPHeaders: {
          // next-intl's "as-needed" routing serves PL on the bare path
          // when the Accept-Language header asks for pl. Tests in this
          // project navigate to `/...` (no prefix).
          "Accept-Language": "pl-PL,pl;q=0.9",
        },
      },
    },
    {
      name: "chromium-en",
      use: {
        ...devices["Desktop Chrome"],
        locale: "en-GB",
        extraHTTPHeaders: {
          "Accept-Language": "en-GB,en;q=0.9",
        },
      },
    },
  ],
});
