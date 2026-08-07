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

**Uwaga o stanie zestawu E2E (2026-08-07):** z ~256 przypadków ~35 pada
z przyczyn środowiskowych — `ECONNREFUSED 127.0.0.1:8081`, bo część
testów idzie przez proxy na lokalne billing-svc. Te same padnięcia są na
`main`. Dopóki nie zostaną oczyszczone, porównuj **liczbę** padnięć przed
i po zmianie, zamiast oczekiwać zieleni:

```bash
rm -rf .next && pnpm test:e2e 2>&1 | grep -c "✘"
```

**`rm -rf .next` jest obowiązkowe** przy takim porównaniu. Przełączanie
gałęzi przy działającym serwerze dev rozjeżdża cache i daje lawinę
`SyntaxError ... after JSON` — ten sam commit dawał 176 padnięć na
brudnym cache i 35 po jego usunięciu. Szczegóły:
`../docs/61_TESTY_MARKETING_SITE.md` §3a.

Dwie pułapki, które już nas kosztowały czas:

- **`pnpm test` nie sprawdza typów.** Test przechodzi, `tsc` i `next build`
  padają na tym samym pliku. Dlatego `test:all` zaczyna od `typecheck`.
- **Testy E2E mockują RPC bez sprawdzania nagłówków**, więc nie wyłapią
  wywołania wysłanego bez tokenu. Pilnują tego testy jednostkowe w
  `src/lib/connect/` i `src/lib/firebase/`.

Po napisaniu testu regresji zepsuj kod celowo i sprawdź, że test pada.

Pełny opis: `../docs/61_TESTY_MARKETING_SITE.md`.
