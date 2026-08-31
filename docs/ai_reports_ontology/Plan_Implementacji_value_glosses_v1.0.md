# Plan implementacji: rozszerzenie metaschematu `value_glosses`

| Pole | Wartość |
|---|---|
| Plik | `docs/plany/Plan_Implementacji_value_glosses.md` (numeracja `docs/` bez zmian — plan wykonawczy, nie dokument architektury) |
| Wersja | 1.0 |
| Data | 23 sierpnia 2026 r. |
| Status | G1–G3, G5 zrealizowane 2026-08-26 (gałąź `feat/value-glosses`); G4 w zakresie istniejącego UI (Studio) — picker A7 czeka na T11; ewaluacja §6.4 czeka na T9 |
| Kontekst | Porównanie ontologii PPT 0.1.0 ze zweryfikowanym promptem ujawniło glosy przy 4 pozycjach katalogu potencjalności podstawowych („wzorzec (uczenie się na modelu…)", „pewność (decyzyjność)" itd.). Metaschemat v1.4 nie ma pola na objaśnienie pojedynczej wartości enumu — tylko `definition` per konstrukt. Wpisanie glosy do wartości enumu psuje matching (schemat, walidator R1, telemetria, benchmark). |
| Decyzja | Opcja (b): nowe opcjonalne pole `value_glosses` per konstrukt — identyfikatory enumu pozostają gołe, glosy renderowane do promptu S2 i pickera A7 |
| Dokumenty powiązane | `11_Architektura_Wnioskowania_Ontologia.md` v1.4 (§3.2 metaschemat; T19); `13_Glebia_Wnioskowania.md` (bez zmian); ontologia `ppt/0.1.1` (pierwszy konsument); benchmark §8.2 dok. 11 (bramka przy zmianie promptu S2) |
| Zakres zmian | Metaschemat + walidacja CI · registry · renderer promptu S2 · picker A7 (web + Flutter) · wytyczne anotacji benchmarku · testy |
| Poza zakresem | Zmiany w S3/S4/S5, telemetrii, modelu danych claims; tłumaczenia glos (treść ontologii jest PL — i18n nie dotyczy); glosy w relacjach |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-23 | Pierwsza wersja. |
| 1.1 | 2026-08-26 | **Realizacja G1–G3, G5 + zapis odstępstw.** (a) G6 zaimplementowane jako ERROR dla konstruktu używającego glos i OSTRZEŻENIE dla konstruktu bez glos — §2.2 (bezwarunkowy ERROR) i §9 DoD („ppt/0.1.0 przechodzi bez zmian”) wzajemnie się wykluczały, bo 0.1.0 zawiera parę pewność/pewność siebie; linter drukuje ostrzeżenia bez failowania. (b) T19.G2 „registry”: osobny serwis registry nie istnieje — glosy płyną istniejącą ścieżką YAML→`pkg/ontology.Parse`→prompt S2 oraz do Studio; test kontraktowy 6.2 (schemat bajtowo identyczny) w CI. (c) T19.G4: **picker A7 nie istnieje** (T11 niezrealizowany) — dowiezione wsparcie w istniejącym UI: Ontology Studio (web) edytuje glosy (podpis pod wartością, limit 120 znaków, testy round-trip modelu), a osierocona glosa po edycji values celowo NIE jest czyszczona po cichu (wykrywa ją G1 z walidacji serwera). Picker terapeuty wraca razem z T11. Flutter: brak jakiegokolwiek UI ontologii — nic do zrobienia. (d) T19.G5: seed `ppt/0.1.1` (semver PATCH) z glosami 4 pozycji; wartość z planu „wzorzec” w rzeczywistym katalogu nazywa się „wzorzec/naśladowanie”; glosa „pewność” zapisana jako „decyzyjność (zdolność…)” — bez wewnętrznego „ — ”, żeby nie kolidować z separatorem renderera (§4.1 pokazywał to samo w formie wyrenderowanej). (e) Prompt S2 → s2/1.3.0; dok. 11 → v1.6; konwencja semver-patch w `ontology/README.md`. (f) Ewaluacja A/B (G6 planu, §6.4) odłożona do T9 zgodnie z planem. |

