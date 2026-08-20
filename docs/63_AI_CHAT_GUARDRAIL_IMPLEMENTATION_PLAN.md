# Plan implementacji: AI Chat z warstwą guardrail (wg ADR v1.3)

| Pole | Wartość |
|---|---|
| Źródło | `docs/kronikarz/62_ADR_AI_Chat_Klasyfikator_Web_Mobile_v1.0_2.md` **w brzmieniu v1.3** (2026-08-20) |
| Data | 2026-08-20 (aktualizacja po rozstrzygnięciu D1) |
| Gałąź robocza | `feat/chat-window` |
| Status | **F0–F10 zaimplementowane 20.08.2026** — stan wykonania w sekcji 9; blokery pozakodowe w sekcji 4 |

Plan zakłada architekturę backendową (faza 2 z `ai_assistant.go`) — ADR §6
przesądza: „identyczny guardrail po stronie serwera (żadnej logiki
klasyfikacji w kliencie)", a §4.1 odrzuca kontrolę przez system prompt.
Obecna implementacja czatu (wywołanie Vertex z urządzenia przez Firebase
AI Logic) podlega wymianie, nie rozbudowie.

---

## 0. Rozstrzygnięcia (stan na 20.08.2026)

| # | Decyzja | Rozstrzygnięcie |
|---|---|---|
| D1 | Charakter A8–A10 | **Pełne operacje generatywne** (PO, 20.08): konceptualizacja, ocena postępu i propozycje interwencji są generowane jako hipotezy z wymuszonym uziemieniem cytatowym; granice pozostają na P1_DIAG / P2_MED / R_RISK. Ekstraktywne odpowiedniki (A7/A2) stają się ścieżką **degradacji** przy `conf < τ` i w trybie `defined_ops` |
| D4 | Kod kategorii ryzyka | `R_RISK` zachowany (wraz z `X_OTHER`) — zastosowane w ADR v1.1 |
| — | Umiejscowienie | `pkg/guardrail` w `clinical-svc` — budżet p95 ≤ 1,5 s nie mieści osobnego przeskoku |
| — | Transport | RPC **unary** — weryfikator wymaga kompletnej odpowiedzi; wyjątek dopuszczalny tylko dla A4_EDU |
| — | Flagi | tabela `app_config`, cache ≤ 30 s — env-vary wykluczone (deploy), ADR żąda < 1 h |
| — | Weryfikator | dwutrybowy: deterministyczny dla cytatów (pewność 1,0 > próg 0,95), LLM dla pól wolnotekstowych |
| — | Quota | mikrodolary (liczby całkowite), rezerwacja **przed pierwszym wywołaniem modelu**, commit wg `UsageMetadata` |
| — | Log dowodowy | `guardrail_decisions`, 24 miesiące, **jawnie wyłączony z GDPR-purgera** + test negatywny (bez tego pakiet dowodowy na art. 94 MDR wygasa po 90 dniach) |

Konsekwencja D1 nazwana w §9 ADR v1.1: moduł generuje nową informację
kliniczną o konkretnym pacjencie — linia obrony to „ograniczone,
uziemione, oznaczone, mierzone i wyłączalne", nie „odmawiane". Opinia
regulacyjna przed GA jest warunkiem krytycznym; §9 wymaga ponownego
podpisu.

## 1. Stan dokumentu źródłowego

Niespójności v1.0_2 (enum 5.4, prompt 5.5, progi 8.2, kody R_RISK,
artefakt w §3, kolumny schematów A8–A10, changelog) — **naprawione w ADR
v1.1** (ten sam plik, commit razem z tym planem). Otwarte pozostają:

- ~~podpis §9~~ — **zaakceptowany 20.08.2026** (dyspozycja PO, odnotowana w ADR),
- przeniesienie ADR z `docs/kronikarz/` do rejestru `docs/adr/` z nadaniem numeru.

---

## 2. Architektura docelowa (skrót)

