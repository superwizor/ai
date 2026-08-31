# Scalenie E4 (fakty i ciągłość) z F7a/F7b — jeden system pamięci

| Pole | Wartość |
|---|---|
| Wersja | 1.0 |
| Data | 31 sierpnia 2026 r. |
| Status | Obowiązujący projekt wykonawczy dla T42 (D1–D4 zatwierdzone przez właściciela produktu 2026-08-31) |
| Impuls | Nota Zmian Silnika §E4 była pisana względem dok. 11 v1.4 — bez wiedzy o wdrożonym w sierpniu kontekście międzysesyjnym (docs/65: okno F7a + indeks semantyczny F7b). Wdrożenie E4 „obok" stworzyłoby dwa równoległe systemy pamięci |
| Dokumenty | docs/65 (F7a/F7b — zrealizowane); docs/plany/Nota_Zmian_Silnika_v1.5.md §E4/§E1; dok. 11 v1.7 |

## 1. Rozstrzygnięcie naczelne

**`prior_report_context` z noty NIE powstaje. PastContext (F7a/F7b) JEST tym wejściem.**

Wszystko, czego nota żąda od `prior_report_context`, już istnieje — szerzej, niż nota prosi:

| Nota §E4 żąda | F7a/F7b już daje | Różnica |
|---|---|---|
| zatwierdzone twierdzenia poprzedniego raportu | okno W=3 sesji: twierdzenia + cytaty dowodowe (budżety 60/120) | okno SZERSZE (3 sesje, nie 1) — zostaje |
| `claim_ref` z wersją | `PastClaim.ID` = uuid wiersza `report_claims`; wersje potoku/ontologii w `report_run_context` | gotowe |
| ładowane do S2b | S2b nie istnieje w implementacji; konsumentami są S2 (blok ustaleń w prompcie), S4 (datowane cytaty) i walidator | konsument z noty ZASTĄPIONY realnymi |
| `cap_when_no_prior_context` (E1) | `PastContext.Stats` (liczba sesji w oknie) | gotowe wejście dla T46 |

## 2. Mapa scalenia — co z noty jest nowe, co istnieje, co umiera

| Element noty §E4 | Werdykt | Realizacja |
|---|---|---|
| `fact_kind` w S1 + weryfikacja mechaniczna | **NOWE** | **T42a (ta iteracja)** — sekcja 3 |
| mapowanie faktów deterministycznie, bez S2 | **NOWE** | **T42a** — pole ontologii `fact_kind_map`, sekcja 3 |
| wejście `prior_report_context` | **UMIERA** | PastContext (§1) |
| ciągłość: relacje `wzmocnienie`/`sprzeczność` do przeszłych hipotez | **NOWE, scalone** z planowanym „kanałem ciągłości" F7b-3 | **T42b** — sekcja 4 |
| „brak relacji = bez nowych danych" (jawny render) | NOWE | T42b |
| rozliczenie pracy domowej (omówiona z rezultatem / wspomniana / nie wrócono) | NOWE | T42b — ta sama rodzina osądu co relacje; w T42a przeszłe ustalenia i tak płyną oknem do S4 z datami |
| ciągłość „reguła 9/7 promptu" w prozie | ISTNIEJE częściowo | V7 (zakotwiczenie ciągłości) + datowane cytaty — od F7a |

**Numeracja reguł — sprostowanie noty.** Nota nadaje „zakazowi procentów" numer V7, a lustru R11 numer V8. V7 jest zajęte (`V7_ciaglosc_bez_zakotwiczenia`, F7a), V8 było zarezerwowane dla kanału ciągłości F7b-3, który niniejszym rozpuszcza się w T42b bez własnej reguły V (jego zabezpieczeniem pozostaje V7). Obowiązująca numeracja: **V8 = zakaz procentów przy hipotezach systemu (E1)**, **V9 = lustro R11 w prozie (E2)**.

## 3. T42a — fakty sesyjne (ta iteracja)

1. **S1**: nowe pole spanu `fact_kind` ∈ {agreement_client, agreement_therapist, agenda_next, agenda_unaddressed, mood_rating, client_metaphor} — opcjonalne; nadawane w ekstrakcji; weryfikacja mechaniczna cytatu bez zmian (fakt bez prawdziwego cytatu nie istnieje). Prompt S1 → s1/1.1.0.
2. **Ontologia**: nowe pole konstruktu `fact_kind_map: {<fact_kind>: <kategoria|"">}`. Konstrukt z tym polem jest **pomijany w S2** (jak kompozyty) i mapowany deterministycznie: span z pasującym `fact_kind` → twierdzenie {kategoria z mapy, status observation, confidence 1.0, dowód = ten span}, walidowane w S3 jak każde inne. Lint F1–F5: klucz z enum; kategoria ∈ values (lub pusta przy values: null); **jeden konstrukt na fact_kind** (deterministyczna trasa); wymagany `forced_status: observation`; tylko kind: category.
3. **Baza**: `report_spans.fact_kind` (migracja 000103) — fakt utrwalony przy spanie płynie do przyszłych sesji istniejącym oknem F7a bez żadnego nowego kodu ładowania.
4. **Seed**: `cbt/0.1.2` — `fact_kind_map` na `session_agreement` (4 mapowania) i `mood_rating`; poza tym identyczny z 0.1.1.

Dlaczego fakt ma być twierdzeniem, a nie osobnym bytem: sekcja `ustalenia` layoutu CBT, okno F7a, indeks F7b i proweniencja działają na twierdzeniach. Fakt jako twierdzenie-obserwacja dziedziczy CAŁĄ tę infrastrukturę za darmo; osobny byt musiałby ją zdublować.

## 4. T42b — ciągłość i rozliczenie (następna iteracja)

Parowanie deterministyczne (kod): bieżące twierdzenie × przeszłe twierdzenia TEGO SAMEGO konstruktu z PastContext (okno + kanał semantyczny). Osąd relacji: jedna zbiorcza runda LLM ze schematem enum {wzmacnia, oslabia, bez_zwiazku} + wskazanie spanów; zapis `report_claim_links` (current_claim_id, past_claim_id, relation); render w sekcji konstruktu („potwierdza hipotezę z 20.08 / osłabia / bez nowych danych"). Rozliczenie pracy domowej: przeszłe twierdzenia `agreement_client` × bieżące spany — ten sam mechanizm osądu, wynik trójstanowy z noty. Reguła: relacja bez pary istniejących identyfikatorów = odrzucenie relacji (nie raportu).

## 5. Niezmienniki (przeniesione z docs/65 §N1–N5 — obowiązują dalej)

Przeszła hipoteza nigdy nie jest dowodem (R2_no_current_span zostaje); retrieval jest częścią proweniencji przebiegu; konfiguracja selekcji wersjonowana; bariera kolejności; zero nowych powierzchni prywatności (fact_kind nie tworzy nowej — to atrybut istniejącego spanu).
