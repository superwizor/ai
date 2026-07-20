---
type: Compliance Specification
title: "Ocena Skutków dla Ochrony Danych (DPIA)"
description: "art. 35 RODO — Data Protection Impact Assessment"
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/compliance/03_DPIA_OCENA_SKUTKOW.md
tags: [compliance]
timestamp: 2026-06-24T18:11:41+02:00
---

# Ocena Skutków dla Ochrony Danych (DPIA)

**art. 35 RODO — Data Protection Impact Assessment**

**System:** Superwizor AI — Aplikacja wspierająca terapeutów w analizie sesji klinicznych z użyciem AI  
**Właściciel systemu:** Euphire sp. z o.o., ul. Odrzańska 10a/48, Kraków  
**KRS:** 0000907254 | **NIP:** 6793219020  
**Data sporządzenia:** ___________  
**Wersja:** 1.0 DRAFT — sekcja techniczna do uzupełnienia oceną prawną radcy prawnego  
**Sporządził (sekcja techniczna):** Na podstawie analizy kodu źródłowego i konfiguracji infrastruktury

---

## 1. Uzasadnienie Przeprowadzenia DPIA

Przeprowadzenie DPIA jest **bezwzględnie wymagane** na podstawie art. 35 ust. 3 RODO, ponieważ przetwarzanie spełnia jednocześnie następujące przesłanki:

| Przesłanka | Zastosowanie w SuperWizor AI |
|---|---|
| **Dane szczególnych kategorii** (art. 9 ust. 1) | Treść sesji terapeutycznych = dane dotyczące zdrowia psychicznego |
| **Przetwarzanie na dużą skalę** | Planowane wdrożenie komercyjne (SaaS) dla wielu terapeutów z wieloma pacjentami |
| **Nowe technologie** | Sztuczna inteligencja (LLM — Gemini 2.5 Pro), automatyczna transkrypcja mowy (Chirp 3), wektorowa baza pamięci (pgvector RAG) |
| **Automatyczne podejmowanie decyzji** | Automatyczna diaryzacja (przypisanie wypowiedzi do mówców), automatyczna klasyfikacja HiTOP (wymiarowa psychopatologia) |
| **Profilowanie** | Budowanie pamięci kontekstowej (RAG) — longitudinalny profil tematyczny pacjenta na podstawie wielu sesji |

Dodatkowo, przetwarzanie figuruje na **liście czynności wymagających DPIA** opublikowanej przez Prezesa UODO (pkt 1, 2, 3, 4, 8, 9, 10).

---

## 2. Systematyczny Opis Przetwarzania

### 2.1. Cel i charakter przetwarzania

SuperWizor AI jest narzędziem SaaS wspierającym Użytkowników Profesjonalnych (terapeutów, coachów, psychologów) w ich praktyce zawodowej. Główne funkcjonalności:

1. **Nagrywanie lub przesyłanie** nagrań audio sesji terapeutycznych
2. **Automatyczna transkrypcja** nagrań z identyfikacją mówców (diaryzacja)
3. **Generowanie raportów z sesji** przez sztuczną inteligencję
4. **Pomiary wymiarowe HiTOP** (Hierarchiczna Taksonomia Psychopatologii)
5. **Budowanie pamięci kontekstowej** (pseudonimizowane podsumowania sesji na potrzeby ciągłości terapeutycznej)
6. **Zarządzanie kartotekami pacjentów** i historią sesji

**Charakter:**
- Usługodawca (Euphire sp. z o.o.) jest **Podmiotem Przetwarzającym** danych Klientów (pacjentów)
- Użytkownik Profesjonalny (terapeuta) jest **Administratorem** danych swoich Klientów
- Przetwarzanie odbywa się **wyłącznie na udokumentowane polecenie Administratora** (DPA)

