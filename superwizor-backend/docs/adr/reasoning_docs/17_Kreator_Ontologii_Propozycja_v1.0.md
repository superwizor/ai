# 17. Kreator ontologii — propozycja

| | |
|---|---|
| Status | PROPOZYCJA do decyzji |
| Data | 2026-08-23 |
| Kontekst | Ontology Studio (plan 16, F4) ma dziś edytor tekstowy YAML z lintem serwerowym. Ekspert kliniczny nie jest programistą i nie powinien produkować błędów składniowych, żeby dowiedzieć się, że pomylił pole. |
| Zakres | Jak zbudować powierzchnię, w której ontologia zgodna z metaschematem powstaje z pracy merytorycznej, a nie mimo walki ze składnią. |

---

## 1. Teza

**Metaschemat ma 37 reguł. Formularz może uczynić 28 z nich NIEMOŻLIWYMI
DO ZŁAMANIA, a nie tylko wykrywalnymi.**

To jest ta sama zasada, na której stoi cały potok wnioskowania:
*egzekwowanie przez nieobecność*. Model nie może zwrócić kategorii spoza
taksonomii nie dlatego, że mu tego zabroniono w prompcie, tylko dlatego,
że `enum` w schemacie takiej odpowiedzi nie dopuszcza. Edytor ontologii
powinien działać tak samo: ekspert nie ma popełniać błędu i czytać o nim
w komunikacie — ma nie mieć jak go popełnić.

Lint zostaje, ale przestaje być pierwszą linią. Staje się tym, czym
powinien być: wyłapywaniem błędów **merytorycznych**, których żaden
formularz nie zapobiegnie.

---

## 2. Podział reguł — co formularz eliminuje, a co tylko zgłasza

### 2.1. Znikają całkowicie (formularz nie daje ich wyrazić)

| Reguła metaschematu | Jak znika |
|---|---|
| `modality` musi pasować do `[a-z][a-z0-9_]*` | Modalność WYBIERANA z listy istniejących, nigdy wpisywana |
| `version` musi być semverem | Numer nadaje system (`bumpPatch` już istnieje w `OntologyStudio.tsx`); ekspert wybiera „poprawka / rozszerzenie / zmiana łamiąca" |
| `constructs` nie może być puste | Zapis pierwszej wersji niemożliwy bez jednego konstruktu |
| identyfikator konstruktu `[a-z][a-z0-9_]*` | Generowany ze slugu nazwy polskiej, z podglądem i możliwością korekty w tym samym formacie |
| `label_pl` wymagane | Pole wymagane formularza |
| pusta definicja | j.w. |
| nieznany `epistemic_status` | Lista zamknięta z checkboxami |
| brak `insufficient_data` / `no_fit` | Renderowane jako **zaznaczone i niewyłączalne**, z wyjaśnieniem dlaczego |
| `etiology_policy` ≠ `strict` | Pole w ogóle nieedytowalne — jedna legalna wartość |
| `therapist_boundary` ≠ `strict` | j.w. |
| nieznany `relation_type` | Lista zamknięta |
| `is_not` wskazuje nieistniejący konstrukt | **Picker konstruktów, nigdy wolny tekst** |
| `requires` wskazuje nieistniejący konstrukt | j.w. |
| konstrukt wskazuje sam na siebie | Wykluczony z własnego pickera |
| `slots` przy `kind` innym niż `composite` | Sekcja slotów pojawia się WYŁĄCZNIE po wyborze „kompozyt" |
| `slot.type` w złym formacie | Wybór z czterech form + picker konstruktu dla `construct_ref`/`enum_ref` |
| slot wskazuje nieistniejący konstrukt | j.w. |
| `min_complete_slots` > liczby slotów | Suwak ograniczony liczbą zdefiniowanych slotów |
| pozostałe reguły formatu i referencji | Analogicznie |

