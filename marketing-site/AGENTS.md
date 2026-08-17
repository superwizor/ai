<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# Run the tests before committing

```bash
pnpm test:all      # typy → jednostkowe (vitest) → E2E (Playwright)
```

Uruchom to **przed każdym commitem i przed każdym merge do `main`**.

**CI nie uruchamia testów E2E.** Workflow robi typy, l10n, testy jednostkowe
i build; Playwright wymaga przeglądarki i serwera dev, więc zostaje po stronie
autora zmiany. Zielone CI **nie** oznacza, że E2E przeszły.

Pojedyncze warstwy, gdy pracujesz nad czymś wąskim:

```bash
pnpm typecheck                 # tsc --noEmit
pnpm test                      # jednostkowe
pnpm test:watch                # jednostkowe, tryb ciągły
pnpm test:e2e                  # E2E headless
pnpm test:e2e:ui               # E2E interaktywnie (debugowanie)
pnpm test:e2e:install          # jednorazowo: pobranie Chromium
```

**Stan zestawu E2E (2026-08-07):** 256 przypadków, 0–3 pada zależnie od
przebiegu (było 34). Reszta padnięć to niestabilność w `account-settings`
i `dashboard-handheld` — dzielą jedną sesję logowania z `beforeEach`.
Porównuj **liczbę** padnięć przed i po zmianie:

```bash
rm -rf .next && pnpm test:e2e 2>&1 | grep -c "✘"
```

**`rm -rf .next` jest obowiązkowe.** Przełączanie gałęzi przy działającym
serwerze dev rozjeżdża cache i daje lawinę `SyntaxError ... after JSON` —
ten sam commit dawał 176 padnięć na brudnym cache i 35 po jego usunięciu.

**Część testów wymaga lokalnego `billing-svc` na porcie 8081.**
`next.config.ts:43` przepisuje tam `/api/checkout`. Bez tej usługi pada
14 przypadków w `register-flow` i `crm-onboarding-stripe` — wygląda to
na regresję, a jest brakiem usługi. Sprawdź port, zanim zaczniesz szukać
winy w swojej zmianie.

**Stan zastany (2026-08-11):** 8 padnięć w `register-therapist`
(`label[for="uiLanguage"]`) istnieje niezależnie od bieżących zmian —
spec rozjechał się z interfejsem. Potwierdzone przez `git stash` samych
plików źródłowych i ponowny przebieg.

**`--workers=2` jest wbudowane w skrypt `test:e2e`** i ma tam zostać.
Przy domyślnej równoległości serwer dev produkuje 164 fałszywe padnięcia.

Szczegóły: `../docs/61_TESTY_MARKETING_SITE.md` §3a.

Dwie pułapki, które już nas kosztowały czas:

- **`pnpm test` nie sprawdza typów.** Test przechodzi, `tsc` i `next build`
  padają na tym samym pliku. Dlatego `test:all` zaczyna od `typecheck`.
- **Testy E2E mockują RPC bez sprawdzania nagłówków**, więc nie wyłapią
  wywołania wysłanego bez tokenu. Pilnują tego testy jednostkowe w
  `src/lib/connect/` i `src/lib/firebase/`.

Po napisaniu testu regresji zepsuj kod celowo i sprawdź, że test pada.

Pełny opis: `../docs/61_TESTY_MARKETING_SITE.md`.
