# 12. Zarządzanie wiedzą domenową — biblioteka źródeł, wiedza kanoniczna, indeksy

| Pole | Wartość |
|---|---|
| Plik | `docs/12_Zarzadzanie_Wiedza_Domenowa.md` |
| Wersja | 1.0 |
| Data | 21 sierpnia 2026 r. |
| Status | Projekt — do zatwierdzenia decyzji D1–D3 (sekcja 11) |
| Dokumenty powiązane | `11_Architektura_Wnioskowania_Ontologia.md` v1.1 (potok S1–S5, metaschemat ontologii); ADR-0YY *Ontologia modalności*; ADR-0XX *AI Chat z klasyfikatorem*; *Analiza wymagań regulacyjnych* rozdz. 7 (dyscyplina claimów), 10 |
| Zakres | Sposób pozyskiwania, przechowywania, kuratorowania i udostępniania wiedzy domenowej (literatura psychologiczna/psychoterapeutyczna) dla wszystkich modalności; pilot: PPT |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-21 | Pierwsza wersja: warstwy L0–L3, manifest korpusu, pipeline ingestu, retrieval dla A4_EDU, benchmark retrievalu, proces i RACI. |

---

## 1. Streszczenie decyzyjne

Generyczny LLM przechowuje wiedzę **parametrycznie**: jako stratną kompresję statystycznych regularności korpusu treningowego, bez granic między źródłami i bez gwarancji wierności taksonomii (pełny wywód: dokument 11 v1.1, sekcja 2a). Dla teorii niszowych (PPT — literatura źródłowa w znacznej części niemieckojęzyczna, śladowy korpus polski) wiedza parametryczna jest szczątkowa i zanieczyszczona parafrazami z prac wtórnych. Wniosek: **model nie jest źródłem prawdy o teorii i nigdy nim nie będzie** — wiedzę domenową dostarczamy systemowo.

Kluczowe rozdzielenie, które w potocznym „wgrajmy książki do RAG" się zlewa:

1. **L0 Biblioteka źródeł** — surowe dzieła (książki, artykuły) z jawnym statusem licencyjnym.
2. **L1 Wyciągi kanoniczne** — autoryzowane przez ekspertów definicje i rozstrzygnięcia terminologiczne; źródło prawdy dla maszyn.
3. **L2 Ontologia** — struktura teorii (enumy, relacje, minima dowodowe) — zdefiniowana w dokumencie 11.
4. **L3 Indeksy pochodne** — chunki i embeddingi; **cache w pełni odtwarzalny z L0/L1, nigdy źródło prawdy**.

Zasada podziału pracy (motto wspólne z dokumentem 11): **LLM proponuje, struktura rozporządza.** Konsekwencja routingu: **S2 (mapowanie na konstrukty) nigdy nie konsumuje wyników RAG** — dostaje L1+L2 w całości w kontekście. RAG (L3) obsługuje wyłącznie warstwę edukacyjną `A4_EDU` i warsztat pracy ekspertów. To zamyka drogę powrotną do błędu zdiagnozowanego przez recenzenta: „RAG daje informacje, ale nie gwarantuje zachowania ontologii".

Rekomendowany model treści produktowych (D1): treści widoczne dla użytkownika w `A4_EDU` to **materiały własne pisane przez ekspertów** (IP przeniesione na spółkę), z odesłaniami bibliograficznymi do literatury i co najwyżej krótkimi cytatami; pełne teksty źródłowe żyją wyłącznie w warstwie roboczej ekspertów. Usuwa to ryzyko licencyjne z produktu, daje treści po polsku spójne terminologicznie z L1 i lepszą jakość retrievalu niż OCR z wydań obcojęzycznych.

---

## 2. Warstwy wiedzy: definicje, konsumenci, źródła prawdy

| Warstwa | Zawartość | Format i miejsce | Konsument | Źródło prawdy? |
|---|---|---|---|---|
| **L0 Biblioteka źródeł** | Pełne teksty dzieł: książki, artykuły, materiały szkoleniowe; konkretne wydania | PDF/EPUB w GCS (europe-central2, CMEK — Żelazna Lokalizacja) + `corpus/<modality>/manifest.yaml` w repo | Eksperci (warsztat pracy), pipeline ingestu | **Tak — dla ludzi** |
| **L1 Wyciągi kanoniczne** | Autoryzowane definicje per konstrukt (po kilkaset tokenów), rozstrzygnięcia terminologii PL, przykłady/kontrprzykłady, `source: {work_id, pages}` per definicja | Markdown/YAML w repo obok ontologii; PR + approvers (CODEOWNERS) | **S2** (pełny kontekst mapowania), autorzy ontologii, generator treści A4 | **Tak — dla maszyn** |
| **L2 Ontologia** | Enumy, `is_not`, `requires`, `min_evidence`, `aliases` | `ontology/<modality>/<semver>.yaml` (dokument 11) | S2/S3, walidator, picker A7 | **Tak — dla struktury** |
| **L3 Indeksy pochodne** | Chunki + embeddingi + metadane | pgvector (Cloud SQL PostgreSQL 16 — istniejący stack) | `A4_EDU` (RAG), wyszukiwarka ekspercka | **Nie — cache odtwarzalny** |