**Dlaczego akurat `is_not` jest tu najważniejszy:** przy pisaniu szkicu
PPT do tego repozytorium wpisałem tam `need` i `resource` jako **tekst
opisowy**, przepisany wprost z dokumentu 11 §3.3. Metaschemat wymaga
identyfikatorów konstruktów. Złapał to lint — ale dopiero po zapisie, a
błąd wyglądał na literówkę, nie na nieporozumienie co do typu pola.
Jeżeli popełniłem go, mając metaschemat przed oczami, ekspert kliniczny
popełni go na pewno.

### 2.2. Zostają dla lintu (formularz ich nie zapobiegnie)

To są błędy **merytoryczne**, nie strukturalne:

- czy definicja konstruktu jest dobra;
- czy katalog `values` jest kanoniczny dla tej szkoły;
- czy `min_evidence` ma sensowny próg;
- czy `common_confusions` pokrywa realne pomyłki;
- czy `forced_status` jest właściwy.

Żadnej z nich formularz nie rozstrzygnie i nie powinien udawać, że
rozstrzyga. To jest praca ekspercka i o nią w F1 chodzi.

---

## 3. Kształt powierzchni

### 3.1. Dwa panele: formularz + podgląd YAML (tylko do odczytu)

YAML zostaje **widoczny**, ale nieedytowalny w trybie podstawowym.

Nie jest to ozdoba. Ekspert autoryzuje treść imiennie (`approved_by`), a
autoryzuje się to, co się widziało. Podgląd jest też jedynym miejscem, w
którym widać, że pole `is_not` to lista identyfikatorów, a nie zdanie —
czyli buduje model mentalny, którego sam formularz nie przekaże.

Furtka „tryb zaawansowany" (edycja YAML wprost) zostaje dla nas i dla
przypadków, których formularz nie obejmie. Przełączenie jest jawne, a
powrót do formularza wymaga przejścia lintu — inaczej formularz musiałby
umieć wczytać dowolny YAML, także taki, którego nie potrafi wyrazić.

### 3.2. Konstrukt powstaje z trzech pytań, nie z pól

Nowy konstrukt zaczyna się od pytań w języku dziedziny, nie schematu:

1. **„Czy to zjawisko ma zamkniętą listę możliwości?"**
   → tak: `values` (edytor listy); nie: `values: null`
2. **„Czy jednemu fragmentowi może przysługiwać kilka etykiet naraz?"**
   → tak: `multi_label: true`
3. **„Czy to jedno pojęcie, czy struktura złożona z części?"**
   → struktura: `kind: composite` + edytor slotów

Trzy odpowiedzi rozstrzygają cały kształt konstruktu. Ekspert nigdy nie
widzi słów `multi_label` ani `kind` — widzi pytanie o swoją dziedzinę.

### 3.3. Granice i pomyłki jako osobny, wyróżniony krok

`is_not` i `common_confusions` to pola, które **realnie widzi S2** i
które najmocniej wpływają na jakość mapowania. Są też najmniej oczywiste
dla eksperta, bo w podręczniku nie ma rozdziału „czym to nie jest".

Krok zadaje trzy pytania:

- *„Z czym to bywa mylone spośród pozostałych konstruktów?"* → picker → `is_not`
- *„Jaki termin ludzie wpisują błędnie i co powinno tam być zamiast?"* → dwa pola → `common_confusions`
- *„Podaj przykład, który się kwalifikuje, i taki, który nie"* → `examples` / `counter_examples`

Drugie pytanie zasługuje na osobną uwagę: rejestr pomyłek jest **żywy** —
ma rosnąć z feedbacku i z błędów benchmarku. Kreator powinien pozwalać
dopisać wpis w jednym kliknięciu z panelu Jakości, gdy odrzucenie
walidatora pokaże powtarzającą się pomyłkę. To zamyka pętlę F1↔F3.

### 3.4. Import szkicu z soczewki czatu

Soczewki PPT, CBT i Gestalt w Prompt Studio **już zawierają taksonomię**
— rozlaną w prozie, ale zawierają. Jednorazowa akcja „wyciągnij szkic z
soczewki" (wywołanie LLM z wymuszonym schematem, dokładnie jak S2)
wypełnia formularz kandydatami, które ekspert następnie poprawia.

