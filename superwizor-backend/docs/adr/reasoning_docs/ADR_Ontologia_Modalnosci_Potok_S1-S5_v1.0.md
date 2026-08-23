# ADR-0YY: Ontologia modalności jako warstwa egzekwująca wierność teorii (potok S1–S5)

| Pole | Wartość |
|---|---|
| Numer | ADR-0YY *(nadać zgodnie z rejestrem; następny po ADR czatu)* |
| Status | **Proponowany** — do akceptacji po rozstrzygnięciu D1–D3 |
| Data | 20 sierpnia 2026 r. |
| Wersja | 1.0 |
| Decydent | Dario (Product Owner); treść ontologii: eksperci kliniczni |
| Dokumenty powiązane | `docs/11_Architektura_Wnioskowania_Ontologia.md` (specyfikacja pełna); ADR-0XX *AI Chat z klasyfikatorem*; *Analiza wymagań regulacyjnych* rozdz. 4, 10 |
| Impuls | Feedback zewnętrznego recenzenta po teście Supervisor AI (sierpień 2026): 7 klas błędów wnioskowania w raporcie PPT; problem uznany za wspólny dla wszystkich modalności |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-20 | Pierwsza wersja. |

---

## 1. Kontekst

Raport konceptualizacyjny generowany jest dziś w pojedynczym przebiegu LLM z groundingiem RAG. Recenzja ekspercka wykazała systematyczne błędy: kategorie spoza taksonomii szkoły, mieszanie poziomów konstruktów, fałszywe konflikty kluczowe bez wymaganych danych, przymus wypełniania pól, konfabulację etiologiczną, zlanie obserwacji z interpretacją. Diagnoza: *collapse of domain ontology* — model utrzymuje bliskość semantyczną pojęć, ale nie ich formalne relacje; RAG dostarcza tekst o teorii, nie strukturę teorii; schemat raportu wymusza odpowiedź w każdym polu; żadne twierdzenie nie musi wskazać źródła, więc koszt dopowiedzenia jest zerowy.

Iteracja promptów nie rozwiązuje problemu klasy strukturalnej i bez benchmarku daje złudzenie postępu.

## 2. Decyzja

1. **Ontologia każdej modalności jest danymi**, nie treścią promptu: wersjonowane pliki `ontology/<modality>/<semver>.yaml` walidowane wspólnym metaschematem; katalogi zamknięte (np. potencjalności PPT) jako **enumy w JSON Schema wyjścia** — odpowiedź spoza taksonomii jest odrzucana walidacją.
2. **Treść ontologii autoryzują wyłącznie eksperci kliniczni** (pilot: Ewa + zewnętrzny recenzent); CI blokuje użycie ontologii z pustym `approved_by`; zmiany przez PR z uzasadnieniem klinicznym (CODEOWNERS).
3. Generacja raportu przechodzi z pojedynczego przebiegu na **potok S1–S5**: (S1) ekstrakcja jednostek dowodowych z mechaniczną weryfikacją cytatów, (S2) mapowanie per konstrukt na enumach z ontologii, (S3) deterministyczny walidator dziedzinowy (enum, pokrycie dowodowe, zależności `requires`, entailment span→twierdzenie, twarde odrzucenie etiologii bez spanu, rejestr pomyłek `is_not`), (S4) synteza **bez dostępu do transkryptu** — wyłącznie z twierdzeń zatwierdzonych, (S5) weryfikator wyjścia (proweniencja, statusy epistemiczne, zakaz kategorii spoza ontologii).
4. **`insufficient_data` jest wartością pierwszej klasy** w schematach, promptach i UI; pole niewypełnione renderuje się jako „brak wystarczających danych + pytanie na kolejną sesję".
5. **Status epistemiczny** (obserwacja / interpretacja / hipoteza teoretyczna / pytanie otwarte / brak danych) jest wymaganym polem każdego twierdzenia, rozróżnianym wizualnie w UI; każde twierdzenie jest klikalne do spanu źródłowego.
6. Raport dla konstruktów interpretacyjnych przechodzi na **format przestrzeni hipotez** (hipoteza A/B, dane za, dane przeciw, czego nie wiemy, pytania na kolejną sesję) — warunkowo do D1 (rekomendacja: opcja B z dokumentu 11).
7. **Benchmark ekspercki z bramką CI**: złoty zestaw konceptualizacji, metryki wg 7 klas błędów z feedbacku; release promptu lub ontologii wymaga przejścia progów (m.in. pokrycie dowodowe 100 %, konfabulacja etiologii 0, obowiązkowy niezerowy odsetek `insufficient_data` na zestawie z niepełnymi danymi).
8. AI Chat współdzieli komponenty: `A7_TEMPLATE_MAP` z pickerem kategorii z enumów (kategorie nie są generowane), `A4_EDU` z ontologii+RAG, weryfikator czatu z regułami ontologicznymi, wspólny komponent entailmentu, cache spanów S1 per sesja.
9. Silnik jest generyczny: nowa modalność = nowy plik ontologii + praca ekspercka, nie nowy kod. Pilot: PPT; kolejne modalności po przejściu PPT przez benchmark (warunkowo do D3).

## 3. Rozważane opcje

