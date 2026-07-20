---
type: Compliance Specification
title: "Rejestr Czynności Przetwarzania Danych Osobowych (RCP)"
description: "art. 30 RODO — Rozporządzenia Parlamentu Europejskiego i Rady (UE) 2016/679"
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/compliance/02_REJESTR_CZYNNOSCI_PRZETWARZANIA.md
tags: [compliance]
timestamp: 2026-06-24T18:11:41+02:00
---

# Rejestr Czynności Przetwarzania Danych Osobowych (RCP)

**art. 30 RODO — Rozporządzenia Parlamentu Europejskiego i Rady (UE) 2016/679**

**Administrator / Podmiot Przetwarzający:** Euphire sp. z o.o.  
**Adres:** ul. Odrzańska 10a/48, Kraków  
**KRS:** 0000907254 | **NIP:** 6793219020  
**Kontakt ws. ochrony danych:** kontakt@superwizor.ai  
**Data ostatniej aktualizacji:** ___________  
**Wersja:** 1.0 DRAFT — do weryfikacji przez radcę prawnego

---

## Część A: Rejestr Administratora (art. 30 ust. 1 RODO)

Euphire sp. z o.o. jest Administratorem danych osobowych Użytkowników Profesjonalnych (terapeutów, coachów, psychologów) w zakresie opisanym poniżej.

---

### A-1. Rejestracja i zarządzanie kontem Użytkownika Profesjonalnego

| Pole | Opis |
|---|---|
| **Nr czynności** | A-1 |
| **Nazwa czynności** | Rejestracja i zarządzanie kontem Użytkownika Profesjonalnego |
| **Cel przetwarzania** | Utworzenie konta, uwierzytelnienie, zarządzanie profilem, personalizacja usługi (modalność terapeutyczna, język interfejsu, styl raportów) |
| **Podstawa prawna** | Art. 6 ust. 1 lit. b RODO (wykonanie umowy) |
| **Kategorie osób** | Użytkownicy Profesjonalni (terapeuci, psychologowie, psychiatrzy, coachowie) |
| **Kategorie danych** | Imię, nazwisko, adres e-mail, numer telefonu (opcjonalny), tytuł zawodowy, numer uprawnień zawodowych, biografia, zdjęcie profilowe, Firebase UID, hash hasła, tokeny uwierzytelniające (Google/Apple SSO), preferowana modalność terapeutyczna, strefa czasowa, język interfejsu, preferencje stylu raportów |
| **Odbiorcy danych** | Google Firebase Authentication (uwierzytelnianie), Google Cloud SQL (przechowywanie), Google Cloud Storage (zdjęcia profilowe) |
| **Transfer poza EOG** | Firebase Authentication i FCM są usługami globalnymi Google — dane uwierzytelniające mogą być przetwarzane poza EOG; Google LLC posiada certyfikację EU-US Data Privacy Framework (DPF) |
| **Planowany termin usunięcia** | Do momentu usunięcia konta przez Użytkownika + 30 dni retencji soft delete |
| **Środki bezpieczeństwa** | TLS/SSL, dedykowane SA z minimalnymi uprawnieniami (Zero Trust), szyfrowanie bazy danych CMEK, logowanie audytowe, MFA (Google/Apple SSO) |

---

### A-2. Obsługa płatności i rozliczeń

| Pole | Opis |
|---|---|
| **Nr czynności** | A-2 |
| **Nazwa czynności** | Obsługa płatności, subskrypcji i fakturowania |
| **Cel przetwarzania** | Realizacja płatności za subskrypcje, zarządzanie cyklem życia subskrypcji, wystawianie dokumentów księgowych |
| **Podstawa prawna** | Art. 6 ust. 1 lit. b RODO (wykonanie umowy) + Art. 6 ust. 1 lit. c RODO (obowiązek prawny — przepisy podatkowe) |
| **Kategorie osób** | Użytkownicy Profesjonalni |
| **Kategorie danych** | Adres e-mail, identyfikator subskrypcji Stripe, identyfikator klienta Stripe, rodzaj planu, okres abonamentowy, status subskrypcji, daty płatności, kwoty brutto/netto, stawka VAT, NIP (dla B2B), adres rozliczeniowy. Uwaga: Euphire nie przechowuje pełnych danych kart płatniczych — są przetwarzane wyłącznie przez Stripe (PCI DSS Level 1) |
| **Odbiorcy danych** | Stripe Payments Europe, Ltd. (Irlandia) / Stripe, Inc. (USA), zewnętrzny system fakturowy (Fakturownia/iFirma) |
| **Transfer poza EOG** | USA (Stripe, Inc.) — na podstawie EU-US Data Privacy Framework + standardowe klauzule umowne |
| **Planowany termin usunięcia** | 5 lat od końca roku podatkowego, w którym dokonano ostatniej transakcji (wymóg ordynacji podatkowej) |
| **Środki bezpieczeństwa** | Stripe PCI DSS Level 1, TLS/SSL, webhook signature verification, idempotencja zdarzeń (`provider_event_id` UNIQUE) |

