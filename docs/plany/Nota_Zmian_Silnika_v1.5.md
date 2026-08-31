# Nota zmian silnika — delta do dokumentu 11 (v1.4 → v1.5)

| Pole | Wartość |
|---|---|
| Plik | `docs/plany/Nota_Zmian_Silnika_v1.5.md` |
| Wersja | 1.0 |
| Data | 31 sierpnia 2026 r. |
| Status | D1–D4 zatwierdzone 2026-08-31; realizacja w toku (E5/E7/E9/E10 + T42a wdrożone; E4 wg docs/67) |
| Impuls | Porównanie ontologii `cbt/0.1.0` ze zweryfikowanym promptem CBT ujawniło luki silnika przekrojowe (nie tylko CBT); metaschemat w repo (2026-08-26) ma już M5+ `layout`, `label_en`, `value_glosses` — ten dokument dopisuje to, czego nadal brakuje |
| Konsument | `ontology/_meta/schema.yaml` (kontrakt), `pkg/ontology` (lint, typy), `llm-worker` (S1/S2/S4), `guardrail-svc` (S3/S5), benchmark, `cbt/0.1.1`, `ppt/0.1.1` |
| Dokumenty powiązane | dok. 11 v1.4 (§3.2, §4, §8); dok. 13 (R4, S2b); dok. 14 (§7 polityka ryzyka, §8 aplikacja); dok. 15 (R10); plan `value_glosses` v1.0; `cbt_0.1.1.yaml` |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-31 | Pierwsza wersja: E1–E10, wpływ na PPT, tickety T37–T46. |
| 1.1 | 2026-08-31 | **Decyzje D1–D4 zatwierdzone przez właściciela produktu zgodnie z rekomendacjami** (D1: tak — tiery; D2: tak, za flagą per tenant; D3: odrzucana; D4: kolejność logiczna z testem A/B). Faza addytywna E5/E7/E9/E10 wdrożona 2026-08-31 (dok. 11 v1.7). **E4 realizowany wg docs/67** (scalenie z F7a/F7b): `prior_report_context` NIE powstaje — tym wejściem jest istniejący PastContext; numeracja reguł skorygowana (V8 = zakaz procentów, V9 = lustro R11 — V7 zajęte przez ciągłość z F7a). T42a (fact_kind + mapowanie deterministyczne) wdrożone; T42b (relacje ciągłości + rozliczenie pracy domowej) następne. |

---

## 0. Zasada i zakres

Wszystkie zmiany są w duchu „więcej struktury, nie mniej szyn". Dziewięć z dziesięciu jest **addytywnych** (istniejące ontologie i potok działają bez zmian). Jedna — **E1** — zmienia semantykę `min_evidence` (z jedynej bramki na próg dopuszczenia) i wymaga decyzji, bo dotyka tego, jak potok traktuje hipotezy o niskim, ale niezerowym oparciu.

Kolejność ważności (od największego wpływu na wierność promptowi i pozycję regulacyjną): E1 → E2 → E3 → E4 → E6 → E5 → E7 → E8 → E9 → E10.

---

## E1. Kalibracja pewności — deterministyczna, nie deklarowana

**Problem.** Oba zweryfikowane prompty (CBT reguła 8, PPT reguła 6) definiują trzy poziomy pewności przez **cechy dowodów**: „wstępna" (pojedyncze przesłanki / pierwsza sesja), „umiarkowana" (wzorzec w ≥ 2 niezależnych momentach lub sesjach), „ugruntowana" (wiele sesji + rozważona alternatywa) — i zakazują procentów. Potok ma `confidence 0..1` deklarowane przez model w S2 i **żadnego mechanizmu poziomów słownych**. Dodatkowo `min_evidence` działa jako jedyna bramka pass/fail: `core_belief` z `sessions: 2` w pierwszej sesji → R2 → `insufficient_data`, podczas gdy prompt wymaga „wstępna hipoteza jako kierunek do zbadania".

**Zmiana.** Rozdzielenie dwóch pojęć w metaschemacie i S3:

