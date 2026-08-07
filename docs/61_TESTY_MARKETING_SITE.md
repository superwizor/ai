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

## 3a. Stan zestawu E2E na 2026-08-07 — CZYTAJ PRZED URUCHOMIENIEM

Pełny przebieg: **256 przypadków, 219 przechodzi, 37 pada.**

Padnięcia to **dług testowy: specyfikacje opisują interfejs sprzed
przebudowy**, nie awaria środowiska.

> **SPROSTOWANIE.** Pierwsza wersja tego akapitu przypisywała padnięcia
> brakowi lokalnego billing-svc (`ECONNREFUSED 127.0.0.1:8081`). To była
> pomyłka — komunikat faktycznie sypał się w logu serwera, ale nie on
> wywracał testy. Sprawdzone eksperymentem:
>
> | uruchomione usługi | przechodzi / pada |
> |---|---|
> | żadne | 222 / 35 |
> | billing-svc (8081) | 223 / 34 |
> | billing-svc + identity-svc (8080) | 222 / 34 |
>
> `ECONNREFUSED` zniknął całkowicie, a padnięć ubyło jedno. Korelacja
> nie była przyczyną.

Prawdziwa przyczyna, ustalona po wyizolowaniu pojedynczego przypadku:

```
expect(locator).toBeVisible() failed
Locator: locator('#professionalTitle')
Error: element(s) not found
```

Pole `professionalTitle` **zostało usunięte z formularza rejestracji**
(występuje już tylko w panelu admina), a test wciąż szuka go na kroku 5.
`git log -S professionalTitle -- src/` pokazuje trzy commity
przebudowujące ten formularz; specyfikacji za nimi nie zaktualizowano.

Sprawdzone także: te same padnięcia występują na `main` i na gałęzi ze
zmianami — porównałem `register-therapist.spec.ts` w obu wersjach,
wynik identyczny (12 przechodzi / 8 pada). To nie jest niczyja regresja,
tylko zaległość.

**Wniosek praktyczny.** Dopóki te 37 nie zostanie oczyszczone,
„E2E przechodzą" nie jest sensownym kryterium. Traktuj zestaw
porównawczo: uruchom przed zmianą i po zmianie, i sprawdź, czy liczba
padnięć **nie wzrosła**. Do tego służy:

```bash
rm -rf .next                          # ZAWSZE przed porównawczym przebiegiem
pnpm test:e2e 2>&1 | grep -c "✘"      # przed zmianą i po zmianie
```

**`rm -rf .next` nie jest przesadną ostrożnością.** Przełączanie gałęzi
albo podmiana plików przy działającym serwerze dev rozjeżdża cache
Next.js, a objawia się to lawiną `SyntaxError: Unexpected non-whitespace
character after JSON` z serwera i setkami padnięć bez związku ze zmianą.
Realny przypadek z 2026-08-07: ten sam commit dawał **176 padnięć** na
brudnym cache i **35** po jego usunięciu. Bez tej wiedzy odrzuca się
poprawną zmianę jako regresję.

Uruchomienie billing-svc lokalnie usuwa większość padnięć — wtedy
kryterium „wszystko zielone" wraca do gry.

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
