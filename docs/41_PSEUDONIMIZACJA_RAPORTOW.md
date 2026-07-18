# 41 — Pseudonimizacja danych identyfikujących w raportach (call-2)

**Status: WDROŻONE** (implementacja zmergowana do main 2026-07-17;
staging pracuje w trybie `all`, utrwalonym jako default w
`infra/environments/staging/variables.tf`; default w module terraform
pozostaje `off`). Bramka jakości: `cmd/pii-eval` (GATE PASS ×3,
2026-07-17) + e2e `TestPseudonymize_E2E` (strict, leaks=[]). Reguły
promptu żyją WYŁĄCZNIE w stałej `pseudonymize.PIIPromptRules` — każdą
zmianę przepuścić przez pii-eval. Rewizja zakresu 2026-07-17: imiona
zostają, pracodawcy/szkoły i miejscowości do tokenów (§1/§1.1/§3.1).
Uzupełnienie 2026-07-18: minimalizacja u źródła domknięta inwariantem
docs/43 §4 (klient bez imion/nazwisk w całym systemie, jedyny
identyfikator = e-mail).

## 1. Cel i rama prawna

Usunąć z tekstu podawanego do call-2 (raport kliniczny) — a docelowo
także z `Title`/`Summary`/tematów RAG — dane identyfikujące osoby.

**Zakres redakcji (rewizja 2026-07-17, decyzja produktowa):**

| Kategoria | Decyzja |
|---|---|
| **Imiona** | **ZOSTAJĄ** — niosą relacyjną treść kliniczną („Karol", „Kasia"), a samo imię identyfikuje słabo; raport pozostaje naturalnie czytelny |
| Nazwiska | redakcja (pełne imię+nazwisko → samo imię; nazwisko solo → `[NAZWISKO-n]`) |
| Identyfikatory: PESEL, nr dokumentów, telefony, e-maile | redakcja (warstwa regex, deterministyczna) |
| Adresy: ulice, numery, kody pocztowe | redakcja |
| Pracodawcy i szkoły | redakcja do tokenu generycznego — patrz §1.1 |
| Miejscowości | redakcja — patrz §1.1 (rozstrzygnięcie graniczne) |
| Daty urodzenia | redakcja (regex + LLM) |

### 1.1 Rozstrzygnięcia kategorii granicznych

**Pracodawcy i szkoły → redakcja do tokenu generycznego** (decyzja
2026-07-17). Uzasadnienie: silne quasi-identyfikatory — imię +
„pracuje w [firma X w Krakowie]" potrafi zidentyfikować osobę bez
nazwiska; klinicznie „konflikt w pracy" niesie tę samą wartość co
„konflikt w [nazwa firmy]". Token `[PRACODAWCA]` / `[SZKOŁA]`,
numerowany tylko gdy w sesji występuje więcej niż jeden podmiot danej
kategorii (`[PRACODAWCA-2]`) — zachowuje rozróżnialność wątków bez
ujawniania nazw.