---

### A-3. Komunikacja z Użytkownikami (e-mail transakcyjny i marketingowy)

| Pole | Opis |
|---|---|
| **Nr czynności** | A-3 |
| **Nazwa czynności** | Wysyłka wiadomości e-mail: transakcyjnych (powitanie, weryfikacja, powiadomienia o subskrypcji) oraz — za zgodą — marketingowych |
| **Cel przetwarzania** | Realizacja umowy (wiadomości transakcyjne) + marketing bezpośredni własnych usług (za zgodą) |
| **Podstawa prawna** | Art. 6 ust. 1 lit. b RODO (transakcyjne) + Art. 6 ust. 1 lit. a RODO w zw. z art. 398 Prawa komunikacji elektronicznej (marketing) |
| **Kategorie osób** | Użytkownicy Profesjonalni |
| **Kategorie danych** | Adres e-mail, imię, treść wiadomości systemowych, status zgody marketingowej |
| **Odbiorcy danych** | Resend, Inc. (USA) |
| **Transfer poza EOG** | USA — na podstawie standardowych klauzul umownych (art. 46 ust. 2 lit. c RODO) |
| **Planowany termin usunięcia** | Do czasu wycofania zgody (marketing) lub usunięcia konta (transakcyjne) |
| **Środki bezpieczeństwa** | TLS/SSL, każda wiadomość marketingowa zawiera link rezygnacji, zgoda ewidencjonowana w polu `has_marketing_consent` |

---

### A-4. Zapewnienie bezpieczeństwa i diagnostyka

| Pole | Opis |
|---|---|
| **Nr czynności** | A-4 |
| **Nazwa czynności** | Logowanie zdarzeń systemowych, diagnostyka błędów, zapobieganie nadużyciom |
| **Cel przetwarzania** | Zapewnienie bezpieczeństwa systemu, wykrywanie i zapobieganie nadużyciom, diagnostyka problemów technicznych |
| **Podstawa prawna** | Art. 6 ust. 1 lit. f RODO (prawnie uzasadniony interes) |
| **Kategorie osób** | Użytkownicy Profesjonalni, odwiedzający Serwis internetowy |
| **Kategorie danych** | Adres IP, typ i wersja urządzenia, wersja systemu operacyjnego, wersja Aplikacji, identyfikator przeglądarki (user agent), datownik żądania, zdarzenia diagnostyczne, zdarzenia audytowe (akcja, typ zasobu, identyfikator zasobu, identyfikator aktora) |
| **Odbiorcy danych** | Google Cloud Logging, Google Cloud Monitoring |
| **Transfer poza EOG** | Brak — logi przechowywane w europe-central2 |
| **Planowany termin usunięcia** | Logi systemowe: 30 dni; zdarzenia analityczne: 90 dni; zdarzenia audytowe: czas nieokreślony (wymóg rozliczalności) |
| **Środki bezpieczeństwa** | Cloud Logging IAM, exclusion filters (wykluczenie szumu), ADMIN_READ audit config |

---

### A-5. Obsługa zapytań przez Serwis internetowy

