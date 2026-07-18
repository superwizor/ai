# 43 — Companion app B2C: model dwóch domen danych

**Status:** design zaakceptowany kierunkowo (2026-07-18). Brak kodu.
Warunek startu implementacji: rozstrzygnięcia prawne z §10 (rola
administratora + nagrywanie osób trzecich — jedyne kwestie zdolne
zatrzymać produkt).

## 1. Cel produktowy

Companion app sprzedawana **niezależnie klientom** (B2C): klient
rejestruje się sam, nagrywa własne sesje, dostaje raporty. Dodatkowa
pętla wzrostu: klient może „pozyskać" swojego terapeutę — po
sparowaniu z terapeutą posiadającym aktywny seat (docs/38) aplikacja
Companion jest dla klienta bezpłatna.

Rozważany wcześniej wariant „zero e-maila" (onboarding wyłącznie
QR/kod, tożsamość tylko u terapeuty i Apple/Google) **odrzucony**:
samodzielna rejestracja i odzysk konta wymagają e-maila. Z tamtego
projektu zachowujemy to, co przeżyło: e-mail jako jedyny bezpośredni
identyfikator, profil pseudonimowy, płatności mobilne izolowane
w Apple/Google.

## 2. Co się zmienia prawnie — sedno dokumentu

Dziś Euphire jest wyłącznie **podmiotem przetwarzającym**; administratorem
danych klienta jest zawsze terapeuta (RCP część B). Klient samodzielny
nie ma terapeuty-administratora — **administratorem jego danych
zdrowotnych staje się Euphire**, z własną podstawą prawną: wyraźna
zgoda, art. 9 ust. 2 lit. a RODO.

Konsekwencje: nowa czynność w RCP część A, istotne rozszerzenie DPIA
(dane szczególnej kategorii na dużą skalę w roli administratora —
podręcznikowy art. 35 ust. 3 lit. b), konsumencka polityka prywatności
i regulamin, bramka wieku, samoobsługowa realizacja praw podmiotu.
Szczegóły delt: §11.

## 3. Architektura: dwie domeny z jawnym mostem

```
DOMENA A — „Moja przestrzeń” (klient)     DOMENA B — kartoteka (terapeuta)
  administrator: EUPHIRE                    administrator: TERAPEUTA
  podstawa: zgoda art. 9(2)(a)              podstawa: DPA (bez zmian)
  self-kartoteka, nagrania klienta,         dzisiejszy model — nietknięty
  jego raporty, jego pamięć RAG
                    │
                    └── MOST (§7): jawne udostępnienie per pozycja,
                        copy-on-share do kartoteki; nigdy automatyczne
```

Zasady twarde:

1. **Sparowanie z terapeutą nie przelewa danych.** Otwiera domenę B dla
   nowych sesji prowadzonych z terapeutą; historia domeny A zostaje
   przy kliencie.
