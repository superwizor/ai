# 16. Plan implementacji — ontologia modalności w tym repozytorium

| Pole | Wartość |
|---|---|
| Plik | `docs/adr/reasoning_docs/16_Plan_Implementacji_Ontologia_v1.0.md` |
| Wersja | 1.2 |
| Data | 22 sierpnia 2026 r. |
| Status | Plan wykonawczy dla dokumentu 11 v1.4 — do akceptacji |
| Podstawa | `11_Architektura_Wnioskowania_Ontologia_v1.4.md` (S1–S5, metaschemat, tickety T1–T36); dokumenty 12–15 przywoływane przez 11 |
| Zakres | Konkretyzacja ticketów na TEN monorepo: serwisy, pliki, migracje, klucze konfiguracji, panele administracyjne, mechanizm wdrożenia modalność-po-modalności z powrotem do obecnego potoku |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-22 | Pierwsza wersja planu. |
| 1.1 | 2026-08-22 | Sekcja 2.5: tryb eksperymentalny — raporty S1–S5 na szkicu ontologii przed autoryzacją; wejście główne: przełącznik w ustawieniach aplikacji (dual-run per nowa sesja), uzupełniające: akcja na żądanie (stare sesje + inna modalność); doprecyzowanie bramki fail-closed; F2-DoD. |
| 1.2 | 2026-08-22 | DECYZJA PRODUKTOWA: ontologia przenosi się z repo (read-only, PR/CODEOWNERS) do bazy — Ontology Studio z cyklem życia draft → ready_for_review → approved, nowa rola ONTOLOGY_EDITOR, aktywacja produkcyjna wyłącznie przez SUPERWIZOR_ADMIN. Własności bezpieczeństwa dawnego D2 odtworzone innymi środkami (four-eyes, niemutowalność approved, walidacja serwerowa, audyt). Pliki ontology/ w repo degradują do seedów. |
| 1.3 | 2026-08-23 | F2 zamknięta po stronie kodu: ontopipe S1/S1.5/S2/S3/S4/S5, zapis grafu twierdzeń (000093), wpięcie w llm-worker za fail-closed przełącznikiem, tryb eksperymentalny obydwoma wejściami (przełącznik dual-run + GenerateExperimentalReport), rejestr zamówień (000094). Otwarte: F1 (autoryzacja ekspercka treści) i F3 (złoty zestaw) — obie zależne od pracy ludzi, nie kodu. |

Ten dokument nie powtarza architektury — mapuje ją na repozytorium. Gdzie
dokument 11 mówi „co i dlaczego", ten mówi „gdzie, czym i w jakiej
kolejności". Rozstrzygnięcia sprzeczne z 11 są niedopuszczalne; miejsca,
w których 11 zostawia wybór, są tu rozstrzygnięte z uzasadnieniem.

---

## 1. Zasada nadrzędna i dwa niezmienniki wdrożeniowe

**„LLM proponuje, struktura rozporządza"** (11 §1). Z tego wynikają dwa
niezmienniki, które obowiązują każdą fazę tego planu:

1. **Stary potok pozostaje nietknięty i ciepły.** Obecna generacja
   raportu (call-1 → RAG → call-2, prompt z `modalities.
   therapist_ai_general_prompt`) nie jest modyfikowana — nowy potok
   powstaje OBOK, za przełącznikiem. Powrót do starego modelu jest
   operacją konfiguracyjną (≤ 30 s propagacji), nie deployem i nie
   rollbackiem kodu.
