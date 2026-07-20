# Mechanizmy zabezpieczania danych i podejście do pseudonimizacji

**Dokument dla działu prawnego i sprzedaży**

**Wersja:** 1.2 (1.2: pełna pseudonimizacja danych kanonicznych —
transkrypcja w bazie również redagowana; ODWRÓCONA decyzja z dawnego
§7 — §5.2, §7, §8. 1.1: wdrożony inwariant „jedyny identyfikator
klienta = e-mail" — §5.1, §8, §9 pkt 6)
**Data:** 2026-07-20
**Odpowiedzialny:** Euphire sp. z o.o., ul. Odrzańska 10a/48, Kraków
**Kontakt:** kontakt@superwizor.ai
**Status:** DRAFT — do weryfikacji przez radcę prawnego
**Źródło:** stan faktyczny kodu i infrastruktury (Terraform) na 2026-07-18;
dokument opisuje mechanizmy WDROŻONE, chyba że wprost oznaczono inaczej.

---

## 1. Cel i sposób czytania

Dokument odpowiada na dwa pytania:

1. **Dla prawników:** jakie środki techniczne i organizacyjne faktycznie
   działają w produkcie (art. 32 RODO), gdzie fizycznie są dane, kim są
   podprocesorzy i co wymaga aktualizacji w dokumentach compliance.
2. **Dla sprzedaży:** co wolno obiecywać klientom (sekcja §8 — dozwolone
   i zakazane sformułowania), z uzasadnieniem, żeby odpowiedź na trudne
   pytanie terapeuty lub IOD-a po stronie kliniki była spójna z prawdą
   techniczną.

Dokument uzupełnia — nie zastępuje — istniejącą serię compliance:
`01_POLITYKA_RETENCJI_DANYCH.md`, `02_REJESTR_CZYNNOSCI_PRZETWARZANIA.md`
(RCP), `03_DPIA_OCENA_SKUTKOW.md`. Sekcja §9 wylicza delty, które trzeba
do nich nanieść (nowy podprocesor STT, pseudonimizacja raportów).

---

## 2. Model ról (kto jest administratorem czego)

| Dane | Administrator | Rola Euphire |
|---|---|---|
| Dane terapeutów (konto, profil, płatności) | **Euphire sp. z o.o.** | Administrator |
| Dane klientów/pacjentów (nagrania, transkrypcje, raporty, kartoteki, notatki) | **Terapeuta** (Użytkownik Profesjonalny) — każdy indywidualnie | Podmiot przetwarzający (procesor) na podstawie DPA |

To rozróżnienie jest fundamentem architektury i wraca w §7 (dlaczego nie
redagujemy transkryptu dla terapeuty): **terapeuta jest administratorem
danych swojego pacjenta i prowadzi dokumentację procesu** — my
dostarczamy narzędzie i zabezpieczamy dane, ale nie decydujemy za
administratora, co z jego dokumentacji zniknie.

---

## 3. Przepływ danych sesji i zabezpieczenia na każdym etapie

```
Nagranie (aplikacja terapeuty)
  │  TLS; upload przez podpisane adresy URL (V4, krótki TTL)
  ▼
Google Cloud Storage, europe-central2 (Warszawa)
  │  szyfrowanie CMEK; automatyczne usunięcie audio po maks. 48 h (OLM)
  ▼
Transkrypcja (STT) — jeden z dwóch dostawców, oba w UE:
  ├─ Deepgram Nova-3 (domyślny): endpoint api.eu.deepgram.com,
  │    przetwarzanie synchroniczne BEZ trwałej kopii po stronie dostawcy,
  │    mip_opt_out=true (zakaz użycia danych do ulepszania modeli)
  └─ Google Chirp 3 (automatyczny fallback): eu-speech.googleapis.com,
       europe-west4; surowe wyniki STT usuwane po 7 dniach (OLM)
  ▼
Analiza AI — Vertex AI Gemini, europe-west4 (Holandia)
  │  call-1: metadane + wykrycie danych identyfikujących (sekcja PII)
  │  PSEUDONIMIZACJA (deterministyczny silnik — §5) — dopiero potem:
  │  call-2: raport kliniczny na tekście już pseudonimizowanym
  ▼
Zapis — PostgreSQL Cloud SQL, europe-central2
  │  envelope encryption (AEAD + Cloud KMS, rotacja klucza co 90 dni);
  │  raport, Title/Summary i pamięć RAG zapisywane w wersji
  │  pseudonimizowanej; transkrypt kanoniczny w oryginale (§7),
  │  zaszyfrowany jak wszystkie dane szczególnej kategorii
  ▼
Dostęp — wyłącznie uwierzytelniony terapeuta-właściciel kartoteki
   (oraz pacjent w panelu klienta — widzi wersję pseudonimizowaną)
```

Właściwości przekrojowe:

- **Rezydencja danych klinicznych: EOG.** Przechowywanie w
  europe-central2 (Warszawa), przetwarzanie AI w europe-west4
  (Holandia), STT na endpointach EU. Wyjątki dotyczą wyłącznie danych
  terapeutów, nie pacjentów: Stripe (płatności, EU-US DPF + SCC),
  Resend (e-mail, SCC), FCM (tokeny push — treść powiadomień nie
  zawiera żadnych danych pacjentów).
- **Brak treningu modeli na danych klientów.** Vertex AI nie używa
  danych klientów do trenowania modeli (warunki Google Cloud);
  Deepgram — `mip_opt_out=true` wymuszone **w kodzie jako inwariant**
  (parametr nie jest konfigurowalny żadną flagą; istnieje test
  automatyczny, który nie pozwala go wyłączyć), audytowalne w logach
  konsoli Deepgram.
- **Endpoint EU jako inwariant.** Adres API Deepgram jest przypięty w
  Terraformie do `api.eu.deepgram.com`, a serwis **odmawia startu**,
  jeśli skonfigurowany endpoint nie jest endpointem EU. Nie istnieje
  ścieżka kodu wysyłająca audio poza UE.
- **Minimalizacja czasowa.** Audio żyje maks. 48 h, surowe wyniki STT
  7 dni, logi systemowe 30 dni, analityka 90 dni; dane merytoryczne —
  przez czas umowy + 30 dni soft delete, potem nieodwracalny hard
  delete (GDPR Purger). Szczegóły: Polityka Retencji (dok. 01).
- **Firestore (synchronizacja statusów w czasie rzeczywistym) nie
  zawiera treści** — wyłącznie identyfikatory UUID i status
  przetwarzania (np. „transcribing", „done").

---

## 4. Kontrola dostępu i tożsamości

- **Uwierzytelnianie:** Firebase Authentication (Google/Apple SSO,
  e-mail); izolacja per organizacja i per kartoteka — każdy dostęp do
  danych klinicznych przechodzi przez sprawdzenie uprawnień do
  konkretnej kartoteki.
- **Zero Trust wewnątrz systemu:** każdy mikroserwis ma dedykowane
  konto serwisowe z minimalnymi uprawnieniami; CI/CD bez długotrwałych
  kluczy (Workload Identity Federation); sekrety wyłącznie w Secret
  Manager; baza za VPC Connectorem, połączenia tylko szyfrowane.
- **Zaproszenie pacjenta = dwa niezależne czynniki** (wdrożone
  2026-07-17): link e-mailowy dowodzi tylko władania skrzynką, dlatego
  aktywację konta pacjenta warunkuje dodatkowo **6-cyfrowy kod
  parowania**, który terapeuta przekazuje pacjentowi poza e-mailem
  (na sesji lub telefonicznie). Kod nigdy nie jest wysyłany e-mailem;
  w bazie przechowywany jest wyłącznie jego hash; porównanie odbywa
  się w czasie stałym; 5 błędnych prób blokuje zaproszenie; terapeuta
  może zaproszenie jawnie **cofnąć**; ważność linku: 72 h. Każde
  zdarzenie (wysłanie, akceptacja, blokada, cofnięcie) trafia do
  dziennika audytowego.
- **Dziennik audytowy** (`audit_events`): operacje na danych
  klinicznych są rejestrowane (kto, co, kiedy, na jakim zasobie);
  retencja bezterminowa (rozliczalność, art. 5 ust. 2 RODO).
- **Płatności:** Euphire nie przechowuje danych kart — wyłącznie
  Stripe (PCI DSS Level 1).

---

## 5. Pseudonimizacja — jak działa naprawdę

Pseudonimizacja działa na **trzech warstwach**, od momentu zebrania
danych po treści generowane przez AI. Wdrożona i aktywna na środowisku
staging od 2026-07-17 (tryb pełny), po przejściu bramek jakości (§6).

### 5.1 Warstwa 1: minimalizacja u źródła

Od 2026-07-18 (wdrożenie inwariantu docs/43 §4) minimalizacja jest
egzekwowana **serwerowo, na całej długości systemu** — nie jest już
tylko konwencją formularza:

- **System nie zbiera imion ani nazwisk klienta w żadnym punkcie**:
  kartoteka ma wyłącznie pole **„Pseudonim"**, rejestracja klienta nie
  pyta o dane osobowe, a serwer ignoruje pola imion nadesłane przez
  starsze wersje aplikacji (zgodność wsteczna bez utrwalania danych).
- **Jedynym bezpośrednim identyfikatorem klienta jest adres e-mail**,
  przechowywany wyłącznie w domenie tożsamości: w zaproszeniu (z
  ograniczonym czasem życia) i na koncie po aktywacji. Kartoteka
  kliniczna nie przechowuje adresu; zapis „dokąd wysłano" materiały
  jest utrwalany wyłącznie w postaci zamaskowanej (p***@domena);
  format adresu jest walidowany serwerowo.
- Pseudonim (working alias) **nie jest przekazywany do modeli AI**
  ani zapisywany w dzienniku audytowym — utrzymywane jako inwarianty
  (zweryfikowane w kodzie 2026-07-17/18).
- Etykiety mówców w transkrypcji są neutralne lub rolowe
  („Terapeuta"/„Klient") — nigdy imienne.

### 5.2 Warstwa 2: pseudonimizacja treści sesji

Od 2026-07-20 redakcja obejmuje nie tylko treści generowane przez AI,
ale i **kanoniczny zapis transkrypcji w bazie danych**. Wszystko, co
system trwale przechowuje z treści sesji — transkrypcja (blob i
segmenty, które renderują widoki terapeuty i klienta), raport z sesji,
jego tytuł i skrót (widoczne na listach w aplikacji), pamięć
kontekstowa RAG (długoterminowa pamięć procesu terapeutycznego) —
przechodzi przez ten sam deterministyczny silnik redakcji. Jedyny
wyjątek czasowy: między zapisem surowej transkrypcji a przebiegiem
analizy (zwykle pojedyncze minuty) transkrypcja leży w oryginale,
zaszyfrowana; po zbudowaniu planu redakcji zostaje nieodwracalnie
nadpisana wersją zredagowaną. Zakres redakcji:

| Kategoria | Decyzja | Efekt w raporcie |
|---|---|---|
| **Imiona** | **ZOSTAJĄ** (decyzja produktowa, uzasadnienie niżej) | „Karol", „Kasia" |
| Nazwiska | redakcja | „Anna Kowalska" → „Anna"; nazwisko solo → `[NAZWISKO-1]` |
| PESEL, nr dokumentów, telefony, e-maile, kody pocztowe | redakcja **warstwą regex** — deterministyczną, działającą zawsze, niezależnie od AI | `[IDENTYFIKATOR]` |
| Adresy (ulice, numery) | redakcja | `[ADRES]` |
| Pracodawcy i szkoły | redakcja do tokenu generycznego | `[PRACODAWCA]`, `[SZKOŁA]` |
| Miejscowości — **wszystkie**, także duże miasta | redakcja | `[MIEJSCOWOŚĆ-A]` |
| Daty urodzenia | redakcja | `[DATA-URODZENIA]` |

Dlaczego imiona zostają: samo imię identyfikuje słabo, a niesie
istotną klinicznie treść relacyjną („konflikt z Karolem" vs „konflikt
z `[OSOBA-3]`") — raport pozostaje naturalnie czytelny dla terapeuty.
Dlaczego pracodawcy, szkoły i wszystkie miejscowości znikają: to silne
quasi-identyfikatory — kombinacja „imię + firma + miasto" potrafi
wskazać osobę bez nazwiska, a wartość kliniczna „konfliktu w pracy"
jest taka sama jak „konfliktu w [nazwa firmy]".

Konstrukcja techniczna (istotna dla oceny ryzyka):

- **Dwie niezależne linie obrony.** Identyfikatory strukturalne
  (PESEL, telefony, e-maile, kody, numery dokumentów) usuwa warstwa
  wyrażeń regularnych — w 100% deterministyczna, niezależna od modelu
  AI, niemożliwa do „przegapienia" przez model. Nazwy własne wskazuje
  model AI (wraz z odmianą gramatyczną i wariantami przekręconymi
  przez rozpoznawanie mowy), a samą zamianę wykonuje deterministyczny
  kod (dopasowanie po granicach słów, spójny token w całej sesji).
- **Mniej danych u podprocesora.** Pseudonimizacja następuje PRZED
  drugim wywołaniem modelu (generowaniem raportu) — model piszący
  raport w ogóle nie widzi nazwisk, adresów ani nazw miejscowości.
- **Pamięć długoterminowa (RAG) przechowywana wyłącznie w wersji
  pseudonimizowanej** — dane identyfikujące nie kumulują się w pamięci
  procesu terapeutycznego między sesjami.
- **Panel klienta dziedziczy pseudonimizację** — pacjent czytający
  własny raport również widzi tokeny.

### 5.3 Warstwa 3: pseudonimizacja niezależna od treści

Niezależnie od powyższego: statusy w Firestore to wyłącznie UUID,
powiadomienia push nie zawierają żadnych danych pacjentów, embeddingi
wektorowe liczone są na tekście po redakcji.

### 5.4 Kwalifikacja prawna — uczciwie

**To jest pseudonimizacja (art. 4 pkt 5 RODO), nie anonimizacja.**
Dane pozostają danymi osobowymi — terapeuta zna tożsamość pacjenta,
a wykrywanie nazw własnych przez model jest best-effort: nazwisko
mocno przekręcone przez rozpoznawanie mowy może przejść. Zyskiem jest
**istotna minimalizacja ryzyka** (mniejsza ekspozycja danych
identyfikujących w raportach, na listach w UI, w pamięci
długoterminowej i u podprocesora LLM), wzmacniająca DPIA — nie
zwolnienie z reżimu RODO. Semantyka błędów: jeżeli wykrywanie PII
zawiedzie, raport powstaje bez redakcji (fail-open) i zdarzenie jest
logowane oraz monitorowane — świadomie nie blokujemy sesji terapeuty
z powodu awarii funkcji prywatnościowej, bo dane i tak pozostają
zaszyfrowane i dostępne wyłącznie dla uprawnionego terapeuty.

---

## 6. Kontrola jakości pseudonimizacji (bramki przed włączeniem)

Pseudonimizacja nie została włączona „na wiarę" — przechodzi przez dwie
automatyczne bramki, powtarzalne przy każdej zmianie reguł:

1. **Eval offline (`pii-eval`):** zestaw syntetycznych polskich
   transkryptów z celowo wstrzykniętą PII (odmiana nazwisk przez
   przypadki, nazwiska przekręcone jak przez STT, leki mylące się z
   nazwiskami, zdrobnienia imion, które NIE mogą zniknąć). Progi:
   0% przecieków na formach bazowych i warstwie regex, <5% na formach
   odmienionych, ~0 fałszywych usunięć. Wynik 2026-07-17: **wszystkie
   progi spełnione, potwierdzone trzykrotnie** (0/8, 0/11, 0/14).
2. **Test end-to-end na żywym środowisku:** nagranie audio z
   wstrzykniętymi danymi (nazwisko, pracodawca, miasto, szkoła,
   telefon) przechodzi cały łańcuch nagranie→STT→AI→raport; test
   sprawdza, że żadna wstrzyknięta dana nie występuje w raporcie,
   tytule ani skrócie, a imiona i tokeny są obecne. Wynik 2026-07-17:
   **zero przecieków**.

Reguły wykrywania PII mają jedno źródło w kodzie, a proces wymaga
przepuszczenia każdej ich zmiany przez bramkę 1 — to mechanizm trwały,
nie jednorazowy audyt.

---

## 7. Zakres redakcji transkryptu — decyzja odwrócona 2026-07-20

Do 2026-07-20 transkrypcja w bazie pozostawała w oryginale, a redakcja
obejmowała wyłącznie treści generowane przez AI (uzasadnienie ówczesnej
decyzji zachowane w historii tego dokumentu, wersja 1.1). **Decyzją
produktową z 2026-07-20 redakcja objęła również kanoniczny zapis
transkrypcji** — terapeuta i klient widzą transkrypcję i raport w tej
samej, pseudonimizowanej postaci. Uzasadnienie nowej decyzji:

1. **Jednolita powierzchnia ochrony.** Po zmianie w bazie danych nie
   ma ŻADNEJ trwałej kopii treści sesji z nazwiskami, adresami,
   pracodawcami czy miejscowościami (imiona zostają — §5.2). Incydent
   bezpieczeństwa, żądanie dostępu, kopia zapasowa, eksport DSAR —
   każda ścieżka wyjścia danych operuje wyłącznie na wersji
   zredagowanej. To istotnie silniejsze twierdzenie w DPIA niż
   „redagujemy wyjścia AI, ale źródło leży w oryginale".
2. **Weryfikowalność raportu źródłem zostaje zachowana** — a wręcz
   staje się spójniejsza. Raport i transkrypcja przechodzą przez TEN
   SAM plan redakcji z tej samej sesji: token `[NAZWISKO-1]` w
   raporcie odpowiada `[NAZWISKO-1]` w transkrypcji, a imiona
   (klinicznie nośne) pozostają w obu. Terapeuta konfrontuje każde
   zdanie raportu z zapisem sesji dokładnie tak jak dotąd.
3. **Ryzyko omylności redakcji jest kontrolowane bramkami** (§6):
   0% przecieków na formach bazowych, <5% na odmienionych, testy przy
   każdej zmianie. Fałszywe trafienie (np. nazwa leku wzięta za
   nazwisko) pozostaje ryzykiem — przyjętym świadomie; zapis kliniczny
   pozostaje czytelny, bo zamiana jest tokenem pozycyjnym, nie
   wycięciem treści.
4. **Okno czasowe**: surowa transkrypcja istnieje w bazie (wyłącznie
   zaszyfrowana) od zapisu STT do przebiegu analizy — zwykle minuty.
   Audio znika najpóźniej po 48 h. Sesje przetworzone przed
   2026-07-20 pozostają w oryginale do czasu osobno zatwierdzonej
   migracji historycznej.

Jednym zdaniem dla sprzedaży: **wszystko, co system trwale przechowuje
z treści sesji — transkrypcja, raport, pamięć AI — jest
pseudonimizowane; imiona zostają dla czytelności klinicznej, a
terapeuta zachowuje pełną możliwość weryfikacji raportu zapisem
sesji.**

---

## 8. Ściąga dla sprzedaży: co wolno mówić

**Dozwolone (zgodne ze stanem faktycznym):**

- „Dane kliniczne są przechowywane i przetwarzane w Unii Europejskiej
  (Warszawa/Holandia); transkrypcja mowy odbywa się na europejskich
  endpointach."
- „Ani Google (Vertex AI), ani Deepgram nie używają danych z sesji do
  trenowania swoich modeli — w przypadku Deepgram rezygnacja z programu
  ulepszania modeli jest wymuszona w kodzie i audytowalna."
- „Nagranie audio jest usuwane automatycznie najpóźniej po 48 godzinach."
- „Wszystkie dane szczególnej kategorii są szyfrowane w spoczynku
  (envelope encryption z rotacją kluczy) i w tranzycie."
- „Transkrypcje, raporty, ich tytuły i pamięć długoterminowa AI są
  pseudonimizowane: nazwiska, identyfikatory, adresy, pracodawcy,
  szkoły i miejscowości są zastępowane tokenami; imiona pozostają dla
  czytelności klinicznej." (transkrypcje od 2026-07-20; sesje sprzed
  tej daty — po migracji historycznej)
- „Jakość pseudonimizacji jest kontrolowana automatycznymi bramkami
  testowymi przy każdej zmianie."
- „Aktywacja konta pacjenta wymaga dwóch niezależnych czynników:
  linku e-mail ORAZ kodu przekazanego osobiście przez terapeutę."
- „Nie zbieramy imion ani nazwisk klientów — jedynym identyfikatorem
  konta klienta jest adres e-mail, a kartoteka działa na pseudonimie
  nadanym przez terapeutę." (od 2026-07-18, egzekwowane serwerowo)
- „Usunięcie danych jest zautomatyzowane i nieodwracalne (30 dni od
  usunięcia następuje trwały purge, również z kopii zapasowych przez
  wygaśnięcie kluczy)."
- „Nie przechowujemy danych kart płatniczych" (Stripe, PCI DSS L1).

**ZAKAZANE (niezgodne z prawdą lub ryzykowne prawnie):**

- ~~„Dane są anonimizowane"~~ — NIE; to pseudonimizacja (art. 4 pkt 5
  RODO), dane pozostają danymi osobowymi.