| Pole | Opis |
|---|---|
| **Nr czynności** | A-5 |
| **Nazwa czynności** | Obsługa formularzy kontaktowych i rejestracyjnych w Serwisie superwizor.ai |
| **Cel przetwarzania** | Odpowiedź na zapytanie; rejestracja nowego Użytkownika; dostarczenie materiałów informacyjnych |
| **Podstawa prawna** | Art. 6 ust. 1 lit. f RODO (kontakt) + Art. 6 ust. 1 lit. b RODO (rejestracja) + Art. 6 ust. 1 lit. a RODO (lead magnet za zgodą) |
| **Kategorie osób** | Odwiedzający Serwis, potencjalni Użytkownicy |
| **Kategorie danych** | Imię, adres e-mail, temat i treść wiadomości, dane rejestracyjne, dane z formularzy Tally (lead magnet) |
| **Odbiorcy danych** | Tally Forms (Belgia, EOG) — formularze lead magnet |
| **Transfer poza EOG** | Brak (Tally = EOG) |
| **Planowany termin usunięcia** | Do czasu załatwienia sprawy + okres przedawnienia roszczeń |
| **Środki bezpieczeństwa** | TLS/SSL, CORS allowlist na bucket GCS |

---

## Część B: Rejestr Podmiotu Przetwarzającego (art. 30 ust. 2 RODO)

Euphire sp. z o.o. jest Podmiotem Przetwarzającym dane osobowe Klientów (pacjentów) w imieniu Użytkowników Profesjonalnych (Administratorów) na podstawie Umowy Powierzenia Przetwarzania Danych (DPA).

---

### B-1. Transkrypcja nagrań sesji terapeutycznych

| Pole | Opis |
|---|---|
| **Nr czynności** | B-1 |
| **Nazwa czynności** | Przesyłanie, przechowywanie (tymczasowe) i transkrypcja nagrań audio sesji terapeutycznych/coachingowych |
| **Administrator** | Użytkownik Profesjonalny (terapeuta/coach) — każdy indywidualnie |
| **Kategorie osób** | Klienci (pacjenci, osoby poddawane coachingowi) oraz inne osoby uczestniczące w sesjach (partner w terapii par, członkowie rodziny) |
| **Kategorie danych** | **Dane szczególnych kategorii (art. 9 ust. 1 RODO):** nagrania audio sesji terapeutycznych zawierające dane dotyczące zdrowia fizycznego i psychicznego; dane identyfikacyjne pojawiające się w nagraniu (imiona, nazwiska, adresy — w zakresie wypowiadanym przez uczestników); automatyczna transkrypcja z etykietami mówców (neutralne: „Osoba 1", „Osoba 2" lub ról: „Terapeuta", „Pacjent") |
| **Cel przetwarzania** | Wykonanie usługi na polecenie Administratora: konwersja mowy na tekst w celu dalszej analizy AI |
| **Sub-procesorzy** | Google Cloud Storage (tymczasowe przechowywanie audio — europe-central2), Google Cloud — Vertex AI Speech-to-Text Chirp 3 (transkrypcja — eu-speech.googleapis.com / europe-west4) |
| **Transfer poza EOG** | **Brak** — przetwarzanie wyłącznie w EOG (europe-central2 + europe-west4) |
| **Środki bezpieczeństwa** | Szyfrowanie CMEK (audio bucket), OLM 48h automatyczne usuwanie, TLS/SSL w tranzycie, dedykowane SA (stt-worker-sa) z minimalnymi uprawnieniami, idempotencja (status check `FOR UPDATE SKIP LOCKED`) |

---

### B-2. Analiza sesji przez sztuczną inteligencję

| Pole | Opis |
|---|---|
| **Nr czynności** | B-2 |
| **Nazwa czynności** | Generowanie ustrukturyzowanego Raportu z Sesji i pomiarów HiTOP przez LLM (Gemini 2.5 Pro) |
| **Administrator** | Użytkownik Profesjonalny |
| **Kategorie osób** | Klienci (pacjenci) |
| **Kategorie danych** | **Dane szczególnych kategorii:** transkrypcja sesji (zaszyfrowana, odszyfrowana w runtime na potrzeby promptu), kontekst pamięci RAG (pseudonimizowany). Wyjście: raport sesji (zaszyfrowany), pomiary HiTOP (severity, confidence), metryki procesu |
| **Cel przetwarzania** | Generowanie raportu klinicznego i pomiarów wymiarowych HiTOP na polecenie Administratora |
| **Sub-procesorzy** | Google Cloud — Vertex AI Gemini 2.5 Pro (europe-west4), Google Cloud — Text Embeddings (europe-west4) |
| **Transfer poza EOG** | **Brak** — Vertex AI skonfigurowany na europe-west4 (Holandia, EOG) |
| **Środki bezpieczeństwa** | Envelope encryption wyników (AEAD + Cloud KMS), dedykowane SA (llm-worker-sa), idempotencja pipeline, raporty dostępne w trybie read-only (P4), pseudonimizacja pamięci kontekstowej |

