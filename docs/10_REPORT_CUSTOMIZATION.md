# 10_REPORT_CUSTOMIZATION

> Dokument projektowy — personalizacja raportów per terapeuta + system
> ocen jakości w stylu LLM-czatu (👍/👎). **Status: faza projektowa.**
> Branch implementacyjny: `feat/iphone-audio-upload` lub branch
> następczy. Wszystkie pięć pytań otwartych pierwotnej wersji zostało
> rozstrzygniętych — patrz **§13 Dziennik decyzji**.
>
> Powiązane ADR: ADR-IMPL-002 (brak hardcodowanych etykiet ról),
> ADR-IMPL-007 (prompty modalności jako baseline kliniczny),
> ADR-IMPL-007a (recovery sparse labels). Ta funkcja **nie może** ich
> osłabić.

---

## 1. Problem

Dziś terapeuci otrzymują raporty kliniczne generowane na podstawie
jednego promptu per-modalność (`modalities.therapist_ai_general_prompt`).
Każdy terapeuta CBT dostaje identycznie sformatowany raport. Każdy
psychodynamiczny — identycznie sformatowany raport. Nie ma sposobu,
żeby pojedynczy terapeuta dostroił styl *swoich* raportów bez edycji
globalnego promptu modalności — co jest zmianą treści klinicznej
wymagającą migracji i wpływającą na wszystkich użytkowników tej
modalności.

Dwa konkretne bolączki:

1. **Brak osi personalizacji.** Terapeutka preferująca zwięzłe,
   1-stronicowe podsumowania z minimalną liczbą cytatów pacjenta nie
   ma jak tego zażyczyć; dostaje ten sam 2-stronicowy raport z licznymi
   cytatami, co wszyscy inni.
2. **Brak pętli zwrotnej.** Gdy raport chybi celu, terapeuta nie ma
   wewnątrzproduktowego kanału, żeby to zasygnalizować. Nie wiemy,
   czy raporty trafiają w punkt — jedynym sygnałem jest milczenie
   (implicit) albo zewnętrzny Slack-rant. Brak danych → brak poprawy.

Ten dokument proponuje sprzężone rozwiązanie: **preferencje per
terapeuta nakładane na (nigdy nie zastępujące) baseline modalności**,
oraz **lekki UX oceniania w stylu LLM-czatu**, który w sposób odkrywalny
łączy niezadowolenie → konfigurację preferencji.

## 2. Cele / poza zakresem

**Cele**
- Terapeuta personalizuje styl raportu w prostym polskim (nie technicznie,
  nie "prompt engineering").
- Personalizacja jest nakładana **po** i **podporządkowana** baseline'owi
  modalności — kliniczny framework pozostaje zablokowany.
- Prosty widget oceny 👍 / 👎 pod każdym raportem; jedno kliknięcie
  dla typowego przypadku, strukturalne szczegóły dla negatywów.
- Negatywne oceny otwierają odkrywalną ścieżkę do UI preferencji.
- **Aktywne sugestie**: jeśli kilka ostatnich raportów dostało tę samą
  skargę ("za długi"), strona preferencji proponuje zmianę wymiaru
  jednym kliknięciem.
- Dane jakościowe są zbierane na potrzeby przyszłego eval / auto-tuningu.

**Poza zakresem (v1)**
- Modyfikacja treści klinicznej promptów modalności (zablokowane,
  treści licencjonowane).
- Preferencje styl per pacjent (zbyt drobnoziarniste; rozsadziłoby
  przestrzeń preferencji i macierz eval).
- Per-session override stylu na ekranie nowej sesji (odrzucone —
  patrz §13 Dziennik decyzji).
- Auto-tuning samych promptów modalności na podstawie zagregowanych
  ocen (odsunięte do v3 — najpierw faza zbierania danych).
- Pokazywanie terapeucie technicznych szczegółów wygenerowanego
  fragmentu promptu (odrzucone — patrz §13).

## 3. Ścieżka użytkownika

