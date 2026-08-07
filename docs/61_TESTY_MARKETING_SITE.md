---
type: System Documentation
title: "61. Testy marketing-site — co uruchamiać i kiedy"
description: "Instrukcja operacyjna dwóch warstw testów panelu webowego: jednostkowych (vitest) i E2E (Playwright). Komendy, zakres, pułapki."
tags: [frontend, testing, ci, playwright, vitest]
timestamp: 2026-08-07T00:00:00+02:00
---

# 61. Testy marketing-site — co uruchamiać i kiedy

Dokument **operacyjny**. Raport z audytu pokrycia z czerwca leży w
`34_E2E_TEST_COVERAGE.md` i jest już nieaktualny (opisuje jeden plik
specyfikacji, gdy jest ich dziesięć) — tu opisujemy stan bieżący i to,
czego wymagamy przed commitem.

---

## 1. Zasada

**Przed każdym commitem i przed każdym merge do `main` uruchom `pnpm test:all`.**

```bash
cd marketing-site && pnpm test:all
```

Jedna komenda robi trzy rzeczy po kolei: typy → testy jednostkowe → E2E.
Zatrzymuje się na pierwszym niepowodzeniu.

Powód, dla którego to jest reguła, a nie sugestia: **CI nie uruchamia
testów E2E**. Workflow `marketing-site.yml` odpala typy, l10n, testy
jednostkowe i build — E2E wymagają przeglądarki i działającego serwera,
więc pozostają po stronie autora zmiany. Jeśli ich nie odpalisz Ty, nie
odpali ich nikt.

---

## 2. Dwie warstwy i podział pracy

| | jednostkowe (vitest) | E2E (Playwright) |
|---|---|---|
| Gdzie | `src/**/*.test.ts` | `tests/e2e/*.spec.ts` |
| Co sprawdzają | reguła jest poprawna | ekran działa |
| Czas | sekundy | ~1–2 min |
| W CI | **tak, blokująco** | **nie** |
| Przeglądarka | nie | tak (Chromium) |

Zestawy celowo się nie dublują. Jednostkowe biorą logikę, którą da się
wywołać bez renderowania; E2E biorą przepływy, gdzie liczy się złożenie
ekranu, nawigacja i kontrakt sieciowy.

---

## 3. Komendy

```bash
pnpm typecheck          # tsc --noEmit
pnpm test               # jednostkowe, jednorazowo
pnpm test:watch         # jednostkowe w trybie ciągłym (przy pisaniu)
pnpm test:e2e           # E2E, headless
pnpm test:e2e:headed    # E2E z widoczną przeglądarką
pnpm test:e2e:ui        # interaktywny tryb Playwrighta (debugowanie)
pnpm test:e2e:report    # raport HTML z ostatniego przebiegu
pnpm test:e2e:install   # jednorazowo: pobranie Chromium
pnpm test:all           # typy + jednostkowe + E2E
```

Pojedynczy plik albo pojedynczy przypadek:

```bash
pnpm vitest run src/lib/connect/transport.test.ts
pnpm test:e2e tests/e2e/register-therapist.spec.ts
pnpm test:e2e -g "happy path"
```

---

## 3a. Stan zestawu E2E na 2026-08-07

Po uzgodnieniu specyfikacji z interfejsem: **256 przypadków, 0–3 pada**
zależnie od przebiegu. Trzy kolejne pomiary: 256/0, 256/0, 253/3.

Punkt wyjścia był inny — 34 padnięcia. Przyczyny, w kolejności wielkości:

| Przyczyna | Ile |
|---|---|
| Polskie napisy na sztywno w spec-u admina (padało tylko w `chromium-en`) | 8 |
| `/api/checkout` zwracał 503 zamiast 400 — konfiguracja Stripe sprawdzana przed walidacją | 12 |
| Atrapa `GetSubscription` z `Timestamp` jako obiektem zamiast łańcucha RFC3339 | 8 |
| Wyścig nawigacji `/dashboard` → `/account` (`net::ERR_ABORTED`) | 4 |
| Formatowanie numeru telefonu, usunięte pole `#professionalTitle`, nagłówki | reszta |

### Co zostaje

**Niestabilność 0–3 przypadków na przebieg**, głównie `account-settings`
i `dashboard-handheld`, za każdym razem inne. Źródło: te specyfikacje
dzielą jedną sesję logowania zakładaną w `beforeEach`. Trwałe
rozwiązanie to osobne konto na plik; nie zostało zrobione.

**Test „can update profile and organization successfully" bywa oporny
w `chromium-en`** — przy teście jest komentarz z tym, co już ustalono.

### Dwie pułapki wbudowane w narzędzia