**Miejscowości → redakcja wszystkich do `[MIEJSCOWOŚĆ-x]`**
(rekomendacja — do akceptacji). Sama „duża" miejscowość identyfikuje
słabo („mieszkam w Krakowie"), ale (a) mała miejscowość identyfikuje
mocno, (b) granica duża/mała jest nieegzekwowalna spójnie przez LLM,
(c) w KOMBINACJI z imieniem i generycznym `[PRACODAWCA]` nawet duże
miasto zawęża („Karol, nauczyciel w [SZKOŁA] w Krakowie"). Jednolita
reguła „wszystkie miejscowości" jest prostsza, testowalna i kosztuje
klinicznie tyle co nic — kontekst „przeprowadzka", „dojazdy" zostaje.
Odrzucona alternatywa: próg wielkości miasta (niespójna egzekucja).

**To jest pseudonimizacja, nie anonimizacja** (RODO art. 4 pkt 5):
dane pozostają danymi osobowymi; zysk to minimalizacja ryzyka —
mniejsza ekspozycja PII w treści raportu, w pamięci długoterminowej
(rag_memories), na listach w UI oraz u podprocesora LLM (Vertex).
Wzmacnia DPIA (docs/37), niczego nie zwalnia. Detekcja jest
best-effort: nazwiska odmienione lub przekręcone przez STT mogą
przejść — dokumentujemy to wprost, bez obietnicy 100% recall.

## 2. Zakres i nie-zakres

| W zakresie | Poza zakresem (świadomie) |
|---|---|
| tekst transkryptu w prompcie call-2 | kanoniczny blob transkryptu i widok w aplikacji (terapeuta widzi oryginał; szyfrowane at rest) |
| `Title`, `Summary` z call-1 (widoczne na listach w UI) | wejście call-1 (model musi czytać oryginał, żeby wykryć PII) |
| tematy RAG (`RAG_Theme`) i `RAG_Summary` — twarda zamiana zamiast dzisiejszej ochrony wyłącznie promptowej | audio → STT (głos sam w sobie identyfikuje; domena DPA z providerem STT, docs/39 Faza 0) |
| cytaty blockquote w raporcie (pochodna transkryptu) | `working_alias` pacjenta — dziś NIE trafia do promptów llm-workera (zweryfikowano 2026-07-17); utrzymać jako inwariant |

## 3. Architektura — wariant W1 (po decyzji z 2026-07-17)

Kontekst decyzji: na ścieżce Deepgram call-1 **nie robi już
klastrowania** (dostaje gotowych mówców, gramatyka role-only) — jego
obciążenie jest niskie, więc ekstrakcję PII dokładamy do call-1
zamiast osobnego wywołania. Historyczny argument „nie przeładowywać
call-1" dotyczył gramatyki klastrującej (źródła doom-loopów) i po
Deepgramie wygasł.

```
call-1 (role-only, Format B) ──► # Speakers / # Metadata / # RAG …
                                 # PII                  ← NOWA SEKCJA
                                   [NAZWISKO-1]: Nowak | Nowaka | Nowakiem   (imiona zostają!)
                                   [PRACODAWCA]: Softex | Softexie
                                   [SZKOŁA]: SP 12 | dwunastce
                                   [MIEJSCOWOŚĆ-A]: Wrocław | Wrocławiu
        │
        ▼
pseudonymize.Apply(text, entities)   ← czysty Go, deterministyczny
  1. warstwa regex: PESEL, telefon, e-mail, kody pocztowe, nr kont
  2. zamiana form powierzchniowych z # PII:
     longest-match-first, granice słów, case-insensitive,
     spójny placeholder per encja w całej sesji
        │
        ├─► transkrypt Format B do promptu call-2
        ├─► Title / Summary (przed persist + publish)
        └─► RAG_Summary / RAG_Theme (przed embed + persist)
```

### 3.1 Taksonomia placeholderów (rewizja 2026-07-17)

Imiona zostają, więc placeholdery rolowe dla osób są ZBĘDNE — czytelność
relacji zapewniają imiona. Redakcja osób sprowadza się do nazwisk:

- pełne „Anna Kowalska" → **„Anna"** (nazwisko po prostu znika — zero
  tokenu, naturalny tekst);
- nazwisko solo („pani Kowalska", „z Kowalskim") → `[NAZWISKO-n]`
  (numerowane per osoba; BEZ inicjału — inicjał + pracodawca +
  miejscowość potrafi identyfikować);
- `[PRACODAWCA(-n)]`, `[SZKOŁA(-n)]`, `[MIEJSCOWOŚĆ-x]`, `[ADRES]`,
  `[IDENTYFIKATOR]` (warstwa regex), `[DATA-URODZENIA]`.

Efekt uboczny rewizji: znika największe źródło false-positives
(imiona-homonimy słów pospolitych) i ryzyko pomylenia ról przez LLM —
model nie klasyfikuje już relacji, tylko wskazuje nazwiska i nazwy.

### 3.2 Gramatyka sekcji `# PII` (parser w internal/diarization)

Jedna linia na encję: `PLACEHOLDER: forma1 | forma2 | …`. Model ma
wypisać **wszystkie formy powierzchniowe z transkryptu** (odmiana,
zdrobnienia, przekręcone warianty STT, inicjały). Parser tolerancyjny
jak przy `RAG_Theme`: brak sekcji → pusta lista (fail-open), linia
niepasująca do wzorca → pominięta z Warn, limit 40 encji × 15 form,
forma ≤ 60 znaków. Prompt: instrukcja + 2 przykłady + zakaz zgadywania
form nieobecnych w tekście.

### 3.3 Silnik zamiany (`internal/pseudonymize`, czysty pakiet)

- kolejność: regex-warstwa najpierw (deterministyczna, niezależna od
  LLM), potem formy z `# PII` posortowane malejąco po długości
  (unika zamiany „Nowak" wewnątrz „Anna Nowak");
- dopasowanie po granicach słów (unicode), bez wchodzenia w środek
  wyrazów; case-insensitive z zachowaniem placeholdera literalnie;
- kolizje (ta sama forma w dwóch encjach — „Karol" mąż i „Karol"
  syn): pierwsza encja wygrywa + Warn `pii_form_collision`;
- zwraca statystyki: liczba encji, liczba zamian, formy bez ani
  jednego trafienia (sygnał halucynacji modelu → metric).

### 3.4 Fallback na ścieżce klastrującej (Chirp)

Po automatycznym failoverze deepgram→chirp call-1 wraca do ciężkiej
gramatyki klastrującej — tam sekcji `# PII` NIE dokładamy (nie ruszamy
kruchej gramatyki skazanej na usunięcie w docs/39 Faza 4). Zamiast
tego: osobny mini-call pseudonimizacyjny (ten sam prompt sekcji PII,
wejście Format B po rozstrzygnięciu mówców). Rzadka ścieżka, metryka
`pseudonymize.fallback_call`. Kod znika razem z gramatyką klastrującą.

## 4. Semantyka błędów

**Fail-open z alertem** (v1): brak/nieparsowalna sekcja `# PII` albo
błąd silnika → raport idzie BEZ pseudonimizacji + `Error`-log
`pseudonymize_failed` + analytics. Uzasadnienie: feature
prywatnościowy nie może stworzyć nowej klasy zawieszonych sesji
(lekcja z docs/21); transkrypt i raport i tak są szyfrowane at rest,
więc przeciek jest względem stanu dzisiejszego, nie absolutny.
Po ustabilizowaniu (metryka failure rate <0,5%/tydz.) rozważyć
zaostrzenie do retry-once.

## 5. Budżety tokenów

`geminiMaxOutMetadata`: 2048 → **4096** (lista encji × formy dla
60-min sesji wielosobowej). Zgodnie z zasadą z docs/agents/05: cap
w parze z dyrektywą promptową (sekcja PII zwięzła, tylko formy
faktycznie obecne). Call-2 bez zmian budżetu (placeholdery są
krótsze niż nazwiska).

## 6. Flaga i rollout

| `LLM_PSEUDONYMIZE` | Zachowanie |
|---|---|
| `off` (default) | sekcja PII nieobecna w prompcie, silnik nieaktywny — bajt w bajt dzisiejsze prompty |
| `call2` | zamiana tylko w tekście do call-2 (etap przejściowy do A/B) |
| `all` (docelowo) | call-2 + Title/Summary + RAG |

Rollout: implementacja za flagą → eval offline (`cmd/pii-eval` —
dedykowana bramka, nie matryca llm-eval) → staging `all` → produkcja.
Rollback = flip env, zero zmian w DB (wzorzec `STT_PROVIDER`).
[Wykonane do etapu staging `all`, 2026-07-17.]

## 7. Ewaluacja jakości (bramka przed włączeniem)

[Zrealizowane jako `cmd/pii-eval`: 5 fixture PL, temp 0.1,
gemini-2.5-flash-lite; GATE PASS ×3 po kalibracji PIIPromptRules
(jawne przypadki gramatyczne, duże miasta, zakaz zdrobnień imion,
byli pracodawcy/marki). Dodatkowo e2e `TestPseudonymize_E2E`
(PII_E2E=strict) na żywym stagingu — leaks=[].]

Zestaw syntetycznych transkryptów PL (generowane dialogi z wstrzykniętą
PII: odmiana przez wszystkie przypadki, zdrobnienia, przekręcone
nazwiska à la STT, nazwiska-homonimy pospolitych słów, leki vs
nazwiska). Metryki:

- **leak rate**: % wstrzykniętych form PII obecnych w wyjściu po
  zamianie (cel v1: <5% na formach odmienionych, 0% na formach
  bazowych i identyfikatorach regex);
- **false-positive rate**: zamiany słów niebędących PII (cel: ~0);
- **jakość raportu A/B**: llm-eval na parach (raport z/bez
  pseudonimizacji) — spójność referencji, kompletność sekcji.

## 8. Decyzje otwarte / podjęte

| Kwestia | Decyzja |
|---|---|
| Mapping pseudonim→oryginał | **Nie przechowujemy** (minimalizacja; terapeuta zna tożsamość). Wariant odwracalny (szyfrowany per sesja, CASCADE) opisany, odłożony do żądania compliance |
| Toggle per terapeuta/kartoteka | Nie w v1 — jedna semantyka raportu; ewentualnie org-level później |
| patient_views (panel klienta) | dziedziczy pseudonimizację z raportu — pacjent czytający własny raport widzi placeholdery; akceptowalne, odnotować w UX-copy |
| docs/37 | dopisać pseudonimizację jako środek minimalizacji w DPIA po wdrożeniu |

## 9. Kosztorys

| Pozycja | Szacunek |
|---|---|
| Prompt + gramatyka + parser sekcji `# PII` | 1 d |
| `internal/pseudonymize` (regex + zamiana + testy) | 1 d |
| Wpięcie: call-2, Title/Summary, RAG + mini-call fallbacku Chirp | 0,5–1 d |
| Eval (fixtures + llm-eval) | 1 d |
| Flaga, testy, docs (aktualizacja agents/05) | 0,5 d |
| **Razem** | **~3,5–4,5 dnia** |
| Runtime | +300–500 tokenów wyjścia call-1 (~grosze), zero dodatkowej latencji na ścieżce Deepgram |

Dokumenty powiązane: docs/39 (provider STT, Faza 4 — usunięcie
gramatyki klastrującej), docs/30 (RAG — dlaczego twarda ochrona
tematów), docs/37 (zgodność/DPIA), docs/agents/05 (flagi, budżety
tokenów, konwencje gramatyk Markdown).
