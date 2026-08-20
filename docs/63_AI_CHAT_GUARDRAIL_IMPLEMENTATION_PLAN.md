# Plan implementacji: AI Chat z warstwą guardrail (wg ADR v1.0_2)

| Pole | Wartość |
|---|---|
| Źródło | `docs/kronikarz/62_ADR_AI_Chat_Klasyfikator_Web_Mobile_v1.0_2.md` (zmiana w 5.1/5.2 względem v1.0_1) |
| Data | 2026-08-20 |
| Gałąź robocza | `feat/chat-window` |
| Status | Projekt planu — czeka na decyzje D1–D5 (sekcja 8) |

Plan zakłada architekturę backendową (faza 2 z `ai_assistant.go`) — ADR §6
przesądza: „identyczny guardrail po stronie serwera (żadnej logiki
klasyfikacji w kliencie)", a §4.1 odrzuca kontrolę przez system prompt.
Obecna implementacja czatu (wywołanie Vertex z urządzenia przez Firebase
AI Logic) nie jest w stanie zrealizować żadnego punktu ADR i podlega
wymianie, nie rozbudowie.

---

## 0. Interpretacja zmiany 5.1/5.2 (decyzja D1 — do potwierdzenia)

v1.0_2 przenosi trzy kategorie z ZABRONIONYCH do DOZWOLONYCH:

| v1 (PROHIBITED) | v2 (ALLOWED) | kolumna „Schemat wyjścia" w v2 |
|---|---|---|
| `P2_CONCEPT` | `A8_CONCEPT` | „`A7_TEMPLATE_MAP` (terapeuta wybiera kategorię, system podpina cytaty)" |
| `P3_PROGRESS` | `A9_PROGRESS` | „`A2_FACTS` (częstotliwość tematów, status zadań)" |
| `P4_TREAT` | `A10_TREAT` | „biblioteka protokołów (rozdz. 4.3) — terapeuta wybiera" |

Nowe wiersze niosą w kolumnie schematu treść kolumny „Przekierowanie"
ze starej tabeli. Plan przyjmuje **jedyną wewnętrznie spójną
interpretację**: A8–A10 są *dozwolone przez przekierowanie wykonania* —
klasyfikator rozpoznaje je jako odrębne intencje, ale router wykonuje od
razu ekstraktywny odpowiednik (A8 → przepływ A7, A9 → przepływ A2, A10 →
biblioteka protokołów), **bez ściany odmowy** i bez generowania wolnego
tekstu wnioskującego.