---

## 1. Cel i zasada

**Cel:** rozbroić dwuznaczności wewnątrz zamkniętych katalogów (wzorcowy przypadek: „pewność" ⊂ „pewność siebie" — dwie różne pozycje katalogu podstawowych PPT) **w momencie generacji**, zanim błąd zobaczy walidator — oraz dać terapeucie w pickerze A7 podpowiedź znaczenia kategorii.

**Zasada projektowa (niezmienna):** wartość enumu jest **identyfikatorem**, glosa jest **objaśnieniem**. Identyfikator przechodzi przez JSON Schema, R1, telemetrię, benchmark i UI — i nigdy nie zawiera treści objaśniającej. Podział ról po zmianie:

| Warstwa | Rola | Przykład dla „pewność" |
|---|---|---|
| `values` | Identyfikator kanoniczny | `"pewność"` |
| `value_glosses` | Objaśnienie 1-liniowe (prompt S2, picker A7) | `"decyzyjność — zdolność podejmowania decyzji"` |
| L1 (`knowledge/ppt/…`) | Pełna definicja kanoniczna z `source`, przykładami, kontrprzykładami | akapit + strony |
| `aliases` / `common_confusions` | Mapowanie nazw wariantowych i błędów | `"wzór" → "wzorzec"` |

Żadna warstwa nie dubluje żadnej; glosa NIE zastępuje L1 (jest skrótem nawigacyjnym, nie definicją).

---

## 2. Specyfikacja zmiany metaschematu

### 2.1. Diff `ontology/_meta/schema.yaml`

```yaml
constructs:
  <construct_id>:
    values: [string] | null
    value_glosses:              # NOWE (opcjonalne; tylko gdy values != null)
      <wartość-z-values>: string   # 1 linia, plain text, PL
    # Semantyka: objaśnienie pojedynczej pozycji katalogu. Renderowane do
    # promptu S2 (obok enumu) i pickera A7 (podpis pod kategorią).
    # NIE trafia do: JSON Schema wyjścia S2, walidatora R1, telemetrii,
    # wartości w claims, dopasowań benchmarku.
```

### 2.2. Reguły walidacji metaschematu (CI, walidator w Go — rozszerzenie istniejącego lintera z T1)

| # | Reguła | Klasa błędu |
|---|---|---|
| G1 | Każdy klucz `value_glosses` **musi** istnieć w `values` tego konstruktu (dokładne dopasowanie stringa) | ERROR — build fail |
| G2 | `value_glosses` przy `values: null` — niedozwolone | ERROR |
| G3 | Glosa: niepusta, ≤ 120 znaków, bez znaków nowej linii, bez markdown/formatowania | ERROR |
| G4 | Glosa nie może być identyczna z kluczem ani z inną wartością `values` (glosa ≠ identyfikator; glosa równa innej wartości enumu = źródło pomyłek) | ERROR |
| G5 | Klucz glosy nie może występować w `aliases` jako nazwa wariantowa innego konstruktu (spójność krzyżowa — glosujemy kanon, nie warianty) | WARNING |
| G6 | Pokrycie: jeżeli w `values` istnieją dwie pozycje, z których jedna jest podłańcuchem drugiej (np. „pewność" / „pewność siebie"), **obie muszą mieć glosy** | ERROR — to jest reguła wymuszająca dokładnie ten przypadek, dla którego pole powstało |

Implementacja: pakiet `ontlint` (istniejący z T1), nowy plik `glosses.go`, ~80–120 linii + testy tabelaryczne. Reguła G6 wymaga prostego porównania par wartości (`strings.Contains` po normalizacji lower-case).

### 2.3. Zmiany w dokumencie 11 (do naniesienia przy najbliższym podbiciu — v1.5, wpis changelog)

