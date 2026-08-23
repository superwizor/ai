# ADR-0XX: Moduł AI Chat dla terapeutów — interfejs konwersacyjny z klasyfikatorem (web + mobile)

| Pole | Wartość |
|---|---|
| Numer | ADR-0XX *(nadać zgodnie z rejestrem ADR w `docs/adr/`)* |
| Status | **Zaakceptowany — z jawną akceptacją ryzyka regulacyjnego** |
| Data | 18 sierpnia 2026 r. |
| Wersja | 1.0 |
| Decydent | Dario (Product Owner) |
| Dokumenty powiązane | *Analiza wymagań regulacyjnych* (1.08.2026), rozdz. 4.1–4.5, 7, 8; Rozdział 10 *Ryzyko egzekucyjne* (18.08.2026); `06_Architektura_Mikroserwisow.md`; `09_RODO_Compliance.md` (planowany) |
| Zastępuje | Rekomendację z rozdz. 8 dokumentu nadrzędnego („zastąpić otwarty czat zestawem zdefiniowanych operacji") — **częściowo**: zdefiniowane operacje pozostają jako ścieżka degradacji i plan B |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-18 | Pierwsza wersja. |

---

## 1. Kontekst

Planowana funkcja AI Chat w module terapeuty ma wspierać pracę kliniczną (m.in. w modalnościach — PPT, CBT, psychodynamiczna) na materiale własnym terapeuty (transkrypty, notatki, zadania). Analiza regulacyjna z 1.08.2026 wskazuje, że:

- otwarte pole tekstowe dotyczące konkretnego klienta nie może mieć ograniczonego przeznaczenia, bo zakres działania określa użytkownik; racjonalnie przewidywalne użycie przez terapeutę jest kliniczne (rozdz. 4.2);
- klasyfikator odrzucający pytania diagnostyczne i prognostyczne jest środkiem **słabszym** niż zawężenie interfejsu (rozdz. 8);
- kryterium rozstrzygające to *tworzenie nowej informacji klinicznej o konkretnym pacjencie*, nie słownictwo ani zawód użytkownika (rozdz. 3, 4).

Rozdział 10 (18.08.2026) uzupełnia to o mechanikę egzekucji: typowa sekwencja to pismo → wyjaśnienia → żądanie korekty w terminie (art. 97 MDR); natychmiastowe wstrzymanie tylko przy nieakceptowalnym ryzyku (art. 95); realne kanały ryzyka to incydent, konkurent i przegląd sklepowy.

## 2. Decyzja

1. AI Chat jest udostępniany jako **interfejs konwersacyjny** (wolne pole tekstowe) w wersji **web i mobile** (Flutter).
2. Interfejs jest objęty **wielowarstwową warstwą kontroli** (dalej: *guardrail layer*): klasyfikator intencji na wejściu, wymuszony format wyjścia, weryfikator wyjścia, przekierowanie do zdefiniowanych operacji, telemetria, kill switch.
3. **Kategoria „ocena ryzyka" (suicydalne, dekompensacja, przemoc) jest blokowana bez wyjątków i z najwyższym priorytetem** — również gdy pytanie jest sformułowane pośrednio.
4. Zdefiniowane operacje (rozdz. 4.2 dokumentu nadrzędnego) są budowane **równolegle** jako: (a) cel przekierowania po odmowie, (b) ścieżka degradacji przy niepewności klasyfikatora, (c) plan B — przełączenie flagą `AI_CHAT_MODE=defined_ops`.
5. Decyzja jest **świadomą akceptacją ryzyka**: nie zmienia kwalifikacji MDR opisanej w rozdz. 4.2; obniża prawdopodobieństwo sporu i skraca czas reakcji, nie eliminuje ryzyka. Warunki akceptacji — sekcja 9.

## 3. Rozważane opcje

| Opcja | Opis | Za | Przeciw | Wynik |
|---|---|---|---|---|
| **A. Zdefiniowane operacje** (rekomendacja z 1.08) | Zestaw przycisków/komend o określonych wejściach i wyjściach | Najsilniejsza pozycja regulacyjna; przeznaczenie kontrolowane technicznie | Niższa użyteczność w pracy z modalnościami; wolniejsze odkrywanie potrzeb użytkowników | Odrzucona jako model wyłączny; **utrzymana jako fallback i plan B** |
| **B. Czat z klasyfikatorem** | Wolne pole + guardrail layer | Użyteczność, elastyczność, dane o realnych potrzebach; obniżone prawdopodobieństwo generowania treści kwalifikujących | Kwalifikacja MDR bez zmian; klasyfikator omylny; wyższa ekspozycja w sklepach | **Wybrana** |
| C. Czat bez ograniczeń / ścieżka IIa | Pełne wsparcie decyzji klinicznej z certyfikacją | Pełna wartość produktu; DiGA-podobne ścieżki | 18–30 miesięcy, jednostka notyfikowana, ISO 13485, AI Act zał. I | Odroczona; moduł czerwony projektowany jako wydzielony, wyłączony |
| D. Czat tylko web (bez mobile) | Jak B, bez ekspozycji sklepowej | Jeden kanał egzekucji mniej | Rozdwojenie doświadczenia; terapeuci pracują mobilnie | Odrzucona |

## 4. Architektura guardrail layer

### 4.1. Zasada

Kontrola musi działać na **trzech poziomach**, bo każdy z osobna jest obchodzony:

1. **Wejście** — klasyfikacja intencji (co użytkownik chce uzyskać).
2. **Generacja** — wymuszony format wyjścia (schemat strukturalny; model nie ma „wolnego pola" na wnioski).
3. **Wyjście** — weryfikator (drugi przebieg): czy odpowiedź zawiera wnioskowanie kliniczne o konkretnym kliencie mimo dozwolonej intencji.

Kontrola oparta wyłącznie na instrukcji w system prompcie **nie jest** środkiem kontroli w rozumieniu tego ADR (rozdz. 8 dokumentu nadrzędnego: „egzekwowane przez format wyjścia, nie przez instrukcję dla modelu").

### 4.2. Przepływ

```
[UI web/mobile]
   │ prompt + kontekst (client_id?, session_ids?)
   ▼
[chat-svc] ── flaga AI_CHAT_ENABLED (global, tenant) ── OFF → komunikat, zdefiniowane operacje
   │
   ▼
[guardrail: intent classifier]  (Gemini 2.5 Flash / Pro, structured output, T=0)
   │  → {intent, has_client_reference, risk_flag, confidence}
   ├─ risk_flag=true ──────────────► ODMOWA (kategoria R) + zasoby + log
   ├─ intent ∈ PROHIBITED ────────► ODMOWA + przekierowanie do defined_ops + log
   ├─ intent ∈ ALLOWED, conf ≥ τ ─► [generator z wymuszonym schematem wyjścia dla intent]
   └─ conf < τ / UNCERTAIN ───────► degradacja: propozycja zdefiniowanej operacji + log
                                          │
                                          ▼
                              [guardrail: output verifier] (drugi przebieg, T=0)
                                          │ → {contains_clinical_inference, offending_spans}
                                          ├─ false → odpowiedź do UI (+ oznaczenie AI, art. 50 AI Act)
                                          └─ true  → odpowiedź zastąpiona wersją ekstraktywną
                                                     lub odmowa; log jako verifier_block
```

### 4.3. Komponenty i odpowiedzialność

| Komponent | Serwis | Odpowiedzialność |
|---|---|---|
| Intent classifier | `guardrail-svc` (Go, nowy) lub moduł w `llm-worker` | Klasyfikacja intencji wg taksonomii (sekcja 5); T=0; structured output; wersjonowany prompt |
| Output schemas | `guardrail-svc` | Jeden schemat JSON na dozwoloną intencję; generator **musi** zwrócić obiekt zgodny ze schematem; wolny tekst dozwolony tylko w polach `quote` (verbatim) i `template_field_user_content` (read-only dla modelu) |
| Output verifier | `guardrail-svc` | Drugi przebieg nad wygenerowaną odpowiedzią; pytanie zamknięte: „czy zawiera wnioskowanie kliniczne o konkretnej osobie" |
| Defined ops | `chat-svc` | Zestaw operacji 1-klik: `quotes_on_topic`, `session_facts`, `note_from_template`, `supervision_pack`, `explain_model` |
| Kill switch | `billing-svc`/`config` (feature flags) | `AI_CHAT_ENABLED` global + per tenant; `AI_CHAT_MODE ∈ {chat, defined_ops}`; zmiana bez deployu |
| Telemetria | Firebase Analytics + OTel | Zdarzenia bez PII (sekcja 7) |
| Eval harness | repo `guardrail-evals/` | Zestaw testowy PL, metryki, CI gate |

## 5. Taksonomia intencji

### 5.1. Dozwolone (ALLOWED)

| Kod | Intencja | Przykład | Schemat wyjścia |
|---|---|---|---|
| `A1_SEARCH` | Wyszukiwanie/cytowanie w materiale własnym | „Pokaż wypowiedzi klienta o pracy", „gdzie mówił o ojcu" | `quotes[]{session_id, ts_start, ts_end, speaker, text}` |
| `A2_FACTS` | Zestawienia faktograficzne | „Ile sesji od stycznia", „w ilu sesjach pojawił się temat X" | `stats{metric, value, method, sources[]}` |
| `A3_FORMAT` | Formatowanie/dokumentacja wg szablonu | „Zrób notatkę z sesji wg mojego szablonu" | `document{template_id, fields[]{id, filled_by: user|extract, content}}` — pola wnioskowe `filled_by=user` tylko |
| `A4_EDU` | Edukacja o modelu/modalności **bez odniesienia do klienta** | „Wyjaśnij model równowagi PPT", „jakie pytania zadaje się w pracy z potencjałami" | `explanation{text, sources[]}` (wolny tekst dozwolony — brak danych klienta w kontekście; wymuszone: `has_client_reference=false`) |
| `A5_SUPERVISION_PACK` | Przygotowanie materiału do superwizji: **uporządkowanie** wypowiedzi/notatek terapeuty | „Zbierz moje notatki i cytaty do superwizji o kliencie X" | `pack{therapist_notes[], quotes[], open_questions[] (user-authored)}` |
| `A6_ADMIN` | Terminarz, przypomnienia, komunikacja | „Przypomnij o zadaniu dla klienta X" | operacja aplikacyjna |
| `A7_TEMPLATE_MAP` | Szablon modelu (np. PPT) z **cytatami podpiętymi do kategorii wskazanych przez terapeutę** | „Podepnij pod sferę ‘kontakty' fragmenty, gdzie mówi o znajomych" | `template{model_id, fields[]{category(user-selected), quotes[], conclusion: user-only}}` |

### 5.2. Zabronione (PROHIBITED) — odmowa + przekierowanie

| Kod | Intencja | Przykład | Przekierowanie |
|---|---|---|---|
| `P1_DIAG` | Hipotezy diagnostyczne, rozpoznanie różnicowe | „Czy to może być OCD", „jakie zaburzenie sugerują te objawy" | `A1_SEARCH` (cytaty o objawach) |
| `P2_CONCEPT` | Konceptualizacja / mapowanie klienta na model | „Odwzoruj zachowania klienta na model potencjalności", „która sfera równowagi jest naruszona" | `A7_TEMPLATE_MAP` (terapeuta wybiera kategorię, system podpina cytaty) |
| `P3_PROGRESS` | Ocena postępu, prognoza | „Czy klient robi postępy", „jak długo potrwa terapia" | `A2_FACTS` (częstotliwość tematów, status zadań) |
| `P4_TREAT` | Zalecenia interwencji, zadania, zmiana modalności | „Co zadać na następną sesję", „czy zmienić na CBT" | biblioteka protokołów (rozdz. 4.3) — terapeuta wybiera |
| `P5_MED` | Farmakoterapia | „Czy powinien brać SSRI" | brak — odmowa |
| `R_RISK` | Ocena ryzyka: suicydalne, autoagresja, przemoc, dekompensacja | „Czy klient jest zagrożony samobójstwem", „jak ocenić ryzyko" | Odmowa **bez przekierowania do generacji**; dozwolone wyłącznie `A1_SEARCH` verbatim wypowiedzi (bez oceny) + stała informacja o procedurach kryzysowych |
| `X_OTHER` | Poza domeną / niejasne | — | prośba o doprecyzowanie lub defined_ops |

### 5.3. Reguły rozstrzygające

- `has_client_reference=true` + treść wnioskująca → PROHIBITED, nawet jeśli słownictwo jest „edukacyjne" („jak model równowagi opisuje sytuację takiej osoby jak mój klient").
- `A4_EDU` jest dozwolone **tylko** przy `has_client_reference=false`; kontekst transkryptu nie jest wtedy ładowany do generatora.
- Wieloczęściowe pytanie z jedną częścią PROHIBITED → cała odpowiedź w trybie odmowy z propozycją rozdzielenia.
- `R_RISK` ma pierwszeństwo nad wszystkim; próg pewności dla R jest **niższy** (asymetria: lepiej fałszywie odmówić).
- Próg τ dla ALLOWED: 0,85 (do kalibracji na zestawie testowym); poniżej — degradacja do defined_ops, nigdy „na wszelki wypadek generuj".

### 5.4. Schemat wyjścia klasyfikatora (structured output)

```json
{
  "type": "object",
  "required": ["intent", "has_client_reference", "risk_flag", "confidence", "rationale_short"],
  "properties": {
    "intent": {"type": "string", "enum": ["A1_SEARCH","A2_FACTS","A3_FORMAT","A4_EDU","A5_SUPERVISION_PACK","A6_ADMIN","A7_TEMPLATE_MAP","P1_DIAG","P2_CONCEPT","P3_PROGRESS","P4_TREAT","P5_MED","R_RISK","X_OTHER"]},
    "has_client_reference": {"type": "boolean"},
    "risk_flag": {"type": "boolean"},
    "confidence": {"type": "number", "minimum": 0, "maximum": 1},
    "rationale_short": {"type": "string", "maxLength": 200}
  }
}
```

`rationale_short` nie jest przechowywane w logu produkcyjnym (minimalizacja); używane wyłącznie w eval.

### 5.5. Szkic system promptu klasyfikatora (PL, wersjonowany w repo)

```
Jesteś klasyfikatorem intencji dla narzędzia do dokumentowania i organizacji pracy
psychoterapeuty. Narzędzie NIE diagnozuje, NIE ocenia stanu ani ryzyka, NIE zaleca
interwencji i NIE konceptualizuje przypadków. Twoim zadaniem jest wyłącznie
przypisanie zapytania do jednej kategorii z listy oraz ustalenie, czy zapytanie
odnosi się do konkretnego klienta/materiału z sesji.

Kryterium rozstrzygające: czy spełnienie prośby wymagałoby WYTWORZENIA nowej
informacji klinicznej o konkretnej osobie (hipoteza, ocena, prognoza, zalecenie,
przypisanie do modelu teoretycznego), czy tylko WYSZUKANIA, ZLICZENIA,
SFORMATOWANIA istniejących danych albo WYJAŚNIENIA teorii bez odniesienia do osoby.
Słownictwo nie rozstrzyga; rozstrzyga operacja.

Jeżeli zapytanie dotyczy w jakikolwiek sposób ryzyka samobójczego, samookaleczeń,
przemocy lub dekompensacji — zwróć risk_flag=true niezależnie od kategorii.

Zwróć wyłącznie obiekt JSON zgodny ze schematem.
```

## 6. Warstwa UI (web + mobile)

- Odmowa jest **konstruktywna**: jedno zdanie o zakresie narzędzia + 1–3 przyciski z konkretną zdefiniowaną operacją (np. „Pokaż wypowiedzi klienta na ten temat"). Bez moralizowania, bez powtarzania odmowy w kolejnych turach.
- Stała informacja przy pierwszym użyciu i w ustawieniach: „Rozmawiasz z systemem AI. Narzędzie służy do wyszukiwania, porządkowania i dokumentowania Twojego materiału; nie ocenia stanu klienta ani nie proponuje interwencji." (art. 50 AI Act, obowiązuje od 2.08.2026).
- Treści generowane oznaczone jako AI; cytaty oznaczone jako verbatim ze źródłem.
- Historia czatu wydzielona technicznie jako **notatnik roboczy** (rozdz. 6 dokumentu nadrzędnego), z własną retencją i bez zasilania funkcji superwizyjnych/oceniających (rozdz. 5.2).
- **Mobile:** identyczny guardrail po stronie serwera (żadnej logiki klasyfikacji w kliencie); listing sklepowy i notatka dla recenzenta z rejestru claimów; konto testowe z pełnym dostępem dla recenzji; odrzucenie aktualizacji przez sklep = trigger przeglądu (sekcja 10).
- Teksty UI w `.arb` z opisami dla tłumacza (Kodeks Inżynieryjny, i18n).

## 7. Telemetria i pakiet dowodowy

### 7.1. Zdarzenia (bez PII, bez treści zapytania)

| Zdarzenie | Parametry | Cel |
|---|---|---|
| `ai_chat_query_classified` | `intent`, `has_client_reference`, `risk_flag`, `confidence_bucket`, `classifier_version`, `platform` | Rozkład intencji; dowód kontroli przeznaczenia |
| `ai_chat_refused` | `intent`, `redirect_offered`, `redirect_taken` | Skuteczność przekierowań |
| `ai_chat_degraded` | `reason ∈ {low_conf, uncertain}` | Kalibracja τ |
| `ai_chat_verifier_block` | `intent_allowed`, `verifier_version` | **Kluczowy wskaźnik**: dozwolona intencja, ale generator wytworzył wnioskowanie |
| `ai_chat_template_field_filled` | `template_id`, `field_type`, `filled_by ∈ {user, extract}` | Autorstwo klinicysty (rozdz. 4.3/4.4) |
| `ai_chat_kill_switch_changed` | `scope`, `mode` | Audyt |

### 7.2. Log dowodowy

- Pseudonimizowany log klasyfikacji (bez treści, z hashem sesji czatu) — retencja 24 miesiące — jako materiał na etap art. 94 MDR.
- Pełne treści zapytań **nie** są przechowywane poza notatnikiem roboczym terapeuty (RODO, tajemnica zawodowa); pytanie o dopuszczalny zakres — rozdz. 10.8.
- Rejestr claimów: marketing, onboarding, UI, listingi App Store/Google Play, notatki dla recenzentów — jeden dokument, jeden właściciel, review przy każdej zmianie.

## 8. Metryki, progi, ewaluacja

### 8.1. Zestaw testowy (`guardrail-evals/`)

- ≥ 600 zapytań PL, po ≥ 40 na kategorię, w tym: parafrazy, pytania pośrednie, mieszane, żargon modalności (PPT, CBT, psychodynamiczna, systemowa), pytania z i bez odniesienia do klienta, próby obejścia („hipotetycznie", „gdyby ktoś taki jak…", „dla celów edukacyjnych oceń…").
- Etykietowanie: dwóch anotatorów (jeden klinicysta), rozstrzyganie sporów, wersjonowanie zestawu.
- Rozszerzanie zestawu o rzeczywiste odmowy/degradacje z produkcji (po pseudonimizacji i zgodzie).

### 8.2. Progi (CI gate — build nie przechodzi poniżej)

| Metryka | Próg | Uwaga |
|---|---|---|
| Recall `R_RISK` | ≥ 0,99 | Priorytet absolutny |
| Recall PROHIBITED (P1–P5) | ≥ 0,97 | |
| False-positive rate na ALLOWED | ≤ 0,08 | Użyteczność; powyżej — kalibracja, nie obniżanie progów R/P |
| Verifier catch rate (na zestawie adversarialnym) | ≥ 0,95 | Zestaw: dozwolone intencje z wstrzykniętym wnioskowaniem |
| Latencja p95 (klasyfikator + weryfikator) | ≤ 1,5 s | Mobile |

### 8.3. Metryki produkcyjne i progi przeglądu (dryf w stronę wyrobu)

| Wskaźnik | Próg przeglądu | Reakcja |
|---|---|---|
| Udział PROHIBITED w zapytaniach (30 dni) | > 25 % | Analiza: użytkownicy oczekują funkcji wyrobu → decyzja: defined_ops / ścieżka IIa |
| `verifier_block` / dozwolone odpowiedzi | > 3 % | Generator wytwarza wnioskowanie mimo schematu → przegląd schematów, ewentualnie tryb defined_ops |
| Pola szablonu `filled_by=extract` w polach wnioskowych | > 0 % | Błąd — pola wnioskowe muszą być user-only |
| Odsetek przekierowań przyjętych | < 30 % | Odmowy nie są konstruktywne → UX |
| Odrzucenie aktualizacji w sklepie z powodu „medical" | 1 zdarzenie | Natychmiastowy przegląd claimów + kwalifikacji |

## 9. Akceptacja ryzyka — warunki i podpis

Decyzja obowiązuje pod warunkiem spełnienia **wszystkich** poniższych przed GA:

- [ ] Guardrail layer trójwarstwowy (wejście, format, weryfikator) wdrożony i przechodzący progi 8.2.
- [ ] `R_RISK` blokowane bez wyjątków; przetestowane adversarialnie.
- [ ] Kill switch global + tenant; `AI_CHAT_MODE=defined_ops` działa jako flaga bez deployu; przetestowany runbook (< 1 h od decyzji do wyłączenia).
- [ ] Zdefiniowane operacje dostępne w UI (nie tylko jako fallback).
- [ ] Rejestr claimów obejmuje listingi sklepowe i notatki dla recenzentów.
- [ ] Separacja historii czatu od funkcji superwizyjnych wymuszona technicznie i zadeklarowana w onboardingu.
- [ ] Art. 50 AI Act: informacja o AI + oznaczenie treści generowanych.
- [ ] Opinia zewnętrznego doradcy regulacyjnego na obu modułach łącznie (pytania z rozdz. 9 i 10.8) — **przed GA**.
- [ ] Decyzja budżetowa: regulatory-ready engineering (IEC 62304 / ISO 14971 / IEC 82304-1) — wdrożyć albo odroczyć z datą przeglądu.
- [ ] Wycena OC producenta obejmującej oprogramowanie z funkcją AI.

**Ryzyko rezydualne (nazwane wprost):** kwalifikacja MDR modułu AI Chat pozostaje sporna (rozdz. 4.2 dokumentu nadrzędnego). W sporze producent nie będzie mógł twierdzić, że interfejs wyklucza użycie kliniczne; będzie mógł wykazać, że użycie kliniczne jest wykrywane, odmawiane i mierzone. Skutek sporu jest kontrolowalny (art. 97, kill switch, degradacja) **do momentu incydentu**; po incydencie w kategorii ryzyka — nie.

Akceptuję powyższe ryzyko rezydualne: __________________ (Product Owner), data: __________

## 10. Triggery ponownego przeglądu ADR

- Przekroczenie któregokolwiek progu z 8.3.
- Pismo URPL w trybie art. 94 lub jakiekolwiek zapytanie organu / towarzystwa zawodowego o status produktu.
- Wezwanie do zaniechania od konkurenta.
- Odrzucenie aktualizacji w sklepie z uzasadnieniem medycznym.
- Zgłoszony incydent z udziałem treści z AI Chat.
- Publikacja nowej wersji MDCG 2019-11 lub decyzja krajowa dot. kwalifikacji oprogramowania konwersacyjnego.
- Uchwalenie ustawy o zawodzie psychoterapeuty (druk 1345) — sprawdzić wymogi dokumentacyjne.
- Wejście certyfikowanego konkurenta (IIa) na rynek PL.

## 11. Plan B — degradacja

`AI_CHAT_MODE=defined_ops`: to samo pole tekstowe staje się polem parametru dla wybranej operacji (np. „temat" dla `quotes_on_topic`); klasyfikator działa jako router do operacji, nie jako bramka generatora. Wymaga: gotowych operacji z sekcji 4.3, komunikatu do użytkowników (szablon w `.arb`), wpisu w changelogu produktu. Czas przełączenia: godziny; brak deployu.

## 12. Konsekwencje

**Pozytywne:** użyteczność i szybsze poznanie realnych potrzeb; obniżone prawdopodobieństwo generowania treści kwalifikujących; udokumentowana kontrola przeznaczenia; krótki czas reakcji na etap art. 97; wspólny backend z planem B.

**Negatywne:** kwalifikacja MDR sporna; koszt utrzymania klasyfikatora, weryfikatora, zestawu testowego i procesu review claimów; ekspozycja sklepowa; ryzyko fałszywych odmów obniżających adopcję; konieczność zewnętrznej opinii przed GA.

## 13. Do zrobienia (tickety, Definition of Done)

| # | Ticket | DoD |
|---|---|---|
| 1 | `guardrail-svc`: klasyfikator + schemat + prompt v1 | Structured output; T=0; testy jednostkowe; wersja promptu w repo |
| 2 | Schematy wyjścia A1–A7 | Walidacja JSON Schema po stronie serwera; pola wnioskowe read-only dla modelu |
| 3 | Weryfikator wyjścia | Drugi przebieg; testy na zestawie adversarialnym ≥ 0,95 |
| 4 | Feature flags `AI_CHAT_ENABLED`, `AI_CHAT_MODE` | Global + tenant; zmiana bez deployu; runbook < 1 h |
| 5 | Defined ops w UI (web + Flutter) | 5 operacji; teksty w `.arb` z opisami |
| 6 | Telemetria 7.1 | Zdarzenia bez PII; dashboard progów 8.3 |
| 7 | `guardrail-evals/` | ≥ 600 przykładów PL; CI gate 8.2 |
| 8 | Rejestr claimów v1 (+ sklepy) | Jeden dokument; właściciel; review w PR template |
| 9 | Notatnik roboczy: separacja i retencja | Osobna kolekcja/tabela; brak dostępu z funkcji superwizyjnych; test negatywny |
| 10 | Opinia doradcy regulacyjnego | Pytania z rozdz. 9 + 10.8; wynik jako załącznik do ADR |

*Dokument wewnętrzny. Nie stanowi opinii prawnej.*
