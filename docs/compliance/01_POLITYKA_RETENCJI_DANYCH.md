---
type: Compliance Specification
title: "Polityka Retencji Danych Osobowych — SuperWizor AI"
description: "Wersja: 1.0 Data wejścia w życie: Odpowiedzialny: Euphire sp. z o.o., ul. Odrzańska 10a/48, Kraków Kontakt: kontakt@superwizor.ai Status: DRAFT — do weryfika..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/compliance/01_POLITYKA_RETENCJI_DANYCH.md
tags: [compliance]
timestamp: 2026-06-24T18:11:41+02:00
---

# Polityka Retencji Danych Osobowych — SuperWizor AI

**Wersja:** 1.0  
**Data wejścia w życie:** ___________  
**Odpowiedzialny:** Euphire sp. z o.o., ul. Odrzańska 10a/48, Kraków  
**Kontakt:** kontakt@superwizor.ai  
**Status:** DRAFT — do weryfikacji przez radcę prawnego

---

## 1. Cel i Zakres

Niniejsza Polityka Retencji Danych Osobowych określa zasady i okresy przechowywania danych osobowych przetwarzanych przez Euphire sp. z o.o. w związku z świadczeniem usług aplikacji Superwizor AI, zgodnie z:
- art. 5 ust. 1 lit. e RODO (zasada ograniczenia przechowywania),
- art. 17 RODO (prawo do usunięcia),
- art. 30 RODO (obowiązek dokumentowania okresów retencji).

Polityka obejmuje dane osobowe Użytkowników Profesjonalnych (terapeutów) oraz dane osobowe Klientów (pacjentów/osób uczestniczących w sesjach).

---

## 2. Definicje

Definicje używane w niniejszym dokumencie są zgodne z definicjami zawartymi w Regulaminie Świadczenia Usług oraz Polityce Prywatności aplikacji Superwizor AI.

Dodatkowo:
- **Soft delete** — oznaczenie rekordu jako usuniętego poprzez ustawienie kolumny `deleted_at` na aktualną datę i czas; rekord nie jest natychmiast usuwany z bazy danych, ale jest niewidoczny w interfejsie użytkownika i nie jest przetwarzany.
- **Hard delete (purge)** — nieodwracalne fizyczne usunięcie rekordu z bazy danych.
- **OLM (Object Lifecycle Management)** — mechanizm Google Cloud Storage automatycznie usuwający obiekty po upływie określonego czasu od ich utworzenia.
- **GDPR Purger** — dedykowany proces (Cloud Run Job) uruchamiany cyklicznie, realizujący trwałe usuwanie rekordów oznaczonych jako usunięte po upływie okresu retencji soft delete.

---

## 3. Tabela Retencji Danych

### 3.1. Dane Klientów (pacjentów) — dane szczególnych kategorii