**`--workers=2` jest w skrypcie `test:e2e`** i ma tam zostać. Przy
domyślnej równoległości serwer dev sypie lawiną `SyntaxError:
Unexpected non-whitespace character after JSON` i produkuje **164
fałszywe padnięcia**. Objaw trzykrotnie doprowadził do błędnego wniosku
o regresji.

**Tryb `serial` w `test.describe.configure` to ZŁE narzędzie na
niestabilność.** Po pierwszym padnięciu Playwright pomija resztę bloku,
więc licznik padnięć spada, choć testy przestają się wykonywać
(„N did not run"). To ukrywanie, nie naprawa. Właściwy jest `default` —
szereguje w jednym workerze i wykonuje wszystko.

**`forLocale()` sięga do `test.info()`**, więc nie wolno go wywołać na
poziomie modułu. Playwright zgłasza wtedy „test.info() can only be
called while test is running" i nie zbiera ani jednego testu. Etykiety
zależne od lokalizacji definiuj jako funkcje, nie stałe.

---

## 4. Jak działa Playwright w tym repo

Konfiguracja: `marketing-site/playwright.config.ts`.

- **Serwer startuje sam.** `webServer` uruchamia `pnpm dev` i czeka na
  `http://localhost:3000`. Lokalnie `reuseExistingServer` jest włączone,
  więc jeśli masz już `pnpm dev`, Playwright go użyje zamiast podnosić
  drugi.
- **Dwa projekty:** `chromium-pl` i `chromium-en`. Każdy test biegnie
  dwa razy, w obu lokalizacjach — dlatego liczba przypadków w raporcie
  jest dwukrotnością liczby testów w plikach.
- **Pliki `*.setup.ts` są POMIJANE** (`testIgnore`). `admin-auth.setup.ts`
  nie uruchamia się dziś jako część zestawu.

---

## 5. Pułapki, na których już się przejechaliśmy

**`pnpm test` nie sprawdza typów.** Vitest transpiluje bez kontroli
typów. Test potrafi przejść, a `tsc` i `next build` paść na tym samym
pliku. Dlatego `test:all` zaczyna od `typecheck`.

**Testy E2E mockują RPC bez sprawdzania nagłówków.** `mockCreateUser` i
`mockUpdateProfile` przyjmują żądanie niezależnie od tego, czy niesie
`Authorization`. Regresja z 2026-08-05 — wywołania szły bez tokenu i
wracały z 401 — przeszłaby przez ten zestaw. Dopisanie asercji na
nagłówek w mockach zamknęłoby tę lukę; dziś pilnują tego testy
jednostkowe `src/lib/connect/transport.test.ts` i
`src/lib/firebase/auth-ready.test.ts`.

**Asercja pod warunkiem to nie asercja.** Konstrukcja
`if (x !== null) expect(x).not.toBe(y)` przechodzi trywialnie, gdy `x`
jest `null` — czyli dokładnie w awarii, przed którą test miał bronić.
Jeśli wartość MUSI istnieć, asertuj to wprost.

**Sprawdź, czy test faktycznie łapie błąd.** Po napisaniu testu regresji
zepsuj celowo kod i upewnij się, że test pada. Test, który przechodzi
zawsze, jest gorszy od jego braku, bo daje fałszywe poczucie pokrycia.

---

## 6. Co pokrywają testy jednostkowe

| Plik | Czego pilnuje |
|---|---|
| `src/lib/connect/transport.test.ts` | Interceptor dołącza token; dostawca asynchroniczny jest odczekany; token odpytywany przy każdym żądaniu (wygasa po godzinie) |
| `src/lib/firebase/auth-ready.test.ts` | Dostawca tokenu nie odpowiada przed zgłoszeniem stanu przez Firebase; limit czasu; synchroniczne zgłoszenie obserwatora |
| `src/lib/errors/translate.test.ts` | Dopasowanie wzorców w kolejności listy; kody ConnectError; treść błędu serwera nie wycieka do interfejsu |
| `src/lib/register/post-registration.test.ts` | Każdy płatny plan ma cenę Stripe i są one różne; plany darmowe jej nie mają |

---

## 7. Dopisywanie testów

Testy jednostkowe leżą **obok modułu**, który testują, z rozszerzeniem
`.test.ts`. Import względny (`./translate`), nie przez alias — alias
zostaw do importów w poprzek katalogów.

`vitest.config.ts` ma `include` ograniczone do `src/`, żeby nie zbierał
specyfikacji Playwrighta — te nie uruchomią się pod vitestem i wywalą
cały przebieg.

Nazwy przypadków opisują **zachowanie**, nie implementację: „e-mail nie
pojawia się, gdy jest pseudonim", a nie „wywołuje getIdToken".
