# Analiza wymagań regulacyjnych — Rozdział 10

## Ryzyko egzekucyjne, terminy i praktyki rynkowe aplikacji na granicy MDR

| Pole | Wartość |
|---|---|
| Dokument nadrzędny | *Analiza wymagań regulacyjnych dla platformy* (1 sierpnia 2026 r.), rozdz. 1–9 |
| Wersja | 1.0 |
| Data | 18 sierpnia 2026 r. |
| Status | Analiza wewnętrzna — nie stanowi opinii prawnej |
| Zależności | ADR *AI Chat z klasyfikatorem (web + mobile)* — decyzja o architekturze i akceptacji ryzyka |
| Zmiana kontekstu | Podjęto decyzję: interfejs konwersacyjny z klasyfikatorem, dostępny w wersji web **i** mobile. Rozdział opisuje konsekwencje egzekucyjne tej decyzji. |

### Changelog

| Wersja | Data | Zmiana |
|---|---|---|
| 1.0 | 2026-08-18 | Pierwsza wersja. Uzupełnia rozdz. 4.2 (format interfejsu jako czynnik kwalifikujący) o mechanikę egzekucji i praktyki rynkowe. |

---

## 10.1. Konkluzje

- Wariant „nakaz wstrzymania aplikacji z dnia na dzień" jest zarezerwowany dla trybu **nieakceptowalnego ryzyka** (art. 95 MDR). Dla narzędzia B2B z klinicystą w pętli i bez zgłoszonego incydentu tryb ten jest mało prawdopodobny. **Incydent zmienia to natychmiast.**
- Wariant typowy to sekwencja: pismo organu → wyjaśnienia producenta → żądanie usunięcia niezgodności w określonym terminie (art. 97 MDR) → dopiero przy braku reakcji ograniczenie lub wycofanie → ewentualnie odrębne postępowanie o karę pieniężną. Horyzont od pierwszego pisma do prawomocnej kary: realistycznie 12–24 miesiące.
- Formalnego etapu „ostrzeżenia" nie ma, ale procedura MDR i KPA mają wbudowaną gradację, która działa jak ostrzeżenie. Dla oprogramowania usunięcie niezgodności może oznaczać wyłączenie funkcji lub zmianę claimów w ciągu dni — to główna karta przetargowa producenta.
- Ryzykiem egzystencjalnym nie jest URPL sam w sobie, lecz trzy inne kanały: (a) incydent + roszczenie cywilne, (b) konkurent, który poniósł koszt certyfikacji i ma interes w usunięciu produktu niecertyfikowanego, (c) publiczny spór o kwalifikację na rynku profesjonalnym.
- **Decyzja o czacie z klasyfikatorem obniża prawdopodobieństwo trafienia na radar organu, ale nie zmienia kwalifikacji MDR** (rozdz. 4.2 dokumentu nadrzędnego). Jest to świadoma akceptacja ryzyka i musi być tak udokumentowana (ADR).
- Wersja mobile dodaje czwarty kanał: **przegląd sklepowy** (Apple/Google) na podstawie MDCG 2025-4 i polityk sklepów. Nie zmienia kwalifikacji, ale zwiększa liczbę podmiotów, które mogą zakwestionować status produktu.

---

## 10.2. Kanały egzekucji — mapa