2. **Ontologia jest danymi wersjonowanymi z wymuszonym cyklem życia**
   (zmiana względem 11 §3.1/D2 — decyzja produktowa 22.08.2026). Treść
   żyje w bazie i jest edytowana w **Ontology Studio** (sekcja 4), ale
   cztery własności dawnego mechanizmu PR/CODEOWNERS są odtworzone
   innymi środkami i są NIENEGOCJOWALNE:
   (a) wersja `approved` jest niemutowalna — edycja to zawsze nowa
   wersja `draft`; (b) autor wersji nie może jej sam zatwierdzić
   (four-eyes); (c) walidacja metaschematem jest serwerowa i twarda —
   przy zapisie, zatwierdzeniu i aktywacji; (d) **aktywacja produkcyjna
   to osobna operacja, wyłącznie SUPERWIZOR_ADMIN**, wymagająca statusu
   `approved` ORAZ zielonego benchmarku. Status ≠ live: zatwierdzona
   wersja nie serwuje niczego, dopóki admin jej nie aktywuje.

---

## 2. Mechanizm wdrożenia przyrostowego (wymaganie: modalność po modalności, z powrotem)

### 2.1. Przełącznik

Wzorzec już istnieje i jest sprawdzony w boju: `pkg/appconfig`
(kolejność rozstrzygania: wiersz organizacji → wiersz globalny → stała w
kodzie; TTL 30 s; kill-switch czatu działa na nim od F0 czatu).

Nowe klucze, jeden per modalność:

```
REPORT_PIPELINE_PPT  = legacy | ontology     (domyślnie: legacy)
REPORT_PIPELINE_CBT  = legacy | ontology     (domyślnie: legacy)
...analogicznie dla pozostałych kodów systemowych modalności
```

Mapowanie kodów: `modalities.system_code` (PPT, CBT, GESTALT, PSYCHO,
ST, SYS, EFT, COACH, UNIV) ↔ katalog `ontology/<lowercase>/`.

Zachowanie:

- `legacy` — dokładnie dzisiejsza ścieżka, bajt w bajt.
- `ontology` — potok S1–S5. Wartość jest ignorowana z ostrzeżeniem w
  logu, jeżeli modalność nie ma AKTYWNEJ wersji ontologii (wskaźnik
  `active_version_id`, ustawiany wyłącznie przez SUPERWIZOR_ADMIN na
  wersji `approved` z zielonym benchmarkiem) — wtedy raport idzie
  ścieżką `legacy`, a telemetria dostaje `report_pipeline_fallback`.
  Fail-closed na `legacy`, nigdy odwrotnie.

Jedynym usankcjonowanym obejściem bramki aktywnej wersji jest **kanał
eksperymentalny** (sekcja 2.5): osobny artefakt, jawnie oznaczony, nigdy
nie zastępujący raportu produkcyjnego. Bramka chroni RAPORT PRODUKCYJNY,
nie zabrania ekspertom patrzeć na wyniki szkicu — bez tego pętla
autoryzacyjna nie ma na czym pracować.

Nadpisanie per organizacja daje kanarka: pilot na organizacji testowej
(np. BETA z kartotekami testowymi) przed przełączeniem globalnym.

### 2.2. Punkt wpięcia

`llm-worker/main.go` — dziś linia ~280 (`loadModalityPrompt`). Rozgałęzienie:

```go
switch pipelineFor(ctx, cfg, session.SystemCode, session.OrganizationID) {
case "ontology":
    reportJSON, meta, err = ontopipe.Generate(ctx, ...)   // S1–S5
default:
    // dotychczasowa ścieżka, bez zmian
}
```

`ontopipe` to nowy pakiet w `services/ai-pipeline-svc/internal/` —
stary kod generacji nie jest refaktoryzowany „przy okazji". To celowe:
przełącznik ma być wiarygodny, więc gałąź `legacy` musi pozostać
niezmieniona także na poziomie diffa.

### 2.3. Ślad na raporcie (migracja 000089)

```sql
ALTER TABLE reports
  ADD COLUMN pipeline_version   TEXT NOT NULL DEFAULT 'legacy',  -- 'legacy' | 'ontology_s1s5'
  ADD COLUMN ontology_version   TEXT,      -- semver, NULL dla legacy
  ADD COLUMN prompt_versions    JSONB,     -- {s1,s2,s2b,s4,s5} per 11 §7
  ADD COLUMN validator_version  TEXT;      -- wersja reguł R1–R10
```

