Niniejsza Umowa Powierzenia Przetwarzania Danych Osobowych („**DPA**" lub „**Umowa**") zostaje zawarta pomiędzy: 

**Użytkownikiem Profesjonalnym**, który zaakceptował Regulamin Świadczenia Usług aplikacji Superwizor AI, działającym jako: **Administrator Danych Osobowych** (zwany dalej „**Administratorem**") 

a 

**Euphire sp. z o.o.** z siedzibą przy ul. Odrzańskiej 10a/48 w Krakowie, wpisaną do rejestru przedsiębiorców Krajowego Rejestru Sądowego pod numerem KRS 0000907254, posiadającą NIP: 6793219020, działającą jako: **Podmiot Przetwarzający** (zwany dalej „**Podmiotem Przetwarzającym**" lub „**Usługodawcą**") 

zwani dalej łącznie „**Stronami**".

---

## PREAMBUŁA

*   **ZWAŻYWSZY, ŻE** Administrator zawarł z Podmiotem Przetwarzającym umowę o świadczenie usług drogą elektroniczną poprzez akceptację Regulaminu Świadczenia Usług aplikacji Superwizor AI (dalej jako „Regulamin" lub „Umowa Główna"), dostępnego w sekcji „Informacje prawne" w ustawieniach Aplikacji; 
*   **ZWAŻYWSZY, ŻE** w ramach świadczenia usług określonych w Umowie Głównej, Administrator powierza Podmiotowi Przetwarzającemu do przetwarzania dane osobowe swoich Pacjentów oraz innych osób uczestniczących w sesjach, w tym dane szczególnych kategorii (dane dotyczące zdrowia); 
*   **ZWAŻYWSZY, ŻE** niniejsza DPA stanowi wypełnienie obowiązku prawnego określonego w art. 28 ust. 3 Rozporządzenia Parlamentu Europejskiego i Rady (UE) 2016/679 z dnia 27 kwietnia 2016 r. („RODO"); 
*   **ZWAŻYWSZY, ŻE** niniejsza DPA stanowi integralną część Umowy Głównej. 

> Akceptacja Regulaminu poprzez zaznaczenie odpowiedniego pola wyboru (checkbox) podczas rejestracji w Aplikacji jest równoznaczna z akceptacją i zawarciem niniejszej DPA w formie elektronicznej (udokumentowanej), zgodnie z art. 28 ust. 9 RODO. 

Strony postanawiają, co następuje:

---

## § 1. DEFINICJE

1.  Terminy pisane wielką literą, niezdefiniowane w niniejszej DPA, mają znaczenie nadane im w Regulaminie. 
2.  **Polityka Prywatności** – dokument określający zasady przetwarzania danych przez Usługodawcę, dostępny w sekcji „Informacje prawne" w ustawieniach Aplikacji. 
3.  **Dane Osobowe** – wszelkie dane osobowe Pacjentów Administratora oraz innych osób uczestniczących w sesjach (np. partnerów w terapii par, członków rodziny), w tym dane osobowe szczególnych kategorii (dane dotyczące zdrowia fizycznego i psychicznego), przetwarzane przez Podmiot Przetwarzający w imieniu Administratora w związku z wykonywaniem Umowy Głównej. 
4.  **Naruszenie Ochrony Danych Osobowych** – naruszenie bezpieczeństwa prowadzące do przypadkowego lub niezgodnego z prawem zniszczenia, utracenia, zmodyfikowania, nieuprawnionego ujawnienia lub nieuprawnionego dostępu do Danych Osobowych. 
5.  **Państwo Trzecie** – państwo nienależące do Europejskiego Obszaru Gospodarczego (EOG).

---

## § 2. PRZEDMIOT, ZAKRES I CEL PRZETWARZANIA

1.  Administrator powierza Podmiotowi Przetwarzającemu Dane Osobowe do przetwarzania na zasadach i w celu określonym w niniejszej Umowie. 
2.  **Przedmiot przetwarzania:** Realizacja usług świadczonych przez Podmiot Przetwarzający na podstawie Umowy Głównej, polegających na przetwarzaniu nagrań audio sesji terapeutycznych i coachingowych, ich transkrypcji, analizie z wykorzystaniem sztucznej inteligencji oraz generowaniu raportów z sesji. 
3.  **Charakter i cel przetwarzania:** Wykonywanie operacji na Danych Osobowych niezbędnych do świadczenia na rzecz Administratora usług Aplikacji, zgodnie z funkcjonalnościami opisanymi w § 4 Regulaminu, w szczególności: 
    *   Przechowywanie nagrań audio (tymczasowo — nagranie jest usuwane natychmiast po pomyślnej transkrypcji, a najpóźniej w ramach automatycznego mechanizmu czyszczenia uruchamianego po upływie 48 godzin od przesłania).
    *   Automatyczna transkrypcja nagrań audio z wykorzystaniem technologii Speech-to-Text (Chirp 3).
    *   Diaryzacja (identyfikacja i rozróżnienie mówców) wraz z automatycznym przypisaniem etykiet opisujących rolę mówcy w rozmowie (np. „Terapeuta", „Pacjent", w sesjach coachingowych „Trener", „Klient") albo etykiet neutralnych (np. „Osoba 1"), gdy rola nie może zostać ustalona; etykiety nie zawierają imion ani nazwisk i mogą być korygowane przez Administratora.
    *   Generowanie ustrukturyzowanych raportów z sesji z wykorzystaniem sztucznej inteligencji (Vertex AI / Gemini).
    *   Generowanie pomiarów wymiarowych HiTOP.
    *   Tworzenie i przechowywanie zaszyfrowanej pamięci kontekstowej (RAG) — pseudonimizowanych (pozbawionych bezpośrednich identyfikatorów) podsumowań sesji oraz powiązanych wątków tematycznych, służących zapewnieniu ciągłości terapeutycznej.
    *   Generowanie embeddings (reprezentacji wektorowych) na potrzeby pamięci kontekstowej.
    *   Przechowywanie zaszyfrowanych transkrypcji i raportów jako Materiałów Użytkownika.
4.  **Rodzaj Danych Osobowych:** Dane określone w Części II Polityki Prywatności („Informacje dla Pacjentów"), w szczególności: 
    *   Dane identyfikacyjne i kontaktowe, w zakresie w jakim pojawią się w nagraniu lub transkrypcji. 
    *   Dane Osobowe szczególnych kategorii, tj. dane dotyczące zdrowia fizycznego lub psychicznego Pacjentów (art. 9 ust. 1 RODO). 
    *   Wszelkie inne Dane Osobowe zawarte w nagraniach audio, ich transkrypcjach, raportach z sesji i pamięci kontekstowej. 
5.  **Kategorie osób, których dane dotyczą:** Pacjenci Administratora, zgodnie z definicją w § 2 pkt 9 Regulaminu, a także inne osoby uczestniczące w nagrywanych sesjach (np. partner w terapii par, członkowie rodziny, opiekunowie). 
6.  **Czas trwania przetwarzania:** Dane Osobowe będą przetwarzane przez czas obowiązywania Umowy Głównej, zgodnie z § 13 Regulaminu, z zastrzeżeniem że:
    *   Nagrania audio są usuwane natychmiast po pomyślnej transkrypcji, a najpóźniej w ramach automatycznego mechanizmu czyszczenia uruchamianego po upływie 48 godzin od przesłania (niezależnie od statusu Umowy).
    *   Po rozwiązaniu Umowy Głównej, pozostałe Dane Osobowe (transkrypcje, raporty, pamięć kontekstowa) są oznaczane jako usunięte (soft delete) i trwale usuwane po upływie 30 dni, w ramach cyklicznego procesu trwałego usuwania danych.

---

## § 3. OBOWIĄZKI PODMIOTU PRZETWARZAJĄCEGO

Podmiot Przetwarzający zobowiązuje się do: 

1.  **Przetwarzania na polecenie:** Przetwarzać Dane Osobowe wyłącznie na udokumentowane polecenie Administratora — chyba że obowiązek przetwarzania nakłada na niego prawo Unii lub prawo państwa członkowskiego; w takim przypadku przed rozpoczęciem przetwarzania Podmiot Przetwarzający informuje Administratora o tym obowiązku prawnym, o ile prawo to nie zabrania udzielania takiej informacji. Za udokumentowane polecenie uznaje się postanowienia Umowy Głównej i niniejszej DPA, a także bieżące działania i konfiguracje dokonywane przez Administratora w Aplikacji (np. inicjowanie nagrania sesji, tworzenie kartoteki Pacjenta, ustawianie preferencji raportów, korekta etykiet mówców). 
2.  **Poufności:** Zapewnić, aby osoby upoważnione do przetwarzania Danych Osobowych zobowiązały się do zachowania tajemnicy lub podlegały odpowiedniemu ustawowemu obowiązkowi zachowania tajemnicy. 
3.  **Bezpieczeństwa przetwarzania (art. 32 RODO):** Wdrożyć i stosować odpowiednie środki techniczne i organizacyjne zapewniające stopień bezpieczeństwa odpowiadający ryzyku, w szczególności opisane w Części I, pkt 5 Polityki Prywatności, obejmujące:
    *   Szyfrowanie kopertowe (Envelope Encryption) danych szczególnych kategorii na poziomie aplikacji oraz klucze CMEK zarządzane w Cloud KMS z automatyczną rotacją co 90 dni.
    *   Przechowywanie i przetwarzanie Danych Osobowych wyłącznie w EOG: region europe-central2 (Warszawa) oraz — dla usług AI — europe-west4 (Holandia); lokalizacja zasobów jest określona w konfiguracji infrastruktury zarządzanej jako kod i podlega kontroli wersji.
    *   Dostęp do bazy danych kanałami szyfrowanymi z prywatnej sieci VPC, z bezpośrednim dostępem ograniczonym do kontrolowanej listy autoryzowanych adresów administracyjnych.
    *   Dedykowane konta usługowe z minimalnymi uprawnieniami dla każdego mikroserwisu.
    *   Usuwanie nagrań audio natychmiast po transkrypcji, najpóźniej w ramach automatycznego mechanizmu (OLM) po upływie 48 godzin.
    *   Mechanizm soft delete z trwałym usunięciem po upływie 30-dniowego okresu retencji, realizowanym przez cykliczny proces trwałego usuwania.
    *   Logowanie audytowe wszystkich istotnych operacji na danych.
4.  **Pomocy Administratorowi:** W miarę możliwości pomagać Administratorowi wywiązać się z obowiązku odpowiadania na żądania osoby, której dane dotyczą, w zakresie wykonywania jej praw, w szczególności w zakresie prawa do dostępu, sprostowania, usunięcia i przenoszenia danych. 
5.  **Wspierania Administratora:** Uwzględniając charakter przetwarzania oraz dostępne mu informacje, pomagać Administratorowi wywiązać się z obowiązków określonych w art. 32–36 RODO (bezpieczeństwo, ocena skutków, konsultacje z organem nadzorczym). 
6.  **Zgłaszania naruszeń:** Po stwierdzeniu Naruszenia Ochrony Danych Osobowych, bez zbędnej zwłoki zgłosić je Administratorowi, nie później niż w ciągu **48 godzin** od stwierdzenia naruszenia. Zgłoszenie będzie zawierać co najmniej: opis charakteru naruszenia, kategorie i przybliżoną liczbę osób, których dane dotyczą, prawdopodobne konsekwencje naruszenia oraz środki podjęte lub proponowane w celu zaradzenia naruszeniu. 
7.  **Usuwania lub zwrotu danych:** Po zakończeniu świadczenia usług (rozwiązaniu Umowy Głównej), w zależności od decyzji Administratora, usunąć lub zwrócić mu wszelkie Dane Osobowe oraz usunąć ich kopie, chyba że prawo nakazuje ich przechowywanie. Procedura usuwania danych po zakończeniu umowy jest następująca:
    *   **Nagrania audio:** usunięte natychmiast po transkrypcji, najpóźniej w ramach automatycznego mechanizmu po upływie 48 godzin od przesłania (niezależnie od statusu Umowy) — brak działań wymaganych.
    *   **Transkrypcje, raporty, pomiary HiTOP, pamięć kontekstowa RAG:** oznaczone jako usunięte (soft delete) i trwale usunięte z bazy danych po upływie 30 dni, w ramach cyklicznego procesu trwałego usuwania.
    *   **Dane kartotekowe Pacjentów:** usuwane kaskadowo wraz z kontem Użytkownika, z zachowaniem 30-dniowego okresu retencji soft delete.
    *   **Zaszyfrowane kopie zapasowe:** dane mogą być obecne w zaszyfrowanych kopiach zapasowych Cloud SQL przez okres ich retencji (nie dłużej niż 30 dni), po czym są automatycznie nadpisywane. Bez dostępu do Cloud KMS dane w kopiach zapasowych pozostają nieczytelne.
    *   **Klucze szyfrowania:** Rotacja klucza KEK (co 90 dni) powoduje, że zaszyfrowane DEK z poprzednich wersji klucza stają się nieprzydatne po usunięciu materiału kryptograficznego starszych wersji.
8.  **Audytu:** Udostępniać Administratorowi wszelkie informacje niezbędne do wykazania spełnienia obowiązków z art. 28 RODO oraz umożliwiać audyty. Szczegółowe zasady audytu są następujące: 
    *   Strony ustalają, że w celu minimalizacji zakłóceń operacyjnych, Administrator akceptuje w pierwszej kolejności udostępnienie przez Podmiot Przetwarzający raportu z własnej oceny bezpieczeństwa, dokumentacji środków technicznych i organizacyjnych oraz, w miarę dostępności, certyfikatów lub atestów (np. ISO 27001, SOC 2) lub raportów z audytu przeprowadzonych przez niezależne podmioty trzecie. Na dzień wejścia w życie niniejszej DPA, Podmiot Przetwarzający nie posiada certyfikatów ISO 27001 ani SOC 2, jednak infrastruktura oparta jest na Google Cloud Platform, który posiada certyfikaty ISO 27001, ISO 27017, ISO 27018, SOC 1/2/3.
    *   W przypadku, gdy udostępnione informacje nie są wystarczające, Administrator ma prawo przeprowadzić audyt, informując o tym Podmiot Przetwarzający z co najmniej 30-dniowym wyprzedzeniem. Audyt będzie przeprowadzany w godzinach pracy Podmiotu Przetwarzającego, w sposób jak najmniej zakłócający jego działalność. Administrator ponosi wszelkie koszty związane z przeprowadzeniem audytu, w tym koszty audytora.

---

## § 4. OBOWIĄZKI ADMINISTRATORA

Administrator oświadcza i gwarantuje, że: 

1.  Przetwarza Dane Osobowe zgodnie z przepisami prawa, w tym RODO oraz ustawą o ochronie danych osobowych. 
2.  Posiada odpowiednią podstawę prawną do przetwarzania Danych Osobowych Pacjentów i powierzenia ich Podmiotowi Przetwarzającemu, zgodnie z obowiązkiem opisanym w § 5 Regulaminu. W szczególności w przypadku przetwarzania danych dotyczących zdrowia (art. 9 ust. 1 RODO), Administrator zapewnia spełnienie przesłanki z art. 9 ust. 2 RODO (np. lit. h w związku z wykonywaniem zawodu objętego tajemnicą zawodową albo wyraźna zgoda — lit. a, w szczególności gdy Administrator nie wykonuje zawodu objętego ustawową tajemnicą, np. w przypadku usług coachingowych).
3.  Wypełnił obowiązek informacyjny wobec osób, których dane dotyczą (zgodnie z art. 13 lub 14 RODO), w tym poinformował Pacjentów oraz wszystkie inne osoby uczestniczące w sesji o fakcie nagrywania sesji i korzystaniu z Aplikacji. Podmiot Przetwarzający udostępnia w Części II Polityki Prywatności wzorcowe informacje, które mogą być wykorzystane przez Administratora w celu wsparcia go w realizacji tego obowiązku.
4.  Będzie wydawał Podmiotowi Przetwarzającemu wyłącznie zgodne z prawem polecenia dotyczące przetwarzania Danych Osobowych.
5.  Przestrzega zasad tajemnicy zawodowej obowiązujących w jego profesji, wynikających w szczególności z ustawy o zawodach lekarza i lekarza dentysty, ustawy o zawodzie psychologa i samorządzie zawodowym psychologów, ustawy o zawodzie psychoterapeuty oraz kodeksów etyki zawodowej.

---

## § 5. PODPOWIERZENIE I TRANSFER DANYCH

1.  **Ogólna zgoda na podpowierzenie:** Administrator wyraża ogólną pisemną zgodę (art. 28 ust. 2 RODO) na korzystanie przez Podmiot Przetwarzający z usług Sub-procesorów wskazanych w ust. 2. 
2.  **Lista Sub-procesorów:** Podmiot Przetwarzający zobowiązuje się do utrzymywania aktualnej listy Sub-procesorów uczestniczących w przetwarzaniu Danych Osobowych (danych Pacjentów). Na dzień wejścia w życie niniejszej DPA, lista Sub-procesorów jest następująca:

| Sub-procesor | Usługa | Przetwarzane dane | Lokalizacja |
|---|---|---|---|
| **Google Cloud Platform** (Google Cloud EMEA Ltd / Google LLC) | Cloud Run, Cloud SQL PostgreSQL, Cloud Storage, Cloud KMS, Pub/Sub, Secret Manager | Przetwarzanie backendowe i przechowywanie Danych Osobowych | europe-central2 (Warszawa, Polska) |
| **Google Cloud — Vertex AI** | Speech-to-Text (Chirp 3), Gemini (raporty), Text Embeddings (RAG) | Transkrypcja, generowanie raportów, embeddingi | europe-west4 (Holandia) — EOG |
| **Google Firebase** | Cloud Firestore (lustrzane statusy przetwarzania sesji — bez treści sesji), FCM (powiadomienia push — bez treści sesji) | Pseudonimowe identyfikatory sesji i statusy przetwarzania | Firestore: europe-central2; FCM: usługa globalna Google (treść powiadomień nie zawiera Danych Osobowych Pacjentów) |

    Dostawcy przetwarzający wyłącznie dane Użytkowników Profesjonalnych (w szczególności Stripe — obsługa płatności, oraz Resend — wysyłka wiadomości e-mail do Użytkownika), nie przetwarzają Danych Osobowych Pacjentów i nie są Sub-procesorami w rozumieniu niniejszej DPA; są oni wskazani w Polityce Prywatności jako odbiorcy danych Użytkowników Profesjonalnych.

    Aktualna lista jest również dostępna w Części I, pkt 6 Polityki Prywatności.

3.  **Obowiązki przy podpowierzeniu:** Podmiot Przetwarzający zapewni, że umowa z każdym Sub-procesorem nakłada na niego co najmniej takie same obowiązki w zakresie ochrony danych, jakie niniejsza DPA nakłada na Podmiot Przetwarzający. Podmiot Przetwarzający ponosi pełną odpowiedzialność wobec Administratora za niewywiązanie się przez Sub-procesora z jego obowiązków ochrony danych. 
4.  **Prawo do sprzeciwu:** Podmiot Przetwarzający poinformuje Administratora (drogą mailową na adres powiązany z Kontem lub poprzez powiadomienie w Aplikacji) o każdym zamierzonym dodaniu lub zastąpieniu Sub-procesora, dając Administratorowi możliwość wyrażenia uzasadnionego sprzeciwu wobec takich zmian w terminie 14 dni od otrzymania informacji. W przypadku wniesienia uzasadnionego sprzeciwu, Strony podejmą próbę rozwiązania sytuacji. Jeśli rozwiązanie nie będzie możliwe, Administrator ma prawo wypowiedzieć Umowę Główną.
5.  **Brak transferu Danych Osobowych do Państw Trzecich:** Podmiot Przetwarzający gwarantuje, że Dane Osobowe Pacjentów (nagrania audio, transkrypcje, raporty z sesji, pomiary HiTOP, pamięć kontekstowa) **nie są przekazywane do Państw Trzecich** (poza EOG). Infrastruktura przetwarzająca te dane jest zlokalizowana w Europejskim Obszarze Gospodarczym (region europe-central2 — Warszawa oraz region europe-west4 — Holandia), a lokalizacja zasobów jest określona w konfiguracji infrastruktury zarządzanej jako kod i podlega kontroli wersji oraz przeglądom.

---

## § 6. ODPOWIEDZIALNOŚĆ

1.  Odpowiedzialność Stron regulują przepisy RODO, w szczególności art. 82. 
2.  Odpowiedzialność Podmiotu Przetwarzającego jest ograniczona do szkód wynikających bezpośrednio z naruszenia przez niego obowiązków wynikających z niniejszej Umowy lub przepisów RODO dotyczących bezpośrednio Podmiotów Przetwarzających. 
3.  Zgodnie z § 8 Regulaminu, całkowita odpowiedzialność Podmiotu Przetwarzającego wobec Administratora z tytułu niniejszej Umowy jest ograniczona do wysokości Opłat Abonamentowych uiszczonych przez Administratora w ciągu ostatnich 12 miesięcy poprzedzających zdarzenie powodujące szkodę. Ograniczenie to nie dotyczy odpowiedzialności wynikającej z umyślnego działania lub rażącego niedbalstwa.

---

## § 7. POSTANOWIENIA KOŃCOWE

1.  Niniejsza DPA stanowi integralną część Umowy Głównej. W przypadku sprzeczności pomiędzy postanowieniami DPA a Regulaminem w zakresie ochrony danych osobowych, pierwszeństwo mają postanowienia DPA. 
2.  Umowa wchodzi w życie z chwilą akceptacji Umowy Głównej przez Administratora i obowiązuje przez cały okres jej trwania, a w zakresie obowiązków dotyczących usunięcia danych — do momentu ich pełnego wykonania. 
3.  Zasady zmiany DPA są analogiczne do zasad zmiany Regulaminu, opisanych w § 14 Regulaminu. O każdej zmianie Administrator zostanie poinformowany z co najmniej 14-dniowym wyprzedzeniem. 
4.  W sprawach nieuregulowanych niniejszą Umową zastosowanie mają postanowienia Regulaminu oraz Polityki Prywatności, a w dalszej kolejności przepisy prawa polskiego i RODO. 
5.  Sądem właściwym do rozstrzygania sporów będzie sąd właściwy miejscowo dla siedziby Podmiotu Przetwarzającego w Krakowie, zgodnie z § 15 ust. 2 Regulaminu.
