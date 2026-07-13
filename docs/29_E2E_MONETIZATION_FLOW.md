---
type: System Documentation
title: "29. E2E Monetization Flow — Od Rejestracji do Raportu"
description: "Dokument opisuje pełny przepływ monetyzacji (end-to-end) jaki zbudowaliśmy w ramach sesji „Łączymy klocki\" — od kliknięcia CTA na stronie marketingowej do wy..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/29_E2E_MONETIZATION_FLOW.md
tags: []
timestamp: 2026-06-09T00:28:09+02:00
---

# 29. E2E Monetization Flow — Od Rejestracji do Raportu

Dokument opisuje pełny przepływ monetyzacji (end-to-end) jaki zbudowaliśmy w ramach sesji „Łączymy klocki" — od kliknięcia CTA na stronie marketingowej do wygenerowania pierwszego raportu w aplikacji Flutter.

---

## 1. Przegląd Przepływu

```
Terapeuta widzi LP
    │
    ├─► Klika "Wypróbuj za darmo" → #cennik (scroll)
    │
    ├─► Widzi 3 karty: Poznanie (trial) | Równowaga (179 zł) | Rozkwit (299 zł)
    │
    ├─► Klika CTA na wybranej karcie
    │       ├── Trial → /register/therapist
    │       └── Płatny → /register/therapist?plan=solo_monthly
    │
    ├─► Formularz rejestracji (email/hasło lub Google)
    │       └── Firebase createUserWithEmailAndPassword
    │       └── identity-svc CreateUser → users + organizations + subscriptions (MANUAL trial)
    │
    ├─► Routing po rejestracji (post-registration.ts):
    │       ├── Trial/Beta → /register/therapist/verify-email
    │       └── Paid → POST /api/checkout → Stripe Checkout URL → redirect
    │
    ├─► [Paid] Stripe Checkout (polska wersja):
    │       ├── Email: pre-filled z Firebase
    │       ├── Telefon: wymagany (phone_number_collection)
    │       ├── NIP: opcjonalny (tax_id_collection)
    │       ├── Adres: wymagany (billing_address_collection)
    │       ├── VAT: automatyczny 23% (automatic_tax)
    │       ├── Kupony: ROWNOWAGA / ROZKWIT / PIONIER33
    │       └── Sukces → /register/therapist/success?session_id=xxx
    │
    ├─► Stripe Webhook → billing-svc:
    │       ├── customer.subscription.created → upsert subscription + deactivate trial
    │       └── checkout.session.completed → log org→sub link
    │
    ├─► Onboarding Wizard (6 kroków, Framer Motion):
    │       1. Weryfikacja email
    │       2. Profil (imię, nazwisko, tytuł) → UpdateProfile RPC
    │       3. Telefon → UpdateProfile RPC
    │       4. Praktyka (rozmiar, modalność)
    │       5. Preferencje (język raportów)
    │       6. Sukces (konfetti 🎉 + pobranie app)
    │
    ├─► Pobiera aplikację Flutter (TestFlight / Web)
    │       └── Loguje się tymi samymi credentialami
    │
    ├─► Nagrywa pierwszą sesję
    │       ├── Audio → GCS (signed URL via ingestion-svc)
    │       ├── STT (Chirp 3) → transkrypcja
    │       ├── LLM (Gemini 2.5 PRO) → raport kliniczny + HiTOP
    │       └── Push notification (FCM) → "Raport gotowy"
    │
    └─► Otwiera raport w aplikacji ✅
```

---

## 2. Konfiguracja Stripe Checkout

Plik: `marketing-site/src/app/api/checkout/route.ts`

```typescript
const sessionParams: Stripe.Checkout.SessionCreateParams = {
  mode: "subscription",
  line_items: [{ price: priceId, quantity: 1 }],
  metadata: { organization_id: organizationId },
  subscription_data: {
    metadata: { organization_id: organizationId },  // double-link
  },
  allow_promotion_codes: true,
  phone_number_collection: { enabled: true },
  tax_id_collection: { enabled: true },
  billing_address_collection: "required",
  automatic_tax: { enabled: true },
  locale: "pl",
};

// Pre-fill email z Firebase
if (email) sessionParams.customer_email = email;
```

### Kluczowe decyzje:

| Parametr | Wartość | Powód |
|---|---|---|
| `billing_address_collection` | `"required"` | Wymagane do prawidłowej faktury VAT |
| `automatic_tax` | `{ enabled: true }` | Automatyczny 23% VAT (Polska) |
| `customer_email` | pre-filled | UX — user nie wpisuje emaila ponownie |
| `allow_promotion_codes` | `true` | Kupony wpisywane ręcznie w checkout |
| `phone_number_collection` | `{ enabled: true }` | Marcin potrzebuje do follow-upów |
| `tax_id_collection` | `{ enabled: true }` | NIP dla terapeutów z JDG |
| `locale` | `"pl"` | Cały checkout po polsku |

### Metadata Flow:

```
Session metadata.organization_id ──► checkout.session.completed handler (log)
Subscription metadata.organization_id ──► subscription.created handler (upsert)
```

Podwójne linkowanie zapewnia, że nawet jeśli jeden event dotrze pierwszy, drugi może dopasować subskrypcję do organizacji.

---

## 3. Cennik (plans.ts — Source of Truth)

| Plan | Cena brutto /mies | Cena brutto /rok | Sesje/mies | Stripe Price ID (Sandbox) |
|---|---|---|---|---|
| **Poznanie** (Trial) | 0 zł | — | 5 | — (auto-provisioned) |
| **Równowaga** (Solo) | 179 zł | 1 790 zł | 30 | `price_1TgAk2E5jzWcAIgeQ572wpkE` / `price_1TgAlxE5jzWcAIgedH5FM8No` |
| **Rozkwit** (Pro) | 299 zł | 2 990 zł | 90 | `price_1TgAnSE5jzWcAIgeshZ6TqG8` / `price_1TgAqVE5jzWcAIgeOh1veVjP` |
| **Klinika** (Clinic) | 999 zł | 9 990 zł | 150 | — (wkrótce) |