| Kanał | Podmiot | Podstawa | Szybkość | Motywacja | Skutek |
|---|---|---|---|---|---|
| **Administracyjny** | Prezes URPL | MDR art. 93–98; ustawa z 7.04.2022 r. o wyrobach medycznych (Dz.U. 2022 poz. 974) — kontrola, decyzje, kary pieniężne | Wolny (miesiące–lata) | Reaktywna: skarga, incydent, zgłoszenie, kontrola tematyczna | Żądanie działań korygujących → ograniczenie/wycofanie → kara pieniężna |
| **Konkurencyjny** | Konkurent, stowarzyszenie branżowe | Ustawa o zwalczaniu nieuczciwej konkurencji (art. 3, art. 18) — wprowadzenie do obrotu wyrobu bez wymaganej oceny zgodności jako czyn nieuczciwej konkurencji | Szybki (wezwanie → zabezpieczenie w tygodniach) | Biznesowa | Zaniechanie, usunięcie skutków, odszkodowanie; koszty procesu |
| **Platformowy** | Apple, Google | MDCG 2025-4 (sklepy jako podmioty gospodarcze MDR); polityki sklepów dot. aplikacji medycznych/zdrowotnych | Średni (przegląd przy publikacji i aktualizacjach) | Ochrona własna platformy | Odrzucenie aktualizacji, delisting, żądanie CE/UDI w listingu |
| **Cywilny** | Pacjent, terapeuta, ośrodek | Dyrektywa (UE) 2024/2853 o odpowiedzialności za produkty (transpozycja do grudnia 2026 r.; oprogramowanie wprost jako produkt, ułatwienia dowodowe); k.c. | Wolny, ale nieograniczony kwotowo | Szkoda | Odszkodowanie; brak CE jako argument dowodowy o wadliwości |
| **Reputacyjny/zawodowy** | Towarzystwa psychoterapeutyczne, media, superwizorzy | Brak podstawy formalnej | Bardzo szybki | Ochrona standardów zawodu | Utrata kanału dystrybucji (terapeuta = kanał B2B2C) |

**Uwaga do kanału konkurencyjnego.** W Polsce mało widoczny, w Niemczech główny mechanizm egzekucji MDR: konkurenci i stowarzyszenia ścigają naruszenia w drodze wezwań (Abmahnung) i postępowań o zabezpieczenie; BGH (I ZR 193/06) uznał wprowadzanie do obrotu wyrobu bez CE za bezprawne i sprzeczne z zasadami konkurencji. Wraz z wejściem na rynek certyfikowanych konkurentów (DiGA, produkty klasy IIa) prawdopodobieństwo tego kanału w Polsce rośnie.

---

## 10.3. Kanał administracyjny — mechanika i terminy

### 10.3.1. Uprawnienia i sankcje (stan prawny)

- Ustawa z 2022 r. zastąpiła przepisy karne **administracyjnymi karami pieniężnymi**; kara przewidziana jest za naruszenie niemal każdego obowiązku z MDR lub ustawy.
- Wprowadzenie do obrotu lub do używania wyrobu niespełniającego wymogów lub z naruszeniem przepisów o ocenie zgodności — kara do **5 000 000 zł** (art. 74 ustawy).
- Brak systemu zarządzania ryzykiem, oceny klinicznej, nadzoru po wprowadzeniu do obrotu — do **500 000 zł**.
- Prezes URPL prowadzi kontrole zapowiedziane i niezapowiedziane; kontrola bez zawiadomienia dopuszczalna przy uzasadnionym podejrzeniu nieakceptowalnego ryzyka lub niezgodności.
- Ustawa przewiduje tryb rozstrzygnięcia decyzją administracyjną, czy produkt jest wyrobem (do weryfikacji numeru artykułu przez doradcę; URPL powołuje art. 8 ust. 2 ustawy w komunikatach o statusie regulacyjnym).

### 10.3.2. Dane empiryczne o praktyce

- Pod rządami poprzedniej ustawy URPL, mimo posiadania kompetencji, **nie zakwestionował decyzją administracyjną żadnej kwalifikacji produktu** — ani jako wyrobu, ani przeciwnie (stan na 2015 r.).
- Nie zidentyfikowano publicznie dostępnych decyzji URPL o karze pieniężnej wobec producenta oprogramowania działającego jako nie-wyrób. Brak danych ≠ brak ryzyka; oznacza jedynie, że kanał administracyjny jest w Polsce reaktywny i dotychczas skupiony na wyrobach fizycznych, dystrybutorach i reklamie.
- Branża od 2021 r. krytykuje widełki kar jako niewspółmierne (przykład podnoszony w konsultacjach: 5 mln zł dla dystrybutora, który sprawdził wszystko, co mógł). Argument proporcjonalności jest realny w postępowaniu.
- Organy w państwach członkowskich stosują kryteria kwalifikacji do narzędzi zdrowia psychicznego niekonsekwentnie; luka egzekucyjna jest znana Komisji (motyw MDCG 2025-4). To wyjaśnia, dlaczego wiele produktów działa jako wellness — i dlaczego „inni tak robią" nie jest obroną.