Każdy raport mówi, czym powstał — odtwarzalność do audytu i benchmarku
(11 §7). Stare raporty mają `legacy` z DEFAULT i nie są migrowane.

### 2.4. Runbook powrotu

1. Panel admina → Ontologie → modalność → „Przełącz na legacy" (wymagana
   notatka; audyt jak w AdminSetChatControls).
2. Propagacja ≤ 30 s (TTL czytnika appconfig). Raporty w locie kończą
   się potokiem, w którym wystartowały — rozstrzygnięcie następuje raz,
   na początku generacji.
3. Nic więcej. Brak deployu, brak migracji w dół, stare raporty
   nieruszone. Ponowne włączenie: ta sama ścieżka po naprawie.

Analogia operacyjna: kill-switch czatu (ADR 62 §11) — ten sam wzorzec,
ta sama propagacja, ten sam rodzaj wpisu audytowego.

### 2.5. Tryb eksperymentalny — raporty na szkicu ontologii (v1.1)

**Po co.** Eksperci nie autoryzują `values` i `min_evidence` na sucho —
kalibracja wymaga oglądania, co potok S1–S5 realnie produkuje na
prawdziwych transkryptach, ZANIM ontologia dostanie `approved_by`.
Tryb eksperymentalny jest więc instrumentem pętli autoryzacyjnej
(F1→F2), nie wygodą. Drugi cel: porównanie „ta sama sesja, inna
modalność" (raport CBT dla kartoteki prowadzonej w PPT) — dokładnie
wzorzec „dociągnięcia modalności" znany z soczewek czatu.

**Czym raport eksperymentalny NIE jest.** Nie zastępuje raportu
produkcyjnego, nie pojawia się w panelu klienta, nie wchodzi do
`session.status_changed` (żadnych powiadomień „Raport gotowy" — to
lustro produkcyjne), nie jest materiałem klinicznym. Render z twardym
banerem: „EKSPERYMENT — ontologia niezautoryzowana (szkic X.Y.Z).
Nie służy do pracy klinicznej." + standardowe oznaczenie art. 50.

**Co obchodzi, a czego NIE obchodzi.** Obchodzi wyłącznie bramkę
aktywnej wersji (może użyć KAŻDEJ wersji, także `draft` — dual-run
bierze najnowszą, arkusz na żądanie pozwala wybrać; użyta wersja jest
stemplowana na raporcie) oraz benchmark. NIE obchodzi niczego z warstwy
bezpieczeństwa: walidator dziedzinowy (R1–R9), granica terapeuty (R10),
wyłączenie spanów ryzyka (T22) i weryfikator wyjścia (V1–V6) działają w
trybie eksperymentalnym identycznie jak w produkcyjnym — to nie jest
przedmiot eksperymentu, tylko jego warunek.

**Sterowanie.** Klucz `REPORT_EXPERIMENTAL_ENABLED` w appconfig
(domyślnie `false`; włączany per organizacja — organizacja ekspercka /
BETA), plus dzienny limit `REPORT_EXPERIMENTAL_DAILY_LIMIT` na
terapeutę (domyślnie 5 — potok wieloetapowy na Pro jest drogi; licznik
jak w kwocie czatu). Oba widoczne w panelu 4.2 obok przełącznika potoku.

**Backend.**

```
rpc GenerateExperimentalReport(session_id, modality_code, ontology_version?)
    returns (job_accepted: report_id)
```

clinical-svc: `requireTherapistDataAccess` + flaga + limit → publikacja
zdarzenia na istniejący temat `transcript.completed` z atrybutami
`{pipeline: "experimental", modality_override: <KOD>, requested_by}`.
llm-worker (`ProcessTranscript`): atrybut `experimental` → gałąź
ontopipe z `allow_unapproved=true`, zapis raportu z
`pipeline_version='ontology_s1s5_experimental'` (kolumny z migracji
000089 wystarczają — bez nowych kolumn), koszt księgowany jak w każdym
raporcie. Ukończenie → dokument inbox `experimental_report_ready`
(istniejący `InboxRefreshListener`), NIE `session.status_changed`.
Każdy przebieg zasila telemetrię R1–R10 / `no_fit` → panel Jakość
(4.3) — to jest właściwy produkt eksperymentu.