- ~~„Gwarantujemy 100% usunięcia danych osobowych z raportów"~~ — NIE;
  wykrywanie nazw własnych jest best-effort (progi jakości: 0%
  przecieków na formach bazowych, <5% na odmienionych).
- ~~„Żadne dane nie opuszczają EOG"~~ — NIE bez zastrzeżenia; dotyczy
  danych klinicznych pacjentów; dane terapeutów dotykają Stripe/Resend/
  FCM (USA, na podstawie DPF/SCC), treść sesji — nigdy.
- ~~„AI nie widzi danych wrażliwych"~~ — NIE; model musi przeczytać
  transkrypt (w tym w call-1 oryginał, żeby wykryć PII); prawdziwe
  twierdzenie brzmi: model generujący raport pracuje na tekście już
  pseudonimizowanym, a podprocesorzy nie trenują na naszych danych.
- Obiecywanie zgodności z konkretnymi regulacjami sektorowymi (np.
  wymogi dokumentacji medycznej) bez konsultacji z działem prawnym.

---

## 9. Delty do naniesienia w dokumentach compliance (dla prawników)

Stan na 2026-07-18 — poniższe zmiany produktowe z 2026-07-17 nie są
jeszcze odzwierciedlone w RCP (dok. 02) i DPIA (dok. 03):

