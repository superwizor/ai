---
type: System Documentation
title: "34. Pokrycie Testowe E2E — Audyt i Wyniki"
description: "Dokument opisuje pełną strategię testów E2E oraz wyniki audytu przeprowadzonego w ramach sesji „Łączymy klocki\"."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/34_E2E_TEST_COVERAGE.md
tags: [ai, analytics, billing, crm, database, frontend, identity, notifications, testing]
timestamp: 2026-06-09T00:28:09+02:00
---

# 34. Pokrycie Testowe E2E — Audyt i Wyniki

Dokument opisuje pełną strategię testów E2E oraz wyniki audytu przeprowadzonego w ramach sesji „Łączymy klocki".

---

## 1. Podsumowanie

**56 testów — wszystkie PASS** (Playwright, Chromium, PL + EN)

Pliki testowe:
- `marketing-site/tests/e2e/crm-onboarding-stripe.spec.ts` — 28 testów × 2 locale = 56

Czas wykonania: ~4.6s

---

## 2. Pokrycie per Obszar

### A. CRM API Contract (5 testów)

| Test | Co sprawdza |
|---|---|
| CRM page loads (mocked) | Route `/admin` istnieje |
| Follow-up API contract | `today_count`, `overdue_count` w response |
| User detail contract | `lifecycle_stage`, notes, tags, `excluded` |
| Lifecycle stage paths | 7 etapów (new→churned) |
| Excluded user filter | Anti-join SQL nie przepuszcza wykluczonych |

### B. Onboarding Wizard (4 testy)

| Test | Co sprawdza |
|---|---|
| Dashboard page exists | Route `/dashboard` dostępny |
| UpdateProfile field mapping | camelCase → snake_case (4 pola) |
| DB persistence tables | `users` tabela, poprawne kolumny |
| 6-step wizard order | email_verification → done |

### C. Stripe Checkout Config (5 testów)

| Test | Co sprawdza |
|---|---|
| API route exists | POST `/api/checkout` → 400 (nie 404) |
| Rejects missing organizationId | 400 + error message |
| Rejects invalid UUID | Format validation |
| Plan catalog integrity | 4 Stripe Price IDs poprawne |
| Critical config flags | 8 parametrów (tax, billing, locale) |

### D. Email & Password Recovery (6 testów)

| Test | Co sprawdza |
|---|---|
| Forgot-password button | Widoczny na `/login` |
| Validation without email | Error po kliknięciu bez emaila |
| Email + password fields | Input fields obecne |
| Verify-email page | Route istnieje |
| Email templates count | 10 szablonów w notification-svc |
| Email transport | Resend (nie SMTP/SES) |

### E. Pricing & Invoice (4 testy)

| Test | Co sprawdza |
|---|---|
| Brutto prices | "brutto" (nie "netto") w sekcji cennika |
| Coupon codes | ROWNOWAGA, ROZKWIT, PIONIER33 widoczne |
| Tax ID collection | `enabled: true` |
| Annual discount | ~17% zniżka vs monthly |

### F. Stripe Webhook Contract (4 testy)

| Test | Co sprawdza |
|---|---|
| 6 event types | checkout/subscription/invoice handlers |
| Stripe-Signature required | `/stripe/webhook` nie działa bez sygnatury |
| Subscription deactivation | Old subs → CANCELED before upsert |
| invoice.paid reset (ADR-BL-003) | usage_counter z tokens_used=0 |

---

## 3. Bugi Znalezione w Audycie

### 🔴 Krytyczne (naprawione)

| Bug | Plik | Fix |
|---|---|---|
| Brak `billing_address_collection` | `route.ts` | Dodano `"required"` |
| Brak `automatic_tax` | `route.ts` | Dodano `{ enabled: true }` |
| Brak `customer_email` pre-fill | `route.ts` + `post-registration.ts` | Dodano `email` do body |

### 🟡 Do zrobienia

| Item | Priorytet | Opis |
|---|---|---|
| Stripe Tax w Dashboard | Wymagane przed Live | Kliknij "Collect and file" → Poland/23% |
| Krok 4+5 onboardingu | Nice-to-have | Practice + Preferences nie persystowane na backend |
| Frontend email pass | Sprawdzić | Czy komponent przekazuje `user.email` do checkout |

---

## 4. Uruchomienie Testów

```bash
# Wszystkie E2E testy
cd marketing-site
npx playwright test

# Tylko ten plik
npx playwright test tests/e2e/crm-onboarding-stripe.spec.ts

# Tylko PL
TEST_LOCALE=pl npx playwright test tests/e2e/crm-onboarding-stripe.spec.ts

# Tylko EN
TEST_LOCALE=en npx playwright test tests/e2e/crm-onboarding-stripe.spec.ts
```

---

## 5. Jak Dodawać Nowe Testy

Testy używają wzorca locale-agnostic z pliku `_locales.ts`:

```typescript
import { forLocale, urlPrefix } from "./_locales";

test("my test", async ({ page }) => {
  const prefix = urlPrefix(); // "" (PL) lub "/en"
  await page.goto(`${prefix}/my-page`);

  const text = forLocale({
    pl: /polska wersja/i,
    en: /english version/i,
  });
  await expect(page.getByText(text)).toBeVisible();
});
```

Każdy test uruchamiany jest 2 razy (PL + EN) dzięki konfiguracji w `playwright.config.ts`:
```typescript
projects: [
  { name: "chromium-pl", use: { ...devices["Desktop Chrome"] } },
  { name: "chromium-en", use: { ...devices["Desktop Chrome"], locale: "en" } },
]
```