**Flutter — przełącznik w ustawieniach jako wejście główne, akcja na
żądanie jako uzupełnienie.** Dwa wejścia, bo obsługują ROZŁĄCZNE
przypadki; oba za tą samą flagą organizacji.

1. **Ustawienia aplikacji → „Tryb eksperymentalny" (przełącznik).**
   Semantyka: każda NOWA ukończona sesja generuje raport eksperymentalny
   OBOK produkcyjnego (dual-run) — ekspert nagrywa normalnie i dostaje
   oba do porównania, zero czynności per raport. Modalność = modalność
   kartoteki. Technicznie: preferencja per terapeuta w istniejącym
   kanale `ReportPreferences` (llm-worker już czyta je przy generacji —
   `reportprefs`), więc bez nowego RPC w ścieżce automatycznej; sam
   przełącznik widoczny w ustawieniach tylko, gdy organizacja ma
   `REPORT_EXPERIMENTAL_ENABLED`. Koszt: podwójna generacja — dlatego
   flaga org + dzienny limit obowiązują także tu (licznik wspólny z
   wejściem 2).
2. **Na żądanie (czat „⊕" / ekran raportu)** — dla dwóch przypadków,
   których przełącznik nie obejmie z definicji:
   (a) **stare sesje** — transkrypty już istnieją, nic się nie nagrywa,
   więc dual-run nigdy nie wystartuje; kalibracja ekspercka zaczyna się
   właśnie od istniejącego materiału;
   (b) **inna modalność** — „raport CBT dla kartoteki PPT"; automat idzie
   za modalnością kartoteki, więc porównanie międzymodalnościowe wymaga
   jawnego wyboru. Arkusz: sesja (domyślnie ostatnia z transkrypcją) +
   modalność (domyślnie kartoteki) + potwierdzenie. Wywołuje
   `GenerateExperimentalReport`.

Bez aliasu tekstowego `/eksperyment` w czacie: komenda generacji raportu
jest operacją (side-effect, koszt, artefakt), nie pytaniem — parsowanie
jej z pola tekstowego dodaje powierzchnię błędu, a arkusz z „⊕" robi to
samo bez składni do zapamiętania. Klasyfikator i `guardrail_decisions`
w ogóle jej nie widzą — log dowodowy MDR pozostaje czystym Q&A.
Ukończenie (oba wejścia) → dokument inbox `experimental_report_ready` →
dymek w czacie / odświeżenie listy raportów.

**Retencja i porządek.** Raport eksperymentalny może być usunięty przez
autora (istniejące ścieżki usuwania raportów); w zestawieniach
liczników produkcyjnych (`ReportsAvailable` w statystykach czatu A2/A6)
raporty eksperymentalne NIE są liczone — filtr po `pipeline_version`.

---

## 3. Komponenty — mapowanie na repo

| Komponent (11 §7) | Rozstrzygnięcie w tym repo | Uzasadnienie |
|---|---|---|
| `ontology-registry` (nowy serwis) LUB moduł | **`pkg/ontology` — biblioteka Go czytająca AKTYWNĄ wersję z bazy** (cache TTL 30 s, wzorzec appconfig); Studio i workflow serwuje clinical-svc (RPC `OntologyStudio*`); llm-worker rozstrzyga wersję RAZ na starcie generacji i stempluje ją na raporcie | v1.2: ontologia w bazie zamiast go:embed — edycja w Studio bez release; niezmienność zapewnia status `approved` + append-only `ontology_versions`, nie system plików |
| Migracja 000091 | `ontology_versions` (append-only: modality_id, semver, content JSONB, status draft/ready_for_review/approved, created_by, approved_by, change_note) + wskaźnik `active_version_id` na modalności + `ALTER TYPE user_role ADD VALUE 'ONTOLOGY_EDITOR'` + import seedów z `ontology/*/0.1.0.yaml` jako `draft` | wzorzec 1:1 z modality_prompt_versions (append-only + live column + FOR UPDATE); seedy z repo przestają być źródłem prawdy runtime |
| Walidacja metaschematem (T1) | **serwerowa, w `pkg/ontology`** — twarda przy zapisie draftu, zatwierdzeniu i aktywacji (nie da się utrwalić niesparsowalnej treści); `ontology-lint` w CI zostaje wyłącznie dla plików seedowych w repo | jedna implementacja walidatora używana w obu miejscach |
| S1/S1.5/S2/S2b/S4 (LLM + deterministyka) | `services/ai-pipeline-svc/internal/ontopipe/` — osobne pliki per etap; prompty w `ontopipe/prompts/*.txt` wersjonowane jak `pkg/guardrail/prompts/` | spójność z istniejącą konwencją promptów w repo |
| S3/S3b/S5 (walidatory R1–R10, V1–V6) | `pkg/guardrail/ontology_rules.go` + współdzielony entailment | 11 §7 wprost: wspólny komponent raportu i czatu; `pkg/guardrail` już jest współdzielony |
| Model danych spans/claims (T4) | migracja 000090: `report_spans`, `report_claims`, `report_relations` w clinical-svc (sqlc); spany szyfrowane jak segmenty | proweniencja span→claim→raport; kolumny nieszyfrowane: id, statusy, construct_id, liczniki |
| Benchmark (T9/T10) | `pkg/ontology/cmd/ontology-bench` + złoty zestaw w `ontology/<mod>/golden/`; bramka CI jak guardrail-eval | metryki 8.2 liczone automatycznie, wynik w PR |
| Telemetria 8.3 | istniejący Telemetry w clinical-svc + liczniki w `guardrail_decisions`-podobnej tabeli `report_pipeline_events` (bez PII) | progi przeglądu z 8.3 czytane przez panel Jakość |

Przekrojowe „natychmiast" z dokumentu 11 (§11): **T22** (wyłączenie
spanów ryzyka z wnioskowania), **T28/R10** (granica terapeuty), **T32**
(protokół osiągalności w benchmarku) — wchodzą w F2 jako część
pierwszej implementacji walidatora, nie jako późniejsze poprawki.