```yaml
# ontology/_meta/schema.yaml — NOWE (globalne, opcjonalne per modalność; domyślne w _shared)
confidence_tiers:
  preliminary:  {label_pl: "wstępna",     min_spans: 1, min_sessions: 1}
  moderate:     {label_pl: "umiarkowana", min_spans: 2, min_sessions: 1, independent_moments: 2}
  established:  {label_pl: "ugruntowana", min_spans: 3, min_sessions: 2, requires_alternative: true}
  cap_when_no_prior_context: preliminary     # pusty kontekst poprzednich sesji = max wstępna
# per konstrukt:
    min_evidence: {...}         # od E1: próg DOPUSZCZENIA twierdzenia (bez zmian składni)
    admission_tier: preliminary | moderate | established | null   # NOWE: minimalny poziom,
                                # od którego konstrukt może być renderowany jako twierdzenie;
                                # poniżej -> insufficient_data. null = preliminary
```

**Semantyka w S3 (nowa reguła R-T, deterministyczna):** poziom pewności = najwyższy tier, którego wszystkie warunki spełniają metadane dowodów zatwierdzonego twierdzenia (liczba spanów po R4, rozpiętość `sessions`, liczba niezależnych momentów = spany w różnych sesjach lub odległe czasowo o ≥ N minut, obecność `counter_evidence` **lub** hipotezy alternatywnej w przestrzeni hipotez). Cap przy braku `prior_report_context` (E4). `confidence` numeryczne z S2 pozostaje **wewnętrzne** (priorytetyzacja, telemetria), S4 renderuje **wyłącznie** etykietę tieru; S5 dostaje regułę V7: brak procentów przy hipotezach systemu (wyjątek: cytowane samooceny klienta — R9).