---

### B-3. Przechowywanie danych sesji i kartotek pacjentów

| Pole | Opis |
|---|---|
| **Nr czynności** | B-3 |
| **Nazwa czynności** | Trwałe przechowywanie zaszyfrowanych transkrypcji, raportów, pomiarów HiTOP, pamięci kontekstowej RAG, kartotek pacjentów i notatek |
| **Administrator** | Użytkownik Profesjonalny |
| **Kategorie osób** | Klienci (pacjenci) |
| **Kategorie danych** | **Dane szczególnych kategorii:** zaszyfrowane transkrypcje, raporty z sesji, pomiary HiTOP, pamięć kontekstowa (pseudonimizowana), notatki do pacjentów. Dane nieosobowe: working alias pacjenta, typ procesu (indywidualny/par/rodzinny), forma kontaktu, numer sesji |
| **Cel przetwarzania** | Udostępnienie Administratorowi materiałów sesyjnych, zapewnienie ciągłości terapeutycznej, realizacja praw podmiotów danych (dostęp, eksport, usunięcie) |
| **Sub-procesorzy** | Google Cloud SQL PostgreSQL (europe-central2), Google Cloud KMS (europe-central2) |
| **Transfer poza EOG** | **Brak** |
| **Środki bezpieczeństwa** | Envelope encryption (AEAD + KMS CMEK z rotacją co 90 dni), szyfrowanie Cloud SQL w spoczynku (CMEK), SSL_MODE=ENCRYPTED_ONLY, VPC Connector, soft delete + GDPR Purger (30 dni), audyt każdej operacji (`audit_events`), ON DELETE RESTRICT (ADR-DM-010) |

---

### B-4. Synchronizacja statusów przetwarzania (Firestore)

| Pole | Opis |
|---|---|
| **Nr czynności** | B-4 |
| **Nazwa czynności** | Lustrzane odzwierciedlenie statusów przetwarzania sesji w Firestore na potrzeby synchronizacji z aplikacją mobilną w czasie rzeczywistym |
| **Administrator** | Użytkownik Profesjonalny |
| **Kategorie osób** | Klienci (pośrednio — identyfikatory sesji) |
| **Kategorie danych** | Pseudonimowe identyfikatory sesji (UUID), status przetwarzania (np. `uploaded`, `transcribing`, `analyzing`, `done`, `failed`). **Treść sesji nie jest przechowywana w Firestore.** |
| **Cel przetwarzania** | Zapewnienie real-time synchronizacji statusu z aplikacją mobilną |
| **Sub-procesorzy** | Google Firebase — Cloud Firestore (europe-central2) |
| **Transfer poza EOG** | **Brak** — Firestore skonfigurowany na europe-central2 |
| **Środki bezpieczeństwa** | Firestore Security Rules, brak treści sesji w Firestore (ADR-006), dedicated notification-svc SA |

---

### B-5. Powiadomienia push