---

## 4. Panele administracyjne

Rozszerzenie istniejącego admina (`marketing-site/src/app/[locale]/admin/`,
wzorce: `PromptStudio.tsx`, `ChatControls.tsx`, `ActionDialog` z wymaganą
notatką). Wszystkie teksty przez i18n (pl/en, parytet w CI).

### 4.1. `/admin/ontologies` — Ontology Studio (edycja + cykl życia)

Wzorzec: Prompt Studio, z twardszym workflow.

- **Lista modalności** → wersje ze statusami (`draft` /
  `ready_for_review` / `approved`) + wskaźnik AKTYWNEJ wersji prod.
- **Edytor wersji `draft`**: v1 edytor YAML z walidacją serwerową na
  żywo (endpoint lint — te same reguły co przy zapisie) i podglądem
  konstruktów renderowanym strukturalnie; diff między wersjami;
  optimistic lock jak w Prompt Studio. Edytor strukturalny per
  konstrukt (formularze zamiast YAML) — iteracja 2, świadomie.
- **Przejścia statusów** (każde z wymaganą notatką, ActionDialog,
  pełny audyt):
  - `draft → ready_for_review` — autor zgłasza;
  - `ready_for_review → approved` — WYŁĄCZNIE ktoś inny niż autor
    wersji (ONTOLOGY_EDITOR lub admin) — four-eyes egzekwowane
    serwerowo, nie w UI;
  - `ready_for_review → draft` — odrzucenie z uzasadnieniem;
  - `approved` jest NIEMUTOWALNE — „edytuj" tworzy nową wersję `draft`
    z podbitym semver i skopiowaną treścią.