Proponowany wpis: *„v1.5: pole `value_glosses` w metaschemacie (objaśnienia 1-liniowe per wartość enumu; renderowane do promptu S2 i pickera A7; identyfikatory enumu bez zmian); reguły lintera G1–G6, w tym wymuszenie glos dla par wartości w relacji podłańcucha; rozszerzenie T19."* Diff §3.2 jak w 2.1. Żadnych zmian w potoku S1–S5 poza rendererem promptu S2 (sekcja 4).

---

## 3. Registry (`ontology-registry` / moduł w `guardrail-svc`, T3)

- Odpowiedź endpointu enums rozszerzona o glosy:

```json
{
  "construct_id": "actual_capacity_primary",
  "values": ["miłość", "wzorzec", "...", "pewność siebie", "pewność", "jedność"],
  "value_glosses": {
    "wzorzec": "uczenie się na modelu i bycie modelem",
    "pewność siebie": "ufność we własne siły",
    "pewność": "decyzyjność — zdolność podejmowania decyzji",
    "jedność": "integrowanie"
  }
}
```

- Pole zawsze obecne (pusty obiekt, gdy brak glos) — klienci bez logiki warunkowej.
- **Generator JSON Schema wyjścia S2 NIE czyta `value_glosses`** — test kontraktowy w 6.2 pilnuje, że schemat przed/po dodaniu glos jest bajtowo identyczny.
- Cache i endpoint wersji: bez zmian (glosy są częścią wersji ontologii; zmiana glosy = nowa wersja ontologii semver **patch**, bo nie zmienia identyfikatorów ani reguł — zapisać w konwencji wersjonowania w repo `ontology/README`).

---

## 4. Renderer promptu S2 (`llm-worker`)

### 4.1. Format renderowania enumu z glosami

Dotychczas (schematycznie):

```
Dozwolone kategorie (wybierz dokładnie jedną wartość z listy, verbatim):
- miłość
- wzorzec
- pewność siebie
- pewność
```

Po zmianie:

```
Dozwolone kategorie (w polu `category` zwróć DOKŁADNIE wartość sprzed myślnika,
bez objaśnienia w nawiasie ani po myślniku):
- miłość
- wzorzec — uczenie się na modelu i bycie modelem
- pewność siebie — ufność we własne siły
- pewność — decyzyjność (zdolność podejmowania decyzji); NIE mylić z "pewność siebie"
- jedność — integrowanie
```