| Pole | Opis |
|---|---|
| **Nr czynności** | B-5 |
| **Nazwa czynności** | Wysyłka powiadomień push o zakończeniu przetwarzania sesji |
| **Administrator** | Użytkownik Profesjonalny |
| **Kategorie osób** | Klienci (pośrednio — powiadomienie informuje o zakończeniu analizy sesji danego pacjenta) |
| **Kategorie danych** | Token push FCM Użytkownika, identyfikator sesji, status przetwarzania. **Treść powiadomienia nie zawiera danych osobowych Klientów** (np. „Raport z sesji jest gotowy" — bez imion, diagnoz) |
| **Cel przetwarzania** | Powiadomienie Użytkownika o gotowości raportu |
| **Sub-procesorzy** | Google Firebase — FCM (usługa globalna Google) |
| **Transfer poza EOG** | FCM jest usługą globalną — tokeny push mogą być przetwarzane poza EOG; treść powiadomień nie zawiera danych Klientów; Google LLC posiada certyfikację EU-US DPF |
| **Środki bezpieczeństwa** | Brak PII Klientów w payloadzie powiadomienia, dedykowane SA (notification-svc-sa) |

---

## Część C: Lista Sub-procesorów

Na dzień sporządzenia niniejszego Rejestru, Podmiot Przetwarzający korzysta z następujących Sub-procesorów w zakresie danych Klientów:

| Sub-procesor | Usługa | Lokalizacja | Umowa podpowierzenia | Certyfikaty |
|---|---|---|---|---|
| Google Cloud EMEA Ltd / Google LLC | Cloud Run, Cloud SQL, Cloud Storage, Cloud KMS, Pub/Sub, Secret Manager | europe-central2 (Warszawa) | Google Cloud DPA | ISO 27001, 27017, 27018, SOC 1/2/3 |
| Google Cloud — Vertex AI | Speech-to-Text (Chirp 3), Gemini 2.5 Pro, Text Embeddings | europe-west4 (Holandia) | j.w. | j.w. |
| Google Firebase | Cloud Firestore, FCM | Firestore: europe-central2; FCM: globalnie | j.w. | j.w. |

**Uwaga:** Stripe i Resend przetwarzają wyłącznie dane Użytkowników Profesjonalnych (nie Klientów) i nie są Sub-procesorami w rozumieniu DPA.

---

## Część D: Ogólny opis środków technicznych i organizacyjnych (art. 30 ust. 1 lit. g)

| Kategoria | Środek |
|---|---|
| **Szyfrowanie w spoczynku** | CMEK (Cloud KMS) dla Cloud SQL, Cloud Storage, Secret Manager; Envelope Encryption (AEAD) dla wszystkich kolumn PHI z automatyczną rotacją KEK co 90 dni |
| **Szyfrowanie w tranzycie** | TLS/SSL dla wszystkich połączeń; gRPC (HTTP/2) między mikroserwisami; Cloud SQL: `ssl_mode = ENCRYPTED_ONLY` |
| **Kontrola dostępu** | Dedykowane Service Accounts z minimalnymi uprawnieniami dla każdego mikroserwisu (Zero Trust); Firebase Authentication; Workload Identity Federation (CI/CD bez kluczy) |
| **Izolacja sieciowa** | VPC Connector dla Cloud SQL; prywatny adres IP; autoryzowane sieci ograniczone do listy administracyjnej |
| **Pseudonimizacja** | Neutralne etykiety mówców (`pkg/i18n/speakerlabels`); pamięć RAG pseudonimizowana (bez imion, nazwisk, nazw miejsc); embedding chunks z zredagowanym tekstem |
| **Minimalizacja danych** | Audio usuwane po transkrypcji (OLM 48h); surowe wyniki STT usuwane po 7 dniach; analityka po 90 dniach |
| **Automatyczne usuwanie** | GDPR Purger (Cloud Run Job) — hard delete po 30 dniach soft delete; OLM lifecycle rules na GCS |
| **Audyt i logowanie** | Tabela `audit_events` w każdym serwisie; Cloud Logging; ADMIN_READ audit config na wszystkich usługach GCP |
| **Ciągłość działania** | Automated Cloud SQL backups (zaszyfrowane CMEK); Pub/Sub at-least-once delivery z DLQ; idempotencja pipeline |
| **Rozliczalność** | Niniejszy Rejestr; DPA; Polityka Prywatności; Polityka Retencji; Infrastructure as Code (Terraform) z kontrolą wersji |

---

## Zatwierdzenie

| Rola | Imię i nazwisko | Data | Podpis |
|---|---|---|---|
| Zarząd Euphire sp. z o.o. | _______________ | _______________ | _______________ |
| Radca prawny / IOD | _______________ | _______________ | _______________ |

---

*Dokument wygenerowany na podstawie analizy kodu źródłowego, konfiguracji infrastruktury (Terraform), modelu danych (docs/02_DATA_MODEL.md), oraz dokumentacji architektury SuperWizor AI w wersji z dnia 24.06.2026.*
