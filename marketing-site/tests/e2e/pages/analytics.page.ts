// Page Object for the admin analytics dashboard.
//
// Encapsulates tab switching, KPI card assertions, and dashboard
// loading states so spec files stay readable and refactor-safe.

import { expect, type Locator, type Page } from "@playwright/test";
import { forLocale } from "../_locales";

export class AnalyticsDashboardPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly errorTitle: Locator;
  readonly retryButton: Locator;
  readonly loadingSkeleton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.heading = page.locator("h1");

    const errorTitleText = forLocale({
      pl: "Błąd ładowania",
      en: "Loading Error",
    });
    this.errorTitle = page.locator(`text=${errorTitleText}`);

    const retryText = forLocale({ pl: /Spróbuj ponownie/i, en: /Retry/i });
    this.retryButton = page.getByRole("button", { name: retryText });

    // The loading skeleton uses animate-pulse
    this.loadingSkeleton = page.locator(".animate-pulse").first();
  }

  /** Assert the dashboard title is visible. */
  async expectDashboardLoaded() {
    const title = forLocale({
      pl: "Centrum Analityczne",
      en: "Analytics Center",
    });
    await expect(this.heading).toContainText(title, { timeout: 10_000 });
  }

  /** Assert error state is shown. */
  async expectErrorState() {
    await expect(this.errorTitle).toBeVisible();
    await expect(this.retryButton).toBeVisible();
  }

  // ── Tab Navigation ─────────────────────────────────────────────

  async switchToTab(tab: "overview" | "costs" | "quality" | "funnel" | "ops") {
    const tabNames: Record<string, { pl: string; en: string }> = {
      overview: { pl: "Przegląd", en: "Overview" },
      costs: { pl: "Koszty i Ekonomika", en: "Costs & Economics" },
      quality: { pl: "Jakość AI", en: "AI Quality" },
      funnel: { pl: "Lejek i Retencja", en: "Funnel & Retention" },
      ops: { pl: "Operacje", en: "Operations" },
    };
    const name = forLocale(tabNames[tab] as { pl: string; en: string });
    await this.page.getByRole("button", { name }).click();
  }

  // ── KPI Card Assertions ────────────────────────────────────────

  async expectKpiVisible(titleKey: string) {
    await expect(this.page.locator(`text=${titleKey}`)).toBeVisible();
  }

  async expectValueVisible(value: string) {
    await expect(this.page.locator(`text=${value}`).first()).toBeVisible();
  }
}