| Opcja | Opis | Dlaczego odrzucona / przyjęta |
|---|---|---|
| A. Iteracja promptów + rozszerzenie RAG | Dopisać taksonomię do promptu, więcej literatury w RAG | Odrzucona jako rozwiązanie główne: nie egzekwuje relacji formalnych; feedback pokazał, że model „brzmi dobrze" mimo błędów; bez benchmarku nieweryfikowalna. Elementy (definicje w promptach S2) zachowane jako uzupełnienie |
| B. Fine-tuning modelu na materiałach szkoły | Dedykowany model per modalność | Odrzucona: koszt i utrzymanie per modalność; brak gwarancji twardych (nadal generacja swobodna); konflikt z przenośnością na kolejne szkoły; komplikacja pozycji AI Act |
| C. Ontologia jako dane + potok + walidator + benchmark | Jak w decyzji | **Przyjęta**: gwarancje twarde tam, gdzie teoria ma strukturę (enumy, reguły deterministyczne); generyczność między modalnościami; mierzalność |
| D. Rezygnacja z konstruktów interpretacyjnych (tylko ekstrakcja) | Raport = cytaty i zestawienia | Odrzucona jako całość produktu (utrata wartości superwizyjnej), ale zachowana jako: tryb degradacji S5 oraz spójna ścieżka z planem B ADR czatu |

## 4. Konsekwencje

**Pozytywne:** klasa błędów 1–7 adresowana strukturalnie, nie stylistycznie; konfabulacja etiologiczna zablokowana twardo (S3-R5 + S4 bez transkryptu); mierzalny postęp (benchmark) zamiast wrażenia postępu; wspólna proweniencja raportu i czatu; pakiet dowodowy do art. 94 MDR i pozycja pod dyrektywą 2024/2853; realna (nie deklaratywna) obrona „klinicysta jako autor decyzji"; skalowalność na modalności.

**Negatywne / koszty:** praca ekspercka rzędu dni na modalność (warunek krytyczny — bez niej architektura jest pusta); wzrost liczby wywołań LLM per raport (S1 + N×S2 + entailment + S4; szacunek kosztów do FinOps przed F2); dłuższy czas generacji raportu (akceptowalne — proces asynchroniczny); złożoność operacyjna (wersjonowanie ontologii, promptów i walidatora łącznie); ryzyko usztywnienia tam, gdzie szkoła ma taksonomię sporną (adresowane: ontologie „miękkie" — mniej enumów, więcej statusów hipotetycznych).

**Ryzyka rezydualne (nazwane wprost):** błędna treść ontologii = spójnie egzekwowany błąd (mitygacja: autoryzacja ekspercka + benchmark); automation bias terapeuty (mitygacja miękka: UX, telemetria klikalności spanów, randomizacja kolejności hipotez); kwalifikacja MDR funkcji konceptualizacyjnych **bez zmian** — pozostaje wnioskowaniem o konkretnym kliencie (P2/strefa czerwona); status modułu raportu wymaga domknięcia w D1 zgodnie z podejściem modułowym MDCG 2019-11.

## 5. Warunki akceptacji (checklist przed wdrożeniem produkcyjnym)

- [ ] D1–D3 rozstrzygnięte i wpisane do niniejszego ADR (aktualizacja do 1.1).
- [ ] Ontologia PPT ≥ 0.1.0 z niepustym `approved_by` (autoryzacja ekspercka udokumentowana).
- [ ] Potok S1–S5 przechodzi benchmark: pokrycie dowodowe 100 %, konfabulacja etiologii 0, niezerowy `insufficient_data` na zestawie z niepełnymi danymi, trafność kategorii ≥ próg startowy.
- [ ] S4 technicznie pozbawiony dostępu do transkryptu (wymuszone sygnaturą/uprawnieniami, nie konwencją; test negatywny).
- [ ] Rejestr odrzuceń S3 (R1–R6) w telemetrii bez PII; dashboard progów przeglądu.
- [ ] UI: statusy epistemiczne, klikalne spany, „brak danych" jako zaproszenie; wybór hipotezy roboczej przez terapeutę logowany.
- [ ] Raporty legacy oznaczone `pipeline_version=legacy`; komunikat zmiany formatu dla użytkowników testowych.
- [ ] ADR czatu zaktualizowany: współdzielone komponenty (registry, entailment, reguły ontologiczne w weryfikatorze, picker A7) + status modułu raportu zgodnie z D1.

## 6. Triggery ponownego przeglądu

- Benchmark: regresja > 2 p.p. na dowolnej metryce lub niemożność osiągnięcia progów startowych w 2 iteracjach.
- Produkcja: `report_claim_rejected(R5) > 5 %`/mies.; klikalność spanów bliska zeru; rozkład wyboru hipotez zdominowany przez pozycję A.
- Ekspercka zmiana taksonomii szkoły (nowa wersja major ontologii).
- Rozstrzygnięcie D1 na opcję A (moduł czerwony) — przegląd łączny z ADR czatu i rozdz. 10 analizy regulacyjnej.
- Wejście drugiej modalności (weryfikacja generyczności metaschematu).

---

*Dokument wewnętrzny. Nie stanowi opinii prawnej.*