- **Aktywacja produkcyjna** — osobny przycisk, widoczny tylko dla
  SUPERWIZOR_ADMIN, aktywny gdy: status `approved` ✓ + benchmark
  zielony ✓ (checklista przy przycisku). Ustawia `active_version_id`;
  przepięcie wstecz tą samą ścieżką. ONTOLOGY_EDITOR tego przycisku
  NIE MA — tworzy i zatwierdza treść, nie decyduje o produkcji.
- **Role i dostęp**: sekcja `/admin/ontologies` dostępna dla
  ONTOLOGY_EDITOR i SUPERWIZOR_ADMIN (AdminGuard rozszerzony o wyjątek
  sekcyjny); reszta admina pozostaje wyłącznie dla admina. Nowa rola w
  enumie `user_role`; nadawana z panelu użytkowników przez admina.
- RPC (clinical-svc): `OntologyStudioList / GetVersion / CreateDraft /
  UpdateDraft / Lint / SubmitForReview / Approve / Reject /
  ActivateVersion` — wszystkie audytowane; `ActivateVersion` za
  `requireSuperwizorAdmin`, pozostałe za `requireOntologyEditor`
  (dopuszcza też admina).

### 4.2. `/admin/ontologies/rollout` — Sterowanie potokiem

- Tabela modalności × (globalnie, nadpisania org): przełącznik
  legacy ↔ ontology; przełączenie wymaga notatki i jest audytowane
  (wzorzec `AdminSetChatControls` + `recordKillSwitchChange` 1:1).
- Serwer egzekwuje warunki bramki (approved_by, benchmark zielony) —
  panel je tylko POKAZUJE jako checklistę przy przełączniku; przełącznik
  na `ontology` jest nieaktywny z wyjaśnieniem, dopóki warunki nie są
  spełnione.
- RPC: `AdminGetReportPipeline` / `AdminSetReportPipeline(modality,
  pipeline, organization_id?, note)`.

### 4.3. `/admin/ontologies/quality` — Jakość i luki

- Liczniki odrzuceń R1–R10 i V1–V6 per modalność/konstrukt (z
  `report_pipeline_events`), `s1_reject_rate`, `s4_regeneration_rate`.
- **Rejestr luk**: `no_fit` per konstrukt (próg 8.3: >10 % kwartalnie →
  przegląd ekspercki) i `insufficient_data` per pole.
- Wyniki benchmarku per (wersja ontologii, wersje promptów): tabela
  metryk 8.2 z progami i wynikiem bramki; link do przebiegu CI.
- To jest wejście pętli eksperckiej: z tego ekranu powstają propozycje
  do `common_confusions` (przycisk z 4.1).

### 4.4. Czego Studio świadomie nie robi

- Nie zatwierdza wersji jej autorem (four-eyes serwerowo) i nie edytuje
  wersji `approved` — niemutowalność zastępuje dawny CODEOWNERS.
- Nie aktywuje na produkcji niczego poza `approved` z zielonym
  benchmarkiem — i wyłącznie ręką SUPERWIZOR_ADMIN.
- Nie pokazuje treści spanów/cytatów (PII) — wyłącznie liczniki i
  identyfikatory konstruktów, spójnie z telemetrią 8.3 „bez PII".
- Nie przełącza potoku ani nie aktywuje wersji „na chwilę, bez
  notatki" — notatka obowiązkowa, bo wpis audytowy czyta następny
  dyżurny.

---

## 5. Fazy

Numeracja własna planu; w nawiasach tickety z 11 §11. Każda faza ma
bramkę wyjściową — bez jej przejścia następna nie startuje.

