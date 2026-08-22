# 16. Plan implementacji — ontologia modalności w tym repozytorium

| Pole | Wartość |
|---|---|
| Plik | `docs/adr/reasoning_docs/16_Plan_Implementacji_Ontologia_v1.0.md` |
| Wersja | 1.1 |
| Data | 22 sierpnia 2026 r. |
| Status | Plan wykonawczy dla dokumentu 11 v1.4 — do akceptacji |
| Podstawa | `11_Architektura_Wnioskowania_Ontologia_v1.4.md` (S1–S5, metaschemat, tickety T1–T36); dokumenty 12–15 przywoływane przez 11 |
| Zakres | Konkretyzacja ticketów na TEN monorepo: serwisy, pliki, migracje, klucze konfiguracji, panele administracyjne, mechanizm wdrożenia modalność-po-modalności z powrotem do obecnego potoku |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-22 | Pierwsza wersja planu. |
| 1.1 | 2026-08-22 | Sekcja 2.5: tryb eksperymentalny — raporty S1–S5 na szkicu ontologii przed autoryzacją; wejście główne: przełącznik w ustawieniach aplikacji (dual-run per nowa sesja), uzupełniające: akcja na żądanie (stare sesje + inna modalność); doprecyzowanie bramki fail-closed; F2-DoD. |

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
2. **Ontologia jest danymi w repo, read-only w runtime** (11 §3.1, D2).
   Panel administracyjny NIE edytuje ontologii produkcyjnej — czyta ją,
   mierzy jej jakość i produkuje PROPOZYCJE zmian (patch → PR). Autoryzacja
   pozostaje w CODEOWNERS + CI. Inaczej collapse ontologii wraca o warstwę
   wyżej, tylko w ładniejszym UI.

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
  logu, jeżeli rejestr ontologii nie ma dla modalności wersji z
  niepustym `approved_by` ALBO ostatni benchmark tej pary
  (ontologia, prompty) nie przeszedł bramki 8.2 — wtedy raport idzie
  ścieżką `legacy`, a telemetria dostaje `report_pipeline_fallback`.
  Fail-closed na `legacy`, nigdy odwrotnie.

Jedynym usankcjonowanym obejściem bramki `approved_by` jest **kanał
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

**Co obchodzi, a czego NIE obchodzi.** Obchodzi wyłącznie dwie bramki:
`approved_by` i benchmark. NIE obchodzi niczego z warstwy
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
| `ontology-registry` (nowy serwis) LUB moduł | **`pkg/ontology` — biblioteka Go + `go:embed` plików YAML** do binarek, które jej potrzebują (llm-worker, clinical-svc); endpointy dla panelu admina serwuje clinical-svc (admin RPC) | Ontologia jest read-only w runtime i „zmiana = release" (11 §7) — embed realizuje to dosłownie: nowa wersja ontologii wchodzi z deployem, nie ma osobnego serwisu do utrzymania, nie ma zależności sieciowej w ścieżce generacji raportu |
| Walidacja metaschematem w CI (T1) | krok w `ci.yml`: `go run ./pkg/ontology/cmd/ontology-lint ./ontology/...`; blokada pustego `approved_by` dla plików referencjonowanych przez `REPORT_PIPELINE_*` | wzorzec: istniejąca bramka guardrail-eval (F8) |
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

### 4.1. `/admin/ontologies` — Rejestr ontologii (viewer)