Reguły twarde:

- R-W1: Żadna ścieżka danych nie prowadzi z L3 do L1/L2 (indeks nie zasila źródeł prawdy).
- R-W2: S2 nie ma dostępu do L3 (wymuszone architektonicznie — brak zależności serwisowej, nie konwencja).
- R-W3: Każdy chunk L3 nosi `{work_id, pages}`; chunk bez proweniencji nie wchodzi do indeksu.
- R-W4: Zmiana L0/L1 → deterministyczna przebudowa L3 w CI; indeksy są wersjonowane wersją korpusu.

---

## 3. Manifest korpusu — governance przed technologią

`corpus/<modality>/manifest.yaml`, symetryczny do rejestru ontologii, walidowany metaschematem w CI:

```yaml
# corpus/_meta/schema.yaml — walidacja w CI (analogicznie do ontology/_meta)
modality: string
version: semver
approved_by: [string]          # puste = blokada użycia produkcyjnego (CI)
works:
  - id: string                 # np. peseschkian_1987_pppt
    title: string
    authors: [string]
    edition: string            # KONKRETNE wydanie — parametry stron w proweniencji!
    year: int
    language: de|en|pl|...
    license:
      status: owned_copy | licensed | public_domain | pending
      scope_allowed:           # co wolno z dziełem robić (podzbiór):
        - expert_workbench     # warsztat ekspertów (zawsze dozwolone przy owned_copy)
        - rag_internal         # indeksowanie do L3 na użytek wewnętrzny
        - product_quotes       # krótkie cytaty widoczne w produkcie
      notes: string            # podstawa prawna / nr umowy licencyjnej
    ingest: full | excerpts | metadata_only
    translation:
      pl_terms_source: L1      # terminologia PL rozstrzygana w wyciągach, nie per chunk
    approved_by: [string]      # ekspert potwierdzający kanoniczność dzieła dla modalności
```

Zasady:

- **`license.scope_allowed` jest polem decyzyjnym, nie opisowym**: pipeline ingestu odmawia indeksowania dzieła bez `rag_internal`; renderer A4 odmawia cytowania dzieła bez `product_quotes`. Status `pending` = `metadata_only` (dzieło widoczne w bibliografii, treść nieindeksowana).
- Dzieła chronione prawem autorskim (praktycznie cała literatura PPT) wymagają decyzji licencyjnej **przed** ingestem — pozycja w checkliście prawnej obok umów z ekspertami (milestone M1 Macieja: umowy z przeniesieniem praw do materiałów własnych).
- Manifest jest jedynym rejestrem korpusu: dzieło nieobecne w manifeście nie istnieje dla pipeline'u (blokada antywzorca „wrzućmy, co się da").

---

## 4. Wyciągi kanoniczne (L1) — specyfikacja

Format: `knowledge/<modality>/<construct_id>.md` z nagłówkiem YAML:

```yaml
construct_id: positum
ontology_version_min: 0.1.0
source: {work_id: peseschkian_1987_pppt, pages: "..." }   # audytowalność do literatury
approved_by: [Ewa, <recenzent>]
language: pl
---
# Positum — definicja kanoniczna (PL)
[definicja robocza 150–400 tokenów, rozstrzygnięcia terminologiczne,
 czym NIE jest (spójnie z is_not w ontologii), 2–3 przykłady, 1–2 kontrprzykłady]
```

Zasady:

