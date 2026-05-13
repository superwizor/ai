# Umowa Powierzenia Przetwarzania Danych Osobowych (DPA)

*Data wejścia w życie: 21 lipca 2025 r.*

---

## W skrócie (TL;DR)

Jako terapeuta używający Superwizor AI, przetwarzasz dane osobowe swoich pacjentów (nagrania, transkrypcje). Jesteś **Administratorem** tych danych. My — Euphire sp. z o.o. — jesteśmy **Podmiotem Przetwarzającym**, czyli wykonawcą Twoich poleceń.

Niniejsza DPA reguluje te relacje zgodnie z wymogami **art. 28 RODO**.

---

## Strony Umowy

**Administrator Danych:**
Użytkownik Profesjonalny, który zaakceptował Regulamin Świadczenia Usług Superwizor AI.

**Podmiot Przetwarzający:**
Euphire sp. z o.o., ul. Odrzańska 10a/48, 30-408 Kraków
KRS: 0000907254 · NIP: 6793219020
E-mail: kontakt@superwizor.ai

---

## § 1. Definicje

| Pojęcie | Znaczenie |
|---|---|
| **Dane Osobowe** | Dane pacjentów Administratora, w tym dane szczególnych kategorii (dane dot. zdrowia), przetwarzane przez Podmiot Przetwarzający na podstawie niniejszej Umowy |
| **Naruszenie Ochrony Danych** | Naruszenie bezpieczeństwa prowadzące do zniszczenia, utracenia, nieuprawnionego dostępu lub ujawnienia Danych Osobowych |
| **Sub-procesor** | Podmiot trzeci, któremu Podmiot Przetwarzający powierza przetwarzanie Danych Osobowych |
| **Umowa Główna** | Regulamin Świadczenia Usług Superwizor AI zaakceptowany przez Administratora |

---

## § 2. Przedmiot i zakres przetwarzania

Administrator powierza Podmiotowi Przetwarzającemu dane osobowe swoich Pacjentów wyłącznie w celu świadczenia usług Aplikacji, obejmujących:

- Przechowywanie nagrań audio sesji (szyfrowane, w EU)
- Automatyczną transkrypcję i diaryzację mowy
- Analizę kliniczną z wykorzystaniem modeli AI
- Generowanie raportów klinicznych i pomiarów HiTOP
- Zarządzanie kartotekami pacjentów w ramach Aplikacji

**Rodzaj przetwarzanych danych:**
- Dane identyfikacyjne w zakresie, w jakim pojawią się w nagraniu
- Dane dotyczące zdrowia psychicznego (art. 9 ust. 1 RODO)
- Głos i inne dane biometryczne zawarte w nagraniu audio

**Kategorie osób:** Pacjenci Administratora.

**Czas trwania:** Przez cały okres obowiązywania Umowy Głównej.

---

## § 3. Obowiązki Podmiotu Przetwarzającego

Euphire sp. z o.o. zobowiązuje się do:

1. **Przetwarzania wyłącznie na polecenie** Administratora, zgodnie z Umową Główną i niniejszą DPA.

2. **Zapewnienia poufności** — osoby uprawnione do przetwarzania danych są zobowiązane do zachowania tajemnicy.

3. **Bezpieczeństwa technicznego** (art. 32 RODO):
   - Szyfrowanie danych w spoczynku (AES-256, Cloud KMS)
   - Szyfrowanie w tranzycie (TLS 1.3)
   - Envelope encryption dla PHI (danych szczególnie wrażliwych)
   - Zero Trust, dedykowane konta serwisowe

4. **Pomocy Administratorowi** w realizacji praw osób, których dane dotyczą.

5. **Zgłaszania naruszeń** — w ciągu **48 godzin** od stwierdzenia naruszenia ochrony danych.

6. **Usuwania lub zwrotu danych** po zakończeniu Umowy Głównej, zgodnie z decyzją Administratora.

7. **Umożliwienia audytów** — Podmiot Przetwarzający udostępni certyfikaty i raporty bezpieczeństwa. W uzasadnionych przypadkach możliwy jest audyt bezpośredni z 30-dniowym wyprzedzeniem.

---

## § 4. Obowiązki Administratora

Administrator oświadcza i gwarantuje, że:

1. Przetwarza dane osobowe Pacjentów zgodnie z przepisami prawa.
2. Posiada odpowiednią podstawę prawną do przetwarzania danych Pacjentów i powierzenia ich Podmiotowi Przetwarzającemu.
3. Wypełnił obowiązek informacyjny wobec Pacjentów (art. 13 lub 14 RODO).
4. Uzyskał wyraźną zgodę Pacjentów na nagrywanie sesji, przed każdym nagraniem.
5. Będzie wydawał wyłącznie zgodne z prawem polecenia dotyczące przetwarzania danych.

---

## § 5. Sub-procesorzy

Administrator wyraża ogólną, pisemną zgodę (art. 28 ust. 2 RODO) na korzystanie z Sub-procesorów. Aktualna lista:

| Sub-procesor | Cel | Region |
|---|---|---|
| Google Cloud Platform | Hosting infrastruktury (Cloud SQL, GCS, Cloud Run) | EU (europe-central2) |
| Firebase | Uwierzytelnianie i przechowywanie plików | EU |
| Google Speech-to-Text | Transkrypcja audio (Chirp 3) | EU |
| Vertex AI / Gemini | Analiza kliniczna AI | EU (europe-west4) |

Podmiot Przetwarzający poinformuje Administratora o każdej zmianie w liście Sub-procesorów z **14-dniowym wyprzedzeniem**. Administrator ma prawo wyrazić sprzeciw w tym terminie.

---

## § 6. Transfer danych poza EOG

Administrator akceptuje, że dane mogą być przetwarzane przez usługi AI zlokalizowane w Holandii (`europe-west4`), która jest krajem EOG. Nie dochodzi do transferu poza Europejski Obszar Gospodarczy.

---

## § 7. Odpowiedzialność

Odpowiedzialność Stron regulują przepisy RODO, w szczególności art. 82.

Całkowita odpowiedzialność Podmiotu Przetwarzającego wobec Administratora ograniczona jest do wysokości Opłaty Abonamentowej uiszczonej za Okres Abonamentowy, w którym wystąpiło zdarzenie powodujące szkodę.

---

## § 8. Postanowienia końcowe

1. Niniejsza DPA stanowi integralną część Umowy Głównej. W przypadku sprzeczności, pierwszeństwo mają postanowienia DPA w zakresie ochrony danych.

2. DPA wchodzi w życie z chwilą akceptacji Umowy Głównej i obowiązuje przez cały okres jej trwania.

3. Zmiany DPA ogłaszane są z co najmniej 14-dniowym wyprzedzeniem.

4. W sprawach nieuregulowanych stosuje się przepisy prawa polskiego i RODO.

5. Sądem właściwym do rozstrzygania sporów jest sąd właściwy dla siedziby Podmiotu Przetwarzającego (Kraków).

---

*DPA wchodzi w życie z dniem 21 lipca 2025 r.*