2. **Domena A zawsze zostaje przy kliencie** — także po rozstaniu
   z terapeutą. Kopie udostępnione do kartoteki żyją dalej w reżimie
   administratora-terapeuty (spójnie z zasadą „dokumentacja terapeuty
   jest jego" z docs/compliance/06 §7).
3. Jedna platforma, jeden pipeline (ingestion→STT→LLM — bez zmian);
   różnica jest w modelu własności i podstawie prawnej, nie w
   przetwarzaniu.

## 4. Tożsamość i rejestracja

- **E-mail = wyłącznie login + odzysk konta.** Rejestracja NIE zbiera
  imienia ani nazwiska; profil klienta jest pseudonimowy (spójnie
  z polem „Pseudonim" w kartotece). E-mail żyje w identity-svc;
  domena kliniczna operuje na UUID — bezpośredni identyfikator nie
  sąsiaduje z treścią.
- **Bramka wieku:** oświadczenie 16+ przy rejestracji (art. 8 RODO,
  polski próg samodzielnej zgody). Bez weryfikacji dokumentem w v1 —
  do potwierdzenia z radcą (§10).
- Firebase Auth jak dziś (e-mail + SSO); konto klienta z panelu
  zaproszeń (docs/42) i konto samodzielne to **ten sam typ konta** —
  różnią się posiadaniem self-kartoteki i wpisami zgód, nie klasą
  użytkownika. Klient zaproszony przez terapeutę może później otworzyć
  domenę A (upsell), klient samodzielny — sparować się (§6).

## 5. Model zgód (domena A)

Osobne, odwoływalne zgody, wersjonowane i ewidencjonowane
(timestamp + wersja treści; wzorzec `has_marketing_consent`,
ale per zgoda):

| Zgoda | Zakres | Wymagana do |
|---|---|---|
| Z1 | przetwarzanie nagrań i treści zdrowotnych (art. 9(2)(a)) | działania domeny A w ogóle |
| Z2 | analiza AI (transkrypcja + raporty) | generowania raportów |
| Z3 | udostępnienie konkretnej pozycji terapeucie | każdorazowo per share (§7) — nie jest zgodą blankietową |

Wycofanie Z1 = samoobsługowe usunięcie domeny A: istniejąca mechanika
soft delete → GDPR Purger (30 dni), wystawiona klientowi w ustawieniach
(„Usuń moje dane"). Wycofanie Z2 zatrzymuje analizę, nie usuwa danych.

## 6. Parowanie odwrotne i entitlement

**Parowanie:** lustrzane odbicie docs/42 — klient generuje zaproszenie
dla terapeuty, kod parowania przekazany na sesji dowodzi relacji.
Reużycie mechaniki 1:1: kod 6 cyfr, hash-only, constant-time compare,
5 prób → blokada, revoke, TTL 72 h, zdarzenia audytowe. Nowe RPC
w identity-svc symetryczne do `InviteClient`/`AcceptInvitation`.

**Entitlement:** subskrypcja Companion wymagana ⟺ brak aktywnej pary
z terapeutą posiadającym seat (docs/38). Sprawdzenie po stronie
billing-svc przy odświeżeniu entitlementu; zerwanie pary → grace
period (propozycja: 30 dni) → wymóg subskrypcji. Nadużycie „fikcyjny
terapeuta dla darmowej apki" blokuje się samo — parowanie daje
darmowość tylko z terapeutą, który sam płaci za seat.

**Płatności:** mobile wyłącznie IAP (wymóg sklepów dla usługi cyfrowej
B2C; bonus: tożsamość płatnicza zostaje u Apple/Google — Euphire widzi
tylko opaque transaction ID). Płatność webowa przez Stripe = decyzja
otwarta (§10) — technicznie prosta, ale wiąże e-mail klienta z
tożsamością płatniczą i łamie izolację rozliczeń.

## 7. Most udostępniania — copy-on-share

Udostępnienie pozycji (raport/sesja) terapeucie tworzy **kopię** w
kartotece domeny B (snapshot), nie referencję:

- kopia przechodzi pod administrację terapeuty — jego dokumentacja
  jest stabilna (klient nie może retroaktywnie „wyjąć" fragmentu
  dokumentacji procesu, na której terapeuta oparł pracę);
- cofnięcie udostępnienia działa **na przyszłość** (koniec synchronizacji
  kolejnych pozycji), nie wstecz — semantyka jawnie komunikowana w UX
  przy Z3;
- odrzucona alternatywa (referencja z revoke): niestabilna dokumentacja
  terapeuty + sprzeczność z docs/compliance/06 §7.

Zakres share w v1: **raport** (pseudonimizowany — §8). Udostępnianie
surowego transkryptu domeny A: poza zakresem v1 (do dyskusji, gdy
pojawi się potrzeba).

## 8. Pseudonimizacja w trybie self — WŁĄCZONA

Pipeline pseudonimizacji (docs/41, `LLM_PSEUDONYMIZE=all`) obowiązuje
w domenie A bez zmian, z nowym, mocniejszym uzasadnieniem: nagrania
klienta zawierają **osoby trzecie** (partner, rodzina, współpracownicy),
które na nic nie wyrażały zgody i nie są stroną żadnej umowy. Redakcja
nazwisk/adresów/pracodawców/miejscowości w raportach i pamięci RAG to
główny środek ochrony tych osób — w DPIA (§11) wchodzi jako argument
pierwszej wagi, nie dodatek.

Transkrypt kanoniczny domeny A: nietknięty dla klienta-właściciela —
ta sama logika co dla terapeuty (weryfikowalność źródłem, docs/06 §7),
tym bardziej że klient jest podmiotem własnych danych.

## 9. Nagrywanie osób trzecich

Klient nagrywający sesję nagrywa też głos terapeuty i ewentualnych
uczestników. Uczestnik rozmowy w PL nie popełnia przestępstwa
nagrywając (art. 267 kk dotyczy osób postronnych), ale **Euphire
przetwarza głos osoby niebędącej użytkownikiem** — potrzebna podstawa
i mechanika:

- w aplikacji przy każdym nagraniu sesji: deklaracja „jestem
  uczestnikiem rozmowy i poinformowałem pozostałych uczestników
  o nagrywaniu" — zapisywana (timestamp, wersja treści) jako dowód
  staranności;
- **tryb „dziennik" (solo notatka głosowa)** — bez drugiej strony,
  bez problemu prawnego; kandydat na główny tryb marketingowy
  i domyślny w onboardingu;
- ostateczna konstrukcja podstawy prawnej dla głosów osób trzecich —
  pytanie do radcy (§10).

## 10. Pytania do radcy prawnego (blokujące start)

1. Konstrukcja podstawy przetwarzania głosu osób trzecich w nagraniach
   klienta (uzasadniony interes? deklaracja uczestnika wystarczy?) —
   oraz czy tryb „dziennik solo" powinien być jedynym w v1.
2. Zakres obowiązków informacyjnych Euphire-administratora wobec osób
   trzecich wzmiankowanych w nagraniach (art. 14 — niewykonalność?
   wyjątek art. 14 ust. 5 lit. b?).
3. Bramka wieku: czy oświadczenie 16+ wystarczy, czy potrzebna
   weryfikacja; obsługa 13–16 ze zgodą rodzica — czy w ogóle w v1.
4. Czy skala domeny A wymaga powołania IOD (art. 37 ust. 1 lit. c).
5. Płatność webowa (Stripe) obok IAP — akceptowalność powiązania
   e-mail↔tożsamość płatnicza vs korzyść biznesowa (prowizja sklepów).
6. Treść zgód Z1–Z3 i konsumenckiego pakietu dokumentów.

## 11. Delty compliance

| Dokument | Delta |
|---|---|
| RCP część A | nowa czynność A-6: „Companion B2C — przetwarzanie danych zdrowotnych klientów samodzielnych, administrator Euphire" (kategorie, podstawy, retencja jak domena B + zgody) |
| DPIA (docs/compliance/03) | rozszerzenie o domenę A: rola administratora, osoby trzecie w nagraniach, pseudonimizacja jako środek, most copy-on-share |
| Polityka retencji | domena A: te same okresy co B (48 h audio, 30 dni soft delete); + retencja ewidencji zgód |
| Nowe | polityka prywatności konsumencka, regulamin konsumencki Companion |

## 12. Szkic faz wdrożenia

| Faza | Zakres | Zależność |
|---|---|---|
| 0 | rozstrzygnięcia §10 + pakiet dokumentów konsumenckich | radca |
| 1 | identity-svc: self-rejestracja + zgody + bramka wieku; clinical-svc: self-kartoteka (właściciel = klient) | — |
| 2 | pipeline dla domeny A (reużycie; głównie authz i własność), tryb „dziennik" we Flutter Companion | F1 |
| 3 | parowanie odwrotne (reużycie docs/42) + entitlement w billing-svc | F1 |
| 4 | most copy-on-share (Z3, snapshot do kartoteki) | F2+F3 |
| 5 | IAP + (decyzja §10.5) płatność webowa | F3 |

Fazy 2–5 są niezależnie wydawalne; produkt minimalny = F0–F2
(samodzielny klient z dziennikiem i raportami, bez terapeuty).

Dokumenty powiązane: docs/38 (seaty), docs/41 (pseudonimizacja),
docs/42 (mechanika parowania), docs/compliance/06 (§7 — dlaczego
transkrypt właściciela zostaje nietknięty), docs/compliance/01–03
(retencja, RCP, DPIA — delty §11).