Uzasadnienie: każda inna interpretacja (pełna generatywna
konceptualizacja/prognoza/zalecenia) stoi w sprzeczności z niezmienionymi
w v2 sekcjami — 5.3 („`has_client_reference=true` + treść wnioskująca →
PROHIBITED"), 5.5 (prompt: „NIE konceptualizuje przypadków, NIE ocenia
stanu, NIE zaleca interwencji"), §2 pkt 5 i §9 (ryzyko rezydualne oparte
na tym, że użycie kliniczne jest „wykrywane, odmawiane i mierzone").

Różnica w praktyce względem v1: użytkownik pytający „która sfera
równowagi jest naruszona" nie dostaje odmowy z przyciskami, tylko od razu
wchodzi w przepływ szablonu (wybór kategorii + podpięte cytaty), z
komunikatem UI wyjaśniającym transformację. Kryterium „wytwarzanie nowej
informacji klinicznej" pozostaje nieprzekroczone przez generację.

**Konsekwencja dowodowa (do świadomej akceptacji):** dla A8–A10 znika
zdarzenie `ai_chat_refused` — argument z §9 „odmawiane i mierzone" słabnie
dokładnie w kategoriach, o które chodziło. Plan kompensuje to zdarzeniem
`ai_chat_rerouted` z oryginalnym kodem intencji (sekcja F7), tak by próg
przeglądu 8.3 („udział zapytań o funkcje wyrobu > 25%") dalej działał —
liczony jako `P1 + P2 + rerouted(A8..A10)`.

---

## 1. Niespójności ADR do naprawy przed implementacją

Zmiana objęła tylko tabele 5.1/5.2; pozostałe sekcje odwołują się do
kodów, które już nie istnieją. Implementacja według dokumentu w obecnym
stanie jest niemożliwa — schemat 5.4 odrzuciłby kody z tabeli 5.1.

| # | Miejsce | Problem | Proponowana naprawa |
|---|---|---|---|
| 1 | 5.4 enum | zawiera `P2_CONCEPT…R_RISK,X_OTHER`; brak `A8–A10`, `P2_MED`, `P3_RISK`, `P4_OTHER` | zaktualizować enum do v2 (wzorzec w sekcji F2 niżej) |
| 2 | 5.3, 8.2, §9, diagram 4.2 | używają `R_RISK` | rekomendacja: **zachować kod `R_RISK`** zamiast `P3_RISK` — semantyka „własny, niższy próg, absolutny priorytet" jest częścią identyfikatora; przemianowanie niczego nie kupuje, a psuje spójność czterech sekcji (D4) |
| 3 | 5.1 wiersze A8–A10 | kolumna „Schemat wyjścia" zawiera treść przekierowania | wpisać: A8 → schemat A7 `template{}`, A9 → schemat A2 `stats{}`, A10 → operacja aplikacyjna (biblioteka protokołów) |
| 4 | 8.2 „Recall PROHIBITED (P1–P5)" | zbiór P skurczył się do P1_DIAG + P2_MED | rozbić metrykę: recall P1+P2 ≥ 0,97 **oraz nowa**: poprawność routingu A8–A10 ≥ 0,95 (błędny routing = wnioskowanie wychodzi ścieżką generatywną) |
| 5 | Nagłówek §3 | doklejony obcy fragment tekstu („…opcjeTo i gadasz? Gówno.") — wygląda na przypadkowe wklejenie | usunąć |
| 6 | Changelog / wersja | treść zmieniona merytorycznie, metryczka nadal „1.0 / Pierwsza wersja" | podbić do 1.1 z wpisem o zmianie 5.1/5.2 |
| 7 | §9 podpis | zmiana taksonomii jest zmianą merytoryczną w dokumencie o statusie „Zaakceptowany" z niepodpisaną linią akceptacji | ponowna akceptacja PO po naprawie 1–6 |

Naprawy 1–4 są warunkiem startu F2 (klasyfikator koduje enum i progi
wprost z ADR). Mogę przygotować tę korektę jako osobny commit do decyzji.

---

## 2. Architektura docelowa (ustalenia z 19–20.08, skrót)

```
[Flutter / web — wyłącznie UI, zero logiki klasyfikacji]
        │ unary RPC AskPatientQuestion / defined-op RPC
        ▼
[clinical-svc]
  0. wyłącznik: app_config (AI_CHAT_ENABLED, AI_CHAT_MODE; global + org)
  1. quota: rezerwacja mikrodolarów (F6) — odmowa PRZED pierwszym wywołaniem modelu
  2. pkg/guardrail: klasyfikator (gemini-2.5-flash, T=0, structured output)
  3. router: R_RISK → odmowa bez generacji │ P1,P2 → odmowa+przekierowanie
             conf<τ → degradacja │ A1–A7 → ścieżka intencji │ A8–A10 → reroute
  4. pobieranie per intencja:
       A1/A7/A8 → transcript_segments (cytaty verbatim, znaczniki czasu)
       A2/A9    → agregacja SQL, bez modelu
       A5       → notatki terapeuty + cytaty
       A4       → bez kontekstu klienta (wymuszone)
       A10      → biblioteka protokołów (poza zakresem — patrz sekcja 7)
  5. generator ze schematem wymuszonym per intencja
       (pola wnioskowe NIEOBECNE w schemacie — egzekucja przez nieobecność)
  6. weryfikator warunkowy:
       deterministyczny (A1/A7/A8: cytat ⊂ transcript_segments — pewność 1,0)
       LLM drugi przebieg (A3/A5: wolny tekst przy kontekście klienta)
       brak (A2/A9: same liczby; A4: brak osoby w kontekście)
       zapis decyzji ZAWSZE (ślad dowodowy ciągły)
  7. zapis: chat_interactions (notatnik roboczy)
            guardrail_decisions (bez treści, 24 mies., POZA gdpr-purgerem)
  8. commit quoty wg UsageMetadata; zwolnienie nadwyżki rezerwacji
```

Rozstrzygnięcia zamrożone wcześniej, przenoszone do planu bez zmian:

- **`pkg/guardrail` w `clinical-svc`, nie osobny serwis** — budżet p95 ≤ 1,5 s
  nie mieści dodatkowego przeskoku przy trzech szeregowych wywołaniach;
  `pkg/svcauth` wciąż niepodpięty, więc nowy publiczny serwis to nowa
  ekspozycja. Czysty interfejs pakietu = tanie wydzielenie później.
- **Unary zamiast strumienia** — weryfikator wymaga kompletnej odpowiedzi;
  schematy to obiekty JSON, strumieniowanie ich nic nie daje. Wyjątek
  dopuszczalny później: A4_EDU (wolny tekst bez klienta). `connect_adapter_stream.go`
  zostaje dla zgodności proto, ścieżki A1–A10 idą unary.
- **Flagi w tabeli konfiguracji, nie w env** — env-vary na Cloud Run wymagają
  deployu; ADR żąda przełączenia < 1 h. Tabela + cache 30 s = `UPDATE` działa
  w minutę, zakres per org naturalny, historia audytowalna.
- **Klasyfikator i weryfikator na `gemini-2.5-flash`, nie `flash-lite`** —
  udokumentowana słabość lite przy wyjściu strukturalnym (komentarz w
  `llm-worker/main.go`), a tu wszystko jest strukturalne. Do tego lite ma
  sygnalizowane wycofanie 16.10.2026 (do potwierdzenia w konsoli).

Koszt i latencja (kalibracja zmierzona: 3,61 znaku/token; stawki 0,30/2,50 USD):

| tura | wejście | koszt | latencja szac. |
|---|---|---|---|
| klasyfikator | ~650 tok. | $0.0003 | 200–400 ms |
| generator (kontekst ≤ 8 000 znaków) | ~2 700 tok. | $0.0023 | 300–500 ms |
| weryfikator (gdy LLM) | ~900 tok. | $0.0004 | 200–400 ms |
| **razem** | | **≈ $0.0030** | **0,7–1,3 s** |

Budżet 8.2 (p95 ≤ 1,5 s) jest osiągalny bez zapasu — stąd A2/A9 bez modelu
i weryfikator deterministyczny wszędzie, gdzie się da.

---

## 3. Fazy implementacji

Konwencja: każda faza = osobna gałąź z `feat/chat-window`, testy przed
scaleniem, DoD wg §13 ADR. Szacunki dla jednej osoby.

### F0 — Fundamenty (2–3 dni) ⚠ warunek wszystkiego dalej

1. **`pkg/llmcost`** — jedna tabela cen (model → stawki wej/wyj, wersjonowana
   datą). Naprawia dwa istniejące błędy: komentarz w `llm-worker` (zaniża
   6,5×) i naliczanie `reports.llm_total_cost_usd` (zawyża 2,6× — liczy po
   stawkach 2.5-pro dla raportów z 2.5-flash). Korekta danych historycznych
   osobną decyzją; od wdrożenia liczy się poprawnie.
2. **Tabela `app_config`** (migracja 000084): `key`, `value`, `organization_id
   NULL=global`, `updated_at`, `updated_by`; czytana z cache 30 s w
   `clinical-svc`. Zasila `AI_CHAT_ENABLED`, `AI_CHAT_MODE`, później progi τ.
3. **Poprawka ADR** wg sekcji 1 (jeśli D4/D5 zatwierdzone).

DoD: `llm-eval` liczy po nowych stawkach; test jednostkowy cache'a
konfiguracji; runbook wyłączenia czatu (UPDATE + czas propagacji) opisany.

### F1 — Szkielet backendowy czatu (3–4 dni)

„Krok 4" z TODO `ai_assistant.go`: wpięcie `pgxpool` + `cryptobox` (już
istnieją w `clinical-svc`) i nowego klienta Vertex (`cloud.google.com/go/aiplatform`,
generacja + embeddingi, `europe-west4` z env — NIE z kodu klienta);
rejestracja w `connect_adapter.go`; `AskPatientQuestion` unary zwracający
odpowiedź bez guardraili (za flagą, tylko staging); zapis do
`chat_interactions` z `UsageMetadata` (input/output tokenów per
wywołanie); logi `input_tokens`/`output_tokens` jak w `llm-worker`.

DoD: rozmowa działa na stagingu end-to-end; wiersz w `chat_interactions`
po każdej turze; koszt tury widoczny w logach.

### F2 — `pkg/guardrail`: klasyfikator + router (3–4 dni)

- Schemat wyjścia klasyfikatora (5.4 po korekcie):

```json
{"intent": {"enum": ["A1_SEARCH","A2_FACTS","A3_FORMAT","A4_EDU",
  "A5_SUPERVISION_PACK","A6_ADMIN","A7_TEMPLATE_MAP",
  "A8_CONCEPT","A9_PROGRESS","A10_TREAT",
  "P1_DIAG","P2_MED","R_RISK","X_OTHER"]},
 "has_client_reference": {"type":"boolean"},
 "risk_flag": {"type":"boolean"},
 "confidence": {"type":"number"},
 "rationale_short": {"type":"string","maxLength":200}}
```

  (kody `R_RISK`/`X_OTHER` zachowane wg rekomendacji D4; jeśli PO wybierze
  `P3_RISK`/`P4_OTHER`, zmiana jest mechaniczna.)
- Prompt 5.5 wersjonowany w repo (`pkg/guardrail/prompts/classifier_v1.txt`);
  treść bez zmian merytorycznych — pod interpretacją D1 zdania „narzędzie
  NIE konceptualizuje…" pozostają prawdziwe (wykonanie jest ekstraktywne).
- Router: `risk_flag` → odmowa kategorii R (próg asymetryczny — flaga
  honorowana nawet przy niskiej pewności); P1/P2 → odmowa + przekierowanie;
  `conf < τ=0.85` (z `app_config`, kalibrowany w F8) → degradacja do
  defined_ops; A1–A7 → ścieżka intencji; A8–A10 → reroute z komunikatem.
- `rationale_short` nigdy nie trafia do logów produkcyjnych (5.4).

DoD: testy jednostkowe routera na stole decyzyjnym (każda kombinacja
intent × risk_flag × confidence); klasyfikator za interfejsem — mock w
testach, Vertex w integracyjnych.

### F3 — Ścieżki pobierania per intencja (4–5 dni)

| intencja | źródło | uwagi |
|---|---|---|
| A1, A7, A8 | `transcript_segments` (65 MB, deszyfrowanie per segment) | zwrot: cytat + mówca + ts_start/ts_end + session_id |
| A2, A9 | agregacje SQL | zero wywołań modelu; szablon metryk z listy A2/A9 |
| A5 | notatki terapeuty + cytaty | pola `open_questions` wyłącznie user-authored |
| A4 | **brak kontekstu klienta** | wymuszone w kodzie: kontekst nie jest ładowany, nie „proszony o pominięcie" |
| A6 | operacje aplikacyjne | istniejące RPC |
| A10 | biblioteka protokołów | POZA ZAKRESEM planu — nie istnieje w produkcie (grep: zero trafień); do jej powstania A10 zachowuje się jak v1 P4_TREAT: konstruktywna odmowa. Flaga `A10_ENABLED` w `app_config`. |

⚠ **Zależy od decyzji D2**: transkrypcja kanoniczna jest od 2026-07-20
zredagowana at-rest — cytaty „verbatim" będą zawierały tokeny
(`[MIEJSCOWOŚĆ-A]`, `[PRACODAWCA]`). Terapeuta zna te dane; zobaczy tokeny
tam, gdzie pamięta treść. Opcje: (a) zaakceptować i opisać w UI,
(b) zmienić zakres redakcji — poza zakresem tego planu i z konsekwencjami
dla `docs/compliance/06`. Plan zakłada (a) do odwołania.

DoD: każda ścieżka z testem integracyjnym na prawdziwym Postgresie
(konwencja repo); A4 z testem negatywnym „kontekst klienta nieobecny w
promptcie".

### F4 — Schematy wyjścia + generator + weryfikator (4–5 dni)

- Schematy JSON per intencja (§13 t.2) w `pkg/guardrail/schemas/`;
  walidacja serwerowa PO stronie odpowiedzi modelu (nie ufamy samemu
  structured output). **Pola wnioskowe nie istnieją w schemacie
  przekazywanym modelowi** — serwer dokleja treść `filled_by=user` po
  walidacji; test negatywny: próba modelu wypełnienia pola user-only jest
  niemożliwa strukturalnie.
- Weryfikator warunkowy:
  - deterministyczny dla cytatów: każdy `quotes[].text` musi być dosłownym
    podłańcuchem odszyfrowanego segmentu, `speaker`/`ts` zgodne — pewność
    1,0, koszt 0, latencja ~0 (silniejsze niż próg 0,95 z 8.2);
  - LLM (T=0, pytanie zamknięte z 4.3) dla A3/A5 oraz — decyzja
    konserwatywna — dla wszystkiego, co zawiera pole tekstowe dłuższe niż
    cytat;
  - `verifier_block=true` → odpowiedź zastąpiona wersją ekstraktywną albo
    odmowa (4.2) + zdarzenie telemetryczne.
- `guardrail_decisions` (migracja 000085): `id, chat_hash, intent,
  has_client_reference, risk_flag, confidence_bucket, decision, verifier_result,
  classifier_version, verifier_version, platform, occurred_at` — **bez treści**;
  retencja 24 miesiące; **jawne wyłączenie z gdpr-purgera + test negatywny**
  (purger z `analytics_events` kasuje po 90 dniach — bez wyłączenia pakiet
  dowodowy na art. 94 MDR wyparowałby po kwartale).

DoD: zestaw adversarialny wstępny (50 przykładów, rozszerzany w F8);
catch-rate mierzony; test purgera potwierdza nietykalność
`guardrail_decisions`.

### F5 — Kill switch + plan B (2 dni)

- `AI_CHAT_ENABLED` (global/org) i `AI_CHAT_MODE ∈ {chat, defined_ops}` z
  `app_config`; zmiana bez deployu; propagacja ≤ 60 s (TTL cache 30 s ×2).
- Tryb `defined_ops` (§11): to samo pole tekstowe staje się parametrem
  operacji; klasyfikator działa jako router (nie bramka generatora);
  komunikat w `.arb`.
- Zdarzenie `ai_chat_kill_switch_changed` + wpis w `audit_events`.
- Runbook: decyzja → UPDATE → weryfikacja; test na stagingu z pomiarem
  czasu (§9 wymaga < 1 h; realnie minuty).

### F6 — Quota per terapeuta (3 dni)

- Migracja 000086: `chat_usage_counters(therapist_id, period_start,
  period_end, micro_usd_used, micro_usd_reserved, micro_usd_limit)` —
  liczby całkowite w mikrodolarach; okres = okres subskrypcji (jeden zegar).
- Protokół identyczny z tokenowym: **rezerwacja górnego oszacowania przed
  klasyfikatorem** (najtańsze miejsce odmowy — zero wywołań modelu) →
  commit rzeczywistego kosztu z `UsageMetadata` (suma 1–3 wywołań, wycena
  przez `pkg/llmcost`) → zwolnienie nadwyżki.
- Limit domyślny $1.50/mies. = `1_500_000` µUSD w `app_config`
  (per org nadpisywalny); ostrzeżenie w UI przy 80%.
- Wyczerpanie → **degradacja do `defined_ops`**, nie ściana błędu: A2/A9
  (czysty SQL) i A6 działają dalej za darmo; informacja o procedurach
  kryzysowych zawsze widoczna bez modelu. Własny kod błędu
  `CHAT_QUOTA_EXHAUSTED` — odrębny od `SUBSCRIPTION_INACTIVE`.
- Reset administracyjny tą samą ścieżką co `AdminResetTokens`.

DoD: test wyścigu dwóch równoległych tur przy prawie wyczerpanym limicie;
test degradacji; przy $0.0030/turę limit $1.50 ≈ 500 tur/mies. — do
walidacji po pierwszych danych z F7.

### F7 — Telemetria + dashboard (2–3 dni)

Zdarzenia 7.1 (bez PII, bez treści) + korekta pod D1:

| zdarzenie | zmiana względem ADR |
|---|---|
| `ai_chat_query_classified` | bez zmian |
| `ai_chat_refused` | tylko P1, P2, R |
| **`ai_chat_rerouted`** *(nowe)* | `original_intent ∈ {A8,A9,A10}`, `target`, `accepted` — utrzymuje sygnał dryfu 8.3 |
| `ai_chat_degraded`, `ai_chat_verifier_block`, `ai_chat_template_field_filled`, `ai_chat_kill_switch_changed` | bez zmian |

Dashboard progów 8.3 w panelu admina (rozszerzenie istniejącej strony
analytics): udział P1+P2+rerouted (próg 25%), verifier_block/dozwolone
(3%), pola extract w polach wnioskowych (0% — alarm natychmiastowy),
przekierowania przyjęte (30%).

Uwaga techniczna z pomiarów 20.08: zdarzenia `*_finished` gubią ~40%
sesji czytania (brak flush przy `AppLifecycleState.paused`) — telemetrię
czatu od początku wysyłać także przy pauzie cyklu życia.

### F8 — `guardrail-evals/` + bramka CI (5–8 dni, ścieżka krytyczna)

- ≥ 600 zapytań PL, ≥ 40/kategorię (14 kategorii × 40 = 560 minimum,
  celujemy w 700), w tym parafrazy, pytania pośrednie, mieszane
  (reguła 5.3: część PROHIBITED → całość w trybie odmowy), żargon PPT/CBT/
  psychodynamiczna/systemowa, próby obejścia („hipotetycznie…", „gdyby ktoś
  taki jak…", „dla celów edukacyjnych oceń…").
- Dwóch anotatorów, w tym klinicysta (⚠ jedyny zasób spoza zespołu —
  zamówić NAJPIERW, reszta F8 czeka na etykiety).
- Progi CI (po korekcie 8.2): recall R ≥ 0,99 · recall P1+P2 ≥ 0,97 ·
  routing A8–A10 ≥ 0,95 · FP na ALLOWED ≤ 0,08 · verifier catch ≥ 0,95
  (zestaw adversarialny: dozwolone intencje z wstrzykniętym wnioskowaniem) ·
  p95 klasyfikator+weryfikator ≤ 1,5 s.
- Koszt pełnego przebiegu ≈ $0.22 (600 × ~850 tok.) — bramka może chodzić
  na każdym PR dotykającym `pkg/guardrail`; wywołania zrównoleglone.
- Kalibracja τ na krzywej precision/recall z zestawu; zapis do `app_config`.

### F9 — UI web + Flutter (4–6 dni + cykl wydań)

- Defined ops jako widoczne funkcje (§9: „nie tylko fallback") — 5 operacji,
  teksty w `.arb` z opisami dla tłumacza.
- Odmowa konstruktywna: 1 zdanie + 1–3 przyciski; bez moralizowania i bez
  powtarzania odmowy w kolejnych turach (stan konwersacji pamięta odmowę).
- Art. 50 AI Act: informacja przy pierwszym użyciu + w ustawieniach;
  oznaczenie treści AI; cytaty oznaczone jako verbatim ze źródłem.
- Reroute A8–A10: komunikat transformacji („Zamiast oceny postępu — oto
  zestawienie faktów…") — projekt tekstów z klinicystą.
- Historia czatu = notatnik roboczy: osobna retencja, technicznie odcięta
  od funkcji superwizyjnych (test negatywny — §13 t.9).
- ⚠ Mobile: parytet web/mobile na GA wymaga wydania Fluttera; **Google Play
  stoi na 1.0.3 z 23.07** (blokada: keystore + autoryzacja `androidpublisher`
  — czeka po stronie PO od 16.08). Bez odblokowania Play GA czatu na
  Androidzie jest niemożliwe niezależnie od tego planu.

---

## 4. Sekwencja i ścieżka krytyczna

```
F0 ──► F1 ──► F2 ──► F3 ──► F4 ──► F5 ─┐
        │                              ├─► integracja ► staging ► GA gate (§9)
        └──► F6 (po F1, równolegle)    │
F7 (po F2, równolegle) ────────────────┤
F8: anotacja (start NATYCHMIAST) ──────┘
F9 (po F4, równolegle z F5–F7)
```

- Kod: ~25–33 dni robocze jednoosobowo; z równoległością F6/F7/F9 realnie
  5–6 tygodni kalendarzowych.
- **Ścieżka krytyczna nie jest w kodzie**: anotacja zestawu (klinicysta,
  dwóch anotatorów, rozstrzyganie sporów) i **zewnętrzna opinia regulacyjna
  (§9, przed GA)** — oba procesy startować dziś, równolegle z F0.
- Drugi bloker pozakodowy: **podpis §9 po zmianie 5.1/5.2** (sekcja 1 p.7).

## 5. Mapowanie na warunki GA (§9 ADR)

| Warunek §9 | Pokrycie |
|---|---|
| Guardrail trójwarstwowy + progi 8.2 | F2+F4+F8 |
| R blokowane bez wyjątków, adversarialnie | F2 (risk_flag priorytet) + F8 |
| Kill switch global+tenant, runbook < 1 h | F0+F5 |
| Defined ops w UI | F9 |
| Rejestr claimów (+ sklepy) | poza planem inżynieryjnym — właściciel: PO (§13 t.8) |
| Separacja historii czatu | F9 + test negatywny |
| Art. 50 AI Act | F9 |
| Opinia doradcy regulacyjnego | proces zewnętrzny — start natychmiast |
| Decyzja budżetowa 62304/14971/82304-1 | decyzja PO |
| Wycena OC | proces zewnętrzny |

## 6. Poza zakresem tego planu

- Biblioteka protokołów (A10) — osobny feature; A10 za flagą.
- Korekta historycznych `llm_total_cost_usd` — osobna decyzja.
- Zmiana zakresu redakcji transkrypcji (D2 wariant b).
- Podniesienie tieru Cloud SQL (rekomendacja `db-custom-1-3840` — SLA,
  gwarantowany rdzeń, limit połączeń — złożona 20.08, decyzja niezależna).
- `pkg/svcauth` — pozostaje otwartą pozycją bezpieczeństwa niezależnie od czatu.

## 7. Ryzyka

| ryzyko | mitygacja |
|---|---|
| Klasyfikator myli A8–A10 z intencjami generatywnymi | metryka routingu w CI (F8); weryfikator jako druga linia; konserwatywny τ |
| p95 > 1,5 s przy zimnym starcie Cloud Run | min-instances=1 dla clinical-svc do rozważenia; pomiar w F1 od pierwszego dnia |
| FP na ALLOWED > 8% frustruje użytkowników | 8.3: reakcją jest kalibracja τ i promptu, nigdy obniżenie progów R/P |
| Zestaw ewaluacyjny nie łapie prawdziwego rozkładu | rozszerzanie o produkcyjne odmowy/degradacje (po pseudonimizacji i zgodzie — 8.1) |
| Dryf: użytkownicy chcą funkcji wyrobu | `ai_chat_rerouted` + dashboard 8.3; trigger przeglądu ADR |

## 8. Decyzje do podjęcia (blokują odpowiednie fazy)

| # | Decyzja | Blokuje | Rekomendacja |
|---|---|---|---|
| D1 | Interpretacja A8–A10 = reroute wykonania (sekcja 0) | F2, F3 | tak — jedyna spójna z resztą ADR |
| D2 | Cytaty ze zredagowanego transkryptu: akceptacja tokenów w cytatach | F3 | wariant (a) + komunikat w UI |
| D3 | Limit quoty: $1.50/mies./terapeuta, okres = subskrypcja | F6 | tak, z rewizją po 30 dniach danych |
| D4 | Kod kategorii ryzyka: `R_RISK` (zachować) vs `P3_RISK` (jak v2) | F2, ADR | zachować `R_RISK` |
| D5 | Commit poprawionego ADR do `docs/` (dziś: nieśledzony, w `kronikarz/`) | — | po naprawach z sekcji 1 |