### Kupony (Stripe Sandbox):

| Kod | Zniżka | Zastosowanie |
|---|---|---|
| ROWNOWAGA / ROWNOWAGA20 | -50 zł (dokładnie 99 zł) | Plan Równowaga |
| ROZKWIT / ROZKWIT30 | -100 zł (dokładnie 199 zł) | Plan Rozkwit |
| PIONIER33 | -33% (około 99.83 zł / 998 zł) | Wszyscy early adopters (beta) |

---

## 4. Webhook Billing Pipeline

Plik: `billing-svc/internal/adapters/http/stripe_handler.go`

### Event Routing:

| Stripe Event | Handler | Efekt w DB |
|---|---|---|
| `checkout.session.completed` | Log org↔sub link | Tylko log |
| `customer.subscription.created` | `upsertSubscriptionFromStripe` | INSERT/UPDATE `subscriptions` + `usage_counters` |
| `customer.subscription.updated` | `upsertSubscriptionFromStripe` | UPDATE status/plan/period |
| `customer.subscription.deleted` | Set CANCELED | `subscriptions.status = 'CANCELED'` |
| `invoice.paid` | Create usage_counter | Nowy `usage_counters` row (tokens_used=0) — **ADR-BL-003** |
| `invoice.payment_failed` | Set PAST_DUE | `subscriptions.status = 'PAST_DUE'` |

### Idempotency:

- `payment_events.UNIQUE(provider, provider_event_id)` — `ON CONFLICT DO NOTHING`
- `usage_counters.UNIQUE(subscription_id, period_start)` — chroni przed podwójnym resetem
- `upsertSubscriptionFromStripe` działa w transakcji:
  1. `DeactivateOtherActiveSubscriptions` (cancels old trial/manual)
  2. `UpsertStripeSubscription` (insert or update)
  3. `CreateUsageCounter` (if ACTIVE/TRIALING)
  4. `tx.Commit()`

### Signature Verification:

Zero-deps HMAC-SHA256 (stdlib only). Format: `HMAC-SHA256(whsec_key, "{timestamp}.{body}")`. Tolerance: 300s.

---

## 5. Onboarding Wizard

Plik: `marketing-site/src/components/onboarding/OnboardingWizard.tsx`

6-krokowy wizard z pełnoekranowymi kartami i Framer Motion (spring transitions):

| Krok | Tytuł | Pola | Persystencja |
|---|---|---|---|
| 1 | ✉️ Zweryfikuj email | — (auto-check) | Firebase Auth |
| 2 | 👋 Miło Cię poznać | Imię, Nazwisko, Tytuł zawodowy | `identity-svc.UpdateProfile` → `users` |
| 3 | 📱 Numer telefonu | Telefon | `identity-svc.UpdateProfile` → `users.phone_number` |
| 4 | 🏥 Twoja praktyka | Rozmiar praktyki, Modalność | Frontend only (na razie) |
| 5 | 🎯 Preferencje | Język raportów | Frontend only (na razie) |
| 6 | 🎉 Gotowe! | — (konfetti + link do app) | — |

Animacje: Framer Motion `AnimatePresence` z `spring` transition (stiffness: 300, damping: 30).

---

## 6. Email System

### Firebase Auth Emails (automatyczne):
- `sendEmailVerification` — po rejestracji
- `sendPasswordResetEmail` — z formularza logowania ("Zapomniałem hasła")

### Resend Transactional Emails (notification-svc):
10 szablonów w `notification-svc/internal/i18n/templates/pl/`:

| Szablon | Trigger |
|---|---|
| `welcome.md` | Po rejestracji |
| `email_verification.md` | Email confirmation |
| `followup_1.md` | 3 dni po rejestracji |
| `followup_2.md` | 7 dni po rejestracji |
| `trial_exhausted.md` | Trial wyczerpany |
| `quota_warning.md` | Zostało ≤3 kredyty |
| `renewal_reminder.md` | 3 dni przed odnowieniem |
| `beta_expiry_alert.md` | Beta kończy się |
| `invitation.md` | Zaproszenie do zespołu |
| `action_plan.md` | Plan działania pacjenta |

### CRM Emails (ręczne, Marcin):
5 szablonów w `CRMDashboard.tsx` — otwierają `mailto:` link z pre-filled treścią.

---

## 7. Procedura Przejścia Sandbox → Live

| Krok | Co zrobić | Gdzie |
|---|---|---|
| 1 | Stwórz 4 ceny w Live Mode | Stripe Dashboard → Products |
| 2 | Stwórz kupony w Live Mode | Stripe Dashboard → Coupons |
| 3 | Włącz Tax w Live Mode | Stripe Dashboard → Tax → Poland/23% |
| 4 | Stwórz webhook endpoint w Live | Stripe Dashboard → Webhooks |
| 5 | Podmień `STRIPE_SECRET_KEY` | GCP Secret Manager (prod) |
| 6 | Podmień `STRIPE_WEBHOOK_SECRET` | GCP Secret Manager (prod) |
| 7 | Update `subscription_plans` w DB | SQL: `UPDATE subscription_plans SET stripe_price_id = 'price_live_xxx'` |
| 8 | Podmień `NEXT_PUBLIC_STRIPE_KEY` | Cloud Run env (marketing-site prod) |

**Kod nie wymaga żadnych zmian** — wszystkie Price ID i sekrety są w env vars / DB.