```
[Flutter / web — wyłącznie UI]
        │ unary RPC
        ▼
[clinical-svc]
  0. app_config: AI_CHAT_ENABLED, AI_CHAT_MODE (global + org, cache ≤30 s)
  1. quota: rezerwacja µUSD PRZED klasyfikatorem (najtańsza odmowa: 0 wywołań)
  2. pkg/guardrail: klasyfikator (gemini-2.5-flash, T=0, structured output)
  3. router: risk_flag → odmowa R │ P1/P2 → odmowa+przekierowanie
             conf<τ → degradacja (A8→A7, A9→A2, reszta→defined_ops)
             A1–A10 → ścieżka intencji
  4. pobieranie per intencja:
       A1/A7      → transcript_segments (cytaty verbatim + ts)
       A2         → agregacja SQL, bez modelu
       A5         → notatki terapeuty + cytaty
       A4         → BEZ kontekstu klienta (wymuszone w kodzie)
       A8         → cytaty tematyczne + raporty (+ rag_memories jako preselekcja)
       A9         → agregaty A2 + raporty + cytaty trendu
       A10        → cytaty + raporty (biblioteka protokołów: przyszłe wzbogacenie)
  5. generator ze schematem per intencja
       — pola decyzji terapeuty NIE ISTNIEJĄ w schemacie modelu
       — A8–A10 i A5.suggested_questions: twierdzenie bez tablicy cytatów
         jest niereprezentowalne
  6. weryfikator dwutrybowy (decyzja logowana ZAWSZE):
       deterministyczny: cytaty ⊂ transcript_segments (1,0) + uziemienie A8–A10
       LLM T=0:  A1–A7 → „czy zawiera wnioskowanie kliniczne o osobie"
                 A5(sug. pytania)/A8–A10 → „czy zawiera diagnozę /
                 farmakoterapię / ocenę ryzyka"
       brak: A2 (same liczby), A4 (brak osoby)
  7. zapis: chat_interactions + guardrail_decisions (24 mies., poza purgerem)
  8. commit quoty wg UsageMetadata (wycena: pkg/llmcost)
```

Koszt i latencja (kalibracja zmierzona 3,61 znaku/token; stawki 0,30/2,50 USD):

| tura | koszt | latencja szac. |
|---|---|---|
| ekstraktywna (A1–A7) | ≈ $0.0030 | 0,7–1,3 s |
| generatywna (A8–A10; dłuższe wyjście + cytaty w kontekście) | ≈ $0.0035–0.0045 | 0,9–1,4 s |

Budżet 8.2 (p95 ≤ 1,5 s) osiągalny bez zapasu — stąd A2 bez modelu,
weryfikacja deterministyczna wszędzie, gdzie się da, i klasyfikator/
weryfikator na `flash` (udokumentowana słabość `flash-lite` przy wyjściu
strukturalnym; sygnalizowane wycofanie lite 16.10.2026).

---

## 3. Fazy implementacji

Każda faza = gałąź z `feat/chat-window`, testy przed scaleniem, DoD wg
§13 ADR v1.1. Szacunki dla jednej osoby.

### F0 — Fundamenty (2–3 dni) ⚠ warunek wszystkiego dalej

1. **`pkg/llmcost`** — jedna wersjonowana tabela cen. Naprawia dwa błędy:
   komentarz w `llm-worker` (zaniża 6,5×) i naliczanie
   `reports.llm_total_cost_usd` (zawyża 2,6× — stawki 2.5-pro dla raportów
   z 2.5-flash). Korekta danych historycznych osobną decyzją.
2. **Migracja 000084: `app_config`** (`key`, `value`, `organization_id
   NULL=global`, `updated_at`, `updated_by`) + czytnik z cache 30 s.
3. DoD: `llm-eval` liczy po nowych stawkach; test cache'a; runbook
   wyłączenia czatu (UPDATE + pomiar propagacji) opisany i wykonany na stagingu.

### F1 — Szkielet backendowy czatu (3–4 dni)

„Krok 4" z TODO `ai_assistant.go`: wpięcie `pgxpool` + `cryptobox` (już są
w `clinical-svc`) i klienta Vertex (`cloud.google.com/go/aiplatform`,
generacja + embeddingi; **region z env, nie z kodu klienta**); rejestracja
w `connect_adapter.go`; `AskPatientQuestion` unary bez guardraili (flaga,
tylko staging); zapis `chat_interactions` z `UsageMetadata` per wywołanie.

DoD: rozmowa działa na stagingu; wiersz w `chat_interactions` po każdej
turze; koszt tury w logach; pomiar p95 od pierwszego dnia.

### F2 — `pkg/guardrail`: klasyfikator + router (3–4 dni)

- Enum 5.4 v1.1 (A1–A10, P1_DIAG, P2_MED, R_RISK, X_OTHER); prompt
  `classifier_v2.txt` wersjonowany w repo.