| Kategoria danych | Lokalizacja przechowywania | Okres retencji | Mechanizm usuwania | Automatyczny? | Podstawa prawna retencji |
|---|---|---|---|---|---|
| **Nagrania audio sesji** | Google Cloud Storage (`europe-central2`) | Usuwane natychmiast po pomyślnej transkrypcji; **maks. 48 godzin** od przesłania (niezależnie od wyniku) | OLM lifecycle rule (age=2 dni) na zasobniku GCS + programowe usuwanie po STT | ✅ Tak | Art. 5(1)(e) RODO — minimalizacja; nagranie jest środkiem pośrednim do uzyskania transkrypcji |
| **Surowe wyniki STT (JSON)** | Google Cloud Storage (`europe-central2`, bucket `transcripts-raw`) | **7 dni** od utworzenia | OLM lifecycle rule (age=7 dni) + CMEK | ✅ Tak | Tymczasowy artefakt przetwarzania; retencja wystarczająca do debugowania |
| **Transkrypcje sesji** (zaszyfrowane envelope encryption) | PostgreSQL Cloud SQL (`europe-central2`) | Czas trwania umowy z Użytkownikiem + **30 dni** od soft delete | Soft delete → GDPR Purger (hard delete po 30 dniach) | ✅ Tak | Art. 6(1)(b) + Art. 28 RODO — wykonanie umowy powierzenia; art. 5(1)(e) — 30 dni na odwrócenie przypadkowego usunięcia |
| **Raporty z sesji** (zaszyfrowane) | PostgreSQL Cloud SQL (`europe-central2`) | Czas trwania umowy z Użytkownikiem + **30 dni** od soft delete | Soft delete → kaskadowe usunięcie z sesją → GDPR Purger | ✅ Tak | j.w. |
| **Pomiary HiTOP** | PostgreSQL Cloud SQL (`europe-central2`) | Czas trwania umowy + **30 dni** | Soft delete → kaskadowe usunięcie z sesją → GDPR Purger | ✅ Tak | j.w. |
| **Metryki procesu terapeutycznego** | PostgreSQL Cloud SQL (`europe-central2`) | Czas trwania umowy + **30 dni** | Soft delete → kaskadowe usunięcie z sesją → GDPR Purger | ✅ Tak | j.w. |
| **Pamięć kontekstowa RAG** (zaszyfrowana, pseudonimizowana) | PostgreSQL Cloud SQL (`europe-central2`) + pgvector | Czas trwania umowy + **30 dni** | Soft delete → kaskadowe usunięcie z kartoteką pacjenta → GDPR Purger | ✅ Tak | j.w.; pseudonimizacja = dodatkowy środek ochrony |
| **Embedding chunks** (wektory, zredagowane z PII) | PostgreSQL Cloud SQL (`europe-central2`) + pgvector | Czas trwania umowy + **30 dni** | Kaskadowe usunięcie z `clinical_memory` → GDPR Purger | ✅ Tak | j.w.; embeddingi nie zawierają PII (`chunk_text_redacted`) |
| **Kartoteki pacjentów** (`patient_files`) | PostgreSQL Cloud SQL (`europe-central2`) | Czas trwania umowy + **30 dni** | Soft delete (DSAR) → GDPR Purger | ✅ Tak | j.w. |
| **Notatki do pacjentów** (`patient_notes`, zaszyfrowane) | PostgreSQL Cloud SQL (`europe-central2`) | Czas trwania umowy + **30 dni** | Soft delete → GDPR Purger | ✅ Tak | j.w. |
| **Lustrzane statusy sesji** (Firestore) | Google Firestore (`europe-central2`) | Czas trwania umowy; usuwane z sesją | Kasowane synchronicznie przez notification-svc | ✅ Tak | Synchronizacja statusu, nie zawiera treści sesji |

### 3.2. Dane Użytkowników Profesjonalnych (terapeutów)

| Kategoria danych | Lokalizacja | Okres retencji | Mechanizm usuwania | Automatyczny? | Podstawa prawna |
|---|---|---|---|---|---|
| **Dane identyfikacyjne i kontaktowe** (imię, nazwisko, email, telefon) | PostgreSQL Cloud SQL | Do usunięcia konta + **30 dni** soft delete | Soft delete → GDPR Purger | ✅ Tak | Art. 6(1)(b) RODO — wykonanie umowy |
| **Dane rejestracyjne** (Firebase UID, hash hasła) | PostgreSQL + Firebase Authentication | Do usunięcia konta + **30 dni** (PostgreSQL); natychmiast (Firebase) | Soft delete → GDPR Purger (PG); Firebase Admin SDK delete (Firebase Auth) | ✅ Tak | j.w. |
| **Dane profilowe** (tytuł, modalność, preferencje raportów) | PostgreSQL Cloud SQL | Do usunięcia konta + **30 dni** | Soft delete → GDPR Purger | ✅ Tak | j.w. |
| **Zdjęcie profilowe** | Firebase Cloud Storage (`europe-central2`) | Do usunięcia konta | Programowe usuwanie przy kasowaniu konta | ✅ Tak | j.w. |
| **Dane płatnicze** (subskrypcje, zdarzenia płatnicze) | PostgreSQL Cloud SQL + Stripe (zewnętrzny) | **5 lat** od końca roku podatkowego, w którym dokonano ostatniej transakcji | Retencja podatkowa; dane na Stripe wg polityki Stripe | ❌ Ręczny (retencja podatkowa) | Art. 6(1)(c) RODO — obowiązek prawny (ordynacja podatkowa) |
| **Zgoda marketingowa** (`has_marketing_consent`) | PostgreSQL Cloud SQL | Do wycofania zgody lub usunięcia konta | Aktualizacja w profilu użytkownika | ✅ Tak (wycofanie); ❌ ewidencja zgód | Art. 6(1)(a) RODO — zgoda |
| **Tokeny push FCM** | Firebase FCM (usługa globalna Google) | Zarządzane przez Firebase; wygasają automatycznie | Firebase FCM lifecycle | ✅ Tak | Art. 6(1)(f) — uzasadniony interes (powiadomienia o usłudze) |