### 2.2. Diagram przepływu danych (Data Flow Diagram)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            URZĄDZENIE TERAPEUTY                             │
│  ┌─────────────────┐    ┌───────────────────┐    ┌──────────────────────┐   │
│  │ Flutter App iOS  │    │  Web App (Next.js) │    │  Mikrofon / Plik    │   │
│  │ / Android        │    │  app.superwizor.ai │    │  audio              │   │
│  └────────┬─────────┘    └────────┬──────────┘    └──────────┬──────────┘   │
│           │ HTTPS/gRPC            │ HTTPS/gRPC               │ nagranie     │
└───────────┼───────────────────────┼──────────────────────────┼──────────────┘
            │                       │                          │
            ▼                       ▼                          ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                     GOOGLE CLOUD PLATFORM (europe-central2)                  │
│                                                                               │
│  ┌─── 1. UPLOAD ──────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  ┌──────────────┐  signed URL  ┌───────────────────────────────────┐   │  │
│  │  │ ingestion-svc├─────────────►│ GCS: audio-uploads bucket         │   │  │
│  │  │ (Cloud Run)  │              │ • CMEK encrypted (audio-bucket-key)│  │  │
│  │  └──────┬───────┘              │ • OLM: auto-delete po 48h         │   │  │
│  │         │ Pub/Sub              └───────────────┬───────────────────┘   │  │
│  │         ▼ (audio.uploaded)                     │ nagranie (tymczasowo)│  │
│  └────────────────────────────────────────────────┼──────────────────────┘  │
│                                                    │                         │
│  ┌─── 2. TRANSKRYPCJA ────────────────────────────┼──────────────────────┐  │
│  │                                                 │                      │  │
│  │  ┌──────────────┐  BatchRecognize  ┌───────────▼──────────────────┐   │  │
│  │  │ stt-worker   ├────────────────►│ Vertex AI Speech-to-Text      │   │  │
│  │  │ (Cloud Func) │                 │ Chirp 3 (eu-speech endpoint)  │   │  │
│  │  └──────┬───────┘  ◄─────────────│ europe-west4 (Holandia, EOG)  │   │  │
│  │         │ transkrypcja            └───────────────────────────────┘   │  │
│  │         │ + diaryzacja                                                │  │
│  │         │ Pub/Sub (stt.completed)                                     │  │
│  └─────────┼────────────────────────────────────────────────────────────┘  │
│            │                                                                │
│  ┌─── 3. ANALIZA AI ──────────────────────────────────────────────────┐    │
│  │         ▼                                                          │    │
│  │  ┌──────────────┐  prompt       ┌─────────────────────────────┐   │    │
│  │  │ llm-worker   ├─────────────►│ Vertex AI Gemini 2.5 Pro     │   │    │
│  │  │ (Cloud Func) │   ◄──────────│ europe-west4 (Holandia, EOG) │   │    │
│  │  └──────┬───────┘  raport      └─────────────────────────────┘   │    │
│  │         │ + HiTOP                                                  │    │
│  │         │ + pamięć RAG      ┌─────────────────────────────────┐   │    │
│  │         │ embeddingi ──────►│ Vertex AI Text Embeddings        │   │    │
│  │         │                   │ europe-west4 (Holandia, EOG)     │   │    │
│  │         │                   └─────────────────────────────────┘   │    │
│  └─────────┼────────────────────────────────────────────────────────┘    │
│            │                                                              │
│  ┌─── 4. PRZECHOWYWANIE ─────────────────────────────────────────────┐   │
│  │         ▼                                                          │   │
│  │  ┌─────────────────────────────────────────────────────────┐      │   │
│  │  │ Cloud SQL PostgreSQL 16 + pgvector (europe-central2)    │      │   │
│  │  │ • CMEK encrypted (database-key)                         │      │   │
│  │  │ • SSL_MODE = ENCRYPTED_ONLY                             │      │   │
│  │  │ • VPC Connector (prywatny dostęp)                       │      │   │
│  │  │                                                         │      │   │
│  │  │ Dane zaszyfrowane ENVELOPE ENCRYPTION (AEAD + KMS):     │      │   │
│  │  │ • transcripts.transcript_ciphertext                     │      │   │
│  │  │ • therapist_reports.report_payload_ciphertext            │      │   │
│  │  │ • clinical_memory.long_term_memory_ciphertext           │      │   │
│  │  │ • patient_views.report_payload_ciphertext               │      │   │
│  │  │ • patient_notes.title/text_ciphertext                   │      │   │
│  │  │ • hitop_measurements.evidence_ciphertext                │      │   │
│  │  └─────────────────────────────────────────────────────────┘      │   │
│  │                                                                    │   │
│  │  ┌─────────────────────────────┐  ┌─────────────────────────┐     │   │
│  │  │ Cloud KMS (europe-central2) │  │ Firestore (eur-central2)│     │   │
│  │  │ superwizor-keyring:         │  │ • lustrzane statusy     │     │   │
│  │  │ • audio-bucket-key          │  │ • BEZ treści sesji      │     │   │
│  │  │ • database-key              │  │ • Security Rules        │     │   │
│  │  │ • secrets-key               │  └─────────────────────────┘     │   │
│  │  │ • app-data-key (envelope)   │                                   │   │
│  │  │ Rotacja KEK: co 90 dni     │                                   │   │
│  │  └─────────────────────────────┘                                   │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  ┌─── 5. USUWANIE (GDPR) ────────────────────────────────────────────┐   │
│  │  ┌──────────────┐                                                  │   │
│  │  │ GDPR Purger  │ ← Cloud Scheduler (cyklicznie)                  │   │
│  │  │ (Cloud Run   │ • Hard delete po 30 dniach soft delete           │   │
│  │  │  Job)        │ • Purge: users → files → sessions → notes       │   │
│  │  │              │ • Purge analytics > 90 dni                       │   │
│  │  │              │ • Audit event z podsumowaniem                    │   │
│  │  └──────────────┘                                                  │   │
│  └────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 2.3. Zakres danych

