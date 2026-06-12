## Wstęp

### Cel i Zakres Polityki
Niniejsza Polityka Prywatności („Polityka") określa zasady przetwarzania danych osobowych Użytkowników Profesjonalnych oraz Pacjentów w związku z korzystaniem z aplikacji mobilnej i/lub webowej Superwizor AI („Aplikacja"), świadczonej przez Euphire sp. z o.o. („Usługodawca", „My").

Celem Polityki jest zapewnienie transparentności oraz realizacja obowiązków informacyjnych wynikających z art. 13 i 14 Rozporządzenia Parlamentu Europejskiego i Rady (UE) 2016/679 z dnia 27 kwietnia 2016 r. („RODO"). Usługodawca jest zaangażowany w ochronę prywatności wszystkich osób, których dane przetwarza, oraz w zapewnienie zgodności swoich działań z przepisami RODO.

### Definicje Kluczowych Terminów
Dla celów niniejszej Polityki, poniższe terminy mają następujące znaczenie:
* **Aplikacja:** Oprogramowanie Superwizor AI w wersji mobilnej (iOS, Android) i/lub webowej, służące jako narzędzie wspierające Użytkowników Profesjonalnych w analizie sesji terapeutycznych i coachingowych.
* **Usługodawca:** Euphire sp. z o.o. z siedzibą w ul. Odrzańska 10a/48, Kraków, zarejestrowana pod numerem KRS 0000907254, NIP 6793219020.
* **Użytkownik Profesjonalny (Profesjonalista):** Psychoanalityk, psycholog, psychiatra, terapeuta, coach, praktyka grupowa lub inna organizacja świadcząca usługi w zakresie zdrowia psychicznego lub rozwoju osobistego.
* **Pacjent:** Osoba fizyczna, której dane osobowe są przetwarzane przez Użytkownika Profesjonalnego w związku ze świadczonymi przez niego usługami, przy użyciu Aplikacji. Postanowienia dotyczące Pacjentów stosuje się odpowiednio do innych osób uczestniczących w sesji (np. partnera w terapii par, członków rodziny).
* **Dane Osobowe:** Wszelkie informacje o zidentyfikowanej lub możliwej do zidentyfikowania osobie fizycznej.
* **Dane Dotyczące Zdrowia:** Dane osobowe o zdrowiu fizycznym lub psychicznym ujawniające informacje o stanie zdrowia (Art. 4 pkt 15 RODO).
* **Transkrypcja:** Automatyczny zapis tekstowy nagrania audio, generowany przez technologię rozpoznawania mowy.
* **Raport z Sesji:** Ustrukturyzowany dokument generowany automatycznie przez sztuczną inteligencję na podstawie transkrypcji sesji.
* **HiTOP:** Hierarchiczna Taksonomia Psychopatologii — system wymiarowej oceny objawów psychopatologicznych, którego pomiary generuje Aplikacja na podstawie transkrypcji.
* **Przetwarzanie:** Operacja lub zestaw operacji wykonywanych na danych osobowych.
* **Administrator:** Podmiot, który samodzielnie lub wspólnie z innymi ustala cele i sposoby przetwarzania danych osobowych.
* **Podmiot Przetwarzający (Procesor):** Podmiot, który przetwarza dane osobowe w imieniu administratora.
* **Szyfrowanie Kopertowe (Envelope Encryption):** Technika szyfrowania, w której dane są szyfrowane unikalnym kluczem danych (DEK), a sam DEK jest szyfrowany kluczem głównym (KEK) zarządzanym przez Cloud KMS. Zapewnia podwójną warstwę ochrony.

## Część I: Informacje dla Użytkowników Profesjonalnych

### 1. Administrator Danych Osobowych Użytkowników Profesjonalnych

Administratorem danych osobowych Użytkowników Profesjonalnych, w zakresie danych podawanych podczas procesu rejestracji, zarządzania kontem, dokonywania płatności i korzystania z Aplikacji, jest:
**Euphire sp. z o.o.**
ul. Odrzańska 10a/48, Kraków
KRS: 0000907254, NIP: 6793219020

We wszelkich sprawach dotyczących przetwarzania Państwa danych, w tym w sprawach ochrony danych osobowych, prosimy o kontakt:
* Adres e-mail: kontakt@superwizor.ai

### 2. Cele, Podstawy Prawne i Okres Przetwarzania

Przetwarzamy następujące kategorie danych Użytkowników Profesjonalnych:
* **Dane identyfikacyjne i kontaktowe** (imię, nazwisko, adres e-mail, numer telefonu — jeśli został podany).
* **Dane rejestracyjne** (identyfikator konta Firebase, hash hasła — w przypadku rejestracji e-mail/hasło).
* **Dane uwierzytelniające** (tokeny uwierzytelniające dostawców tożsamości — Google, Apple — w przypadku logowania społecznościowego).
* **Dane profilowe** (zdjęcie profilowe, tytuł zawodowy, wybrana modalność terapeutyczna, strefa czasowa, preferencje językowe interfejsu, preferencje stylu raportów).
* **Dane płatnicze** (informacje związane z obsługą subskrypcji przetwarzane przez Stripe; Usługodawca nie przechowuje pełnych danych kart płatniczych).
* **Dane o korzystaniu z Aplikacji** (logi systemowe, adresy IP, typ i wersja urządzenia, wersja systemu operacyjnego, wersja Aplikacji, zdarzenia diagnostyczne i analityczne rejestrowane we własnej infrastrukturze Usługodawcy — nie korzystamy z zewnętrznych narzędzi analitycznych).

**Cele Przetwarzania:**
1. **Wykonanie umowy o świadczenie usług Aplikacji** (Art. 6 ust. 1 lit. b RODO) — do upływu terminu przedawnienia roszczeń.
2. **Obsługa płatności i rozliczenia** (Art. 6 ust. 1 lit. b i c RODO) — przez okres wymagany przepisami podatkowymi (5 lat od końca roku podatkowego).
3. **Wsparcie techniczne i obsługa reklamacji** (Art. 6 ust. 1 lit. f RODO) — do czasu rozwiązania zgłoszenia.
4. **Zapewnienie bezpieczeństwa i zapobieganie nadużyciom** (Art. 6 ust. 1 lit. f RODO) — logi systemowe są przechowywane co do zasady przez 30 dni, a zdarzenia analityczne przez 90 dni.
5. **Personalizacja usług** (Art. 6 ust. 1 lit. b RODO) — dostosowanie stylu raportów, języka interfejsu i modalności terapeutycznej do preferencji Użytkownika — przez czas trwania Umowy.
6. **Komunikacja związana z cyklem życia usługi** (Art. 6 ust. 1 lit. b i f RODO) — wiadomości e-mail niezbędne do wykonania Umowy lub informujące o jej stanie (np. powitanie, weryfikacja adresu, ostrzeżenie o wyczerpaniu limitu, przypomnienie o odnowieniu subskrypcji) — przez czas trwania Umowy.
7. **Marketing bezpośredni własnych usług drogą elektroniczną** (Art. 6 ust. 1 lit. a RODO w zw. z art. 398 ustawy z dnia 12 lipca 2024 r. — Prawo komunikacji elektronicznej) — wyłącznie po wyrażeniu odrębnej, dobrowolnej zgody (np. podczas rejestracji); zgodę można wycofać w każdej chwili, bez wpływu na zgodność z prawem przetwarzania dokonanego przed jej wycofaniem. Każda wiadomość marketingowa zawiera możliwość rezygnacji.

### 3. Rola Usługodawcy w Przetwarzaniu Danych Pacjentów

W odniesieniu do danych osobowych Pacjentów, Użytkownik Profesjonalny jest Administratorem Danych Osobowych. Usługodawca jest wyłącznie Podmiotem Przetwarzającym (Procesorem) przetwarzającym dane na udokumentowane polecenie Administratora w ramach zawartej Umowy Powierzenia Przetwarzania Danych (DPA).

Usługodawca przetwarza dane Pacjentów wyłącznie w celu świadczenia Usług na rzecz Użytkownika Profesjonalnego, tj. transkrypcji nagrań, generowania Raportów z Sesji, pomiarów HiTOP oraz budowania pamięci kontekstowej. Usługodawca nie wykorzystuje danych Pacjentów do żadnych własnych celów, w tym marketingowych, badawczych ani do trenowania modeli sztucznej inteligencji.

### 4. Obowiązki Użytkownika Profesjonalnego jako Administratora

Jako Administratorzy, ponoszą Państwo pełną odpowiedzialność za zgodność przetwarzania z przepisami, w tym za:
* Zapewnienie odpowiedniej podstawy prawnej (np. Art. 9 ust. 2 lit. h lub lit. a RODO).
* Spełnienie obowiązku informacyjnego (Art. 13 RODO) — w szczególności poinformowanie Pacjenta oraz wszystkich innych osób uczestniczących w sesji o fakcie nagrywania sesji i korzystaniu z Aplikacji.
* Realizację praw Pacjentów (dostęp, sprostowanie, usunięcie, przenoszenie danych, sprzeciw).
* Zapewnienie bezpieczeństwa danych po swojej stronie.

### 5. Środki Techniczne i Organizacyjne

Usługodawca stosuje zaawansowane środki bezpieczeństwa odpowiadające wysokiemu ryzyku związanemu z przetwarzaniem danych szczególnych kategorii (dane dotyczące zdrowia):

**Rezydencja danych i kontrola regionu:**
* Infrastruktura przetwarzająca dane sesji (nagrania, transkrypcje, raporty, pamięć kontekstowa) jest zlokalizowana w regionie **europe-central2 (Warszawa, Polska)** platformy Google Cloud Platform. Lokalizacja zasobów jest określona w konfiguracji infrastruktury zarządzanej jako kod (Infrastructure as Code) i podlega kontroli wersji oraz przeglądom.
* Jedynym wyjątkiem jest usługa Vertex AI (służąca do generowania raportów i embeddings), zlokalizowana w regionie **europe-west4 (Holandia)** — nadal w obrębie Europejskiego Obszaru Gospodarczego (EOG). Usługa Speech-to-Text korzysta z dedykowanego endpointu europejskiego (`eu-speech.googleapis.com`).

**Szyfrowanie danych w spoczynku:**
* **CMEK (Customer-Managed Encryption Keys):** Kluczowe usługi infrastrukturalne (Cloud Storage, Cloud SQL, Secret Manager) korzystają z kluczy szyfrowania zarządzanych przez Usługodawcę w Cloud KMS (keyring `superwizor-keyring`), z automatyczną rotacją co 90 dni.
* **Szyfrowanie kopertowe (Envelope Encryption):** Wszystkie dane szczególnych kategorii (transkrypcje, raporty z sesji, pomiary HiTOP, pamięć kontekstowa RAG) są szyfrowane na poziomie aplikacji z użyciem algorytmu AEAD. Każdy rekord posiada unikalny klucz danych (DEK), który jest szyfrowany kluczem głównym (KEK) zarządzanym w Cloud KMS. Oznacza to, że nawet w przypadku uzyskania dostępu do bazy danych, dane pozostają nieczytelne bez dostępu do Cloud KMS.

**Szyfrowanie danych w tranzycie:**
* Wszystkie połączenia wykorzystują protokół TLS/SSL.
* Komunikacja między serwisami odbywa się przez gRPC (HTTP/2) z szyfrowaniem.

**Izolacja sieciowa:**
* Dostęp do bazy danych (Cloud SQL PostgreSQL) odbywa się kanałami szyfrowanymi, z usług działających w prywatnej sieci VPC (przez VPC Connector); bezpośredni dostęp sieciowy jest ograniczony do ściśle zdefiniowanej, kontrolowanej listy autoryzowanych adresów wykorzystywanych do administracji.

**Kontrola dostępu:**
* Każdy mikroserwis posiada dedykowane konto usługowe (Service Account) z minimalnymi uprawnieniami (zasada najmniejszych przywilejów, Zero Trust).
* Procesy CI/CD uwierzytelniają się przez Workload Identity Federation (bez długoterminowych kluczy dostępowych).
* Uwierzytelnianie Użytkowników odbywa się przez Firebase Authentication (obsługiwane metody: e-mail/hasło, Google Sign-In, Apple Sign-In).

**Cykl życia nagrań audio:**
* Nagrania audio są usuwane z Cloud Storage natychmiast po pomyślnym zakończeniu transkrypcji.
* Niezależnie od wyniku przetwarzania, każde nagranie podlega automatycznemu, trwałemu usunięciu przez mechanizm Object Lifecycle Management (OLM) skonfigurowany na poziomie zasobnika GCS, uruchamiany po upływie 48 godzin od przesłania. Po wykonaniu usunięcia odtworzenie nagrania nie jest możliwe.

**Usuwanie danych i audyt:**
* Dane Użytkowników i Pacjentów są usuwane mechanizmem soft delete (oznaczanie `deleted_at`), co zapewnia ścieżkę audytową wymaganą przez RODO.
* Trwałe, nieodwracalne usunięcie z bazy danych następuje po upływie 30 dni od oznaczenia, w ramach cyklicznego procesu trwałego usuwania danych; każde uruchomienie procesu jest odnotowywane w rejestrze zdarzeń audytowych.
* Każda istotna operacja na danych jest rejestrowana w tabeli zdarzeń audytowych.

**Monitorowanie i testy:**
* Ciągłe monitorowanie logów i metryk za pośrednictwem Google Cloud Logging i Cloud Monitoring.
* Regularne przeglądy bezpieczeństwa infrastruktury i kodu.

### 6. Odbiorcy Danych, Transfer Danych i Sub-procesorzy

W ramach świadczenia usług korzystamy z następujących zaufanych dostawców (odbiorców danych):

| Dostawca | Usługa | Przetwarzane dane | Lokalizacja / podstawa transferu |
|---|---|---|---|
| **Google Cloud Platform** (Google Cloud EMEA Ltd / Google LLC) | Cloud Run, Cloud SQL PostgreSQL, Cloud Storage, Cloud KMS, Pub/Sub, Secret Manager | Przetwarzanie backendowe i przechowywanie danych | europe-central2 (Warszawa, Polska) |
| **Google Cloud — Vertex AI** | Speech-to-Text (Chirp 3), Gemini (generowanie raportów), Text Embeddings (pamięć RAG) | Transkrypcja audio, generowanie raportów z sesji, embeddingi pamięci | europe-west4 (Holandia) dla Vertex AI; eu-speech.googleapis.com dla STT |
| **Google Firebase** | Authentication, Cloud Firestore (wyłącznie synchronizacja statusów — nie jest źródłem prawdy), Cloud Storage (zdjęcia profilowe), FCM (powiadomienia push) | Tokeny uwierzytelniające, lustrzane statusy sesji (bez treści sesji), zdjęcia profilowe, tokeny push | Firestore i Storage: europe-central2. Authentication i FCM są usługami globalnymi Google — dane uwierzytelniające i tokeny push mogą być przetwarzane poza EOG; Google LLC posiada certyfikację EU-US Data Privacy Framework (DPF) |
| **Stripe** (Stripe Payments Europe, Ltd. — Irlandia; Stripe, Inc. — USA) | Przetwarzanie płatności, zarządzanie subskrypcjami | Dane płatnicze, dane do faktur | UE (Irlandia); transfer do Stripe, Inc. (USA) na podstawie EU-US DPF oraz standardowych klauzul umownych (certyfikat PCI DSS Level 1) |
| **Resend, Inc.** (USA) | Wysyłka transakcyjnych wiadomości e-mail (powitanie, weryfikacja, powiadomienia o subskrypcji) oraz — za zgodą — wiadomości marketingowych | Adres e-mail, imię, treść wiadomości systemowych | USA; transfer na podstawie standardowych klauzul umownych (art. 46 ust. 2 lit. c RODO) |

**Dane sesji Pacjentów (nagrania audio, transkrypcje, raporty z sesji, pomiary HiTOP, pamięć kontekstowa) są przetwarzane i przechowywane wyłącznie w obrębie Europejskiego Obszaru Gospodarczego (EOG)** — w regionach europe-central2 (Warszawa) i europe-west4 (Holandia) — i nie są przekazywane do państw trzecich.

W odniesieniu do wybranych danych Użytkowników Profesjonalnych (dane płatnicze, adres e-mail na potrzeby wysyłki wiadomości, dane uwierzytelniające, tokeny push) może dochodzić do przekazania danych do USA — wyłącznie do podmiotów zapewniających odpowiednie zabezpieczenia, o których mowa w rozdziale V RODO (decyzja wykonawcza Komisji w sprawie EU-US Data Privacy Framework lub standardowe klauzule umowne). Kopię stosownych zabezpieczeń można uzyskać kontaktując się z nami.

Wszyscy dostawcy podlegają umowom powierzenia przetwarzania danych. Google Cloud Platform posiada certyfikaty ISO 27001, ISO 27017, ISO 27018, SOC 1/2/3.

Użytkownik zostanie poinformowany o każdej zamierzonej zmianie dotyczącej dodania lub zastąpienia Sub-procesora przetwarzającego dane Pacjentów z co najmniej 14-dniowym wyprzedzeniem, zgodnie z warunkami DPA.

### 7. Prawa Użytkownika Profesjonalnego

Przysługują Państwu następujące prawa:
* Prawo dostępu do danych (Art. 15 RODO).
* Prawo do sprostowania danych (Art. 16 RODO).
* Prawo do usunięcia danych — „prawo do bycia zapomnianym" (Art. 17 RODO).
* Prawo do ograniczenia przetwarzania (Art. 18 RODO).
* Prawo do przenoszenia danych (Art. 20 RODO).
* Prawo do sprzeciwu — w szczególności wobec przetwarzania opartego na prawnie uzasadnionym interesie (Art. 21 RODO).
* Prawo do wycofania zgody w dowolnym momencie — w zakresie, w jakim przetwarzanie odbywa się na podstawie zgody (Art. 7 ust. 3 RODO); wycofanie zgody nie wpływa na zgodność z prawem przetwarzania dokonanego przed jej wycofaniem.
* Prawo do wniesienia skargi do organu nadzorczego (Prezes Urzędu Ochrony Danych Osobowych, ul. Stawki 2, 00-193 Warszawa).

Aby skorzystać ze swoich praw, prosimy o kontakt na adres: kontakt@superwizor.ai.

## Część II: Informacje dla Pacjentów

### 1. Kto jest Odpowiedzialny za Twoje Dane?
Administratorem Twoich danych w ramach sesji terapeutycznych lub coachingowych jest Twój terapeuta/coach/lekarz. To on decyduje, jakie dane są zbierane, w jakim celu korzysta z Aplikacji Superwizor AI i odpowiada za poinformowanie Cię o nagrywaniu sesji.

### 2. Kto Przetwarza Twoje Dane?
Firma Euphire sp. z o.o. (Dostawca Aplikacji) przetwarza Twoje dane wyłącznie jako Podmiot Przetwarzający — w imieniu i na polecenie Twojego terapeuty/coacha/lekarza. Nie wykorzystujemy Twoich danych do żadnych własnych celów, w tym do trenowania modeli sztucznej inteligencji.

### 3. Jakie Dane są Przetwarzane i W Jaki Sposób?
W ramach korzystania z Aplikacji przez Twojego terapeutę, przetwarzane są następujące dane:
1. **Nagranie audio** Twojej sesji — jest przesyłane na zaszyfrowane serwery w Unii Europejskiej (Warszawa), usuwane natychmiast po wykonaniu transkrypcji, a najpóźniej — niezależnie od wyniku przetwarzania — w ramach automatycznego mechanizmu czyszczenia uruchamianego po upływie 48 godzin od przesłania. Po usunięciu odtworzenie nagrania nie jest możliwe.
2. **Transkrypcja** (zapis tekstowy rozmowy) — jest generowana automatycznie przez technologię rozpoznawania mowy. Mówcy w transkrypcji są oznaczani etykietami opisującymi rolę w rozmowie (np. „Terapeuta", „Pacjent", a w sesjach coachingowych „Trener", „Klient") lub neutralnymi etykietami (np. „Osoba 1"), gdy roli nie można ustalić — bez używania imion i nazwisk. Etykiety te są przypisywane automatycznie i mogą zostać skorygowane przez Twojego terapeutę. Transkrypcja jest szyfrowana i przechowywana w zaszyfrowanej formie.
3. **Raport z sesji** — jest generowany automatycznie przez sztuczną inteligencję na podstawie transkrypcji. Zawiera analizę sesji i pomiary wymiarowe. Jest dostępny wyłącznie dla Twojego terapeuty w trybie tylko do odczytu (nie może go edytować w Aplikacji). Raport jest szyfrowany. Raport ma charakter pomocniczy — nie stanowi diagnozy, a jego ostateczna interpretacja należy do Twojego terapeuty.
4. **Pamięć kontekstowa** — krótkie podsumowanie sesji oraz powiązane wątki tematyczne, pozbawione bezpośrednich danych identyfikujących (bez imion, nazwisk, nazw miejsc — pseudonimizowane), mogą być zachowane w zaszyfrowanej formie, aby pomóc Twojemu terapeucie zachować ciągłość opieki pomiędzy sesjami.

Twoje dane są dostępne wyłącznie dla Twojego terapeuty — żaden inny Użytkownik Aplikacji nie ma do nich dostępu.

### 4. Bezpieczeństwo Twoich Danych
Twoje dane są chronione zaawansowanymi technologiami szyfrowania:
* Nagrania, transkrypcje i raporty są szyfrowane zarówno podczas przesyłania (TLS/SSL), jak i przechowywania (szyfrowanie kopertowe z kluczami zarządzanymi w Google Cloud KMS).
* Nagrania audio są usuwane natychmiast po transkrypcji, najpóźniej w ramach automatycznego mechanizmu uruchamianego po 48 godzinach.
* Dane Twoich sesji przechowywane są wyłącznie na serwerach zlokalizowanych w Europejskim Obszarze Gospodarczym (Warszawa, Polska; analiza AI — Holandia).
* Usunięcie konta przez Twojego terapeutę skutkuje kaskadowym usunięciem wszystkich powiązanych danych Pacjentów (trwałe usunięcie następuje po upływie 30-dniowego okresu ochronnego).

### 5. Twoje Prawa
Masz prawo do dostępu, sprostowania, usunięcia, ograniczenia przetwarzania oraz przenoszenia swoich danych. Aby skorzystać ze swoich praw, skontaktuj się ze swoim terapeutą/coachem/lekarzem, który jest Administratorem Twoich danych i jest bezpośrednio odpowiedzialny za realizację Twoich praw.

Masz również prawo do wniesienia skargi do organu nadzorczego — Prezesa Urzędu Ochrony Danych Osobowych (ul. Stawki 2, 00-193 Warszawa).

## Część III: Serwis Internetowy superwizor.ai

Niniejsza część dotyczy osób odwiedzających serwis internetowy dostępny pod adresem superwizor.ai („Serwis"), niezależnie od tego, czy korzystają z Aplikacji. Administratorem danych osobowych osób odwiedzających Serwis jest Euphire sp. z o.o. (dane kontaktowe — Część I, pkt 1).

### 1. Formularz Kontaktowy
Korzystając z formularza kontaktowego, podają Państwo: imię, adres e-mail, temat oraz treść wiadomości. Dane te przetwarzamy w celu obsługi Państwa zapytania (Art. 6 ust. 1 lit. f RODO — prawnie uzasadniony interes polegający na komunikacji z osobami zainteresowanymi), przez okres niezbędny do załatwienia sprawy, a następnie przez okres przedawnienia ewentualnych roszczeń. Wiadomości są dostarczane na naszą skrzynkę e-mail za pośrednictwem naszej infrastruktury powiadomień.

### 2. Rejestracja Konta
Formularze rejestracyjne w Serwisie (rejestracja terapeuty lub organizacji) zbierają dane opisane w Części I niniejszej Polityki (m.in. imię, nazwisko, adres e-mail, numer telefonu, tytuł zawodowy, a dla organizacji — dane rejestrowe i adresowe firmy, w tym NIP). Dane te są przekazywane bezpośrednio do naszego systemu (identity-svc) i przetwarzane na zasadach opisanych w Części I.

### 3. Płatności (Stripe Checkout)
Proces zakupu subskrypcji odbywa się na stronach płatności Stripe. W ramach procesu płatności Stripe zbiera — jako podmiot przetwarzający, a w zakresie wymaganym przepisami o usługach płatniczych jako odrębny administrator — dane takie jak: adres e-mail, numer telefonu, dane karty płatniczej, adres rozliczeniowy oraz NIP (na potrzeby faktur B2B i automatycznego rozliczenia VAT). Szczegóły — Część I, pkt 6 oraz polityka prywatności Stripe.

### 4. Materiały Informacyjne (Lead Magnet)
W Serwisie udostępniamy materiały informacyjne (np. stronę dla pacjentów), z których pobranie lub zapis może odbywać się przez formularz obsługiwany przez zewnętrznego dostawcę **Tally** (Tally Forms — dostawca z siedzibą w Belgii, EOG), działającego jako nasz podmiot przetwarzający. Zakres danych obejmuje dane podane w formularzu (np. adres e-mail). Dane te przetwarzamy w celu dostarczenia zamówionego materiału (Art. 6 ust. 1 lit. b RODO), a do celów dalszej komunikacji marketingowej — wyłącznie za odrębną zgodą (Art. 6 ust. 1 lit. a RODO), którą można wycofać w każdej chwili.

### 5. Logi Serwera
Podczas przeglądania Serwisu infrastruktura hostingowa automatycznie rejestruje standardowe dane techniczne: adres IP, datę i godzinę żądania, adres URL, identyfikator przeglądarki (user agent). Dane te przetwarzamy w celu zapewnienia bezpieczeństwa i prawidłowego działania Serwisu (Art. 6 ust. 1 lit. f RODO) i przechowujemy przez ograniczony okres (co do zasady do 30 dni).

### 6. Pliki Cookies i Podobne Technologie
Serwis **nie korzysta z narzędzi analitycznych ani marketingowych** (brak Google Analytics, pikseli reklamowych itp.) i nie wyświetla reklam. Wykorzystywane są wyłącznie technologie niezbędne do działania Serwisu:
* zapamiętanie wybranej wersji językowej (PL/EN),
* pliki cookies niezbędne do realizacji płatności, ustawiane przez Stripe wyłącznie na stronach procesu płatności (m.in. w celu zapobiegania oszustwom — zgodnie z polityką cookies Stripe).

Technologie te są niezbędne do świadczenia usług żądanych przez użytkownika i jako takie nie wymagają odrębnej zgody (art. 173 ust. 3 pkt 2 ustawy — Prawo telekomunikacyjne / odpowiednie przepisy Prawa komunikacji elektronicznej). Jeżeli w przyszłości wdrożymy narzędzia analityczne lub marketingowe, zaktualizujemy niniejszą Politykę i — tam, gdzie to wymagane — poprosimy o zgodę.

### 7. Prawa Osób Odwiedzających Serwis
Osobom odwiedzającym Serwis przysługują prawa opisane w Części I, pkt 7 (dostęp, sprostowanie, usunięcie, ograniczenie, przenoszenie, sprzeciw, wycofanie zgody, skarga do Prezesa UODO). Kontakt: kontakt@superwizor.ai.

## Postanowienia Końcowe

Usługodawca zastrzega sobie prawo do zmian w niniejszej Polityce w związku z ewolucją prawa, technologii lub zakresu świadczonych usług. O każdej istotnej zmianie Użytkownicy Profesjonalni zostaną poinformowani z co najmniej 14-dniowym wyprzedzeniem.

Aktualna wersja Polityki jest zawsze dostępna w sekcji „Informacje prawne" w ustawieniach Aplikacji oraz w Serwisie pod adresem superwizor.ai/legal/privacy.