| Faza | Zakres | Bramka wyjściowa |
|---|---|---|
| **F0 — fundament i przełącznik** (T1, T3, T4) | `pkg/ontology` (loader + lint + embed), metaschemat w CI, migracje 000089/000090, klucze `REPORT_PIPELINE_*` w appconfig (wszystkie `legacy`), rozgałęzienie w llm-worker z gałęzią `ontology` zwracającą jeszcze błąd „not implemented" → fallback | CI waliduje ontologie; przełącznik istnieje i fail-closed działa (test: ustawienie `ontology` bez implementacji NIE psuje generacji raportu) |
| **F1 — szkielety ontologii** (T2 + przykład CBT) | seedy `ontology/ppt/0.1.0.yaml` i `ontology/cbt/0.1.0.yaml` zaimportowane migracją jako wersje `draft`; rola ONTOLOGY_EDITOR nadana ekspertom; praca ekspercka zakontraktowana (D2) | Eksperci pracują w Studio na draftach PPT; rozbieżności katalogów (sekcja 6.3) rozstrzygnięte lub jawnie odroczone |
| **F2 — potok S1–S5 dla PPT** (T5–T8 + T22 + T28 + R9) | ontopipe: S1 (+weryfikacja mechaniczna cytatów), S1.5 (recurrence/co_occurrence/latency), S2 per konstrukt (schema z enumem, `insufficient_data`/`no_fit`), S3 R1–R10, S4 bez transkryptu (wymuszone sygnaturą), S5 V1–V6; spany ryzyka wyłączone (T22); zapis spans/claims + wersji na raporcie | Testy jednostkowe per reguła; R5 i R10: 0 przepuszczeń na zestawach adversarialnych; raport PPT generuje się end-to-end na kanarku (org testowa); **tryb eksperymentalny (2.5) działa z czatu Flutter dla PPT i CBT** — bo bez niego sesja autoryzacyjna F1 nie ma materiału |
| **F3 — benchmark i bramka** (T9, T10, T32) | harness, złoty zestaw PPT (≥15 transkryptów × ≥2 ekspertów, podzbiory `no_fit`/`insufficient_data`, protokół osiągalności), bramka CI na progach 8.2 | benchmark PPT zielony → dopiero to odblokowuje przełącznik `ontology` dla PPT poza kanarkiem |
| **F4 — Ontology Studio + panele** (rusza zaraz po F0 — Studio jest warunkiem pracy eksperckiej F1) | 4.1 Studio (edytor, statusy, four-eyes, aktywacja admina), 4.2 rollout, 4.3 jakość; RPC-y; rola w enumie + panel users; i18n; testy | Playwright: pełny cykl draft→review→approve→activate na kanarku + zrzuty; four-eyes: test serwerowy, że autor nie zatwierdzi własnej wersji |
| **F5 — CBT i kolejne** (T19–T27 wg D3) | rozszerzenia metaschematu M1–M4 są w `pkg/ontology` od F0 (metaschemat 3.2 zawiera je w całości) — F5 to autoryzacja treści CBT, złoty zestaw CBT, benchmark, przełączenie | sekwencyjnie per D3: PPT → CBT → psychodynamiczna → ST → Gestalt |
| **F6 — integracja czatu** (T11, T12) | picker A7 z enumów, A4 z ontologii+RAG, reguły ontologiczne w weryfikatorze czatu; soczewki czatu (Prompt Studio) pozostają bez zmian do tej fazy | latencja czatu p95 utrzymana; osobna decyzja o losie soczewek po T11 |

Głębia (T13–T18) wchodzi po F3 za flagą `REPORT_RELATIONS_ENABLED`,
zgodnie z dokumentem 13 — nie jest warunkiem przełączenia PPT.

### Zależności od decyzji blokujących (11 §12)

- **D1 (format raportu)**: F2 buduje S4 w formacie przestrzeni hipotez
  (rekomendacja B). Jeśli D1 rozstrzygnie inaczej — zmiana dotyczy
  wyłącznie S4/UI, nie potoku.
- **D2 (właścicielstwo)**: blokuje wyjście z F1. Bez zakontraktowanej
  pracy eksperckiej ontologie zostają szkicami i przełącznik pozostaje
  fizycznie zablokowany bramką `approved_by` — plan tego nie obchodzi.