```
   Generacja raportu sesji                        (bez zmian)
            │
            ▼
   Terapeuta czyta raport w apce
            │
            ▼
   Dół widoku raportu:  "Czy ten raport był pomocny?"
                            👍   👎
            │
        ┌───┴───────────────────────────┐
        ▼                               ▼
       👍                              👎
        │                               │
   ciche podziękowanie            Modal: "Co było nie tak?"
   log pozytywnej oceny           chipy (multi-select) + textarea
                                  ┌─ za długi
                                  ├─ za krótki
                                  ├─ zły ton
                                  ├─ za dużo cytatów
                                  ├─ za mało cytatów
                                  ├─ niedokładna interpretacja
                                  ├─ brakuje mocnych stron pacjenta
                                  ├─ brakuje kontekstu / złe akcenty
                                  └─ inne (textarea)
                                  │
                                  ▼
                                  Primary CTA:
                                  "Skonfiguruj swoje raporty →"
                                  (link głęboki do ustawień,
                                   pod-podświetla wymiar(y)
                                   wynikające z wyboru chipów)
                                  Secondary: "Po prostu zapisz"
                                  │
                                  ▼
                            Ustawienia → Preferencje raportów
                            (zmiany dotyczą PRZYSZŁYCH raportów;
                             stare raporty pozostają niezmienione)
```

**Timing widgetu oceny**
- Widget zawsze widoczny na dole raportu.
- Bez auto-promptu przy pierwszym czytaniu (zbyt natrętne).
- Powiadomienie po sesji (T+24h): jeden push z akcją quick-rate —
  odsunięte do v2.

**"Inteligentny link głęboki" — szczegóły**
- Wybór `za długi` → ustawienia otwierają się z podświetlonym wymiarem
  **Długość**.
- `zły ton` → podświetlony **Ton**.
- `za dużo cytatów` / `za mało cytatów` → **Gęstość cytatów**.
- `niedokładna interpretacja` → **Ostrożność hipotez** + **Język
  diagnostyczny** (oba podświetlone — są skorelowane).
- `brakuje mocnych stron pacjenta` → **Framing wokół zasobów**.
- `brakuje kontekstu / złe akcenty` → **Akcent sekcji**.
- Wybór dwóch lub więcej → wszystkie relewantne wymiary podświetlone,
  bez wymuszonej kolejności.
- Link głęboki przekazuje też `?source=rating&report_id=…` do funnel
  analytics.

## 4. Wymiary personalizacji (v1)

7 strukturalnych wyborów + 1 pole tekstowe-awaryjne. **Wszystkie wartości
przechowywane jako enum-stringi; UI tłumaczy na lokalizowane etykiety.**
Defaulty są zachowawcze (środek pola); terapeuta, który nigdy nie
odwiedzi ustawień, dostaje raport identyczny z dzisiejszym.

| # | Wymiar | Wybory (enum → etykieta PL) | Default | Wpływ na LLM |
|---|---|---|---|---|
| 1 | **Długość** (`length`) | `brief` "Krótki (≈1 strona)" / `standard` "Standardowy (≈2 strony)" / `detailed` "Szczegółowy (3+ strony)" | `standard` | Cap MaxOutputTokens + dyrektywa w prompcie |
| 2 | **Ton** (`tone`) | `clinical_formal` "Kliniczny-formalny" / `empathic_warm` "Empatyczny-ciepły" / `pragmatic_direct` "Pragmatyczny-bezpośredni" / `academic_rigorous` "Akademicki-rygorystyczny" | `clinical_formal` | Dyrektywa stylu w prompcie |
| 3 | **Gęstość cytatów** (`quote_density`) | `few` "Mało (≤2 cytaty)" / `selective` "Wybiórczo (3–5)" / `many` "Dużo (>5)" | `selective` | Cap-and-floor dyrektywa na liczbę cytatów verbatim |
| 4 | **Język diagnostyczny** (`diagnostic_language`) | `descriptive` "Opisowo (np. 'unika kontaktu wzrokowego')" / `clinical_labels` "Etykiety kliniczne (np. 'unikanie społeczne')" / `dsm_icd` "Pełne etykiety DSM/ICD" | `descriptive` | Dyrektywa słownictwa |
| 5 | **Ostrożność hipotez** (`hypothesis_hedging`) | `tentative` "Ostrożnie (możliwe / sugeruje)" / `balanced` "Zrównoważone" / `assertive` "Pewnie (jest / wskazuje na)" | `tentative` | Dyrektywa modalności-czasownikowej / pewności |
| 6 | **Akcent sekcji** (`section_emphasis`, multi-select) | Multi-select na 7 sekcjach raportu: `clinical_picture`, `interventions`, `case_formulation`, `supervisory_recommendations`, `homework_between_sessions`, `cultural_context`, `safety_and_risk` | `[]` (zrównoważone) | Nudge per-sekcyjnej długości |
| 7 | **Framing wokół zasobów** (`strengths_framing`) | `problem_focused` "Skupienie na problemach" / `balanced` "Zrównoważone" / `strengths_first` "Mocne strony na początku" | `balanced` | Dyrektywa kolejności i framingu sekcji |
| 8 | **Pole wolnotekstowe** (`free_text`, max 500 znaków) | Prosty polski, jedna textarea: "Coś jeszcze, co powinienem wiedzieć o tym, jak piszesz raporty?" | `""` | Doklejone verbatim (po sanityzacji) |