- Lista modalności: wersja ontologii, status autoryzacji (`approved_by`
  puste = „SZKIC — zablokowane w prod"), liczba konstruktów, data,
  aktywny potok (legacy/ontology, globalnie i per org).
- Szczegół konstruktu: definicja, `values` (enum), `aliases`, `is_not`,
  `min_evidence`, `common_confusions`, `source` (work_id/strony),
  przykłady i kontrprzykłady. Diff między wersjami semver.
- Źródło danych: nowe RPC `AdminListOntologies` / `AdminGetOntology`
  w clinical-svc (czytają z wkompilowanego `pkg/ontology`).
- **Bez edycji.** Przycisk „Zaproponuj poprawkę" otwiera formularz
  ograniczony do `common_confusions` i `aliases` (najczęstsze wnioski z
  produkcji), który generuje gotowy patch YAML do wklejenia w PR —
  odpowiednik `AdminUpdateModalityPrompt` NIE powstaje dla ontologii.

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

### 4.4. Czego panele świadomie nie robią

- Nie edytują `values`, `min_evidence`, definicji — to PR + CODEOWNERS (D2).
- Nie pokazują treści spanów/cytatów (PII) — wyłącznie liczniki i
  identyfikatory konstruktów, spójnie z telemetrią 8.3 „bez PII".
- Nie przełączają potoku „na chwilę, bez notatki" — notatka obowiązkowa
  jak w ChatControls, bo wpis audytowy czyta następny dyżurny.

---

## 5. Fazy

Numeracja własna planu; w nawiasach tickety z 11 §11. Każda faza ma
bramkę wyjściową — bez jej przejścia następna nie startuje.

| Faza | Zakres | Bramka wyjściowa |
|---|---|---|
| **F0 — fundament i przełącznik** (T1, T3, T4) | `pkg/ontology` (loader + lint + embed), metaschemat w CI, migracje 000089/000090, klucze `REPORT_PIPELINE_*` w appconfig (wszystkie `legacy`), rozgałęzienie w llm-worker z gałęzią `ontology` zwracającą jeszcze błąd „not implemented" → fallback | CI waliduje ontologie; przełącznik istnieje i fail-closed działa (test: ustawienie `ontology` bez implementacji NIE psuje generacji raportu) |
| **F1 — szkielety ontologii** (T2 + przykład CBT) | `ontology/ppt/0.1.0.yaml` i `ontology/cbt/0.1.0.yaml` (sekcja 6 — pliki są JUŻ w tym PR jako szkice z `approved_by: []`), sesja autoryzacyjna z ekspertami zakontraktowana (D2), changelog decyzji | Ekspercka autoryzacja PPT rozpoczęta; rozbieżności katalogów (sekcja 6.3) rozstrzygnięte lub jawnie odroczone |
| **F2 — potok S1–S5 dla PPT** (T5–T8 + T22 + T28 + R9) | ontopipe: S1 (+weryfikacja mechaniczna cytatów), S1.5 (recurrence/co_occurrence/latency), S2 per konstrukt (schema z enumem, `insufficient_data`/`no_fit`), S3 R1–R10, S4 bez transkryptu (wymuszone sygnaturą), S5 V1–V6; spany ryzyka wyłączone (T22); zapis spans/claims + wersji na raporcie | Testy jednostkowe per reguła; R5 i R10: 0 przepuszczeń na zestawach adversarialnych; raport PPT generuje się end-to-end na kanarku (org testowa); **tryb eksperymentalny (2.5) działa z czatu Flutter dla PPT i CBT** — bo bez niego sesja autoryzacyjna F1 nie ma materiału |
| **F3 — benchmark i bramka** (T9, T10, T32) | harness, złoty zestaw PPT (≥15 transkryptów × ≥2 ekspertów, podzbiory `no_fit`/`insufficient_data`, protokół osiągalności), bramka CI na progach 8.2 | benchmark PPT zielony → dopiero to odblokowuje przełącznik `ontology` dla PPT poza kanarkiem |
| **F4 — panele administracyjne** (równolegle z F2/F3 po F0) | 4.1 rejestr, 4.2 rollout, 4.3 jakość; RPC-y w clinical-svc; i18n; testy | Playwright: przełączenie kanarka z panelu + zrzut; parytet l10n |
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

Wszystkie `approved_by: []` — CI blokuje użycie w prod. Treść pochodzi z
dokumentu 11 §3.3 oraz z soczewek czatu (PPT i CBT) autorstwa zespołu;
każda lista i próg oznaczone jako placeholder do autoryzacji.

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