### 10.3.3. Sekwencja procedury (MDR + KPA)

| Etap | Podstawa | Co się dzieje | Typowy czas | Co może zrobić producent |
|---|---|---|---|---|
| 0. Impuls | — | Skarga (konkurent, terapeuta, pacjent), incydent, zgłoszenie od UODO/NFZ, kontrola tematyczna | — | Monitorować sygnały; mieć gotowy pakiet dowodowy (10.4) |
| 1. Ocena | art. 94 MDR | Organ żąda dokumentacji: przeznaczenie, opis funkcji, materiały handlowe, dane PMS | Tygodnie–miesiące | Odpowiedzieć pełnym pakietem: uzasadnienie kwalifikacji, log klasyfikatora, rejestr claimów |
| 2a. Niezgodność bez nieakceptowalnego ryzyka | art. 97 MDR | Organ wyznacza „rozsądny, jasno określony termin" proporcjonalny do niezgodności; praktyka UE (MDCG 2022-18): zwykle do 12 miesięcy | Miesiące | **Usunąć niezgodność**: wyłączyć funkcję (kill switch), zmienić claimy, zawęzić interfejs — dla SaaS w dniach |
| 2b. Nieakceptowalne ryzyko | art. 95 MDR | Organ bez zwłoki żąda działań korygujących i, proporcjonalnie, ograniczenia/wycofania/recall — również w komunikowanym terminie; środki krajowe dopiero przy braku reakcji | Dni–tygodnie | Natychmiastowe wyłączenie funkcji; komunikacja do użytkowników (FSN) |
| 2c. Środki tymczasowe | art. 98 MDR | Możliwe przy natychmiastowym zagrożeniu | Dni | Jak 2b |
| 3. Kara pieniężna | ustawa 2022 + KPA dział IVa | Odrębne postępowanie; strona ma prawo do wypowiedzenia się; decyzja zaskarżalna (wniosek o ponowne rozpatrzenie / WSA / NSA) | 6–18 miesięcy od wszczęcia | Wykazać wagę naruszenia jako nikłą, dobrowolne działania naprawcze, współdziałanie; wnosić o odstąpienie od kary na rzecz pouczenia (art. 189f KPA) |
| 4. Notyfikacja UE | art. 95 ust. 4–5, EUDAMED | Środki krajowe notyfikowane Komisji i państwom; przy braku sprzeciwu w 2 miesiące mogą być stosowane w całej UE | 2+ miesiące | Istotne przy ekspansji poza PL |

**Wnioski dla decyzji o czacie:**
1. „Ostrzeżenie" istnieje de facto na etapie 1 i 2a. Producent, który reaguje pełną dokumentacją i szybką korektą, ma silną pozycję do zamknięcia sprawy bez kary lub z karą symboliczną.
2. Wszystko, co przenosi sprawę do 2b (incydent, treść generowana w obszarze ryzyka suicydalnego, błąd w obszarze leczenia), odbiera producentowi kontrolę nad tempem. Stąd twarda reguła w ADR: klasyfikator **musi** blokować kategorię *ocena ryzyka* z najwyższym priorytetem i bez wyjątków.
3. Kill switch per tenant i globalny (feature flag) jest środkiem regulacyjnym, nie tylko inżynieryjnym: skraca „rozsądny termin" do godzin.

---

## 10.4. Kanał platformowy — konsekwencje wersji mobile

Decyzja o udostępnieniu czatu w aplikacji mobilnej terapeuty (Flutter, App Store / Google Play) dodaje podmiot, który ocenia status produktu niezależnie od URPL:

- MDCG 2025-4 wskazuje, że sklepy z aplikacjami mogą pełnić rolę podmiotów gospodarczych MDR (importer/dystrybutor) i muszą weryfikować CE, UDI-DI i dane producenta dla aplikacji będących wyrobami; organy krajowe (np. HPRA dla Apple/Google w Irlandii) mogą prowadzić nadzór, a Komisja może wymusić usunięcie na podstawie DSA.
- Skutek praktyczny: przegląd sklepowy działa jak **audyt claimów** przy każdej aktualizacji. Listing (opis, zrzuty, słowa kluczowe), notatki dla recenzenta i treści in-app widoczne w recenzji są oceniane pod kątem „czy to aplikacja medyczna".
- Środki:
  1. Rejestr claimów (rozdz. 7 dokumentu nadrzędnego) obejmuje **listingi sklepowe** i notatki dla recenzenta — ta sama dyscyplina co dokumentacja techniczna.
  2. Deklaracja przeznaczenia w notatce dla recenzenta: narzędzie do dokumentowania i organizacji pracy; funkcja czatu jako wyszukiwanie i formatowanie danych własnych użytkownika; brak funkcji diagnostycznych/terapeutycznych.
  3. Nie ukrywać funkcji przed recenzją (konto testowe z pełnym dostępem) — ukrywanie funkcji jest naruszeniem regulaminów sklepów i osłabia pozycję w ewentualnym sporze o kwalifikację.
  4. Odrzucenie aktualizacji przez sklep traktować jako **sygnał wczesnego ostrzegania** dla przeglądu kwalifikacji (trigger w ADR).
- Ekspozycja modułu klienta (companion app) jest wyższa niż modułu terapeuty — treści patient-facing. Wnioski z rozdz. 4.5 dokumentu nadrzędnego pozostają w mocy.

---

## 10.5. Praktyki rynkowe produktów na granicy MDR — co działa jako obrona

Uporządkowane od najsilniejszej do najsłabszej. Praktyki 1–3 zmieniają kwalifikację lub jej dowodliwość; 4–8 obniżają prawdopodobieństwo i skutki sporu.

