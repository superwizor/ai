# SuperWizor — pakiet dokumentacji (stan: 22 sierpnia 2026)

Zawartość paczki: aktualne wersje wszystkich dokumentów wypracowanych w cyklu sierpień 2026 — architektura wnioskowania AI, zarządzanie wiedzą domenową, analizy modalności, ADR-y, ryzyko regulacyjne oraz formularz milestones founderów. Wersje wcześniejsze (1.0–1.3 dokumentu 11) zostały zastąpione i nie są dołączone; historia zmian w changelogach dokumentów.

## Mapa dokumentów

| Plik | Wersja | Rola | Zależności |
|---|---|---|---|
| `Analiza_regulacyjna_Rozdzial_10_Ryzyko_egzekucyjne_v1.0.md` | 1.0 | Rozdział 10 analizy regulacyjnej: kanały egzekucji MDR (URPL, konkurencyjny, sklepowy, cywilny), realne terminy, praktyki rynkowe | Dokument nadrzędny: analiza z 1.08.2026 (rozdz. 1–9, poza paczką) |
| `ADR_AI_Chat_Klasyfikator_Web_Mobile_v1.0.md` | 1.0 (Zaakceptowany — akceptacja ryzyka) | Decyzja: czat z klasyfikatorem (web+mobile); taksonomia intencji A1–A7/P1–P5/R_RISK, guardrail trójwarstwowy, kill switch, plan B, checklist GA | Rozdział 10; analiza regulacyjna rozdz. 4 |
| `ADR_Ontologia_Modalnosci_Potok_S1-S5_v1.0.md` | 1.0 (Proponowany — do D1–D3) | Decyzja: ontologia jako dane + potok S1–S5 | Dokument 11 (specyfikacja) |
| `11_Architektura_Wnioskowania_Ontologia_v1.4.md` | **1.4** | **Dokument centralny**: potok S1→S1.5→S2→S3(R1–R10)→S2b→S3b(R8)→S2c→S4→S5(V1–V6); metaschemat ontologii z rozszerzeniami M1–M5; benchmark z bramką CI; telemetria; tickety T1–T36; skorowidz decyzji | Dokumenty 12–15 (specyfikacje szczegółowe rozszerzeń) |
| `12_Zarzadzanie_Wiedza_Domenowa_v1.0.md` | 1.0 | Warstwy wiedzy L0–L3, manifest korpusu z polityką licencyjną, wyciągi kanoniczne L1, pipeline ingestu, retrieval A4_EDU, benchmark retrievalu | Dokument 11 §2a (S2 nie konsumuje RAG) |
| `13_Glebia_Wnioskowania_v1.0.md` | 1.0 | Głębia wnioskowania: S1.5 (wzorce), S2b (integracja) + R8, rozwarstwienie R4, metryki głębi (recall ustaleń eksperckich), kalibracja dwustronna abstencji | Rozszerza dokument 11 do v1.2 |
| `14_Modalnosc_CBT_Analiza_Dopasowania_v1.0.md` | 1.0 | CBT: inwentarz, rozszerzenia M1–M4 (kompozyty, multi-label, kwantyfikacja+R9, mediacja+S2c), polityka treści ryzyka (przekrojowa), synergia z aplikacją towarzyszącą | Rozszerza dokument 11 do v1.3 |
| `15_Modalnosci_Psychodynamiczna_Gestalt_v1.0.md` | 1.0 | Psychodynamiczna i Gestalt: R10 (granica terapeuty), `paralela`, `latency`, `interaction_frame`/`observed_by`, protokół osiągalności, M5; synteza czterech modalności i kolejność | Rozszerza dokument 11 do v1.4 |
| `SuperWizor_Milestones_Founderow_Formularz_v1.0.docx` | 1.0 | Formularz roboczy milestones trzech founderów (do uzupełnienia i warsztatu przed prawnikiem); po wgraniu na Dysk Google otwiera się jako natywny Google Doc | Niezależny (ścieżka korporacyjna) |

Kolejność czytania dla nowej osoby: Rozdział 10 → ADR czatu → dokument 11 (całość) → 12 → 13 → 14 → 15; ADR ontologii jako podsumowanie decyzyjne.

## Działania „natychmiast" (niezależne od wszystkich otwartych decyzji)

1. **T22** — wyłączenie spanów ryzyka z wnioskowania (S2/S2b/S2c/S1.5); dokument 14 §7.
2. **T28** — reguła R10: zakaz inferencji o stanach wewnętrznych terapeuty; dokument 15 §2.2-a.
3. **T32** — pole `osiągalność` w protokole anotacji złotego zestawu — **przed** rozpoczęciem anotacji PPT przez ekspertów; dokument 15 §3.2.

## Rejestr otwartych decyzji (stan na 22.08.2026)

| Gdzie | Decyzje |
|---|---|
| Dokument 11 §12 | D1 format raportu (rekomendacja: przestrzeń hipotez) · D2 właścicielstwo ontologii + kontraktacja ekspertów · D3 kolejność modalności (rekomendacja: PPT→CBT→psychodynamiczna→schematy→Gestalt) |
| Dokument 12 §11 | D1 model treści produktowych A4 (rekomendacja: materiały własne ekspertów) · D2 lista dzieł i budżet licencji PPT · D3 terminologia PL wyłącznie w L1 |
| Dokument 13 §13 | D1 limit relacji (~7) · D2 S2b za flagą do przejścia progów · D3 budżet rozszerzonej anotacji |
| Dokument 14 §10 | D1 kanon zniekształceń/emocji · D2 REBT jako wariant · **D3 polityka ryzyka (wymaga doradcy)** · D4 formularze aplikacji równolegle z ontologią CBT |
| Dokument 15 §8 | D1 kanon psychodynamiczny (rekomendacja: McWilliams) · **D2 poziomy organizacji poza v1 (wymaga doradcy)** · D3 kanon Gestalt · D4 budżet anotacji hypothesis-heavy · D5 kolejność 3–5 |
| ADR czatu §9 | Checklist warunków GA (w tym opinia doradcy przed GA) |

Pakiet dla doradcy regulacyjnego (jedno spotkanie): pytania z rozdz. 9 analizy nadrzędnej + rozdz. 10.8 + D3/14 (render sekcji ryzyka) + D2/15 (poziomy organizacji).

Pula pracy eksperckiej do zakontraktowania łącznie (Ewa + recenzent): ontologia PPT + wyciągi L1 + manifest korpusu + anotacja złotego zestawu (z wagami, relacjami i osiągalnością) — D2/11 + D3/12 + D3/13; opcja na CBT w tym samym kontrakcie.

---
*Wszystkie dokumenty: wewnętrzne, nie stanowią opinii prawnej. Treści kliniczne (katalogi, progi) są placeholderami do autoryzacji eksperckiej.*