### 3.3. Dane operacyjne i techniczne

| Kategoria danych | Lokalizacja | Okres retencji | Mechanizm usuwania | Automatyczny? | Podstawa |
|---|---|---|---|---|---|
| **Logi systemowe** (Cloud Logging) | Google Cloud Logging | **30 dni** (domyślna retencja GCP) | Automatyczna rotacja Cloud Logging | ✅ Tak | Art. 6(1)(f) — bezpieczeństwo i diagnostyka |
| **Zdarzenia analityczne** (tabela wewnętrzna) | PostgreSQL Cloud SQL | **90 dni** | `PurgeOldAnalyticsEvents` w GDPR Purger | ✅ Tak | Art. 6(1)(f) — uzasadniony interes (diagnostyka produktu) |
| **Zdarzenia audytowe** (`audit_events`) | PostgreSQL Cloud SQL | **Czas nieokreślony** (wymóg rozliczalności) | Brak automatycznego usuwania | ❌ Nie | Art. 5(2) + 24(1) RODO — rozliczalność |
| **Klucze idempotencji** (`idempotency_keys`) | PostgreSQL Cloud SQL | **7 dni** | Automatyczne wygasanie | ✅ Tak | Techniczna deduplikacja żądań |
| **Wiadomości Pub/Sub** | Google Cloud Pub/Sub | **7 dni** (`message_retention_duration = 604800s`) | Automatyczna retencja Pub/Sub | ✅ Tak | Techniczna kolejka zdarzeń |
| **Kopie zapasowe bazy danych** | Google Cloud SQL Automated Backups | **Do 7 dni** (automated backup, PITR wyłączone na staging) | Automatyczna rotacja GCP | ✅ Tak | Art. 6(1)(f) — ciągłość działania; dane zaszyfrowane CMEK |
| **Komentarze feedback** (`report_feedback.comment`) | PostgreSQL Cloud SQL | **18 miesięcy** od utworzenia (ADR-DM-015) | Redakcja pola `comment` po 18 miesiącach; oceny liczbowe zachowane | ✅ Tak (planowane) | Art. 5(1)(e) — minimalizacja; ilościowy signal jakości AI jest retencjonowany |

---

## 4. Szczegóły Mechanizmów Automatycznych

### 4.1. GDPR Purger (Cloud Run Job)

**Lokalizacja w repozytorium:** `services/clinical-svc/cmd/purger/main.go`

Proces uruchamiany cyklicznie (planowane: Cloud Scheduler → Cloud Run Job), realizujący:
1. Pobranie wszystkich rekordów z `deleted_at` starszym niż 30 dni.
2. Trwałe (nieodwracalne) usunięcie w kolejności zapobiegającej naruszeniu FK:
   - Patient users → Patient files → Sessions → Patient notes
3. Usunięcie zdarzeń analitycznych starszych niż 90 dni.
4. Zapis zbiorczego zdarzenia audytowego (`audit_events` z `action = "purger.run"`).
5. Commit transakcji atomowej.

### 4.2. OLM (Object Lifecycle Management) — nagrania audio

**Konfiguracja Terraform:** `infra/modules/storage/main.tf`

```hcl
lifecycle_rule {
  condition {
    age = 2  # 48 godzin
  }
  action {
    type = "Delete"
  }
}
```

Niezależnie od statusu przetwarzania, każdy obiekt w zasobniku `audio-uploads` jest automatycznie i nieodwracalnie usuwany po 48 godzinach.

### 4.3. OLM — surowe wyniki STT

**Konfiguracja Terraform:** `infra/modules/storage/main.tf`

```hcl
lifecycle_rule {
  condition {
    age = 7  # 7 dni
  }
  action {
    type = "Delete"
  }
}
```

Bucket `transcripts-raw` z wynikami BatchRecognize — zaszyfrowany CMEK, automatyczne usunięcie po 7 dniach.