| Kategoria | Szczegóły | Szyfrowanie |
|---|---|---|
| Nagrania audio | Mowa: terapeuta + pacjent + ewentualnie inne osoby | CMEK (GCS) |
| Transkrypcja | Pełny tekst rozmowy z etykietami mówców | Envelope encryption (AEAD + KMS) |
| Raport z sesji | Analiza AI: podsumowanie, tematy, obserwacje, zalecenia | Envelope encryption |
| Pomiary HiTOP | Severity (1-10), confidence (0-1) na 6 wymiarach psychopatologicznych | Częściowo (evidence_ciphertext) |
| Metryki procesu | Alianse terapeutyczny, wgląd, intensywność emocji | Niezaszyfrowane (dane numeryczne) |
| Pamięć kontekstowa | Pseudonimizowane podsumowania + embeddingi | Envelope encryption |
| Notatki do pacjentów | Tytuł + treść notatki terapeutycznej | Envelope encryption |

### 2.4. Skala przetwarzania

| Metryka | Estymacja Soft Launch | Estymacja Skala |
|---|---|---|
| Liczba terapeutów (Użytkowników) | 10-50 | 500-5000 |
| Liczba pacjentów na terapeutę | 10-30 | 10-30 |
| Sesje/miesiąc na terapeutę | 20-80 | 20-80 |
| Całkowita liczba sesji/miesiąc | 200-4000 | 10 000-400 000 |
| Czas trwania sesji | 30-90 min | 30-90 min |
| Rozmiar transkrypcji | 5-20 KB (zaszyfrowane) | 5-20 KB |

---

## 3. Ocena Konieczności i Proporcjonalności

### 3.1. Konieczność przetwarzania