Uczciwe ramy: wynik jest **szkicem do poprawienia**, nigdy propozycją do
zatwierdzenia. Ekran po imporcie pokazuje każdą pozycję jako
niepotwierdzoną, a zapis wymaga przejścia przez wszystkie konstrukty.
Inaczej import zamieni się w automatyczne generowanie ontologii — czyli
w dokładnie to, przed czym broni cała architektura.

### 3.5. Diff przy przeglądzie

Ścieżka `draft → ready_for_review → approved` wymaga, żeby **drugi
ekspert** (four-eyes) zobaczył, co się zmieniło. Dziś zobaczy dwa bloki
YAML. Powinien zobaczyć: *dodano kategorię X*, *usunięto Y*, *próg
podniesiono z 1 do 2 spanów*, *dopisano trzy pomyłki*.

Diff semantyczny, nie tekstowy — bo zmiana kolejności kluczy w YAML nie
jest zmianą ontologii, a przesunięcie progu jest.

---

## 4. Czego NIE budować

**Edytora grafowego.** Kuszące przy słowie „ontologia", ale ekspert
kliniczny nie myśli o swojej szkole jako o grafie węzłów i krawędzi.
Relacje w tym systemie i tak nie są częścią ontologii — powstają w S2b
między twierdzeniami, nie między konstruktami.

**Autouzupełniania w YAML.** Rozwiązuje najmniejszy z problemów
(literówki w nazwach pól), a zostawia wszystkie pozostałe: złą strukturę,
wiszące referencje, sloty w niewłaściwym miejscu. Podpowiadanie składni
komuś, kto nie powinien pisać składni, to leczenie objawu.

**Walidatora po stronie klienta.** Istnieje jedna implementacja
metaschematu (`pkg/ontology`) i tak ma zostać. Druga, w TypeScript,
rozjechałaby się przy pierwszej zmianie — a rozjazd oznaczałby, że
Studio przepuszcza treść, którą CI odrzuca, albo odwrotnie.

---

## 5. Kolejność wdrożenia

Etapy uszeregowane wg stosunku „usunięty ból / koszt":

| Etap | Zakres | Dlaczego tu |
|---|---|---|
| **K1** | Formularz nagłówka + lista konstruktów + formularz konstruktu prostego (`values`, `min_evidence`, `label_pl`, `definition`) | Pokrywa większość treści każdej z trzech istniejących ontologii |
| **K2** | Pickery dla `is_not` / `requires` + `common_confusions` | Największy zysk jakościowy per linia kodu — te pola widzi S2 |
| **K3** | Kompozyty i sloty | Rzadsze; PPT ma jeden, CBT jeden, Gestalt jeden |
| **K4** | Diff semantyczny przy przeglądzie | Odblokowuje sensowne four-eyes |
| **K5** | Import z soczewki | Największy zysk czasowy, ale wymaga K1–K3 jako celu importu |

K1+K2 to moim zdaniem próg użyteczności: poniżej niego ekspert nadal
potrzebuje nas przy każdym zapisie.

---

## 6. Czego ta propozycja nie rozstrzyga

- **Kto pisze definicje kanoniczne (L1).** Wszystkie trzy szkice mają
  dziś `PLACEHOLDER` i `source: {work_id: "", ...}`. Kreator ułatwi
  wpisanie, nie rozstrzygnie, skąd wziąć treść i kto odpowiada za
  zgodność z literaturą.
- **Czy `detectors` wchodzi do metaschematu.** Szkic Gestalt w dok. 15
  ich potrzebuje (markery leksykalne dla introjekcji, wzorzec `sequence`
  dla defleksji). Jeśli wejdą, kreator musi je objąć — a wcześniej trzeba
  rozstrzygnąć, czy marker deterministyczny *wspiera* wynik S2, czy go
  *zastępuje*.
- **Czy `values` powinny mieć własne opisy.** Dziś to gołe napisy. Opis
  per wartość byłby wartościowy dla S2, ale to zmiana metaschematu i
  wszystkich trzech ontologii.