- **D3 (kolejność)**: przyjęta sekwencyjnie; CBT ma w tym PR szkic
  ontologii wyłącznie po to, by metaschemat od początku dźwigał M1–M4
  (composite, multi_label, quantities, mediacja) na realnej treści —
  nie po to, by wdrażać CBT równolegle.

---

## 6. Pierwsze przykłady ontologii (w tym PR)

### 6.1. Pliki

- `ontology/_meta/schema.yaml` — metaschemat 3.2 z dokumentu 11, dosłownie.
- `ontology/ppt/0.1.0.yaml` — 13 konstruktów, w tym kompozyt
  `capacity_assessment` (potencjalność + stan deficyt/balans/nadmiar).
- `ontology/cbt/0.1.0.yaml` — 7 konstruktów, w tym kompozyt
  `cbt_episode` (M1: epizod 5-elementowy z kwantyfikacją `stated_only`)
  i `cognitive_distortion` z `multi_label: true` (M2).

Od v1.2 pliki te są SEEDAMI: migracja 000091 importuje je jako wersje
`draft` do bazy i tam toczy się dalsze życie treści (Studio). Pliki w
repo pozostają jako dokumentacja formatu i punkt startowy świeżego
środowiska; nie są źródłem prawdy runtime. Treść pochodzi z dokumentu
11 §3.3 oraz z soczewek czatu (PPT i CBT); każda lista i próg oznaczone
jako placeholder do autoryzacji.

### 6.2. Skąd wzięta treść i co jest jej mocną stroną

Soczewki czatu PPT/CBT zawierają już zamknięte katalogi, notacje,
mapowania antybłędowe („TO NIE SĄ…") — to jest dokładnie materiał na
`values`, `is_not` i `common_confusions`. Plan świadomie przenosi tę
treść z warstwy promptu do warstwy danych, zgodnie z diagnozą 11 §2
(wiersz 7): prompt nie gwarantuje taksonomii, enum gwarantuje.

### 6.3. Rozbieżność do rozstrzygnięcia ekspercko (jawna)

Katalog potencjalności PIERWOTNYCH: dokument 11 §3.3 wymienia **11**
pozycji; soczewka PPT (i literatura popularyzatorska) — **13** (dodatkowo
„seksualność/czułość" i „pewność siebie"; „wzór" vs „wzorzec/naśladowanie",
„wiara" vs „wiara/sens" jako warianty nazw). Szkic 0.1.0 przyjmuje 13 z
aliasami i oznacza rozbieżność w `common_confusions` konstruktu — to
pierwszy punkt sesji autoryzacyjnej, nie decyzja tego planu.

---

## 7. Ryzyka i granice planu

- **Praca ekspercka jest ścieżką krytyczną** (D2). Kod F0–F2 można
  dowieźć bez niej, ale przełącznik pozostanie zablokowany — i tak ma
  być. Ryzyko harmonogramowe, nie techniczne.
- **Koszt i latencja potoku S1–S5** — wieloetapowość na Pro będzie
  droższa od dzisiejszego call-2. Raport jest asynchroniczny (11 §4),
  więc latencja jest akceptowalna; koszt zmierzymy na kanarku PRZED
  przełączeniem globalnym (metryka w F2, próg do ustalenia z PO).
- **Plan nie zmienia kwalifikacji MDR** (11 §1, §10) — konceptualizacja
  pozostaje P2/strefa czerwona; domknięcie D1 w ADR jest poza tym planem.
- **Soczewki czatu i Prompt Studio działają bez zmian do F6** — nie ma
  okresu, w którym czat traci ontologiczne wsparcie, bo dziś ma je w
  warstwie promptu, a po T11 dostanie twardsze w warstwie danych.
- **Benchmark mierzy zgodność z ekspertami, nie prawdę** (11 §9) —
  sufit anotacyjny nazwany, nie obchodzony.

---

*Dokument wewnętrzny. Treści kliniczne w plikach ontologii są
placeholderami do autoryzacji eksperckiej (D2); CI blokuje ich użycie
produkcyjne do czasu niepustego `approved_by`.*