### 4.4. Szyfrowanie a retencja

Wszystkie dane szczególnych kategorii (PHI) podlegają **envelope encryption** (AEAD + Cloud KMS):
- Klucz KEK (Key Encryption Key) jest zarządzany w Cloud KMS (`superwizor-keyring/app-data-key`)
- Automatyczna rotacja KEK co **90 dni** (`rotation_period = "7776000s"`)
- Każdy rekord ma unikalny DEK (Data Encryption Key)
- Nawet w kopiach zapasowych dane pozostają nieczytelne bez dostępu do Cloud KMS
- Po trwałym usunięciu rekordów z bazy, DEK są usuwane wraz z nimi; odszyfrowanie z kopii zapasowych staje się niemożliwe po wygaśnięciu wersji KEK

---

## 5. Procedura Usuwania Danych po Zakończeniu Umowy

Po usunięciu Konta Użytkownika Profesjonalnego lub rozwiązaniu Umowy:

| Krok | Termin | Dane | Mechanizm |
|---|---|---|---|
| 1 | Natychmiast | Nagrania audio | Usunięte wcześniej (OLM 48h); brak działań |
| 2 | Natychmiast | Konto → `deleted_at = now()` | Soft delete |
| 3 | Natychmiast | Kartoteki, sesje, raporty, pamięć | Kaskadowy soft delete |
| 4 | Po 30 dniach | Wszystkie powyższe | GDPR Purger — trwałe usunięcie |
| 5 | Do 7 dni po purge | Kopie zapasowe | Automatyczne nadpisanie (Cloud SQL backup retention) |
| 6 | Zachowane | Dane fakturowe | 5 lat — wymóg podatkowy |
| 7 | Zachowane | Zdarzenia audytowe | Wymóg rozliczalności RODO |

---

## 6. Realizacja Praw Podmiotów Danych

### 6.1. Prawo do usunięcia (Art. 17 RODO)

**Dla Klientów (pacjentów):**  
Użytkownik Profesjonalny (Administrator) inicjuje usunięcie danych swojego Klienta za pośrednictwem interfejsu Aplikacji lub kontaktując się z Usługodawcą. Usługodawca realizuje żądanie za pomocą dedykowanych operacji DSAR:
- `SoftDeletePatientFileForDSAR` — soft delete kartoteki
- `SoftDeleteSessionsForDSAR` — soft delete wszystkich sesji
- `SoftDeletePatientNotesForDSAR` — soft delete notatek
- `SoftDeletePatientUserForDSAR` — soft delete użytkownika pacjenta

Trwałe usunięcie następuje po 30 dniach poprzez GDPR Purger.

**Dla Użytkowników Profesjonalnych:**  
Użytkownik może usunąć swoje konto za pośrednictwem funkcji „Usuń konto" w ustawieniach Aplikacji. Usunięcie konta jest operacją nieodwracalną i skutkuje kaskadowym usunięciem wszystkich powiązanych danych Klientów.

### 6.2. Prawo do eksportu (Art. 20 RODO)

Dedykowane zapytania SQL:
- `GetSessionsForExport` — eksport sesji z kartoteki
- `GetPatientNotesForExport` — eksport notatek

Dane są odszyfrowane w runtime i udostępnione Użytkownikowi Profesjonalnemu.

---

## 7. Przegląd i Aktualizacja

Niniejsza Polityka Retencji jest przeglądana:
- Co **6 miesięcy** w ramach regularnego audytu bezpieczeństwa.
- **Natychmiast** po każdej zmianie w architekturze przetwarzania danych, dodaniu Sub-procesora lub zmianie w przepisach prawa.
- Po każdym incydencie bezpieczeństwa dotyczącym danych osobowych.

Aktualizacje podlegają kontroli wersji w repozytorium kodu (`docs/compliance/`).

---

## 8. Zatwierdzenie

| Rola | Imię i nazwisko | Data | Podpis |
|---|---|---|---|
| Zarząd Euphire sp. z o.o. | _______________ | _______________ | _______________ |
| Radca prawny / IOD | _______________ | _______________ | _______________ |

---

*Dokument wygenerowany na podstawie analizy kodu źródłowego, konfiguracji infrastruktury (Terraform) oraz dokumentacji architektury SuperWizor AI w wersji z dnia 24.06.2026.*