| Operacja | Uzasadnienie konieczności |
|---|---|
| Nagrywanie audio | Jedyne źródło danych — terapeuta nie wprowadza danych ręcznie; usuwane po transkrypcji (48h max) |
| Transkrypcja | Niezbędna do generowania raportu; nie jest możliwe generowanie analizy bezpośrednio z audio przez LLM bez transkrypcji |
| Analiza LLM | Główna funkcjonalność produktu — generowanie raportu klinicznego, co zajmowałoby terapeucie 30-60 min ręcznie |
| Pomiary HiTOP | Obiektywna, powtarzalna ocena wymiarowa — niemożliwa do wykonania ręcznie w czasie sesji |
| Pamięć RAG | Ciągłość terapeutyczna — terapeuta z 20+ pacjentami nie jest w stanie zapamiętać szczegółów każdej sesji; pseudonimizowana |
| Diaryzacja | Kluczowa dla jakości raportu — rozróżnienie wypowiedzi terapeuty i pacjenta |

### 3.2. Proporcjonalność — minimalizacja danych

| Środek minimalizacji | Implementacja |
|---|---|
| Audio usuwane natychmiast po transkrypcji | OLM 48h backstop — w praktyce usuwane w sekundach po STT |
| Neutralne etykiety mówców | "Osoba 1", "Osoba 2" — bez imion i nazwisk w etykietach |
| Pseudonimizacja pamięci RAG | Brak bezpośrednich identyfikatorów (imion, nazwisk, nazw miejsc) |
| Embeddingi z zredagowanym tekstem | `chunk_text_redacted` — „no PHI" |
| Raporty read-only | Terapeuta nie może edytować treści wygenerowanej przez AI (P4) |
| Brak trenowania na danych | Dane Klientów NIE są wykorzystywane do trenowania modeli AI |
| Firestore = lustro statusów | Firestore przechowuje wyłącznie UUIDs i statusy — żadnych treści sesji (ADR-006) |

### 3.3. Gwarancje praw podmiotów danych

| Prawo (RODO) | Sposób realizacji |
|---|---|
| Dostęp (Art. 15) | Export queries: `GetSessionsForExport`, `GetPatientNotesForExport`; odszyfrowanie w runtime |
| Sprostowanie (Art. 16) | Korekta etykiet mówców w UI; edycja kartoteki pacjenta |
| Usunięcie (Art. 17) | DSAR soft delete (`SoftDeletePatientFileForDSAR` etc.) → GDPR Purger hard delete 30 dni |
| Ograniczenie (Art. 18) | Soft delete bez purge (wstrzymanie automatycznego usuwania) |
| Przenoszenie (Art. 20) | Export w formacie tekstowym (transkrypcja, raport) |
| Sprzeciw (Art. 21) | Usunięcie konta / kartoteki na żądanie |

---

## 4. Matryca Ryzyk

### 4.1. Metodologia

Ocena ryzyka w skali:
- **Prawdopodobieństwo:** Niskie (1) / Średnie (2) / Wysokie (3)
- **Wpływ:** Niski (1) / Średni (2) / Wysoki (3) / Bardzo wysoki (4)
- **Ryzyko = Prawdopodobieństwo × Wpływ**

### 4.2. Scenariusze zagrożeń