- Jedno miejsce prawdy dla terminologii polskiej (D3): warianty tłumaczeń („potencjalności/zdolności aktualne", kalki z *Aktualfähigkeiten*) rozstrzygane tutaj i lustrzanie wpisywane do `aliases` w ontologii — S2 i UI mówią jednym językiem.
- Budżet objętości: suma L1 dla modalności ≤ ~15 tys. tokenów, tak by S2 zawsze dostawał **całość** L1+L2 w kontekście (bez retrievalu, bez selekcji — selekcja to wektor błędu).
- CI sprawdza spójność krzyżową: każdy konstrukt ontologii ma wyciąg L1 i odwrotnie; `is_not` w ontologii ⊆ sekcja „czym nie jest" w L1.

---

## 5. Pipeline ingestu (L0 → L3)

```
[Pozyskanie]  zakup egzemplarzy/licencji → wpis do manifestu → decyzja scope_allowed
      │
      ▼
[Ekstrakcja]  Document AI / OCR dla skanów; ZACHOWANIE numeracji stron oryginału
      │        (bez stron proweniencja "dzieło+strona" umiera); language detection
      ▼
[Normalizacja]  czyszczenie artefaktów OCR, struktura nagłówków, spis treści → mapa sekcji
      │
      ▼
[Chunking strukturalny]  granice po sekcjach/podrozdziałach (NIE naiwnie co N tokenów);
      │   definicje konstruktów jako chunki atomowe;
      │   metadane: {work_id, chapter, pages, language, construct_ids[]}
      │   — otagowanie chunków identyfikatorami konstruktów z ontologii (tanie,
      │   wysoki zysk precyzji retrievalu; tagowanie: LLM z weryfikacją ekspercką
      │   dla chunków definicyjnych)
      ▼
[Embeddingi]  model wielojęzyczny (Vertex AI, aktualny model text-embedding multilingual);
      │   korpus de/en/pl, zapytania pl → embedding cross-lingual jest WARUNKIEM,
      │   nie optymalizacją
      ▼
[Zapis L3]  pgvector; wersja korpusu w metadanych; przebudowa deterministyczna w CI
```

Schemat tabel (Cloud SQL, sqlc):

```sql
-- corpus_works: lustro manifestu (read-only w runtime, ładowane przy release)
-- corpus_chunks:
--   id, work_id FK, chapter, pages, language,
--   construct_ids text[], content text, embedding vector(768),
--   corpus_version, tsv tsvector  -- BM25/FTS dla wyszukiwania hybrydowego
-- indeksy: HNSW na embedding; GIN na tsv i construct_ids
```

---

## 6. Retrieval dla `A4_EDU`

1. Wejście przechodzi klasyfikator czatu (ADR-0XX): `A4_EDU` tylko przy `has_client_reference=false`; kontekst kliniczny nie jest ładowany.
2. Wyszukiwanie **hybrydowe**: BM25 (tsv) + wektorowe (HNSW), filtr `modality`, boost dla chunków z pasującym `construct_ids`, reranking top-k.
3. **Próg pewności retrievalu**: poniżej progu podobieństwa odpowiedź brzmi „nie znajduję tego w autoryzowanym korpusie [modalności]" — bez dryfu do wiedzy parametrycznej. To edukacyjny odpowiednik `insufficient_data` (spójność z dokumentem 11).
4. Kompozycja odpowiedzi zależnie od D1: wariant rekomendowany — treść z materiałów własnych ekspertów (dzieła z `product_quotes` mogą być cytowane krótko), **zawsze** z odesłaniem `{work, edition, pages}`.
5. Weryfikator wyjścia czatu (istniejący) + reguła: każda teza teoretyczna w A4 ma odesłanie bibliograficzne albo jest oznaczona jako parafraza materiału własnego.

---

## 7. Benchmark retrievalu

Symetrycznie do benchmarku wnioskowania (dokument 11, sekcja 8):

- Złoty zestaw ≥ 100 pytań edukacyjnych per modalność (PL), z oczekiwanymi źródłami `{work_id, pages}` i oczekiwaną odpowiedzią wzorcową; w tym pytania-pułapki: (a) spoza korpusu (oczekiwane: „nie znajduję w autoryzowanym korpusie"), (b) z terminologią wariantową (test `aliases`), (c) cross-lingual (pytanie PL → źródło DE).
- Metryki i progi startowe (bramka CI dla release korpusu): recall@5 źródła ≥ 0,90; trafność odesłań (praca+strony) ≥ 0,95; odsetek poprawnych odmów na pytaniach spoza korpusu ≥ 0,95; halucynacja bibliograficzna (odesłanie do nieistniejącego miejsca) = **0** (twarde).
- Telemetria produkcyjna (bez PII): `edu_query {construct_ids, hit, refused}`, `edu_source_clicked` (czy użytkownicy weryfikują źródła), `edu_refused_rate` per modalność — wysoki wskaźnik odmów = luka korpusu, sygnał do rozszerzenia manifestu.

---

## 8. Proces i RACI

Cykl życia dzieła: ekspert zgłasza → decyzja licencyjna → ingest → ekspert kuratoruje wyciągi L1 z dzieła → PR z approvals → release wersji korpusu → przebudowa L3 w CI → benchmark retrievalu → produkcja.

| Aktywność | R (wykonuje) | A (odpowiada) | C (konsultuje) | I (informowany) |
|---|---|---|---|---|
| Wybór dzieł kanonicznych per modalność | Ekspert modalności | Maciej (SME/produkt) | Recenzent | Darek |
| Decyzja licencyjna, umowy | Darek | Darek | Prawnik | Maciej |
| Ingest i jakość ekstrakcji | Darek (pipeline) | Darek | Ekspert (spot-check) | — |
| Wyciągi L1 + terminologia PL | Ekspert | Maciej | Recenzent | Darek |
| Ontologia L2 | Ekspert | Maciej | Recenzent | Darek |
| Release korpusu (wersja, benchmark) | Darek | Darek | Ekspert | Founderzy |
| Materiały własne A4 (D1) | Ekspert | Maciej | — | Darek |

Antywzorce jawnie blokowane procesem: streszczenia z internetu w korpusie (nieautoryzowana jakość — dokładnie to zanieczyściło wiedzę parametryczną modeli); ingest bez statusu licencyjnego; chunki bez stron; L3 jako źródło dla L1; selekcja fragmentów L1 do kontekstu S2 (S2 dostaje całość albo nic).

---

## 9. Bezpieczeństwo i zgodność

- L0/L3 nie zawierają danych klientów — wyłącznie literatura; separacja od danych art. 9 pełna (osobne zasoby, osobny dostęp).
- Rezydencja: GCS + Cloud SQL w europe-central2, CMEK (spójnie z Żelazną Lokalizacją).
- Dostęp do L0: eksperci przez podpisane URL-e/warsztat, nie publiczny bucket; log dostępu.
- Claimy produktowe o „oparciu na literaturze" muszą być spójne z manifestem (rejestr claimów, analiza regulacyjna rozdz. 7): twierdzimy tylko to, co korpus i L1 faktycznie pokrywają.

---

## 10. Plan wdrożenia — tickety

| # | Ticket | Definition of Done |
|---|---|---|
| K1 | Metaschemat manifestu + walidacja CI | `corpus/_meta/schema.yaml`; blokada pustego `approved_by` i ingestu bez `rag_internal`; testy negatywne |
| K2 | Manifest PPT 0.1.0 + decyzje licencyjne | Lista dzieł kanonicznych od eksperta; status licencyjny każdego; dzieła `pending` jako `metadata_only` |
| K3 | Format L1 + CI spójności z ontologią | Szablon wyciągu; sprawdzenie krzyżowe konstrukt↔wyciąg i `is_not`↔„czym nie jest"; budżet tokenów egzekwowany |
| K4 | Pipeline ingestu | Ekstrakcja z zachowaniem stron; chunking strukturalny; tagowanie `construct_ids` z weryfikacją ekspercką chunków definicyjnych; przebudowa deterministyczna |
| K5 | Schemat L3 w Cloud SQL + wyszukiwanie hybrydowe | Tabele + indeksy (HNSW, GIN); BM25+wektor+rerank; filtr modalności; testy |
| K6 | Integracja A4_EDU | Próg odmowy; kompozycja z odesłaniami; reguła weryfikatora (teza→odesłanie); telemetria |
| K7 | Benchmark retrievalu + bramka CI | Złoty zestaw ≥ 100 pytań PL z pułapkami; progi sekcji 7; raport w PR |
| K8 | Materiały własne A4 dla PPT (po D1) | Pokrycie konstruktów strefy edukacyjnej; autoryzacja ekspercka; IP na spółkę |

Kolejność: K1–K3 równolegle z pracą ekspercką nad ontologią (T2 z dokumentu 11 — te same osoby, ta sama sesja robocza); K4–K7 po zatwierdzeniu manifestu; K8 po D1.

---

## 11. Decyzje blokujące

| # | Decyzja | Opcje | Rekomendacja | Status |
|---|---|---|---|---|
| D1 | Model treści produktowych A4_EDU | A: materiały własne ekspertów z odesłaniami do literatury · B: licencjonowane cytowanie literatury w produkcie · C: hybryda (własne + krótkie cytaty z dzieł `product_quotes`) | **A**, docelowo C dla dzieł z uzyskaną licencją | ☐ otwarta |
| D2 | Zakres i budżet licencji dla PPT | Lista dzieł Peseschkiana + wydania (determinują parametry stron w proweniencji) | Zebrać listę od eksperta w ramach K2; decyzja budżetowa po wycenie | ☐ otwarta |
| D3 | Rozstrzyganie terminologii PL | A: wyłącznie w L1 (jedno miejsce prawdy, lustrzane `aliases` w L2) · B: warianty per źródło | **A** | ☐ otwarta |

---

*Dokument wewnętrzny. Nie stanowi opinii prawnej; kwestie licencyjne (sekcja 3) wymagają potwierdzenia przez prawnika przed ingestem dzieł chronionych.*