- Router: `risk_flag` honorowany niezależnie od intencji i pewności;
  P1/P2 → odmowa + przekierowanie (P1 wskazuje też A8 jako legalną
  alternatywę — „konceptualizacja zamiast diagnozy"); `conf < τ=0.85`
  (z `app_config`) → degradacja A8→A7, A9→A2, reszta → defined_ops.
- `rationale_short` nigdy w logach produkcyjnych.

DoD: stół decyzyjny w testach jednostkowych (intent × risk_flag ×
confidence × tryb); klasyfikator za interfejsem (mock w unit, Vertex w
integracyjnych).

### F3 — Ścieżki pobierania per intencja (5–6 dni)

| intencja | źródło | uwagi |
|---|---|---|
| A1, A7 | `transcript_segments` | cytat + mówca + ts + session_id |
| A2 | agregacje SQL | zero wywołań modelu |
| A5 | notatki + cytaty | `open_questions` wyłącznie user-authored; *(ADR v1.2)* `suggested_questions` — propozycje AI z uziemieniem |
| A4 | **brak kontekstu klienta** | wymuszone w kodzie, test negatywny |
| A6 | istniejące RPC | |
| **A8** | cytaty tematyczne (`transcript_segments`) + raporty; `rag_memories` jako preselekcja sesji kandydackich | kontekst ograniczony do ~8 000 znaków; selekcja cytatów pod kategorie modelu |
| **A9** | agregaty jak A2 + skróty raportów + cytaty ilustrujące trend | prognozy wyłącznie warunkowe (schemat wymusza `caveats`) |
| **A10** | cytaty + raporty | biblioteka protokołów = przyszłe wzbogacenie, nie zależność |

⚠ **Decyzja D2 (otwarta) nabiera wagi**: transkrypcja jest zredagowana
at-rest (od 2026-07-20), a uziemienie A8–A10 pokazuje cytaty przy **każdej
hipotezie** — tokeny `[MIEJSCOWOŚĆ-A]`, `[PRACODAWCA]` będą widoczne w
samym sercu funkcji, nie na jej obrzeżu. Warianty: (a) zaakceptować +
komunikat w UI, (b) zmienić zakres redakcji (konsekwencje dla
`docs/compliance/06`). Plan zakłada (a) do odwołania.

**Wyszukiwanie tematyczne i rola RAG (doprecyzowanie 20.08).** `rag_memories`
(wektory tematów per sesja, 768 wym., indeks HNSW) służy w czacie wyłącznie
do **preselekcji sesji kandydackich** — embedding zapytania → `rag.SelectHits`
→ lista sesji (A8; opcjonalnie A1/A5 przy zapytaniach tematycznych „o pracy",
„o matce"). Wyszukanie samych cytatów odbywa się **wewnątrz** wybranych sesji,
na odszyfrowanych `transcript_segments`, lexykalnie (pg_trgm / FTS —
rozszerzenia `pg_trgm` i `btree_gin` są już zainstalowane, migracja 000001).
Segmenty nie mają dziś embeddingów i plan ich nie dodaje: per-segmentowa
wektoryzacja to osobna decyzja (koszt backfillu i składowania), do podjęcia
dopiero jeśli ewaluacja pokaże lukę recall w wyszukiwaniu cytatów. Pełny
potok RAG z generowania raportów (kotwica, MMR, `ContextMaxChars`) **nie
przenosi się do czatu wprost**, bo `rag_memories` przechowuje pseudonimizowane
skróty bez znaczników czasu — a uziemienie A8–A10 i cytaty A1/A7 wymagają
dokładnych segmentów z `ts_start`/`ts_end`.

DoD: każda ścieżka z testem integracyjnym na prawdziwym Postgresie;
A4 z testem „kontekst nieobecny w promptcie".

### F4 — Schematy + generator + weryfikator dwutrybowy (5–6 dni)

- Schematy A1–A10 w `pkg/guardrail/schemas/`; walidacja serwerowa PO
  odpowiedzi modelu. Pola decyzji terapeuty (`conclusion`, `decision`,
  `filled_by=user`) **nieobecne w schemacie modelu** — serwer dokleja po
  walidacji. A8–A10: `hypotheses[].quotes` z `minItems: 1` — hipoteza bez
  cytatu jest niereprezentowalna strukturalnie. **A5 *(ADR v1.2)*: pole
  modelowe `suggested_questions[]{question, quotes[] minItems:1}` obok
  user-only `open_questions[]` — pierwsza kalibracja granicy autorstwa
  w trybie „poszerzenie = udokumentowana decyzja" (changelog 1.2,
  osobny wpis).**
- Weryfikator:
  - **deterministyczny** (koszt 0, pewność 1,0): każdy cytat dosłownym
    podłańcuchem odszyfrowanego segmentu; mówca/ts zgodne; A8–A10 —
    kompletność uziemienia;
  - **LLM** (T=0, pytanie zamknięte per intencja): A1/A3/A5/A7 —
    wnioskowanie kliniczne o osobie; `A5.suggested_questions` i A8–A10 —
    diagnoza nozologiczna / farmakoterapia / ocena ryzyka w treści;
  - `verifier_block` → zastąpienie wersją ekstraktywną albo odmowa + log.
- **Migracja 000085: `guardrail_decisions`** (bez treści; hash sesji
  czatu; intent, risk_flag, confidence_bucket, decision, verifier_result,
  block_reason, wersje promptów, platforma) — retencja 24 mies., **jawne
  wyłączenie z gdpr-purgera + test negatywny w CI**.

DoD: zestaw adversarialny wstępny (50 przykładów, w tym wstrzyknięta
diagnoza w A8, ocena ryzyka w A9 i diagnoza w sugerowanym pytaniu A5);
catch-rate mierzony; test purgera zielony.

### F5 — Kill switch + plan B (2 dni)

`AI_CHAT_ENABLED` / `AI_CHAT_MODE` z `app_config`; tryb `defined_ops`
(§11: A8–A10 niedostępne, zastępują je A7/A2); zdarzenie
`ai_chat_kill_switch_changed` + `audit_events`; runbook z pomiarem czasu
(cel < 5 min, wymóg < 1 h).

### F6 — Quota per terapeuta (3 dni)

Migracja 000086: `chat_usage_counters(therapist_id, period_start,
period_end, micro_usd_used, micro_usd_reserved, micro_usd_limit)`;
protokół rezerwuj → zatwierdź → zwolnij; rezerwacja górnego oszacowania
**przed klasyfikatorem**; commit wg `UsageMetadata` × `pkg/llmcost`;
limit domyślny $1.50/mies. = `1_500_000` µUSD w `app_config` (per org
nadpisywalny); ostrzeżenie 80%; wyczerpanie → degradacja do defined_ops
(A2/A6 dalej działają; informacja kryzysowa zawsze widoczna); kod błędu
`CHAT_QUOTA_EXHAUSTED`; reset ścieżką `AdminResetTokens`.

Przy $0.003–0.0045/turę limit $1.50 ≈ **330–500 tur/mies.** — do rewizji
po 30 dniach danych (D3).

DoD: test wyścigu dwóch równoległych tur przy prawie wyczerpanym
limicie; test degradacji.

### F7 — Telemetria + dashboard (2–3 dni)

Zdarzenia 7.1 ADR v1.1: `ai_chat_query_classified`, `ai_chat_refused`
(P1/P2/R), `ai_chat_degraded` (low_conf | uncertain | quota),
**`ai_chat_clinical_generated`** (A5/A8–A10: grounding_quote_count,
verifier_result), `ai_chat_verifier_block` (block_reason ∈ {inference,
diag_med_risk, ungrounded}), `ai_chat_template_field_filled`,
`ai_chat_kill_switch_changed`, **`ai_chat_starter_used`** (starter_id,
intent, position — ADR v1.3).

Dashboard progów 8.3 w panelu admina: udział P1+P2+R (25%); **udział
A8–A10 (raport miesięczny, próg miękki 60% — dryf mierzony użyciem)**;
verifier_block (3%); `grounding_quote_count=0` (0% — alarm); pola extract
w polach user-only (0%); przekierowania przyjęte (30%).

Uwaga z pomiarów 20.08: zdarzenia `*_finished` gubią ~40% sesji czytania
— telemetrię czatu wysyłać także przy `AppLifecycleState.paused`.

### F8 — `guardrail-evals/` + bramka CI (5–8 dni, ścieżka krytyczna)

- ≥ 600 zapytań PL (celujemy w 700), ≥ 40/kategorię × 14 kategorii;
  parafrazy, pytania pośrednie, mieszane (reguła 5.3), żargon modalności,
  próby obejścia; **pary graniczne P1↔A8** (diagnoza przebrana za
  konceptualizację i odwrotnie) — nowa, najważniejsza klasa przykładów;
  adversarialne A5: diagnoza/ryzyko przemycone w sugerowanym pytaniu.
- Dwóch anotatorów, w tym klinicysta — **zamówić natychmiast**, reszta F8
  czeka na etykiety.
- Progi CI (8.2 v1.1): recall R ≥ 0,99 · recall P1+P2 ≥ 0,97 ·
  **konfuzja P1→A8 ≤ 0,02** · FP na ALLOWED ≤ 0,08 · verifier catch
  ≥ 0,95 (zestaw dwuczęściowy) · **uziemienie: 0 hipotez bez cytatu** ·
  p95 ≤ 1,5 s.
- Koszt pełnego przebiegu ≈ $0.25 — bramka na każdym PR dotykającym
  `pkg/guardrail`; wywołania równoległe.
- Kalibracja τ na krzywej precision/recall; zapis do `app_config`.
- **Seed v1 wygenerowany 20.08** (`guardrail-evals/`): 658 przykładów
  klasyfikatora (14 kategorii, wszystkie ≥ 40) + 43 przykłady weryfikatora
  (22 block / 21 pass), etykiety `proposed`; `tools/validate.py` działa jako
  brama CI do czasu runnera z F2. Decyzja PO 20.08: **pierwsza iteracja
  implementacyjna bramkuje na `proposed`** (brama regresyjna); bramka GA
  (§9) bez zmian — wyłącznie `adjudicated`. Anotacja pozostaje więc ścieżką
  krytyczną **do GA, nie do startu implementacji**. Zastrzeżenie: etykiety
  `proposed` pochodzą z tej samej rodziny modeli co klasyfikator — poziomy
  metryk mogą być zawyżone; interpretować regresje, nie wartości bezwzględne.

### F9 — UI web + Flutter (5–7 dni + cykl wydań)

- Defined ops jako widoczne funkcje (§9), teksty w `.arb`.
- Odmowa konstruktywna (1 zdanie + 1–3 przyciski; bez powtarzania odmowy).
- Art. 50 AI Act: informacja przy pierwszym użyciu + ustawienia; oznaczenie
  treści AI; **prezentacja A8–A10**: hipotezy oznaczone jako AI do
  weryfikacji klinicysty, rozwijalne cytaty przy każdej hipotezie, pola
  decyzji wizualnie odrębne i edytowalne tylko przez terapeutę.
- *(ADR v1.3)* **Zapytania startowe** przy pierwszym uruchomieniu i pustym
  stanie: rejestr starterów (`starter_id` → intencja → klucz `.arb`);
  kompozycja (włączone/kolejność) z `app_config` — zmiana bez wydania
  aplikacji (lekcja z Google Play 1.0.3); dotknięcie wstawia edytowalny
  tekst do pola. Optymalizacja opcjonalna: **niezmieniony** tekst startera
  może ominąć klasyfikator (intencja znana z rejestru, treść kuratorowana
  ⇒ `risk_flag=false` z konstrukcji) — oszczędza ~$0.0003 i 200–400 ms;
  tekst edytowany zawsze przez klasyfikator. Teksty starterów w rejestrze
  claimów; nazwa celowo różna od `A5.suggested_questions`.
- Historia czatu = notatnik roboczy (osobna retencja, odcięta technicznie
  od funkcji superwizyjnych — test negatywny).
- ⚠ Mobile: parytet web/mobile na GA wymaga wydania Fluttera; **Google
  Play stoi na 1.0.3 z 23.07** (keystore + autoryzacja `androidpublisher`
  po stronie PO od 16.08).

### F10 — Szablony dokumentów terapeuty (po GA; ~6–8 dni)

*Nowe w planie 20.08 (D7). Wypełnia gniazdo, które ADR już przewiduje:
A3_FORMAT niesie `document{template_id, fields[]{filled_by: user|extract}}`,
A7 — `template{model_id, …}`. Zero nowej architektury guardraili —
szablon komponuje istniejące executory.*

- **Zasada (D7): szablon = kompozycja sekcji typowanych, nie zapisany
  prompt.** Typy sekcji: `extract` / `quotes` (A1/A2), `summary` (A5),
  `stats` (A6), `user_only` (`filled_by: user` — pole nieobecne w
  schemacie przekazywanym modelowi), `generative_grounded` (A8–A10:
  schemat z `quotes minItems: 1`, weryfikator bez zmian). Kategorie P/R
  pozostają nieosiągalne konstrukcyjnie — szablon składa wyłącznie
  operacje ALLOWED (§4.1: kontrola strukturalna, nie instrukcyjna).
- Sekcja `generative_grounded` ma pole `instructions` ≤ 500 znaków w roli
  `focus_hint`: wchodzi jako treść użytkownika (nigdy do promptu
  systemowego). Swoboda w „o czym", zero swobody w „jakimi regułami".
- Tabela `report_templates` (migracja — numer wg stanu w momencie
  realizacji): `owner_therapist_id`, `organization_id NULL`, `name`,
  `sections JSONB`, wersje **append-only** (edycja = nowa wersja).
  Wygenerowany dokument zapisuje `(template_id, template_version)` —
  odtwarzalność spójna z pakietem dowodowym.
- Szablon jest **niezależny od kartoteki**: własność terapeuty, dane
  kartoteki wchodzą dopiero w momencie generacji — to realizuje
  „odtworzenie na dowolnej kartotece" z definicji.
- Współdzielenie: prywatny (domyślnie) → organizacja (świadoma akcja
  właściciela). Użycie cudzego szablonu = **fork konkretnej wersji**,
  nie żywa referencja — edycja autora nie zmienia wstecznie cudzych
  dokumentów.
- **Walidacja przy zapisie** (nie przy każdym uruchomieniu): sanityzacja
  `instructions` jak `free_text` (wzorce injection z identity-svc —
  wydzielić do pakietu współdzielonego) + jeden przebieg klasyfikatora
  (~$0.0002); sekcja żądająca P1/P2/R odrzucana z komunikatem już przy
  zapisie. Nowy punkt kontroli ⇒ jednozdaniowa nota do ADR (v1.4) przy
  realizacji.
- Uruchomienie szablonu = zwykłe tury czatu: quota mikro-USD bez zmian,
  `guardrail_decisions` logowane per sekcja, D2 (tokeny redakcji w
  cytatach) obowiązuje tak samo.
- Telemetria: `template_saved` / `template_run` / `template_shared` /
  `template_forked`.
- Evals: rozszerzyć `guardrail-evals/datasets/verifier` o injection przez
  `instructions` (żądania diagnozy/leków/oceny ryzyka w treści sekcji).
- **DoD**: CRUD + walidacja przy zapisie z testami odrzuceń (P1/P2/R w
  `instructions` → odrzucone); test fork/share; dokument niesie wersję
  szablonu; e2e: zapis → uruchomienie na dwóch różnych kartotekach →
  pola `user_only` puste w wyjściu modelu.
- Zależności: F2 (klasyfikator) + F4 (schematy/weryfikator). Poza ścieżką
  krytyczną GA — start dopiero po GA czatu.


---

## 4. Sekwencja i ścieżka krytyczna

```
F0 ──► F1 ──► F2 ──► F3 ──► F4 ──► F5 ─┐
        │                              ├─► integracja ► staging ► GA gate (§9)
        └──► F6 (po F1, równolegle)    │
F7 (po F2, równolegle) ────────────────┤
F8: anotacja (start NATYCHMIAST) ──────┘
F9 (po F4, równolegle z F5–F7)
F10 (po GA — poza ścieżką krytyczną; zależy od F2+F4)
```

- Kod: ~27–36 dni roboczych jednoosobowo; z równoległością realnie
  5–6 tygodni kalendarzowych.
  F10 (~6–8 dni) poza tym szacunkiem — realizacja po GA.
- **Ścieżka krytyczna poza kodem**: (1) anotacja zestawu z klinicystą,
  (2) **zewnętrzna opinia regulacyjna obejmująca wprost generatywne
  A8–A10** — po D1 to najdłuższy i najważniejszy element; oba startować
  dziś, równolegle z F0. (3) ~~Podpis §9~~ — **zaakceptowany 20.08.2026**.

## 5. Mapowanie na warunki GA (§9 ADR v1.1)

| Warunek | Pokrycie |
|---|---|
| Guardrail trójwarstwowy + progi 8.2 | F2+F4+F8 |
| R blokowane bez wyjątków, adversarialnie | F2+F8 |
| Uziemienie A8–A10 + catch diag/med/risk ≥ 0,95 | F4+F8 |
| Kill switch + runbook | F0+F5 |
| Defined ops w UI | F9 |
| Quota aktywna | F6 |
| `guardrail_decisions` poza purgerem + test | F4 |
| Rejestr claimów (z funkcjami generatywnymi) | poza planem inżynieryjnym — właściciel: PO |
| Separacja historii czatu | F9 |
| Art. 50 + oznaczenie hipotez | F9 |
| Opinia regulacyjna (A8–A10 wprost) | proces zewnętrzny — start dziś |
| Decyzja budżetowa 62304/14971/82304-1; wycena OC | decyzje PO |

## 6. Poza zakresem

- Biblioteka protokołów (wzbogacenie A10) — osobny feature.
- Auto-generacja dokumentu z szablonu po każdej sesji (llm-worker) —
  ewentualne rozszerzenie F10; F10 obejmuje wyłącznie on-demand w czacie.
- Globalna kuratorowana biblioteka szablonów — naturalne rozszerzenie
  Prompt Studio (docs/36); F10 kończy się na udostępnieniu w organizacji.
- Korekta historycznych `llm_total_cost_usd`.
- Zmiana zakresu redakcji transkrypcji (D2 wariant b).
- Tier Cloud SQL (`db-custom-1-3840`: SLA, dedykowany rdzeń — rekomendacja z 20.08, decyzja niezależna).
- `pkg/svcauth` — otwarta pozycja bezpieczeństwa niezależna od czatu.

## 7. Ryzyka

| ryzyko | mitygacja |
|---|---|
| **Ekspozycja kwalifikacyjna MDR generatywnych A8–A10** (nazwana w §9 v1.1) | opinia zewnętrzna przed GA jako twarda bramka; granice P1/P2/R w weryfikatorze; uziemienie; kill switch < 5 min; log dowodowy 24 mies. |
| Diagnoza przemycona jako konceptualizacja (P1↔A8) | próg konfuzji ≤ 0,02 w CI; weryfikator LLM na treści hipotez; pary graniczne w zestawie |
| Cytaty z tokenami redakcji w hipotezach (D2) | decyzja produktowa + komunikat UI; wariant (b) jako opcja |
| p95 > 1,5 s (3 wywołania + pobieranie + deszyfrowanie) | A2 bez modelu; weryfikacja deterministyczna; pomiar od F1; min-instances=1 do rozważenia |
| FP na ALLOWED frustruje | kalibracja τ i promptu, nigdy obniżanie progów R/P |
| Zestaw nie łapie realnego rozkładu | rozszerzanie o produkcyjne przypadki (8.1) |

## 8. Decyzje

| # | Decyzja | Stan |
|---|---|---|
| D1 | Charakter A8–A10 | **Rozstrzygnięta 20.08**: pełne generatywne z uziemieniem |
| D2 | Cytaty ze zredagowanego transkryptu w hipotezach A8–A10 | **Otwarta** — waga wzrosła po D1 |
| D3 | Limit quoty $1.50/mies., okres = subskrypcja | Przyjęty jako domyślny; rewizja po 30 dniach danych |
| D4 | Kod `R_RISK` | **Rozstrzygnięta**: zachowany (ADR v1.1) |
| D5 | Umiejscowienie ADR | Poprawiony w miejscu (`docs/kronikarz/`); przeniesienie do `docs/adr/` z numerem — otwarte |
| D6 | Podstawa etykiet w pierwszej iteracji | **Rozstrzygnięta 20.08**: CI deweloperskie na `proposed`; bramka GA wyłącznie na `adjudicated` |
| D7 | Szablony terapeuty: struktura czy zapisany prompt | **Rozstrzygnięta 20.08**: szablon = kompozycja sekcji typowanych na executorach ALLOWED (F10); swobodny zapisywany prompt odrzucony (§4.1 ADR — omijałby warstwę schematów i tworzył powierzchnię generatywną poza klasyfikatorem) |

---

## 9. Stan wykonania (20.08.2026)

Implementacja F0–F10 wykonana w jednym przebiegu na gałęzi
`feat/chat-window`. Kolumna „dowód" wskazuje, co potwierdza działanie —
nie „napisano kod", tylko test, który wywraca się, gdy zachowanie zniknie.

| faza | stan | dowód |
|---|---|---|
| F0 | gotowe | `pkg/llmcost` (test regresyjny na obu błędach cenowych, mutacja truncate wywraca), migracja 000084, `pkg/appconfig` z `-race`, runbook docs/64 |
| F1 | gotowe (kod) | proto unary, `internal/chat` + backend Vertex; **rozmowa na stagingu niewykonana** — patrz niżej |
| F2 | gotowe | stół decyzyjny na pełnym iloczynie intent × risk_flag × pewność × tryb; mutacja przestawiająca risk_flag za pewność wywraca `TestRiskFlagRefusesEverywhere` |
| F3 | gotowe | ścieżki per intencja; **A4 z testem negatywnym** (mutacja wstrzykująca kontekst wywraca go); `TestRetrievalDecryptsOncePerSessionNotPerSegment` |
| F4 | gotowe | schematy z wymuszaniem przez nieobecność, weryfikator dwutrybowy, migracja 000085 + trzy testy źródłowe (mutacje: retencja 90 dni, FK do patient_files, kolumna `question` — wszystkie wywracają CI) |
| F5 | gotowe | `AdminGet/SetChatControls` z wpisem audytowym; SQL w runbooku jako break-glass |
| F6 | gotowe | migracja 000086; **test wyścigu** — przy read-then-write przechodzi 11 z 32 rezerwacji zamiast jednej i licznik przekracza limit 3,4× |
| F7 | gotowe | zdarzenia §7.1; test, że w telemetrii nie ma pytania, odpowiedzi, cytatu ani `rationale_short` |
| F8 | gotowe (bramka strukturalna) | runner + CI; znalazł realną lukę (8 przykładów granicznych P1↔A8 → dosypane do 36) i rozjazd etykiet; **tryb `-live` świadomie poza bramką scaleń** — wymaga Workload Identity |
| F9 | gotowe (kod) | Flutter: wywołanie Vertex z urządzenia usunięte, `firebase_ai` wypada z pubspec; web: `/admin/ai-chat`, build 77 stron, l10n parity OK |
| F10 | gotowe (backend) | migracja 000087, `pkg/guardrail/template.go`; trzy mutacje wywracają: sekcja→intencja zakazana, instrukcje na sekcji ekstraktywnej, zakazane przy wysokiej pewności |

### Odstępstwa od planu odkryte w implementacji

**F3 — pg_trgm nie zadziała.** Plan zakładał wyszukiwanie leksykalne w
`transcript_segments` przez pg_trgm. `text_ciphertext` jest zaszyfrowany;
Postgres nie dopasuje trigramu do szyfrogramu, a deszyfrowanie
per-segment to jeden round-trip do KMS na segment — przy 6 sesjach ×
~200 segmentów około 1200 round-tripów wobec budżetu p95 1,5 s na całą
turę. Zaimplementowano odczyt kanonicznego bloba
(`transcripts.transcript_ciphertext`, źródło prawdy wg ADR-IMPL-006):
**jeden** deszyfr KMS na sesję, sesje równolegle, `segment_id`
domapowany z niezaszyfrowanych `(transcript_id, start_offset_ms)`, więc
weryfikator nadal sprawdza cytaty wobec prawdziwych segmentów.

**Rozjazd nazw etykiet.** Kod Go wymyślił własne wartości (`A2_STATS`,
`A5_PREP`, `A7_TEMPLATE`, `A10_INTERVENTION`) zamiast tych z ADR §5.4
i zestawu ewaluacyjnego. Wartości trafiają do `guardrail_decisions` na
24 miesiące, więc rozjazd unieważniłby zapis historyczny. Wyrównane;
bramka F8 pilnuje tego odtąd automatycznie.

**Schematy uproszczone względem ADR §5.4.** ADR opisuje kształty per
intencja (`pack{…}`, `template{model_id, fields[]}`,
`suggestions{options[]{intervention, rationale, quotes[]}}`).
Zaimplementowano wspólny kształt `sections[]` / `hypotheses[]` z tymi
samymi ograniczeniami (uziemienie `minItems:1`, pola user-only
nieobecne). Kształt jest zgodny co do gwarancji, uboższy co do
specyficzności — do rozstrzygnięcia, czy dociągnąć przed GA.

**Druga, nieosłonięta generacja w kliencie.** „Podsumuj rozmowę" wołało
model bez klasyfikatora, schematu i weryfikatora, żeby wytworzyć nową
treść kliniczną o kliencie. Usunięte; rozmowa zapisuje się dosłownie.

### Latencja: budżet §8.2 nie jest osiągalny (odkryte 20.08 na produkcji)

Pierwsze prawdziwe tury, zmierzone przez `guardrail_decisions`:

| intencja | czas | cytaty | koszt |
|---|---|---|---|
| A1_SEARCH | 10,4 s | 2 | $0,0012 |
| A8_CONCEPT | 25,5 s | 1 | $0,0022 |

Rozkład na składniki (`internal/chat/latency_test.go`):

| krok | czas |
|---|---|
| klasyfikator | 1,60 s |
| embedding | 0,19 s |
| generator @4096 | 12,83 s (912 tokenów wyjścia) |
| **generator @2048** | **7,41 s (903 tokeny — to samo wyjście)** |
| generator @1024 | 7,01 s (139 tokenów — ucięte) |
| weryfikator | 2,47 s |

Zastosowano: `MaxTokens` 4096 → 2048 (5,4 s za dziewięć tokenów treści),
`callTimeout` 20 s → 45 s po tym, jak A5 wywaliło się twardo na 504
DEADLINE_EXCEEDED przed terapeutą.

Po poprawce tura to **~11,5 s** samych wywołań modelu, plus pobieranie i
KMS. Próg §8.2 mówi **p95 ≤ 1,5 s**.

**To nie jest kwestia dalszego strojenia.** Trzy sekwencyjne wywołania
modelu, z których jedno pisze prozę kliniczną, nie zmieszczą się w 1,5 s.
Streaming to ukrywa, ale weryfikator go zabrania z założenia (§4.2) — i
ten kompromis jest słuszny, tylko liczba w ADR mu nie odpowiada.

Warianty do rozstrzygnięcia przez PO:
1. **Zrewidować próg** do wartości osiągalnej (np. p95 ≤ 15 s) i przenieść
   ciężar na komunikat w UI („przygotowuję odpowiedź…"). Guardrail bez zmian.
2. **Zdjąć weryfikator LLM** dla intencji ekstraktywnych — oszczędza 2,5 s,
   ale osłabia warstwę, która złapała diagnozę w teście na żywym modelu.
   Odradzam.
3. **Skrócić kontekst** poniżej 8000 znaków — tanie kilka sekund kosztem
   recall cytatów; wymaga pomiaru, ile recall się traci.

Rekomendacja: wariant 1. Wariant 3 jako uzupełnienie po pomiarze.

### Co pozostaje przed GA

| pozycja | właściciel |
|---|---|
| Migracje 000084–000087 zastosowane na stagingu + rozmowa end-to-end + pomiar p95 | inżynieria (wymaga deployu) |
| Wykonanie runbooku docs/64 na stagingu i wpisanie pomiaru propagacji (§7 tego dokumentu) | inżynieria (po deployu) |
| Tryb `-live` bramki F8 (Workload Identity do projektu Vertex) | inżynieria |
| Anotacja zestawu przez klinicystę → `adjudicated` | PO |
| Zewnętrzna opinia regulacyjna obejmująca wprost generatywne A8–A10 | PO |
| Odblokowanie Google Play (parytet mobilny) | PO |
| Decyzja D2 (tokeny redakcji w cytatach) | PO |
| Teksty czatu do `.arb` / `messages/*.json` (obecnie `TODO(i18n)` w widgetach) | inżynieria |
| RPC dla szablonów F10 + UI edytora | inżynieria |