| # | Scenariusz zagrożenia | Praw. | Wpływ | Ryzyko | Środki ograniczające | Ryzyko rezydualne |
|---|---|---|---|---|---|---|
| R-1 | **Wyciek transkrypcji z bazy danych** (nieautoryzowany dostęp do Cloud SQL) | 1 | 4 | 4 | Envelope encryption (AEAD + KMS CMEK), VPC Connector, SSL_ONLY, autoryzowane sieci IP, dedykowane SA | **Bardzo niskie** — dane nieczytelne bez KMS |
| R-2 | **Nieautoryzowany dostęp do Cloud KMS** (kompromitacja klucza KEK) | 1 | 4 | 4 | IAM Zero Trust (dedykowane SA z minimalnymi uprawnieniami), automatyczna rotacja KEK co 90 dni, Cloud Audit Log (ADMIN_READ), prevent_destroy na kluczach | **Bardzo niskie** — atak wymaga kompromitacji IAM + SA |
| R-3 | **Naruszenie konta terapeuty** (przejęcie konta, phishing) | 2 | 3 | 6 | Firebase Auth (email/hasło, Google SSO, Apple SSO), dostęp ograniczony do własnych kartotek, Firestore Security Rules | **Średnie** — brak MFA na email/hasło; rekomendacja: wdrożyć MFA |
| R-4 | **Wyciek danych z Vertex AI** (naruszenie w usłudze Google) | 1 | 4 | 4 | Dane nie opuszczają EOG (europe-west4), Google DPA, ISO 27001/27017/27018, SOC 1/2/3, dane nie są używane do trenowania modeli Google | **Niskie** — ryzyko zależne od bezpieczeństwa Google Cloud |
| R-5 | **Nieprawidłowa diaryzacja / etykiety** (atrybucja wypowiedzi do złego mówcy) | 2 | 2 | 4 | Neutralne etykiety (brak PII), możliwość korekty przez terapeutę, oznaczenie AI w UI (AI Act compliance), charakter pomocniczy | **Niskie** — błąd nie powoduje wycieku PII |
| R-6 | **Nieusunięcie nagrania audio po transkrypcji** (awaria OLM) | 1 | 3 | 3 | Podwójne zabezpieczenie: 1) programowe usuwanie po STT + 2) OLM 48h (niezależne); CMEK na bucket | **Bardzo niskie** — dwa niezależne mechanizmy |
| R-7 | **Dostęp pracownika/współpracownika do danych pacjentów** (insider threat) | 1 | 4 | 4 | Zasada need-to-know, dedykowane SA (brak globalnego dostępu), audit_events, Cloud SQL ograniczony do jednego IP administracyjnego, WIF (brak kluczy w CI) | **Niskie** — brak bezpośredniego dostępu deweloperów do danych PHI w produkcji |
| R-8 | **Incydent bezpieczeństwa — opóźnione wykrycie** | 2 | 3 | 6 | Cloud Logging + Monitoring, audit_events, alerting (do wdrożenia), procedura IR (do wdrożenia) | **Średnie** — brak formalnej procedury IR i alertów; rekomendacja: wdrożyć |
| R-9 | **Utrata danych (corruption, awaria DB)** | 1 | 4 | 4 | Automated Cloud SQL backups (CMEK), at-least-once Pub/Sub delivery, idempotencja pipeline, deletion_protection na instancji Cloud SQL | **Niskie** — wielowarstwowa ochrona |
| R-10 | **Halucynacja LLM w raporcie** (nieprawdziwe treści kliniczne) | 3 | 2 | 6 | Oznaczenie jako AI-generated (AI Act), raport read-only, HiTOP jako closed ontology (ADR-DM-006), obowiązek krytycznej oceny przez terapeutę (§4.7 Regulaminu), Aplikacja nie jest wyrobem medycznym (§4.5) | **Średnie** — akceptowalne, bo terapeuta sprawuje nadzór merytoryczny |
| R-11 | **Transfer danych poza EOG** (zmiana konfiguracji regionu) | 1 | 4 | 4 | Org policy blokująca inne regiony, Infrastructure as Code (Terraform) z code review, P3 Iron Localization, konfiguracja regionu pod kontrolą wersji | **Bardzo niskie** — org policy jest hard constraint |

### 4.3. Podsumowanie ryzyk

| Poziom ryzyka | Scenariusze | Ocena |
|---|---|---|
| **Bardzo niskie** (1-2) | R-1, R-2, R-6, R-11 | Akceptowalne — środki adekwatne |
| **Niskie** (3-4) | R-4, R-5, R-7, R-9 | Akceptowalne — monitorować |
| **Średnie** (5-6) | R-3, R-8, R-10 | Wymagają dodatkowych działań (patrz §5) |
| **Wysokie** (>6) | Brak | — |

---

## 5. Rekomendowane Działania Dodatkowe