1. **Nowy podprocesor STT: Deepgram** (domyślny dostawca transkrypcji;
   Chirp 3 pozostaje fallbackiem). Do RCP część C dopisać: Deepgram,
   Inc. — usługa Speech-to-Text Nova-3, endpoint `api.eu.deepgram.com`
   (hosting AWS UE), przetwarzanie synchroniczne bez trwałej kopii,
   `mip_opt_out=true`. Zaktualizować B-1 (sub-procesorzy, środki).
   **⚠ Warunek: podpisanie DPA z Deepgram pod dane szczególnej
   kategorii + pisemne potwierdzenie rezydencji EU i semantyki
   retencji przy `mip_opt_out` — w toku (docs/39 Faza 0). Do czasu
   podpisania status prawny podpowierzenia wymaga opinii radcy.**
2. **Pseudonimizacja raportów** (docs/41): dopisać do DPIA jako
   dodatkowy środek minimalizacji (B-2/B-3: raporty, Title/Summary
   i RAG przechowywane w wersji pseudonimizowanej; opis warstw §5).
3. **Kod parowania zaproszeń pacjenta** (docs/42): dopisać do środków
   organizacyjno-technicznych (część D RCP) — dwuskładnikowa
   aktywacja, hash-only, blokada po 5 próbach, revoke, TTL 72 h,
   zdarzenia audytowe.