| # | Praktyka | Efekt | Status w projekcie |
|---|---|---|---|
| 1 | **Zawężenie interfejsu** do zdefiniowanych operacji o określonych wejściach/wyjściach | Zmienia kwalifikację: przeznaczenie jest kontrolowane technicznie | Odrzucona jako wyłączny model (ADR); zachowana jako **ścieżka degradacji** (fallback klasyfikatora i plan B) |
| 2 | **Podejście modułowe** (MDCG 2019-11): producent definiuje moduły z przeznaczeniem medycznym i certyfikuje tylko je | Umożliwia platformę nie-wyrób z wydzielonym modułem czerwonym za flagą, gotowym do IIa | Do wdrożenia: strefa czerwona jako osobny moduł, wyłączony flagą, z własną granicą API |
| 3 | **Udokumentowane uzasadnienie kwalifikacji**: drzewo MDCG 2019-11, deklaracja przeznaczenia, rejestr claimów, log klasyfikatora | Pakiet dowodowy na etap art. 94; organ ocenia proces producenta | Do wdrożenia (ADR, sekcja „Pakiet dowodowy") |
| 4 | **Klasyfikator intencji + weryfikator wyjścia + wymuszony format** | Ogranicza „racjonalnie przewidywalne użycie"; obniża prawdopodobieństwo generowania treści kwalifikujących | **Decyzja podjęta** — szczegóły w ADR |
| 5 | **Dyscyplina claimów** w marketingu, UI, listingach sklepowych, onboardingu | Usuwa najczęstszą podstawę sporu (w DE: główny przedmiot Abmahnung) | Rozdz. 7 dokumentu nadrzędnego; rozszerzyć o sklepy |
| 6 | **Regulatory-ready engineering**: IEC 62304 (cykl życia), ISO 14971 (ryzyko), IEC 82304-1 (health software) bez pełnego ISO 13485 | Skraca ścieżkę certyfikacji z 18–30 do ~9–15 miesięcy, jeśli zostanie wymuszona | Do decyzji budżetowej |
| 7 | **Telemetria dryfu**: odsetek odrzuconych zapytań, wskaźniki obejścia, odsetek pól szablonów wypełnionych przez model vs terapeutę | Dowód, że przeznaczenie jest kontrolowane; wczesne ostrzeganie o dryfie w stronę wyrobu | ADR, sekcja „Metryki i progi" |
| 8 | **Kill switch** per tenant / globalny | Skraca „rozsądny termin" art. 97 do godzin; ogranicza skutki art. 95 | ADR |
| 9 | Ubezpieczenie OC producenta obejmujące oprogramowanie | Ogranicza skutek kanału cywilnego | Do wyceny |
| 10 | Wniosek do URPL o rozstrzygnięcie kwalifikacji | Pewność prawna, ale wynik może być niekorzystny dla strefy żółtej | Dopiero po opinii doradcy; tylko dla strefy zielono-żółtej |

**Praktyki, które nie działają:** disclaimery („nie jest wyrobem medycznym") sprzeczne z funkcją; ograniczenie odbiorców do niepsychiatrów (rozdz. 3.1); klasyfikator oparty na słownictwie zamiast na wnioskowaniu (blokuje „diagnoza", przepuszcza „odwzoruj na model" — patrz 10.6).

---

## 10.6. Modalności terapeutyczne a granica wyrobu — konkretyzacja

Pytanie projektowe: jak zachować wsparcie pracy w modalnościach (np. PPT — model potencjalności, model równowagi; analogicznie inne szkoły), nie tworząc funkcji kwalifikującej.

**Reguła:** kryterium jest *wnioskowanie o konkretnym kliencie*, nie *słownictwo*. „Odwzoruj zachowania klienta X na model potencjalności" = konceptualizacja przypadku = nowa informacja kliniczna o konkretnym pacjencie = strefa czerwona (Reguła 11, IIa), niezależnie od modalności.

| Warstwa | Przykład | Kwalifikacja | Uwagi |
|---|---|---|---|
| **Edukacyjna, bez klienta** | „Wyjaśnij model równowagi w PPT", „jakie pytania zadaje się przy pracy z modelem potencjalności", literatura | Poza zakresem (materiał referencyjny) | Dozwolone. Klasyfikator: brak odniesienia do klienta/transkryptu |
| **Wyszukiwanie wg kategorii wskazanych przez terapeutę** | „Pokaż wypowiedzi klienta o wyborze między pracą a rodziną", „zestaw fragmenty, w których pojawia się temat sensu" | Wyszukiwanie/odtworzenie danych | Dozwolone. Wyjście: cytaty verbatim + sygnatura + mówca. Terapeuta sam mapuje na model |
| **Szablon wypełniany przez terapeutę** | Struktura konceptualizacji PPT jako formularz; system podpina cytaty do pól wskazanych przez terapeutę; wnioski pisze terapeuta | Dokumentacja (autorstwo klinicysty) | Dozwolone pod warunkiem: pola wnioskowe **read-only dla modelu**; telemetria „kto wypełnił pole" |
| **Wnioskowanie modelu** | „Do której sfery modelu równowagi należy przypisać ten wzorzec?", „jaki potencjał aktualny jest tu naruszony?" | **Wyrób** (konceptualizacja) | Klasyfikator: odmowa + przekierowanie do warstwy 2/3 |
| **Ocena, prognoza, interwencja** | „Czy klient robi postępy", „co zalecić", „jakie ryzyko" | **Wyrób** (IIa/IIb) | Odmowa bez wyjątków; kategoria ryzyka — najwyższy priorytet |

Ta tabela jest wejściem do taksonomii intencji klasyfikatora (ADR, sekcja 5).

---

## 10.7. Ocena decyzji „czat z klasyfikatorem, web + mobile"

| Wymiar | Ocena |
|---|---|
| Kwalifikacja MDR | **Nie zmienia się** względem rozdz. 4.2: racjonalnie przewidywalne użycie przez terapeutę pozostaje kliniczne; klasyfikator jest środkiem kontroli, nie zmianą przeznaczenia. W sporze o kwalifikację pozycja jest słabsza niż przy zawężonym interfejsie. |
| Prawdopodobieństwo sporu | Niższe niż bez klasyfikatora; wyższe niż przy zawężonym interfejsie. Wersja mobile dodaje przegląd sklepowy. |
| Skutek sporu | Kontrolowalny, jeśli: kill switch, pakiet dowodowy, ścieżka degradacji do zdefiniowanych operacji, brak incydentu. Niekontrolowalny przy incydencie w kategorii ryzyka. |
| Warunki akceptacji ryzyka | (1) klasyfikator z weryfikatorem wyjścia i wymuszonym formatem, nie tylko filtr wejścia; (2) kategoria *ocena ryzyka* blokowana bez wyjątków; (3) telemetria dryfu z progami uruchamiającymi przegląd; (4) kill switch; (5) rejestr claimów obejmujący sklepy; (6) opinia zewnętrznego doradcy na obu modułach łącznie **przed** GA; (7) budżet na regulatory-ready engineering lub świadome odroczenie z datą przeglądu. |
| Plan B | Degradacja do zdefiniowanych operacji (interfejs 1-klik, ten sam backend) — do przygotowania równolegle, tak by przełączenie było flagą, nie projektem. |

---

## 10.8. Pytania do doradcy regulacyjnego (uzupełnienie rozdz. 9)

- Czy klasyfikator intencji z weryfikatorem wyjścia i wymuszonym formatem ekstraktywnym jest wystarczający, by uznać, że producent kontroluje racjonalnie przewidywalne użycie interfejsu konwersacyjnego (rozdz. 4.2)?
- Jaki numer artykułu ustawy z 2022 r. reguluje decyzję Prezesa URPL o kwalifikacji produktu i czy wniosek producenta jest w tym trybie dopuszczalny?
- Czy log odrzuconych zapytań (pseudonimizowany) może być przechowywany jako dowód kontroli przeznaczenia bez naruszenia zasady minimalizacji (RODO) i tajemnicy zawodowej?
- Czy dla wersji mobile listing sklepowy i notatka dla recenzenta stanowią „materiały producenta" w rozumieniu art. 7 MDR (zakaz wprowadzających w błąd twierdzeń)?
- Jakie klauzule OC producenta obejmują oprogramowanie nie-wyrób z funkcją AI używane w kontekście klinicznym?

---

## Źródła

- Rozporządzenie (UE) 2017/745 (MDR): art. 2 pkt 1, art. 7, art. 93–98; zał. VIII Reguła 11.
- MDCG 2019-11 rev.1 (czerwiec 2025) — kwalifikacja i klasyfikacja oprogramowania; podejście modułowe.
- MDCG 2022-18 — stosowanie art. 97 MDR (praktyka „rozsądnego terminu").
- MDCG 2025-4 — sklepy z aplikacjami jako podmioty gospodarcze MDR.
- Ustawa z 7 kwietnia 2022 r. o wyrobach medycznych (Dz.U. 2022 poz. 974) — rozdz. o kontroli i karach pieniężnych (art. 74 i n.).
- Kodeks postępowania administracyjnego, dział IVa (art. 189a–189k) — administracyjne kary pieniężne, art. 189f (odstąpienie od kary).
- Ustawa o zwalczaniu nieuczciwej konkurencji — art. 3, art. 18.
- Dyrektywa (UE) 2024/2853 o odpowiedzialności za produkty wadliwe.
- BGH, wyrok z 9.07.2009, I ZR 193/06 — wprowadzenie do obrotu wyrobu bez CE jako czyn nieuczciwej konkurencji.
- Rozporządzenie (UE) 2024/1689 (AI Act) — art. 50 (od 2.08.2026); zał. I i III (terminy po Digital Omnibus: 2.12.2027 / 2.08.2028).

*Zastrzeżenie: analiza wewnętrzna, nie opinia prawna. Stan prawny i rynkowy na 18 sierpnia 2026 r.*