Na podstawie oceny ryzyk, rekomendowane są następujące działania:

| # | Działanie | Priorytet | Dotyczy ryzyka | Status |
|---|---|---|---|---|
| D-1 | **Wdrożenie MFA** (Multi-Factor Authentication) dla logowania email/hasło | Wysoki | R-3 | ⬜ Do wdrożenia |
| D-2 | **Formalna procedura Incident Response** z SLA (48h powiadomienie Administratorów, 72h UODO) | Wysoki | R-8 | ⬜ Do wdrożenia (draft w Wewnętrznej Polityce) |
| D-3 | **Alerting bezpieczeństwa** (Cloud Monitoring alerty na anomalie: niestandardowe logi KMS, nietypowe wzorce dostępu do DB) | Średni | R-8 | ⬜ Do wdrożenia |
| D-4 | **Regularne testy penetracyjne** (co 12 miesięcy lub po istotnych zmianach) | Średni | R-1, R-2, R-7 | ⬜ Planowane na post-launch |
| D-5 | **Szkolenie zespołu** z zakresu ochrony danych osobowych i procedur bezpieczeństwa | Średni | R-7, R-8 | ⬜ Do wdrożenia |
| D-6 | **Jasny komunikat w UI** o ograniczeniach AI i obowiązku weryfikacji przez terapeutę | Niski | R-10 | ✅ Zaimplementowane (§4.7 Regulaminu, oznaczenia AI w UI) |
| D-7 | **Backup PITR** (Point-in-Time Recovery) dla produkcji | Średni | R-9 | ⬜ Wyłączone na staging; włączyć w produkcji |
| D-8 | **Rate limiting i abuse detection** na endpointach publicznych | Niski | R-3 | ⬜ Do wdrożenia |

---

## 6. Konsultacja z Organem Nadzorczym

Na podstawie przeprowadzonej oceny, **ryzyko rezydualne nie jest wysokie** — dzięki wielowarstwowym środkom bezpieczeństwa (envelope encryption, CMEK, Zero Trust, automatyczne usuwanie, pseudonimizacja, przetwarzanie wyłącznie w EOG).

**Wniosek:** Konsultacja z Prezesem UODO na podstawie art. 36 RODO **nie jest wymagana** na obecnym etapie, pod warunkiem wdrożenia działań D-1 do D-5 przed wejściem w fazę komercyjną.

> ⚠️ **UWAGA DLA RADCY PRAWNEGO:** Powyższy wniosek wymaga formalnej oceny prawnej. Sekcja techniczna (§2-4) stanowi wkład inżynierski; ocena adekwatności środków i konieczności konsultacji z UODO leży po stronie radcy prawnego.

---

## 7. Zatwierdzenie

| Rola | Imię i nazwisko | Data | Podpis |
|---|---|---|---|
| Zarząd Euphire sp. z o.o. | _______________ | _______________ | _______________ |
| Radca prawny / IOD | _______________ | _______________ | _______________ |
| CTO / Architekt systemu | _______________ | _______________ | _______________ |

---

## 8. Harmonogram Przeglądów

DPIA podlega przeglądowi:
- Co **12 miesięcy** (regularny przegląd)
- Po każdej **istotnej zmianie** w architekturze przetwarzania (nowy sub-procesor, nowy typ danych, zmiana regionu)
- Po każdym **incydencie bezpieczeństwa**
- Po **zmianie przepisów** (np. nowelizacja RODO, nowe wytyczne EROD/UODO)

---

*Dokument wygenerowany na podstawie analizy kodu źródłowego (Go, Terraform, SQL), konfiguracji infrastruktury GCP, modelu danych (docs/02_DATA_MODEL.md), dokumentacji architektury (docs/01_ARCHITEKTURA_TECHNICZNA.md), oraz dokumentów prawnych (Regulamin, Polityka Prywatności, DPA) SuperWizor AI w wersji z dnia 24.06.2026.*