4. **Zmiana pola kartoteki na „Pseudonim"** — wzmocnienie minimalizacji
   u źródła; warto odnotować w DPIA.
5. Decyzja świadoma do odnotowania w DPIA: transkrypt kanoniczny
   pozostaje niepseudonimizowany dla terapeuty-administratora —
   uzasadnienie w §7 niniejszego dokumentu.
6. **Inwariant „jedyny identyfikator klienta = e-mail"** (docs/43 §4,
   wdrożony 2026-07-18): zawęzić w RCP B-3 kategorie danych klienta —
   system NIE przechowuje imion i nazwisk klientów (pola istnieją
   tylko na wire dla zgodności wstecznej i są ignorowane); e-mail
   klienta wyłącznie w domenie tożsamości (zaproszenia z TTL +
   users.email po aktywacji), usunięty z kartoteki klinicznej
   (migracja 000077); adres wysyłki materiałów utrwalany wyłącznie
   zamaskowany; dziennik audytowy bez pseudonimu kartoteki. Do DPIA:
   istotna redukcja powierzchni danych identyfikujących klienta.
   Otwarte: czyszczenie danych zastanych (imiona wpisane przed
   inwariantem) — decyzja operacyjna do podjęcia.

---

## 10. Dokumenty źródłowe

| Dokument | Zakres |
|---|---|
| `docs/compliance/01_POLITYKA_RETENCJI_DANYCH.md` | okresy retencji, GDPR Purger, OLM |
| `docs/compliance/02_REJESTR_CZYNNOSCI_PRZETWARZANIA.md` | RCP art. 30, lista podprocesorów |
| `docs/compliance/03_DPIA_OCENA_SKUTKOW.md` | ocena skutków dla ochrony danych |
| `docs/39_DEEPGRAM_STT_MIGRATION.md` | migracja STT, inwarianty EU/mip_opt_out, Faza 0 (DPA) |
| `docs/41_PSEUDONIMIZACJA_RAPORTOW.md` | pełny design pseudonimizacji, taksonomia tokenów |
| `docs/42_AUTORYZACJA_ZAPROSZEN_KLIENTA.md` | kod parowania, revoke, model zagrożenia |

---

## Zatwierdzenie

| Rola | Imię i nazwisko | Data | Podpis |
|---|---|---|---|
| Zarząd Euphire sp. z o.o. | _______________ | _______________ | _______________ |
| Radca prawny / IOD | _______________ | _______________ | _______________ |