**Dlaczego te 7 (a nie 4 czy 15)**
- Pierwsze 3 (długość, ton, cytaty) pokrywają najczęstsze skargi typu
  LLM-rating.
- Wymiar 4 (język diagnostyczny) to klinicznie znacząca oś, na której
  terapeuci faktycznie różnią się stylistycznie — opisowo vs etykiety.
- Wymiar 5 (ostrożność) bezpośrednio wpływa na to, jak raport czyta się
  jako dokument kliniczny — top-skarga, gdy LLM brzmi zbyt pewnie.
- Wymiar 6 (akcent sekcji) to escape hatch dla "chcę więcej X, mniej Y"
  bez dyktowania dokładnych długości. Uwaga: lista sekcji obejmuje
  `safety_and_risk`, więc terapeuta wciąż może wzmocnić sekcję ryzyka
  (osobny wymiar "Risk framing" usunięty z designu po decyzji §13.1).
- Wymiar 7 (zasoby) to wariancja best-practice terapeutycznej — część
  układa raporty wokół problemów, część wokół zasobów; warto mieć
  pokrętło.
- Więcej niż 7 zaczyna wyglądać jak panel preferencji Adobe.
  Terapeuci odbijają.

**Bezpieczeństwo pola wolnotekstowego**
- Twardy cap 500 znaków (walidowane server-side + client-side).
- Strip newlines (`\n`/`\r`), code fences (` ``` `), zero-width chars.
- Odrzucanie wzorców wyglądających na prompt injection:
  `(?i)(ignore|disregard|forget) .* (previous|above|prior)`,
  `(?i)system prompt`, `(?i)you are now`, etc. Odrzucenie + komunikat
  walidacyjny, nie ciche stripowanie.
- Fragment trafia do promptu **po** baseline'ie modalności i **przed**
  blokiem zasad zwięzłości, oprawiony jako *"PREFERENCJE TERAPEUTY
  (uzupełnienia stylu, NIE sprzeczne z powyższymi zasadami klinicznymi)"*.
  Framing "NIE sprzeczne" broni przed sytuacją, w której terapeuta
  niechcący jailbreakuje własny pipeline.

## 5. System ocen

**UX powierzchnia**
- Stały pasek na dole widoku raportu: 👍 / 👎.
- Stan dotyku zachowany per raport (idempotentne — drugi tap toggluje).
- Bez anonimowości (terapeuta jest zalogowany; wiemy kto ocenia).

**Ścieżka 👍**
- Tap → krótki fade na podziękowanie ("Dziękujemy za feedback!").
- Server zapisuje `{report_id, therapist_id, rating: "positive",
  source: "in_app", created_at}`.

**Ścieżka 👎**
- Tap → modal wjeżdża z dołu:
  - Nagłówek: *"Co było nie tak z tym raportem?"*
  - Multi-select chip array (8 kategorii z §3).
  - Textarea: *"Cokolwiek jeszcze?"* (cap 200 znaków, opcjonalne, ta
    sama sanityzacja co `free_text`).
  - Primary CTA: *"Skonfiguruj swoje raporty →"* (link głęboki
    z podświetlonymi wymiarami zgodnie z §3).
  - Secondary CTA: *"Po prostu zapisz"* — zapisuje ocenę bez nawigacji.
- Server zapisuje `{report_id, therapist_id, rating: "negative",
  issues: [...], notes: "...", source: "in_app", created_at}`.

**Brak oceny to najczęstszy stan i jest OK.** Jak w LLM-czatach,
większość raportów nie dostanie oceny. Optymalizujemy pod
wysokoenergetyczne negatywy, nie pełne pokrycie.

**Agregacja (do v1: query dla suggestion engine; do v2: dashboard)**
- Per-terapeuta: % negatywów, top kategorie skarg, czas od ostatniego
  negatywu.
- Per-modalność: to samo, na wszystkich terapeutach.
- Per-tydzień / cohort: detekcja regresji (czy zmiana modelu zepsuła
  coś dla pewnego segmentu?).

## 6. Suggestion engine (v1)

**Cel:** zamknąć pętlę — gdy terapeuta wielokrotnie skarży się na ten
sam wymiar, propozycja zmiany konfiguracji jednym kliknięciem.

**Trigger**
- Trzy (lub więcej) negatywne oceny z tą samą kategorią chipa w ciągu
  ostatnich pięciu ratowanych raportów terapeuty.
- Albo: w ciągu ostatnich 14 dni — dla terapeutów z rzadszym
  rytmem sesji.
- Liczone tylko negatywy, nie pozytywne.

**Mapowanie kategorii → propozycja zmiany**

| Kategoria chipa | Propozycja (jeśli wymiar nie jest już ekstremum) |
|---|---|
| `za długi` (≥3×) | Długość: `standard → brief` lub `detailed → standard` |
| `za krótki` (≥3×) | Długość: `brief → standard` lub `standard → detailed` |
| `zły ton` (≥3×) | Sugestia ogólna: *"Może spróbować innego tonu?"* — bez auto-wyboru (zbyt wieloznaczne) |
| `za dużo cytatów` (≥3×) | Gęstość cytatów: o jeden poziom w dół |
| `za mało cytatów` (≥3×) | Gęstość cytatów: o jeden poziom w górę |
| `niedokładna interpretacja` (≥3×) | Ostrożność hipotez: o jeden poziom bardziej tentative; lub język diagnostyczny: `dsm_icd → clinical_labels → descriptive` |
| `brakuje mocnych stron pacjenta` (≥3×) | Framing wokół zasobów: `problem_focused → balanced → strengths_first` |
| `brakuje kontekstu / złe akcenty` (≥3×) | Sugestia ogólna: *"Może warto wzmocnić akcent jednej z sekcji?"* — bez auto-wyboru |
| `inne` | Bez automatycznej propozycji — czysta zbiórka danych |

**Prezentacja propozycji w UI**

W górnej części ekranu *Ustawienia → Preferencje raportów*:

```
┌────────────────────────────────────────────────────────┐
│ 💡 Zauważyliśmy, że Twoje ostatnie 4 raporty zostały  │
│    ocenione jako "za długi".                           │
│    Czy chcesz przełączyć długość raportów              │
│    z "Standardowy" na "Krótki"?                        │
│                                                        │
│        [ Zastosuj sugestię ]    [ Nie teraz ]          │
└────────────────────────────────────────────────────────┘
```

- **Zastosuj sugestię** → wprowadza zmianę w preferencjach
  (server-side UPSERT), loguje *"suggestion_applied"*, zwija baner.
- **Nie teraz** → ukrywa baner na 14 dni, loguje
  *"suggestion_dismissed"* (sygnał dla analytics — być może mapa
  trigger jest zbyt agresywna).
- Maksimum 1 baner sugestii na raz — jeśli pasują dwa, wygrywa
  najczęstsza kategoria.

**Pasek bezpieczeństwa**
- Tylko jedna propozycja na sesję ustawień (terapeuta nie jest
  zalewany).
- Auto-zastosowanie wyłączone — terapeuta zawsze klika.
- Propozycje nie pokazują się, jeśli wymiar jest już w skrajnym stanie
  (np. `length=brief` przy skardze "za długi" → bez propozycji, bo
  nie ma gdzie skrócić).
- Wartości proponowane są deterministyczne (per tabela powyżej), nie
  ML-driven w v1.

**Telemetria**
- Każda propozycja loguje: `(therapist_id, dimension, from_value,
  to_value, trigger_count, action)` gdzie action ∈
  `{shown, applied, dismissed}`. To dane treningowe dla v3.

## 7. Schemat danych / API

### `users.report_preferences JSONB`

Dodajemy do istniejącej tabeli `users`. Lżej niż osobna tabela —
1:1 z terapeutą, czytane przy każdym wywołaniu generacji raportu.

```sql
ALTER TABLE users
  ADD COLUMN report_preferences JSONB NOT NULL DEFAULT '{}'::jsonb;
```

Shape:

```json
{
  "version": 1,
  "length": "standard",
  "tone": "clinical_formal",
  "quote_density": "selective",
  "diagnostic_language": "descriptive",
  "hypothesis_hedging": "tentative",
  "section_emphasis": ["clinical_picture", "interventions"],
  "strengths_framing": "balanced",
  "free_text": "Preferuję terminy behawioralne zamiast diagnostycznych etykiet.",
  "updated_at": "2026-05-18T10:23:00Z"
}
```

- `version` pozwala ewoluować schemat bez migracji na każdy dodawany
  klucz.
- Pusty obiekt = "użyj wszystkich defaultów" (zero-cost dla
  niekonfigurujących użytkowników).
- `updated_at` zduplikowane mimo istnienia `users.updated_at`, bo
  chcemy timestamp specyficznie dla edycji preferencji
  (np. dla UI copy *"Preferencje zaktualizowane 3 tygodnie temu"*).

### Tabela `report_ratings`

```sql
CREATE TABLE report_ratings (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id    UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  therapist_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating       TEXT NOT NULL CHECK (rating IN ('positive','negative')),
  issues       TEXT[] NOT NULL DEFAULT '{}',
  notes        TEXT NOT NULL DEFAULT '',
  source       TEXT NOT NULL DEFAULT 'in_app',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (report_id, therapist_id)
);
CREATE INDEX idx_report_ratings_therapist
  ON report_ratings(therapist_id, created_at DESC);
CREATE INDEX idx_report_ratings_negative
  ON report_ratings(therapist_id, created_at DESC)
  WHERE rating = 'negative';
```

- `UNIQUE (report_id, therapist_id)` żeby ponowna ocena upsertowała
  istniejący wiersz, nie tworzyła drugiego.
- `ON DELETE CASCADE` żeby cleanup ocen szedł za usunięciem raportu
  (P1 Zero Data Loss nienaruszone — oceny są derywatywne).
- `notes` przechowuje sformułowania bez PHI, ta sama sanityzacja co
  `report_preferences.free_text`.
- `issues` jako TEXT[] (nie JSONB) dla trywialnego GROUP BY w analityce
  i suggestion engine.

### Tabela `preference_suggestions_log` (v1, suggestion engine)

```sql
CREATE TABLE preference_suggestions_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  therapist_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  dimension       TEXT NOT NULL,        -- 'length', 'tone', etc.
  from_value      TEXT NOT NULL,
  to_value        TEXT NOT NULL,
  trigger_count   INT NOT NULL,         -- ile negatywów wywołało
  action          TEXT NOT NULL CHECK (action IN ('shown','applied','dismissed')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_pref_sugg_log_therapist
  ON preference_suggestions_log(therapist_id, created_at DESC);
```

- Niepełna analityka — sucha telemetria sugestii. Można drop+rebuild
  bez utraty user-facing state.

### gRPC API

Dodaj do `identity-svc` (ustawienia użytkownika żyją tutaj):

```protobuf
service IdentityService {
  // ... istniejące RPC ...
  rpc GetReportPreferences(GetReportPreferencesRequest) returns (GetReportPreferencesResponse);
  rpc UpdateReportPreferences(UpdateReportPreferencesRequest) returns (ReportPreferences);
}

message ReportPreferences {
  int32 version = 1;
  string length = 2;
  string tone = 3;
  string quote_density = 4;
  string diagnostic_language = 5;
  string hypothesis_hedging = 6;
  repeated string section_emphasis = 7;
  string strengths_framing = 8;
  string free_text = 9;
  google.protobuf.Timestamp updated_at = 10;
}

message GetReportPreferencesResponse {
  ReportPreferences preferences = 1;
  // Suggestion engine output — null gdy brak aktywnej sugestii.
  PreferenceSuggestion active_suggestion = 2;
}

message PreferenceSuggestion {
  string dimension = 1;          // 'length', 'quote_density', ...
  string from_value = 2;
  string to_value = 3;
  string reason_label = 4;       // 'za długi' (kategoria chipa)
  int32 trigger_count = 5;       // ile negatywów wywołało
  string suggestion_id = 6;      // do logowania accept/dismiss
}
```

Dodaj do `clinical-svc` (raporty + oceny żyją konceptualnie tutaj):

```protobuf
service ClinicalService {
  // ... istniejące RPC ...
  rpc RateReport(RateReportRequest) returns (RateReportResponse);
  rpc GetReportRating(GetReportRatingRequest) returns (ReportRating);
}

message RateReportRequest {
  string report_id = 1;
  string rating = 2;             // "positive" | "negative"
  repeated string issues = 3;    // wybory chipów
  string notes = 4;              // ≤ 200 znaków, po sanityzacji
  string source = 5;             // "in_app", "email", ...
  string idempotency_key = 6;    // obowiązkowy
}
```

`UpdateReportPreferences` zwraca post-update preferencje, żeby app
flutterowy miał kanoniczny stan bez drugiego round-tripa.

## 8. Integracja z potokiem AI

Personalizacja slotuje się tylko do **call 2** w `llm-worker` — call 1
(diaryzacja / metadane) nietknięty (brak wartości dla terapeuty, czyste
ryzyko dla atrybucji mówców).

### Loading

W `llm-worker.loadSessionContext()` (po loadzie promptu modalności)
dodaj query:

```sql
SELECT report_preferences
FROM users
WHERE id = (SELECT therapist_id FROM sessions WHERE id = $1)
```

Cache na strukturze `SessionContext` obok `ModalityPrompt`.

### Renderowanie fragmentu promptu

Nowy helper w pakiecie `internal/reportprefs/`:

```go
// RenderFragment buduje polski blok promptu ze strukturalnych prefs.
// Zwraca "" gdy prefs są wszystkimi defaultami — utrzymuje prompty
// call 2 identyczne z dzisiejszymi dla użytkowników, którzy nie
// skonfigurowali nic.
func RenderFragment(prefs ReportPreferences) string { ... }
```

Output shape (przykład):

```
PREFERENCJE TERAPEUTY (uzupełnienia stylu, NIE sprzeczne z powyższymi
zasadami klinicznymi):

- Długość raportu: krótki (≈1 strona)
- Ton: empatyczny-ciepły
- Cytaty z transkryptu: wybiórczo (3-5)
- Język diagnostyczny: opisowo
- Pewność hipotez: ostrożnie (możliwe / sugeruje)
- Mocniej rozwiń: obraz kliniczny, interwencje
- Framing: zrównoważony (problemy i zasoby)
- Dodatkowe wskazówki terapeuty: Preferuję terminy behawioralne
  zamiast diagnostycznych etykiet.
```

### Wstrzykiwanie w prompt call 2

Modyfikujemy konstruowanie promptu call 2 w
`llm-worker/main.go::generateReport()`:

```go
reportPrompt := fmt.Sprintf(`%s

JĘZYK RAPORTU: %s
...

%s                                    ← NEW: RenderFragment(prefs)

ZASADY ZWIĘZŁOŚCI (kluczowe — nie ignoruj):
...

KONTEKST POPRZEDNICH SESJI:
%s

TRANSKRYPT BIEŻĄCEJ SESJI (Markdown, grupowanie po mówcach):
%s`, modalityPrompt, reportLanguage, fragment, ragContext, transcriptForCall2)
```

Fragment leży **między** baseline'em modalności a uniwersalnymi
zasadami zwięzłości, dlatego:
- Prompt modalności (framework kliniczny) wygrywa przy konflikcie.
- Uniwersalne zasady zwięzłości wciąż obowiązują.
- Personalizacja jest kontekstualizowana jako *styl*, nie *treść*.

### MaxOutputTokens nudge

Gdy `length == "brief"` — obniż `MaxOutputTokens` z 65535 do 16384;
gdy `detailed` — zostaw 65535. To efekt belt-and-suspenders obok
dyrektywy w prompcie — model lepiej trzyma się długości przy
twardym cap'ie.

## 9. Bezpieczeństwo i zabezpieczenia

| Ryzyko | Zabezpieczenie |
|---|---|
| Terapeuta niechcący jailbreakuje własny pipeline przez `free_text` | Cap 500 znaków + regex-odrzucenie typowych wzorców injekcji + framing "uzupełnienia, NIE sprzeczne" podporządkowany modalności. |
| Modyfikacja kliniczna modalności | **Nie wystawiona w tym UI.** Preferencje to osobna warstwa; prompty modalności pozostają immutable JSONB na `modalities`, modyfikowalne tylko migracją. |
| Zła konfiguracja psuje wszystkie przyszłe raporty jednego terapeuty | Przycisk "Przywróć ustawienia domyślne" (zawsze widoczny, jedno kliknięcie) zeruje prefs. |
| Zła konfiguracja psuje raporty dla wszystkich | Niemożliwe — JSONB per-user, brak globalnej ścieżki zapisu. |
| Regresja jakości na spersonalizowanych raportach | Dodać kombinacje preferencji do eval matrix runner (`services/ai-pipeline-svc/cmd/llm-eval/`). Probe defaults + każdy preset + kilka realistycznych kombinacji. |
| Audit / debug | Logować wyrenderowany fragment promptu (PHI-free, bo to wyłącznie wording od terapeuty) per call wraz z `prefs_version`, `prefs_updated_at`, fragment string. Structured fields w Cloud Logging. |
| Spam / abuse ocen | Per-terapeuta rate-limit na `RateReport` (np. 1/sec/report). Standardowy handling idempotency_key. |
| Suggestion engine = noise / agresywne nudge'e | Cooldown 14 dni na dismissed; max 1 baner na sesję ustawień; brak auto-apply. |
| GDPR / right-to-deletion | `report_ratings` i `preference_suggestions_log` cascade'ują na `users` delete (FK). `report_preferences` jest na samej `users`, usunięte z wierszem. |

## 10. Plan wdrożenia

**v1 — Configure + Rate + Suggest** (ten dokument)
- 7 rozwijanych list + free-text + przycisk reset.
- Ocena 👍 / 👎 z chipami i notatkami przy negatywie.
- Inteligentny link głęboki z ocen negatywnych → ustawienia z
  pod-podświetlonymi wymiarami.
- **Suggestion engine** (§6): trigger ≥3 negatywów na kategorię w 5
  ostatnich raportach → baner propozycji w ustawieniach,
  jednokliknięciowa akceptacja.
- Pokrycie probe'em w eval matrix.
- Bez powiadomień, bez admin-dashboard analytics.
- Szacunek: 2 sprinty (Flutter UI + 2 backend services + 2 migracje +
  pokrycie eval).

**v2 — Reduce friction + observability**
- Push notification w T+24h: "Oceń dzisiejszy raport" z akcjami
  szybkiej oceny.
- Per-terapeuta widok analityki w admin dashboard (avg rating, top
  skargi, conversion rate sugestii).
- Per-modalność / per-tydzień detekcja regresji na tym samym widoku.
- Rozszerzenie suggestion engine: confidence score, multi-step
  ("Twoje raporty są zarówno za długie jak i za pewne — zastosować obie
  zmiany?").

**v3 — Aktywna inteligencja**
- Opcjonalne: example-driven personalizacja (terapeuta wkleja jeden
  ze swoich poprzednich raportów → few-shot do call 2). Duży build,
  shipować tylko jeśli analytics v2 pokażą, że to przesunie wskazówki.
- Opcjonalne: auto-tune na poziomie samego promptu modalności
  używając zagregowanych ocen (wolno, ostrożnie, za feature flagiem,
  po walidacji eval matrix). Czysto addytywne — nigdy nie modyfikuje
  baseline'u bez clinical sign-off.

## 11. Pokrycie macierzy eval

Rozszerz istniejący offline-evaluator w
`services/ai-pipeline-svc/cmd/llm-eval/`:

- Dodaj **PreferenceProfile** jako wymiar macierzy obok modelu,
  temperatury, formatu.
- Profile do testów: `default`, `brief+empathic`, `detailed+formal`,
  `strengths_first+balanced_hedging`, `dsm_labels+assertive_hedging`,
  + 2 realistyczne profile z dużym free-textem (np. *"Skupiaj się
  na wzorcach przywiązania"*).
- Pass-criteria: długość raportu w ±20% oczekiwań wymiaru, heurystyki
  tonu pass, brak driftu treści klinicznej (porównaj do baseline'u
  default-profile na tym samym transkrypcie).
- Regresja w jakimkolwiek profilu blokuje rollout.

## 12. Kolejność implementacji

Sugerowany plan 2-sprintowy, paralelizowalny po service boundaries:

1. **Migracja DB** (`migrations/000NNN_report_customization.up.sql`)
   - `users.report_preferences JSONB DEFAULT '{}'`
   - `CREATE TABLE report_ratings (...)`
   - `CREATE TABLE preference_suggestions_log (...)`
2. **`identity-svc`**
   - sqlc queries na `users.report_preferences`
   - `GetReportPreferences` / `UpdateReportPreferences` RPC
   - Server-side walidacja + sanityzacja injekcji
   - **Suggestion engine query**: dołączyć `active_suggestion` do
     `GetReportPreferencesResponse` (cross-service join do
     `report_ratings` przez stałe schema, lub w drugim wywołaniu —
     zdecydować przy implementacji).
3. **`clinical-svc`**
   - sqlc queries na `report_ratings`, `preference_suggestions_log`
   - `RateReport` / `GetReportRating` RPC
   - Endpoint `LogSuggestionAction(suggestion_id, action)` (lub
     dołączone do `UpdateReportPreferences` z opcjonalnym
     `applied_suggestion_id`)
4. **`ai-pipeline-svc`**
   - Nowy pakiet `internal/reportprefs/`: typy, renderer, testy
   - `loadSessionContext()` joinuje prefs
   - `generateReport()` wstrzykuje fragment
   - Dodać wymiar do macierzy eval
5. **App Flutter**
   - `lib/screens/report_preferences_screen.dart` — 7 dropdownów +
     textarea + reset + **baner sugestii** (Labirynt design tokens)
   - Widok raportu: widget oceniania na dole
   - Modal negatywnej oceny z chipami + notatkami + linkiem głębokim
   - Riverpod provider dla prefs (cached, refresh po update i po
     `applied_suggestion`)
6. **Dokumentacja**
   - `docs/agents/05_ai-pipeline-svc.md` — nowa sekcja: "Wstrzykiwanie
     fragmentu preferencji w call 2"
   - `docs/agents/02_clinical-svc.md` — notka o `report_ratings`
   - `docs/agents/01_identity-svc.md` — sekcja Preferencje + Suggestion engine
   - `docs/agents/06_flutter-therapist-app.md` — nowa sekcja: UX oceny

## 13. Dziennik decyzji (rozstrzygnięcia pytań otwartych)

Pierwotny draft tego dokumentu miał 5 pytań otwartych. Wszystkie
rozstrzygnięte — historia dla kontekstu:

1. **Granulariność personalizacji** — *Decyzja: 7 wymiarów + free
   text.* Pełna lista 8 z draftu okrojona o "Risk framing" (wymiar
   #4 oryginalnego draftu). Powód: ryzyko / safety jest klinicznie
   istotne, ale wystawianie go jako pokrętła stylu daje terapeucie
   możliwość ucichnięcia czerwonego flag'u, co podważa misję
   bezpieczeństwa. Pozostaje dostępne pośrednio przez `section_emphasis`
   (wartość `safety_and_risk`), bo *wzmocnienie* sekcji ryzyka jest OK;
   *osłabienie* jej — nie. Wymiarów teraz 7, plus pole wolnotekstowe.
2. **Per-session override** — *Decyzja: nie.* Globalne preferencje
   wystarczą w v1; per-session dodaje warstwę UI i debug-surface bez
   jasnego "must-have" use-case'u. Jeśli sygnał z prawdziwych użytkowników
   to wymusi, dorobimy w v2.
3. **Głębokość ocen** — *Decyzja: doc default* (binarna 👍/👎 + chipy
   ze szczegółami na ścieżce negatywnej). Najwyższy rating-rate,
   najczystszy sygnał, najtańsze do zbudowania.
4. **Auto-sugestie z agregowanych ocen** — *Decyzja: TAK, w v1.*
   Przesunięte z v3 do v1. Detale w §6 powyżej. Zamyka pętlę
   feedback → action w jednym sprincie i daje natychmiastową wartość
   terapeutom, którzy mogliby nie skojarzyć kategorii oceny z konkretnym
   wymiarem preferencji.
5. **Transparentność promptu** — *Decyzja: nie.* Bez "Pokaż szczegóły
   techniczne" toggle. Abstrakcja plain-language jest wystarczająca;
   wyciąganie surowego fragmentu byłoby mylące dla nietechnicznych
   terapeutów i otwierałoby support-vector ("dlaczego ten fragment
   wygląda inaczej niż ten?"). Audit techniczny pozostaje w Cloud
   Logging (PHI-free) dla zespołu inżynierskiego.

## 14. Co ten projekt NIE zmienia

- Call 1 (diaryzacja / metadane) — nietknięty.
- Prompty modalności — zablokowane. Modyfikowalne tylko migracją.
- Pipeline labelingu mówców (ADR-IMPL-007a) — niezależny.
- Istniejące przechowywanie / szyfrowanie raportów (ADR-IMPL-006 —
  blob transkryptu pozostaje kanoniczny; ciphertext raportu pozostaje
  wyrenderowanym output'em).
- Zakres testów E2E sesji — rozszerza się o jeden profil preferencji,
  nie przepisuje.