Zasady renderera:
- Separator „ — " (spacja-myślnik-spacja); wartości bez glosy renderowane samą nazwą.
- Instrukcja nagłówkowa („zwróć DOKŁADNIE wartość sprzed myślnika") dodawana **tylko**, gdy konstrukt ma ≥ 1 glosę — nie zaśmiecamy promptów konstruktów bez glos.
- Dopisek „NIE mylić z …" generowany automatycznie dla par podłańcuchowych z reguły G6 (renderer ma tę samą detekcję par co linter — wydzielić do wspólnej funkcji w module ontologii).
- Zmiana renderera = **nowa wersja promptu S2** → zgodnie z §8.2 dok. 11 release wymaga przejścia benchmarku. Sekwencja wdrożeniowa w sekcji 7 uwzględnia, że benchmark PPT (T9) może jeszcze nie istnieć.

### 4.2. Budżet kontekstu

Glosa ≤ 120 znaków × realistycznie 10–20 glos na konstrukt = ≤ ~600 tokenów dodatkowych w najgorszym przypadku na wywołanie S2 per konstrukt. Mieści się w budżecie L1 ≤ 15 tys. tokenów (dok. 12 §4) bez korekt; odnotować w FinOps przy szacunku kosztów F2 (pomijalne).

---

## 5. Picker A7 (web + Flutter)

- Kategoria w pickerze: nazwa kanoniczna jako etykieta główna, glosa jako podpis (subtitle/tooltip) — wzorzec identyczny na obu platformach.
- Wyszukiwarka pickera przeszukuje **nazwę + aliasy + glosę** (glosa zawiera słowa, którymi terapeuta myśli — „decyzyjność" znajdzie „pewność").
- Treść glos przychodzi z registry (treść ontologii, PL) — **nie przez `.arb`**; `.arb` pozostaje dla tekstów UI (etykiety kontrolek), zgodnie z dotychczasowym podziałem.
- Dostępność: glosa w `semanticsLabel`/aria-description kategorii (czytniki ekranu czytają nazwę + glosę).
- Stan pusty: brak glosy = brak podpisu (żadnych placeholderów „(brak opisu)").

---

## 6. Testy

### 6.1. Linter (Go, tabelaryczne)

- G1: klucz spoza `values` → ERROR; literówka w kluczu (diakrytyk) → ERROR (dopasowanie dokładne, bez normalizacji — glosujemy kanon).
- G2–G4: przypadki brzegowe (values: null, glosa 121 znaków, glosa z `\n`, glosa == inna wartość enumu).
- G6: para „pewność"/„pewność siebie" bez glos → ERROR; z glosami → PASS; para bez relacji podłańcucha bez glos → PASS.

### 6.2. Kontrakt schematu (krytyczny)

Test porównujący **bajtowo** JSON Schema wyjścia S2 wygenerowany z ontologii bez glos i z glosami (te same `values`) — musi być identyczny. To jest strażnik zasady „identyfikator ≠ objaśnienie"; jego złamanie w przyszłym refaktorze ma wywrócić build.

### 6.3. Snapshot promptu S2

- Golden-file test renderera: konstrukt z glosami / bez glos / z parą podłańcuchową (dopisek „NIE mylić z"); zmiana snapshotu wymaga świadomego zatwierdzenia w PR (konwencja jak dla wersjonowanych promptów).

### 6.4. Ewaluacja skuteczności (po powstaniu benchmarku T9)

- A/B na zestawie testowym S2: prompt bez glos vs z glosami; oczekiwanie: wzrost trafności kategorii dla konstruktów z parami dwuznacznymi, brak regresji gdzie indziej; wynik dołączony do PR wersji promptu.
- Do zestawu testowego dodać przypadki celowane w pary: wypowiedzi klienta o *decyzyjności* (oczekiwane „pewność") i o *ufności we własne siły* (oczekiwane „pewność siebie").

### 6.5. E2E / UI

- Registry zwraca glosy → picker renderuje podpis → wyszukiwarka znajduje po glosie (web: test komponentu; Flutter: widget test).
- Raport wygenerowany po zmianie: wartości `category` w claims **bez** glos (asercja na próbce e2e).

---

## 7. Sekwencja wdrożenia

Rozszerzenie wchodzi jako podzadania istniejącego **T19** (zmiany metaschematu), oznaczone T19.G:

| # | Podzadanie | Zależy od | Definition of Done |
|---|---|---|---|
| T19.G1 | Metaschemat: pole `value_glosses` + reguły G1–G6 w `ontlint` | T1 (linter istnieje) | Diff schematu; testy 6.1 zielone; ontologia bez glos przechodzi bez zmian (addytywność potwierdzona testem regresji na `ppt/0.1.0`) |
| T19.G2 | Registry: glosy w odpowiedzi enums; konwencja semver-patch dla zmian glos | T3, T19.G1 | Kontrakt JSON jak w §3; test 6.2 (schemat bajtowo identyczny); wpis w `ontology/README` |
| T19.G3 | Renderer promptu S2: format „ — ", instrukcja warunkowa, auto-dopisek dla par G6; wspólna funkcja detekcji par z linterem | T19.G2 | Snapshoty 6.3; wersja promptu podbita; wpis w rejestrze wersji promptów |
| T19.G4 | Picker A7 web + Flutter: podpis, wyszukiwanie po glosie, dostępność | T19.G2 | Testy 6.5; przegląd UX na przypadku „pewność"/„pewność siebie" |
| T19.G5 | Ontologia `ppt/0.1.1`: glosy dla 4 pozycji z promptu (+ ewentualne dla `capacity_state`, jeśli sesja autoryzacyjna doda) | T19.G1 | Lint zielony (w tym G6 dla pary pewność/pewność siebie); pozycja w agendzie sesji autoryzacyjnej: zatwierdzenie treści glos przez ekspertów (glosy są treścią kliniczną — podlegają `approved_by` jak reszta ontologii) |
| T19.G6 | Ewaluacja A/B (6.4) + aktualizacja wytycznych anotacji: anotatorzy widzą glosy w instrukcji (ten sam kontekst co model — inaczej porównujemy nierówne warunki) | T9 (benchmark) | Raport A/B w PR; wytyczne anotacji zaktualizowane |

Ścieżka krytyczna: G1 → G2 → G3 (silnik) równolegle z G4 (UI); G5 po autoryzacji treści; G6 dopiero z benchmarkiem — **wdrożenie G1–G5 nie czeka na T9** (przed istnieniem benchmarku bramka §8.2 formalnie nie działa; po jego powstaniu pierwsza pełna ewaluacja obejmie prompt z glosami jako baseline).

Szacunek łączny: G1 ~0,5 dnia; G2 ~0,5; G3 ~1 (ze snapshotami); G4 ~1–1,5 (dwie platformy); G5 — treść ekspercka w ramach sesji autoryzacyjnej (bez dodatkowego spotkania); G6 ~0,5 po T9. **Razem ~3,5–4 dni inżynierskie**, zero migracji.

---

## 8. Ryzyka i mitygacje

| Ryzyko | Mitygacja |
|---|---|
| Dryf glosy względem L1 (glosa mówi co innego niż definicja kanoniczna) | Glosy podlegają `approved_by` i przeglądowi w tym samym PR co L1; reguła procesowa: zmiana definicji L1 → obowiązkowy przegląd glosy tego konstruktu (checklist w szablonie PR ontologii) |
| Model przepisuje glosę do `category` mimo instrukcji | Trójwarstwowo: instrukcja nagłówkowa (4.1) → walidacja JSON Schema odrzuca (enum bez glos) → metryka odrzuceń R1 per konstrukt w telemetrii; jeśli po wdrożeniu R1-reject rośnie dla konstruktów z glosami — przegląd formatu separatora |
| Glosy puchną w encyklopedię (obchodzenie L1) | Twardy limit G3 (120 znaków) + zasada w README ontologii: glosa odpowiada na „która to pozycja?", nie „co o niej wiadomo" |
| Anotatorzy benchmarku bez glos ≠ model z glosami (nierówne warunki pomiaru) | T19.G6: glosy w wytycznych anotacji — jawnie, z datą zmiany protokołu |
| Przyszły refaktor generatora schematu wciągnie glosy do enumu | Test kontraktowy 6.2 jako strażnik w CI (fail = build down) |

---

## 9. Definition of Done całości

- [ ] `ontlint` egzekwuje G1–G6; `ppt/0.1.0` (bez glos) przechodzi bez zmian.
- [ ] JSON Schema wyjścia S2 bajtowo niezmienny przy dodaniu glos (test 6.2 w CI).
- [ ] Prompt S2 renderuje glosy wg 4.1; snapshoty zatwierdzone; wersja promptu podbita.
- [ ] Picker A7 (web + Flutter) pokazuje i przeszukuje glosy; dostępność sprawdzona.
- [ ] `ppt/0.1.1` z glosami przechodzi lint (w tym G6); treść glos w agendzie sesji autoryzacyjnej.
- [ ] Dokument 11 podbity (wpis changelog + diff §3.2 wg 2.3).
- [ ] Po T9: raport A/B i zaktualizowane wytyczne anotacji.

---

*Dokument wewnętrzny. Treść glos jest treścią kliniczną — placeholdery do autoryzacji eksperckiej.*