**Skutek dla ontologii.** `core_belief` CBT: `min_evidence: {spans: 2}`, `admission_tier: preliminary`, `forced_status: theoretical_hypothesis` → w pierwszej sesji renderuje się jako „wstępna hipoteza-kierunek" (zgodnie z promptem), „ugruntowana" dopiero przy `sessions ≥ 2` + alternatywie. Konstrukty, dla których prompt wymaga twardej bramki (PPT `key_conflict`: „wzorzec w ≥ 2 sytuacjach, inaczej Brak danych") zachowują ją przez `min_evidence` + `admission_tier: moderate`.

**Benchmark.** Nowa metryka: zgodność tieru z oceną ekspercką (ekspert oznacza poziom pewności per ustalenie w złotym zestawie — jedna kolumna więcej w protokole anotacji, T17/T32). Kalibracja słowna liczona z dowodów jest **audytowalna** (organ może prześledzić, dlaczego hipoteza była „wstępna") — to lepszy pakiet dowodowy niż liczba z modelu.

---

## E2. R11 — zakaz treści diagnostycznych jako reguła walidatora

**Problem.** Prompt CBT nazywa to „wymogiem prawnym — bezwzględnym"; PPT: „BEZ DIAGNOZY". Potok ma V2 (terminy kategorii spoza ontologii w trybie oznajmującym), ale nazwa zaburzenia nie jest „kategorią spoza ontologii" — jest zwykłym słowem, które V2 przepuści.

**Zmiana.** Reguła **R11** w S3 (twierdzenia, relacje, `hypothesis_text`) i lustrzana **V8** w S5 (proza): słownik nazw jednostek/zaburzeń (PL/EN, z odmianą), wzorce kodów ICD-10/ICD-11/DSM-5, frazy „spełnia kryteria", „rozpoznanie", „diagnoza:" w trybie oznajmującym → twarde odrzucenie + metryka. **Wyjątek:** treść w `quote_verbatim` spanu (diagnoza wypowiedziana na sesji, cytowana jako słowa terapeuty/klienta — prompt to dopuszcza). Słownik wersjonowany w `guardrail-svc` (współdzielony z klasyfikatorem P1 czatu — jedno źródło). Rejestr odrzuceń R11 dołącza do pakietu dowodowego art. 94: produkt **aktywnie odmawia** diagnozowania.

**Ryzyko nazwane:** słowa potoczne pokrywające się z nazwami (np. „depresja" w cytacie klienta) — dlatego wyjątek dla `quote_verbatim` jest warunkiem, nie opcją; fałszywe odrzucenia mierzone w benchmarku (próg ≤ 2 % na zestawie z cytatami zawierającymi takie słowa).

---

## E3. Specyfikacja granicy R10 dla treści o terapeucie

**Problem.** Oba prompty mają sekcje superwizyjne o pracy terapeuty (struktura sesji, jakość interwencji, autorefleksja). R10 zakazuje predykatów mentalnych o terapeucie, ale nie mówi, co **wolno**. Szkice ontologii zredukowały sekcje do `overlooked` z notą „decyzja ws. R10".

**Zmiana — trzy dozwolone formy, egzekwowane w S3/S5:**

| Forma | Warunki | Status | Przykład |
|---|---|---|---|
| Obserwacja struktury/techniki | span z `speaker: therapist`; predykat behawioralny (słownik: ustalił / zadał / przeszedł / podsumował / zapytał…) | `observation` (wymuszony) | „Terapeuta ustalił agendę [s02]" |
| Ocena skuteczności | twierdzenie o **reakcji klienta** po momencie terapeuty; `involves` = span terapeuty + span klienta | `interpretation`/`theoretical_hypothesis` | „Po pytaniu sokratejskim [s14] klient sformułował myśl alternatywną [s15]" |
| Autorefleksja | pytanie otwarte o możliwą myśl terapeuty, powiązane ze spanem obserwowalnego wyboru | **wyłącznie `open_question`** | „Jaka myśl pojawiła się u Ciebie, gdy klient… [s21]?" |

Zakazane pozostają: predykaty mentalne o terapeucie w trybie oznajmującym lub hipotetycznym („terapeuta poczuł/unikał/bał się"), punktacja, porównania do normy. Nowe kryterium `min_evidence.speaker: therapist | client | any` (E9) czyni to wyrażalnym w ontologii. Skutek: pełne sekcje superwizyjne obu promptów mogą wrócić.

---

## E4. Fakty sesyjne w S1 i ciągłość między sesjami

**Problem.** Połowa „Podsumowania" (CBT) i „Bilansu sesji" (PPT) to **ekstrakcja faktów**, nie wnioskowanie: ustalenia, praca domowa, zobowiązania terapeuty, agenda, tematy nieomówione, pomiar nastroju, metafora klienta. Reguła ciągłości (CBT 9, PPT 7) wymaga porównania z poprzednią sesją. Potok nie ma wejścia „kontekst poprzednich sesji" ani typu spanu dla faktów.

**Zmiana.**
- S1: nowe pole spanu `fact_kind: agreement_client | agreement_therapist | agenda_next | agenda_unaddressed | mood_rating | client_metaphor | null` — nadawane w ekstrakcji, weryfikowane mechanicznie jak cytaty; konstrukty faktowe (`session_agreement`, `mood_rating`) mapowane z tych spanów **deterministycznie** (bez S2) — fakt ze spanem nie potrzebuje inferencji.
- Potok: nowe wejście `prior_report_context` = zatwierdzone twierdzenia i fakty z poprzedniego raportu (jako `claim_ref` z wersją), ładowane do S2b. Ciągłość realizują istniejące typy relacji: bieżące twierdzenie ↔ poprzednia hipoteza jako `wzmocnienie` („potwierdza") / `sprzecznosc` („osłabia"); brak relacji = „bez nowych danych" (renderowane jawnie). Rozliczenie pracy domowej = porównanie faktów `agreement_client` z poprzedniego raportu ze spanami `fact_kind` bieżącej sesji (deterministycznie): omówiona z rezultatem / wspomniana / nie wrócono.
- E1 korzysta: `cap_when_no_prior_context` działa na tym wejściu.

---

## E5. Typy slotów: unie i krotność

**Problem.** `construct_ref(<id>)` i `enum_ref(<id>)` przyjmują jeden identyfikator; slot jest jednowartościowy. Skutki: PPT `capacity_assessment` nie może wskazać „potencjalność pierwotna LUB wtórna" (otwarta decyzja T1 w szkicu); CBT `thought_record` nie może przyjąć zapisu z sesji (`span_ref`) LUB z aplikacji (`entry_ref`); `cognitive_conceptualization` ma sloty `episode_1..3` zamiast listy.

**Zmiana (addytywna):** `type: enum_ref(a|b)`, `construct_ref(a|b)`, `span_ref|entry_ref` (unia przez `|`); `multiple: bool` na slocie (lista wartości tego typu, `min_items` opcjonalne). Walidacja: element listy spełnia którykolwiek typ unii. `min_complete_slots` liczy slot `multiple` jako wypełniony przy ≥ 1 elemencie.

---

## E6. `kind: catalog` i R12 — proweniencja interwencji

**Problem.** Sekcje interwencji obu promptów wymagają: nazwa techniki **z listy zamkniętej** oraz „Opiera się na: hipoteza z tego raportu". Dziś lista żyje w `guidance` (proza), a zależność interwencja→hipoteza jest tylko instrukcją dla S4 — niewymuszona. Regulacyjnie to najbardziej „P4-podobna" część raportu; strukturalne powiązanie z zatwierdzoną hipotezą to tania dowodliwość.

**Zmiana.**
- Nowy `kind: catalog` konstruktu: **nie mapowany w S2**, konsumowany przez S4 w sekcjach `interventions`/`suggestions`; pola: `values`, `value_glosses`, opcjonalne metadane per wartość (`stage_min`, `stage_max` — PPT; `prerequisites`).
- **R12** (S3b/S5): każda propozycja interwencji w wyjściu S4 ma `technique ∈ catalog.values` oraz `based_on: [claim_id]` ≥ 1 wskazujące zatwierdzone twierdzenie/hipotezę; brak = odrzucenie propozycji (nie raportu). Dla PPT: walidacja etapu — technika o `stage_min` > etap ustalony w materiale = odrzucenie („przeskok w przód nie", prompt PPT).

---

## E7. G7 — homonimy międzykonstruktowe (rozszerzenie lintera glos)

**Problem.** G6 wykrywa pary podłańcuchowe **wewnątrz** konstruktu. CBT: `bezradność` jako emocja i jako kategoria `core_belief`. PPT: `kontakt` (sfera) i `kontakt` (potencjalność), `osiągnięcia` analogicznie — homonimy **legitymne**, których prompt PPT każe „zawsze precyzować".

**Zmiana.** G7: identyczna wartość w `values` dwóch konstruktów → WARNING, chyba że **obie** mają `value_glosses` (rozbrojenie w S2 i pickerze). Renderer promptu S2 dopisuje przy takiej wartości „(tu: <label konstruktu>)". Wybór per przypadek: ujednoznacznić treść (CBT: `bezsilność`) albo zglosować obie (PPT: homonimy są kanonem — glosy).

---

## E8. Konstrukty współdzielone — `includes`

**Problem.** `session_agreement`, `mood_rating`, elementy faktowe, `confidence_tiers` są **uniwersalne** — powielanie ich per modalność to dryf w 5 kopiach.

**Zmiana.** `ontology/_shared/<name>.yaml` z konstruktami/ustawieniami; w pliku modalności `includes: [_shared/session_facts, _shared/confidence_tiers]`. Lint: konstrukt z `_shared` może być nadpisany lokalnie tylko w polach `label_*`, `aliases`, `value_glosses`, `common_confusions` (nie w `values`/`min_evidence`). Sekcje `layout` referencjonują konstrukty współdzielone jak własne.

---

## E9. `min_evidence.speaker`

**Problem.** Konstrukty o mówcy-terapeucie (E3), materiał przeniesieniowy (psychodynamiczna — `interaction_frame` istnieje, ale nie jako kryterium `min_evidence`).

**Zmiana.** `min_evidence: {..., speaker: therapist | client | any}` (domyślnie `any`); S3 R2 liczy tylko spany o wskazanym mówcy. Addytywne.

---

## E10. Układ raportu — sekcje `patterns` i `out_of_taxonomy` jako wymóg

**Problem.** Metaschemat ma te rodzaje sekcji, ale `ppt/0.1.0` ich nie używa — wzorce S1.5/S2b/S2c i zjawiska `no_fit` lądują „w sekcji końcowej" z reguły domyślnej, czyli w miejscu przypadkowym.

**Zmiana.** Lint: `layout` bez `kind: patterns` lub bez `kind: out_of_taxonomy` → WARNING (nie ERROR — modalność może świadomie łączyć); rekomendacja: obie sekcje w każdej modalności. Uzasadnienie: „układ nigdy nie ukrywa zweryfikowanej treści" (metaschemat) obejmuje także treść relacyjną i pozataksonomiczną.

---

## Wpływ na PPT (co zmienić w `ppt/0.1.1`)

| Zmiana silnika | Skutek dla PPT | Konkretna edycja `ppt/0.1.1` |
|---|---|---|
| **E1** tiers | Prompt PPT ma tę samą skalę słowną i reguły „pusty kontekst = wstępna"; `key_conflict` z `sessions: 3` dziś blokuje konflikt kluczowy niemal zawsze — a prompt mówi „wzorzec w ≥ 2 **sytuacjach**", nie sesjach | `key_conflict`: `min_evidence: {spans: 2}` + `admission_tier: moderate` (≥ 2 niezależne momenty) + `independent_moments` liczone także wewnątrz sesji; `sessions` przenieść do tieru „ugruntowana". `inner_conflict`, `symptom_function`: `admission_tier: preliminary` (zawsze hipoteza — spójnie z `forced_status`) |
| **E2** R11 | Prompt PPT: „BEZ DIAGNOZY" — identyczny wymóg | Brak edycji ontologii; reguła przekrojowa |
| **E3** R10-spec | Sekcja „Wskazówki superwizyjne w duchu PPT" (trzy filary, etap interakcji, ryzyko pozytywnej tyranii, równowaga miłości i poznania, pytanie do autorefleksji) może wrócić w pełnym kształcie | Nowe konstrukty obserwacyjne: `interaction_stage` (przyłączenie/różnicowanie/oddzielenie — brakował już w porównaniu z promptem), `ppt_pillar_observed` (zasada nadziei / równowagi / konsultacji), `positive_tyranny_marker` (przeformułowanie przed uznaniem cierpienia — obserwacja ze spanami terapeuty i klienta); wszystkie `forced_status: observation`, `min_evidence.speaker: therapist`; autorefleksja w sekcji `questions` |
| **E4** fakty + ciągłość | „Bilans sesji" (kotwice, ustalenia, metafora klienta, wątek otwarty) = fakty; reguła 7 promptu (ciągłość) = relacje z poprzednim raportem | `session_agreement` i `mood_rating` z `_shared` (E8); `client_metaphor` przez `fact_kind`; layout: sekcja `ustalenia` po `bilans_sesji` |
| **E5** unie/krotność | Rozwiązuje otwartą decyzję T1 w `capacity_assessment` | `capacity: {type: enum_ref(actual_capacity_primary\|actual_capacity_secondary)}`; `conflict_processing_form` przebudowany na kompozyt `{sfera: enum_ref(balance_model_area), postawa: aktywna\|pasywna}` (z porównania z promptem — model sfera×postawa, nie „ucieczkowy") |
| **E6** catalog + R12 | Prompt PPT: „interwencję dobiera się do etapu: powrót wstecz dozwolony, przeskok w przód nie" — walidowalne przez metadane katalogu | `ppt_technique` `kind: catalog` z `stage_min/stage_max` (ekran filmowy, linia życia, inwentarz analizy różnicowej, historie i metafory, trening uprzejmość↔otwartość, dialog stanów, pytania przyszłościowe…); R12 egzekwuje etap względem `ppt_stage` ustalonego w materiale; historie transkulturowe: `product_quotes` z manifestu korpusu (nie przypisywać Peseschkianowi wymyślonych) |
| **E7** G7 | Homonimy `kontakt`/`osiągnięcia` są kanonem PPT | `value_glosses` na obu stronach każdej pary: `balance_model_area.kontakt/relacje` („sfera życia") i `actual_capacity_primary.kontakt` („potencjalność pierwotna: zdolność nawiązywania więzi") — analogicznie osiągnięcia |
| **E8** `_shared` | Deduplikacja faktów sesyjnych | `includes: [_shared/session_facts, _shared/confidence_tiers]` |
| **E10** layout | Brak sekcji wzorców i pozataksonomicznej w `ppt/0.1.0` | Dodać `wzorce` (`patterns`) po „Analizie w Modelu Równowagi" i `poza_taksonomia` (`out_of_taxonomy`) na końcu — prompt PPT: „co nie pasuje do żadnej kategorii — opisz zwykłym językiem i zaznacz, że to nie kategoria PPT" |
| Z porównania z promptem (bez zmian silnika) | Katalogi | `wzorzec` (nazwa kanoniczna), glosy 4 pozycji, `równowaga` zamiast `balans`, nazwy sfer wg promptu, `family_concept_dimension` (Ja/Ty/My/Pra-My), kryteria positum w L1 + opcjonalny kompozyt `positive_interpretation` (objaw→funkcja→pytanie), rozstrzygnięcie zasób↔potencjalność (slot `construct_ref` zamiast kolizji `is_not`) |

Wniosek: PPT zyskuje na każdej z dziesięciu zmian, a pięć z nich (E1, E3, E4, E6, E7) usuwa niezgodności z promptem PPT, które istnieją **niezależnie od CBT**. `ppt/0.1.1` powinien powstać po zatwierdzeniu tej noty, jednym przebiegiem.

---

## Kolejność wdrożenia i tickety

Faza silnika (przed treścią, addytywne): E5, E7, E8, E9, E10 → E4 (S1 + wejście) → E3 → E2 → E6. **E1 po decyzji** (zmiana semantyki — wymaga przejścia benchmarku PPT z nową kolumną anotacji tierów).

| # | Ticket | Definition of Done |
|---|---|---|
| T37 | E5 — unie typów i `multiple` w slotach | Parser `pkg/ontology/types.go` + lint; walidacja unii; `min_complete_slots` z `multiple`; testy; `cbt/0.1.1` i `ppt/0.1.1` przechodzą |
| T38 | E7 — G7 homonimy międzykonstruktowe + dopisek „(tu: …)" w rendererze S2 | Lint WARNING; render; test na parze `kontakt`/`kontakt` z glosami (PASS) i bez (WARNING) |
| T39 | E8 — `_shared` + `includes` | Ładowanie, nadpisywanie ograniczone do pól dozwolonych, lint; `_shared/session_facts.yaml`, `_shared/confidence_tiers.yaml` |
| T40 | E9 — `min_evidence.speaker` | R2 filtruje po mówcy; testy |
| T41 | E10 — lint WARNING dla brakujących `patterns`/`out_of_taxonomy` | Reguła + komunikat z uzasadnieniem |
| T42 | E4 — `fact_kind` w S1, mapowanie deterministyczne faktów, wejście `prior_report_context`, ciągłość w S2b, rozliczenie pracy domowej | Schemat spanu; weryfikacja mechaniczna; relacje `wzmocnienie`/`sprzecznosc` z `claim_ref` poprzedniego raportu; render „potwierdza/osłabia/bez nowych danych"; testy e2e na dwóch sesjach |
| T43 | E3 — reguły R10-spec w S3/S5 (słownik predykatów behawioralnych, wymuszenie `open_question` dla autorefleksji) | Zestaw adversarialny: 0 przepuszczeń predykatów mentalnych o terapeucie; pełne sekcje superwizyjne renderują się |
| T44 | E2 — R11 + V8 + słownik współdzielony z P1 | 0 przepuszczeń na zestawie diagnostycznym; ≤ 2 % fałszywych odrzuceń na cytatach; rejestr odrzuceń w telemetrii |
| T45 | E6 — `kind: catalog`, R12, metadane etapu | S2 pomija `catalog`; S4 zwraca `technique` + `based_on`; walidacja; PPT: walidacja etapu |
| T46 | **E1** — `confidence_tiers`, `admission_tier`, R-T, V7, kolumna tieru w protokole anotacji, metryka zgodności tierów | Decyzja zatwierdzona; benchmark PPT z tierami; `core_belief` CBT renderuje „wstępna" w 1. sesji; `key_conflict` PPT wg promptu (≥ 2 sytuacje) |

Aktualizacja dokumentów: dok. 11 → v1.5 (metaschemat §3.2: E5/E7/E8/E9/E10/E1; potok §4: `fact_kind`, `prior_report_context`, R11/R12/R-T, V7/V8; benchmark §8.2: tiery, R11 FP); dok. 13 (R4 bez zmian; wzmianka o tierach obok statusów); dok. 15 (E3 jako dopełnienie R10); plan sesji autoryzacyjnej (16): kolumna tierów w anotacji, decyzje z `cbt/0.1.1` i `ppt/0.1.1`.

---

## Decyzje blokujące

| # | Decyzja | Rekomendacja |
|---|---|---|
| D1 | E1 — zgoda na rozdzielenie dopuszczenia od poziomów pewności (zmiana semantyki `min_evidence`) | **Tak** — bez tego oba prompty są niewiernie odwzorowane w najbardziej widocznym dla terapeuty miejscu (etykieta pewności) |
| D2 | E3 — czy sekcje o pracy terapeuty wracają w pełnym kształcie z regułami E3 | **Tak**, za flagą per tenant (część ośrodków może nie chcieć oceny techniki w raporcie) |
| D3 | E6 — czy interwencja bez `based_on` jest odrzucana, czy degradowana do „propozycja bez oparcia" | **Odrzucana** — propozycja bez hipotezy to dokładnie ten rodzaj treści, którego produkt nie powinien generować |
| D4 | Kolejność sekcji CBT (logiczna vs 1:1 z promptem legacy) | Logiczna (jak w `cbt_0.1.1.yaml`), z testem A/B na pilotażu |

*Dokument wewnętrzny. Nie stanowi opinii prawnej.*
