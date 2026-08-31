# Ontologie — seedy i konwencje

Źródłem prawdy **runtime** jest aktywna wersja w bazie (Ontology Studio).
Pliki `ontology/<modalność>/<semver>.yaml` są seedami do importu jako
draft i dokumentacją formatu; CI lintuje je poleceniem
`go run ./pkg/ontology/cmd/ontology-lint ontology/`.

## Wersjonowanie (semver)

- **MAJOR** — zmiana łamiąca strukturę raportu lub usunięcie konstruktu.
- **MINOR** — nowy konstrukt, nowa pozycja `values`, zmiana progów
  dowodowych, zmiana relacji (`is_not`, `requires`).
- **PATCH** — zmiany nienaruszające identyfikatorów ani reguł, m.in.
  treść `definition`, `examples`, `common_confusions` oraz
  **`value_glosses`** (glosa to objaśnienie, nie identyfikator — jej
  zmiana nie unieważnia porównywalności benchmarku po `values`).

## Glosy wartości (`value_glosses`)

Glosa odpowiada na pytanie „**która** to pozycja?", nie „co o niej
wiadomo" — pełna definicja kanoniczna mieszka w L1 (dok. 12). Limit 120
znaków, jedna linia, czysty tekst (reguła G3). Reguły G1–G6 opisane w
`pkg/ontology/glosses.go`; para wartości w relacji podłańcucha (np.
„pewność" / „pewność siebie") w konstrukcie używającym glos MUSI mieć
glosy obu stron (G6). Unikaj wewnętrznego „ — " w treści glosy —
koliduje z separatorem renderera promptu S2; doprecyzowanie dawaj w
nawiasie.

Glosy są treścią kliniczną: podlegają `approved_by` i przeglądowi w tym
samym PR co definicje. Zmiana definicji L1 konstruktu ⇒ obowiązkowy
przegląd glos tego konstruktu.
