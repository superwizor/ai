---
type: System Documentation
title: "️ SUPERWIZOR AI — DOKUMENT ARCHITEKTURY TECHNICZNEJ"
description: "Wersja: 1.0 Stos: Google Cloud Platform \\+ Go 1.23 \\+ Cloud Run \\+ PostgreSQL 16 \\+ pgvector Region: europe-central2 (Warszawa) — bez wyjątków Powiązane doku..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/01_ARCHITEKTURA_TECHNICZNA.md
tags: [ai, analytics, architecture, billing, crm, database, frontend, identity, infrastructure, ingestion, notifications, security, testing]
timestamp: 2026-04-30T01:03:55+02:00
---

# 🏛️ SUPERWIZOR AI — DOKUMENT ARCHITEKTURY TECHNICZNEJ

**Wersja:** 1.0 **Stos:** Google Cloud Platform \+ Go 1.23 \+ Cloud Run \+ PostgreSQL 16 \+ pgvector **Region:** `europe-central2` (Warszawa) — bez wyjątków **Powiązane dokumenty:** `01_Architektura` (Konstytucja Projektu v3.0)

**Zasada nadrzędna:** Ten dokument opisuje *jak* technicznie realizujemy wymagania opisane w Konstytucji. W żadnym miejscu nie może wejść w konflikt z zasadami `Świętości Nagrania`, `Zero Trust`, `Żelaznej Lokalizacji` i `Blind Wall Principle`. W razie sprzeczności — Konstytucja wygrywa.

---

## 📋 SPIS TREŚCI

1. Executive Summary i decyzje architektoniczne  
2. Widok ogólny systemu (C4 Level 1–2)  
3. Warstwa Compute — Cloud Run \+ Cloud Run Jobs  
4. Podział na mikroserwisy (7 serwisów)  
5. Warstwa danych — Cloud SQL PostgreSQL 16 \+ pgvector  
6. Cloud Firestore jako warstwa synchronizacji mobilnej  
7. Cloud Storage — „Krematorium Audio"  
8. Pipeline AI — Pub/Sub \+ Vertex AI  
9. Komunikacja — gRPC (sync) \+ Pub/Sub (async)  
10. Bezpieczeństwo, IAM i CMEK  
11. Observability — Cloud Logging, Trace, Monitoring  
12. CI/CD i Infrastructure as Code  
13. Stos biblioteczny Go  
14. Organizacja repozytoriów (monorepo)  
15. Estymacja kosztów per tier klientów  
16. Roadmapa implementacji (12 tygodni do MVP)  
17. Ryzyka architektoniczne i mitigacje

---

## 1\. EXECUTIVE SUMMARY I DECYZJE ARCHITEKTONICZNE

### 1.1 Pryncypia (niepodważalne)

| \# | Pryncypium | Konsekwencja techniczna |
| :---- | :---- | :---- |
| P1 | **Zero Data Loss** | Idempotencja na każdym kroku pipeline'u, at-least-once delivery w Pub/Sub, zapasowe mechanizmy (OLM 48h) |
| P2 | **Zero Trust** | Każdy serwis ma dedykowane konto usługi (SA), minimum uprawnień, komunikacja tylko przez VPC Connector lub prywatne IP |
| P3 | **Żelazna Lokalizacja** | Wszystkie zasoby w `europe-central2`; Terraform `google_organization_policy` blokuje inne regiony |
| P4 | **Flutter → read-only na raporty AI** | Reguły Firestore \+ IAM \+ kontrakty gRPC wymuszają brak zapisu raportów z aplikacji mobilnej |
| P5 | **Czytelność \> mikrooptymalizacja kosztu DB** | Znormalizowany schemat PostgreSQL, osobne tabele dla `therapist_view` i `patient_view` |

### 1.2 Decyzje architektoniczne (ADR skrót)

| ADR | Decyzja | Uzasadnienie |
| :---- | :---- | :---- |
| ADR-001 | **Cloud Run** jako jedyny compute | Scale-to-zero \= niski OpEx dla MVP. Brak klastra do administrowania. Timeout 60 min wystarczy dla synchronicznego API; pipeline AI jest asynchroniczny przez Pub/Sub. |
| ADR-002 | **Cloud SQL PostgreSQL 16 \+ pgvector** | Relacyjny model ER z Konstytucji pasuje naturalnie. `pgvector` eliminuje potrzebę osobnego vector store (Pinecone, Qdrant) dla RAG. |
| ADR-003 | **Go 1.23** | Mały footprint RAM (krytyczne dla scale-to-zero i zimnych startów na Cloud Run), statyczne typowanie, doskonałe biblioteki GCP, gRPC natywnie. |
| ADR-004 | **Pub/Sub dla pipeline'u AI** | At-least-once delivery \+ DLQ \+ natywna retry policy. Naturalne dopasowanie do asynchronicznego flow Chirp 2 → RAG → Gemini. |
| ADR-005 | **gRPC dla wywołań synchronicznych** | Strong typing między serwisami, kontrakty `.proto` w repo, niski latency, natywne streaming (potrzebne dla push statusu sesji). |
| ADR-006 | **Firestore tylko jako warstwa synchronizacji mobilnej** | Klient mobilny subskrybuje dokument `session_state/{id}` i dostaje live update statusu. Firestore NIE jest źródłem prawdy — jest replikacją wybranych pól z PostgreSQL. |
| ADR-007 | **Monorepo z Go workspaces** | 7 serwisów współdzieli kontrakty `.proto`, modele domenowe i biblioteki pomocnicze. Mniej overhead versioningu niż multi-repo. |
| ADR-008 | **Terraform \+ Cloud Build** | IaC od dnia zero. Deploy przez Cloud Build → Artifact Registry → Cloud Deploy z canary. |

### 1.3 Czego *nie* robimy i dlaczego

- **Nie GKE** — koszt control plane (\~73 USD/mc) i overhead ops nieuzasadnione poniżej \~20 serwisów.  
- **Nie BigQuery jako głównej hurtowni** — zgodnie z instrukcją; analitykę robimy na read replice Cloud SQL przez najbliższe 12–18 miesięcy.  
- **Nie service mesh (Istio/Anthos)** — zbędna złożoność dla 7 serwisów; mTLS robimy przez VPC Service Controls \+ IAM tokens.  
- **Nie własny broker (Kafka/RabbitMQ)** — Pub/Sub daje SLA 99,95% i zero ops.  
- **Nie Kubernetes Operators dla AI** — Vertex AI jest managed; nie budujemy własnej orkiestracji modeli.

---

## 2\. WIDOK OGÓLNY SYSTEMU

### 2.1 Diagram kontekstu (C4 L1)

┌─────────────────────────────────────────────────────────────────────┐

│                           UŻYTKOWNICY                                │

├──────────────────────┬──────────────────────┬──────────────────────┤

│  Terapeuta (Flutter) │  Pacjent (Flutter)   │  Admin Kliniki (web) │

└──────────┬───────────┴──────────┬───────────┴──────────┬───────────┘

           │                      │                      │

           │ HTTPS/gRPC-Web       │ HTTPS/gRPC-Web       │ HTTPS

           │ Firestore SDK        │ Firestore SDK        │

           ▼                      ▼                      ▼

┌─────────────────────────────────────────────────────────────────────┐

│                      GOOGLE CLOUD LOAD BALANCER                      │

│                    (HTTPS \+ Cloud Armor WAF \+ CDN)                   │

└─────────────────────────────────┬───────────────────────────────────┘

                                  │

                                  ▼

┌─────────────────────────────────────────────────────────────────────┐

│                       CLOUD RUN (europe-central2)                    │

│  identity-svc │ billing-svc │ clinical-svc │ ingestion-svc           │

│  analytics-svc │ notification-svc                                    │

│                                                                      │

│  \+ CLOUD RUN JOBS: ai-pipeline-svc (workers sterowane Pub/Sub)       │

└──────┬──────────────┬──────────────┬──────────────┬─────────────────┘

       │              │              │              │

       ▼              ▼              ▼              ▼

┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐

│Cloud SQL │   │ Cloud    │   │ Pub/Sub  │   │Firestore │

│Postgres16│   │ Storage  │   │ (async)  │   │(mobile   │

│+pgvector │   │ (audio)  │   │          │   │ sync)    │

│ CMEK+HA  │   │ CMEK+OLM │   │          │   │          │

└──────────┘   └──────────┘   └────┬─────┘   └──────────┘

                                   │

                                   ▼

                           ┌───────────────┐

                           │   VERTEX AI   │

                           │  Chirp 2 USM  │

                           │  Gemini 3.1   │

                           │  Embeddings   │

                           └───────────────┘

### 2.2 Diagram kontenerów (C4 L2)

Zobacz sekcję 4 — szczegółowy opis każdego z 7 mikroserwisów, ich odpowiedzialności, zależności i kontraktów gRPC/Pub/Sub.

---

## 3\. WARSTWA COMPUTE — CLOUD RUN \+ CLOUD RUN JOBS

### 3.1 Rozdzielenie Services vs Jobs

**Cloud Run Services** (HTTP/gRPC, request-response):

- `identity-svc` — auth, RBAC, JWT validation  
- `billing-svc` — subskrypcje, limity  
- `clinical-svc` — CRUD kartotek, sesji, odczyt raportów  
- `ingestion-svc` — signed URLs, inicjalizacja upload  
- `analytics-svc` — agregaty B2B, dashboardy szefa kliniki  
- `notification-svc` — FCM push, WebSocket gateway

**Cloud Run Jobs** (długotrwałe, event-driven):

- `ai-pipeline-svc` — trzy oddzielne Jobs uruchamiane z Pub/Sub:  
  - `stt-worker` (Chirp 2, do 30 min)  
  - `llm-worker` (Gemini 3.1 PRO, do 10 min)  
  - `memory-compactor-worker` (kompresja `living_case_formulation`, do 5 min)

### 3.2 Konfiguracja Cloud Run (standard dla services)

\# Fragment Terraform (moduł per serwis)

resource "google\_cloud\_run\_v2\_service" "clinical\_svc" {

  name     \= "clinical-svc"

  location \= "europe-central2"

  ingress  \= "INGRESS\_TRAFFIC\_INTERNAL\_LOAD\_BALANCER"

  template {

    service\_account \= google\_service\_account.clinical\_svc.email

    scaling {

      min\_instance\_count \= 1      \# prod: 1, staging: 0 (scale-to-zero)

      max\_instance\_count \= 50

    }

    vpc\_access {

      connector \= google\_vpc\_access\_connector.main.id

      egress    \= "ALL\_TRAFFIC"

    }

    containers {

      image \= "${var.registry}/clinical-svc:${var.image\_tag}"

      resources {

        limits \= {

          cpu    \= "1"

          memory \= "512Mi"

        }

        cpu\_idle \= true  \# CPU throttled między requestami

        startup\_cpu\_boost \= true

      }

      startup\_probe {

        grpc { port \= 8080 }

        initial\_delay\_seconds \= 2

        timeout\_seconds       \= 3

        period\_seconds        \= 3

        failure\_threshold     \= 5

      }

      env {

        name  \= "DB\_CONN\_NAME"

        value \= google\_sql\_database\_instance.main.connection\_name

      }

      env {

        name \= "DB\_PASSWORD"

        value\_source {

          secret\_key\_ref {

            secret  \= google\_secret\_manager\_secret.db\_password.secret\_id

            version \= "latest"

          }

        }

      }

    }

  }

  traffic {

    type    \= "TRAFFIC\_TARGET\_ALLOCATION\_TYPE\_LATEST"

    percent \= 100

  }

}

**Kluczowe decyzje konfiguracji:**

- `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` — serwisy nie są publiczne; cały ruch klienta idzie przez globalny Load Balancer \+ Cloud Armor.  
- `min_instance_count = 1` dla prod — eliminuje zimne starty, koszt \~30 USD/mc/serwis.  
- `startup_cpu_boost = true` — skraca cold start z \~400 ms do \~150 ms (krytyczne dla Go, który i tak jest szybki).  
- gRPC health check na porcie 8080 (używamy `grpc.health.v1.Health`).

### 3.3 Cloud Run Jobs — konfiguracja workera

resource "google\_cloud\_run\_v2\_job" "llm\_worker" {

  name     \= "llm-worker"

  location \= "europe-central2"

  template {

    task\_count \= 1

    parallelism \= 1

    template {

      service\_account \= google\_service\_account.llm\_worker.email

      max\_retries     \= 0  \# Idempotencja: Pub/Sub retry, nie retry wewnętrzny Job

      timeout \= "900s"  \# 15 min hard cap

      containers {

        image \= "${var.registry}/llm-worker:${var.image\_tag}"

        resources {

          limits \= {

            cpu    \= "2"

            memory \= "2Gi"

          }

        }

        env {

          name  \= "SESSION\_ID"

          value \= ""  \# wstrzykiwane przy tworzeniu execution

        }

      }

    }

  }

}

Jobs są triggerowane przez Eventarc → Pub/Sub → Cloud Run Jobs API (`jobs.run`). Każde wywołanie tworzy izolowaną execution z własnym `sessionId` w zmiennej środowiskowej.

---

## 4\. PODZIAŁ NA MIKROSERWISY

Wariant A z ustaleń — 7 serwisów. Poniżej szczegółowa tabela \+ diagramy zależności.

### 4.1 Tabela odpowiedzialności

| Serwis | Bounded Context | Pryncypalne entity | API | Trigger |
| :---- | :---- | :---- | :---- | :---- |
| `identity-svc` | Tożsamość, RBAC | `User`, `Organization`, `Role` | gRPC (sync) | HTTP z LB |
| `billing-svc` | Rozliczenia | `Subscription`, `Plan`, `UsageCounter` | gRPC (sync) | HTTP \+ cron |
| `clinical-svc` | Rdzeń kliniczny | `PatientFile`, `Session`, `Modality`, `Report` | gRPC (sync) | HTTP z LB |
| `ingestion-svc` | Wejście audio | `UploadTicket`, signed URLs | gRPC (sync) | HTTP z LB |
| `ai-pipeline-svc` | Pipeline AI | `Transcript`, `RAGContext` | Pub/Sub (async) | Eventarc |
| `analytics-svc` | HiTOP, metryki B2B | `HiTOPMeasurement`, `Dashboard` | gRPC (sync) \+ cron | HTTP \+ Cloud Scheduler |
| `notification-svc` | Powiadomienia | `FcmToken`, `WebSocketConn` | gRPC \+ WebSocket | Pub/Sub → FCM |

### 4.2 Szczegóły każdego serwisu

#### 4.2.1 `identity-svc`

**Odpowiedzialność:**

- Weryfikacja JWT (Firebase Auth jako IdP — Flutter loguje się do Firebase, my walidujemy tokeny Firebase po stronie backendu).  
- CRUD profili `User`, `Organization`.  
- RBAC: rozstrzyganie „czy terapeuta X może czytać kartotekę Y".  
- Emisja wewnętrznych tokenów gRPC (service-to-service) — koszt obniżamy przez cache Redis.

**Publiczne metody gRPC (skrót `.proto`):**

service IdentityService {

  rpc ValidateToken(ValidateTokenRequest) returns (UserContext);

  rpc GetUser(GetUserRequest) returns (User);

  rpc UpdateProfile(UpdateProfileRequest) returns (User);

  rpc CheckPermission(CheckPermissionRequest) returns (PermissionDecision);

}

**Dlaczego Firebase Auth, a nie własny IdP:** Flutter ma natywną integrację, 2FA gotowe, koszt do 50k MAU \= 0 USD. Własny IdP to minimum 2 miesiące pracy i ryzyko dziur bezpieczeństwa.

#### 4.2.2 `billing-svc`

**Odpowiedzialność:**

- Twardy middleware w każdym wywołaniu `clinical-svc`: „czy organizacja ma jeszcze kredyty sesji w tym miesiącu?".  
- Integracja z bramką płatności (propozycja: **Stripe** — globalne wsparcie, dobre SDK Go, tryb subskrypcji out-of-the-box).  
- Webhook listener (Cloud Run service, endpoint `/stripe/webhook`) weryfikujący sygnatury Stripe.  
- Cron (Cloud Scheduler) — miesięczny reset liczników `UsageCounter`.

**Kluczowy problem: idempotencja kredytów.** Sesja musi „obciążyć" licznik dokładnie raz, nawet jeśli Pub/Sub dostarczy zdarzenie 2x. Rozwiązanie: tabela `usage_events (session_id UNIQUE, credits_consumed, created_at)` — `INSERT ... ON CONFLICT DO NOTHING`.

#### 4.2.3 `clinical-svc`

**Odpowiedzialność:**

- Rdzeń domeny. CRUD `PatientFile` \+ `Session`.  
- Odczyt `Report` (nigdy zapis z klienta — tylko pipeline AI pisze raporty).  
- Query API dla Flutter: lista kartotek, lista sesji, wyświetlenie raportu.  
- Dostarczanie kontekstu RAG dla `ai-pipeline-svc` (odczyt `clinical_memory`).

**Autoryzacja:** każdy endpoint wywołuje `identity-svc.CheckPermission` z kontekstem (`user_id`, `resource_id`, `action`). Serwis ma własny cache decyzji (5 min TTL) dla oszczędności.

#### 4.2.4 `ingestion-svc`

**Odpowiedzialność (cała magia bezpiecznego uploadu):**

1. Klient wywołuje `RequestUploadTicket(session_id, idempotency_key)`.  
2. Serwis sprawdza limit `billing-svc` → jeśli OK, generuje:  
   - V4 signed URL do Cloud Storage (TTL 15 min, metoda `PUT`, warunek: `Content-Type: audio/m4a`, `x-goog-content-length-range: 0,314572800` — max 300 MB).  
   - Wpis w tabeli `upload_tickets` z `status=PENDING`.  
3. Flutter uploaduje bezpośrednio do GCS (my NIE proxy'ujemy audio).  
4. GCS generuje event `OBJECT_FINALIZE` → Eventarc → Pub/Sub topic `audio.uploaded` → `ai-pipeline-svc`.

**Dlaczego signed URL zamiast uploadu przez backend:** 300 MB przez Cloud Run to koszt \~10 GB egress per 100 sesji (niepotrzebny wydatek) i 15-minutowy timeout request. Signed URL eliminuje oba problemy.

#### 4.2.5 `ai-pipeline-svc` — najbardziej krytyczny

Składa się z **trzech oddzielnych Cloud Run Jobs**, każdy ze swoim Pub/Sub topic:

| Worker | Trigger topic | Co robi | Output topic |
| :---- | :---- | :---- | :---- |
| `stt-worker` | `audio.uploaded` | Wywołuje Chirp 2, zapisuje `Transcript` do PG, **kasuje audio z GCS** | `transcript.ready` |
| `llm-worker` | `transcript.ready` | Pobiera RAG context, wywołuje Gemini, parsuje JSON (Zod-like w Go), zapisuje `Report` i `HiTOPMeasurement` | `report.ready` |
| `memory-compactor-worker` | `report.ready` | Aktualizuje `living_case_formulation` i `recent_vectors`, kompresuje kontekst jeśli \>10k tokenów | — |

**Krytyczne wymuszenia (z Konstytucji):**

- **Idempotencja:** każdy worker najpierw czyta `SELECT status FROM sessions WHERE id=$1 FOR UPDATE SKIP LOCKED`. Jeśli status już przeszedł dalej — ACK bez pracy.  
- **Structured Outputs:** kontrakt JSON Schema przekazany do Gemini przez `response_mime_type: application/json` \+ `response_schema`. W Go walidujemy bibliotekami `santhosh-tekuri/jsonschema`.  
- **Krematorium audio:** `stt-worker` po `INSERT INTO transcripts` wykonuje `storage.Bucket.Object.Delete()` i dopiero wtedy ACK Pub/Sub. Jeśli delete zawiedzie — retry całego etapu.  
- **Exponential backoff:** Pub/Sub subscription ma `retry_policy { minimum_backoff=10s, maximum_backoff=600s }` \+ DLQ po 6 próbach.

**Prompt engineering — struktura:** każdy worker ładuje `SystemPrompt` z PostgreSQL (tabela `modalities.prompt_*`), dzięki czemu zmiana promptu nie wymaga deployu — tylko migracji danych.

#### 4.2.6 `analytics-svc`

**Odpowiedzialność:**

- Odczyt HiTOP z tabel `hitop_measurements` (write-only dla `ai-pipeline-svc`) — widok agregatów przez **materialized views** w PG, odświeżane co 15 min.  
- API dla dashboardu B2B (Looker Studio łączy się przez Cloud SQL connector do read replica).  
- **Blind Wall Principle:** serwis ma fizyczny GRANT tylko do tabel `hitop_*`, `usage_*`, `session_metadata`. Brak dostępu do `transcripts`, `reports`, `clinical_memory`.

**Dlaczego osobny serwis, a nie endpoint w `clinical-svc`:** czytelna separacja uprawnień DB \+ możliwość dania czytelnego SLA (np. dashboardy mogą mieć 15 min opóźnienia, klinika tego nie zauważy).

#### 4.2.7 `notification-svc`

**Odpowiedzialność:**

- Subskrybuje Pub/Sub topic `report.ready` i inne eventy UX.  
- Wysyła FCM push do urządzenia terapeuty („Raport gotowy").  
- Utrzymuje WebSocket connection dla aplikacji Flutter w foreground (live status updates — alternatywa dla Firestore listenera, gdy aplikacja ma otwartą sesję).  
- Zapisuje stan `session.processingStatus` do Firestore (patrz sekcja 6\) — to jedyna ścieżka zapisu do Firestore z backendu.

### 4.3 Mapa zależności

Flutter ──┬──► identity-svc ──► PostgreSQL

          ├──► clinical-svc ──► PostgreSQL

          │        │

          │        └──► identity-svc (RBAC check)

          │        └──► billing-svc (quota check)

          │

          ├──► ingestion-svc ──► Cloud Storage (signed URL)

          │        │

          │        └──► billing-svc (reserve credit)

          │

          └──► Firestore (read-only session state)

Cloud Storage ──► Eventarc ──► Pub/Sub ──► ai-pipeline-svc

                                                │

                                                ├──► Vertex AI (Chirp 2\)

                                                ├──► Vertex AI (Gemini 3.1)

                                                ├──► PostgreSQL (transcripts, reports)

                                                └──► Pub/Sub ──► notification-svc

                                                                      │

                                                                      ├──► FCM

                                                                      └──► Firestore (state sync)

---

## 5\. WARSTWA DANYCH — CLOUD SQL POSTGRESQL 16 \+ PGVECTOR

### 5.1 Topologia instancji

| Środowisko | Maszyna | HA | Storage | Read replicas | Cost/mc (szacunek) |
| :---- | :---- | :---- | :---- | :---- | :---- |
| `staging` | db-custom-2-7680 (2 vCPU, 7,5 GB) | No | 50 GB SSD | 0 | \~95 USD |
| `prod` | db-custom-4-16384 (4 vCPU, 16 GB) | Yes (regional) | 100 GB SSD, auto-grow | 1 (analytics) | \~420 USD |

**Regional HA** \= failover automatyczny \< 60 s, synchronous replication na drugą strefę w `europe-central2`.

**Point-in-Time Recovery (PITR)** włączone — retention 7 dni dla prod.

### 5.2 Schema — mapping z Konstytucji

Encje z diagramu ER (sekcja 5 w Konstytucji) mapują się 1:1 na tabele. Poniżej kluczowe decyzje:

**Typy kolumn (konwencje):**

- `id` → `UUID DEFAULT gen_random_uuid() PRIMARY KEY`  
- `*_id` (FK) → `UUID NOT NULL REFERENCES ... ON DELETE RESTRICT`  
- Timestampy → `TIMESTAMPTZ NOT NULL DEFAULT now()`  
- Enumy (status, role) → typy `ENUM` PostgreSQL (np. `CREATE TYPE session_status AS ENUM (...)`)  
- JSON (wynik raportu, prompty) → `JSONB` z GIN indexem na polach wyszukiwania  
- Tekst długi (transkrypt, `living_case_formulation`) → `TEXT` \+ kompresja TOAST

**Wrażliwe kolumny z szyfrowaniem aplikacyjnym (envelope encryption przez Cloud KMS):**

- `transcripts.tekst_diaryzowany` — pełny transkrypt.  
- `reports.wynik_raportu` — JSON raportu.  
- `clinical_memory.pamiec_dlugotrwala_ai` — Living Case Formulation.  
- `patient_views.prywatny_dziennik_pacjenta`.

Proces: `AEAD(plaintext) → ciphertext + encrypted_dek` → `INSERT`. Klucze DEK rotowane per organizacja raz na 90 dni, KEK w Cloud KMS.

### 5.3 Przykładowe DDL (wycinek)

\-- Pamięć kliniczna z pgvector

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE clinical\_memory (

    id                      UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    patient\_file\_id         UUID NOT NULL REFERENCES patient\_files(id) ON DELETE CASCADE,

    \-- Living Case Formulation (szyfrowany)

    ltm\_ciphertext          BYTEA NOT NULL,

    ltm\_encrypted\_dek       BYTEA NOT NULL,

    ltm\_token\_count         INT NOT NULL,

    \-- Embedding LTM do wyszukiwania semantycznego

    ltm\_embedding           vector(768) NOT NULL,  \-- wymiar z Vertex AI text-embedding-005

    \-- Recent vectors (JSONB z listą ostatnich N faktów \+ ich embeddings)

    recent\_vectors          JSONB NOT NULL DEFAULT '\[\]'::jsonb,

    revision\_number         INT NOT NULL DEFAULT 0,  \-- ochrona przed race condition

    last\_synthesis\_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    created\_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated\_at              TIMESTAMPTZ NOT NULL DEFAULT now()

);

\-- Index HNSW dla szybkiego vector search (pgvector \>= 0.5)

CREATE INDEX ON clinical\_memory USING hnsw (ltm\_embedding vector\_cosine\_ops);

\-- Gwarancja „jedna pamięć per pacjent"

CREATE UNIQUE INDEX ON clinical\_memory (patient\_file\_id);

\-- Optimistic lock

CREATE OR REPLACE FUNCTION increment\_revision()

RETURNS TRIGGER AS $$

BEGIN

    NEW.revision\_number := OLD.revision\_number \+ 1;

    NEW.updated\_at := now();

    RETURN NEW;

END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER trg\_clinical\_memory\_revision

BEFORE UPDATE ON clinical\_memory

FOR EACH ROW EXECUTE FUNCTION increment\_revision();

### 5.4 pgvector dla RAG — architektura

**Scenariusz:** terapeuta ma 40 sesji z pacjentem. `llm-worker` potrzebuje kontekstu.

**Bez pgvector:** ładujemy całe 40 × 500 słów \= 20k słów ≈ 30k tokenów → wchodzimy w efekt "Lost in the Middle", koszt $$.

**Z pgvector:** Embedujemy bieżący transkrypt przez `text-embedding-005`, wyszukujemy top-K (np. 10\) najbardziej podobnych fragmentów z historii (`ORDER BY embedding <=> $1 LIMIT 10`), ładujemy tylko je \+ aktualne LTM (\~500 słów). Zysk: \~70% redukcja kosztów tokenów Gemini, lepsza jakość odpowiedzi.

**Kompresja kontekstu:** `memory-compactor-worker` co 10 sesji wywołuje Gemini PRO Thinking z promptem „skompresuj te 10 sesji do 500 słów kluczowych faktów" i nadpisuje LTM. Stare `recent_vectors` usuwamy (FIFO — trzymamy ostatnie 30).

### 5.5 Migracje i wersjonowanie schematu

- **Narzędzie:** `golang-migrate/migrate` — migracje SQL w repo (`/migrations/001_initial.up.sql` \+ `.down.sql`).  
- **Deploy:** migracje uruchamiane przez dedykowany Cloud Run Job w pipeline CI/CD, przed rolloutem nowej wersji serwisu.  
- **Zero-downtime:** zasada Expand-Contract — najpierw dodajemy kolumnę (expand), deploy nowego kodu czyta obie, potem usuwamy starą (contract w kolejnym release).

### 5.6 Połączenia i pooling

- **Cloud SQL Auth Proxy** jako sidecar w Cloud Run? **Nie** — używamy **Cloud SQL Connector** biblioteki Go (`cloud.google.com/go/cloudsqlconn`), która handshake'uje IAM bez proxy. Mniej moving parts.  
- **Connection pool per instancja Cloud Run:** `pgxpool` z `max_conns=10`. Cloud Run ma do 50 instancji × 10 \= 500 połączeń max. Cloud SQL db-custom-4-16384 obsługuje 400 połączeń → **potrzebujemy PgBouncer** (Cloud SQL ma go wbudowanego od 2024\) z trybem `transaction pooling`.

---

## 6\. CLOUD FIRESTORE JAKO WARSTWA SYNCHRONIZACJI MOBILNEJ

### 6.1 Filozofia użycia

**Firestore NIE jest bazą prawdy.** Jest replikacją wybranych, „live-update" pól z PostgreSQL, wyłącznie po to, aby aplikacja Flutter mogła je subskrybować bez pollowania.

### 6.2 Co trafia do Firestore

Tylko dwie kolekcje:

**`session_states/{sessionId}`:**

{

  "sessionId": "uuid",

  "therapistId": "uid",

  "status": "recording|uploading|transcribing|analyzing|done|failed",

  "progressPercent": 75,

  "errorCode": null,

  "updatedAt": 1714000000

}

**`user_notifications/{uid}/inbox/{notifId}`:**

{

  "type": "report\_ready",

  "sessionId": "uuid",

  "title": "Raport sesji gotowy",

  "createdAt": 1714000000,

  "readAt": null

}

### 6.3 Zapis — tylko z backendu

- Flutter ma `allow write: if false` na obu kolekcjach.  
- `notification-svc` używa Admin SDK z dedykowanym SA, mającym uprawnienie `roles/datastore.user` na projekcie z Firestore.  
- Każdy zapis do Firestore wykonywany jest w ramach tej samej SAGA, co zapis do PostgreSQL — z uwzględnieniem, że Firestore jest „nice to have" (retry z DLQ, ale nie blokuje ścieżki klinicznej).

### 6.4 Reguły Firestore

rules\_version \= '2';

service cloud.firestore {

  match /databases/{database}/documents {

    match /session\_states/{sessionId} {

      allow read: if request.auth \!= null && request.auth.uid \== resource.data.therapistId;

      allow write: if false;

    }

    match /user\_notifications/{uid}/inbox/{notifId} {

      allow read: if request.auth \!= null && request.auth.uid \== uid;

      allow update: if request.auth \!= null && request.auth.uid \== uid

                    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(\['readAt'\]);

      allow create, delete: if false;

    }

    match /{document=\*\*} {

      allow read, write: if false;

    }

  }

}

### 6.5 Koszt

Firestore jest tani przy tym modelu użycia: \~1M reads/miesiąc \= \~0,36 USD. Nawet przy 1000 aktywnych terapeutów i 50 sesjach/tydzień z live listenerami, miesięcznie to \<20 USD.

---

## 7\. CLOUD STORAGE — „KREMATORIUM AUDIO"

### 7.1 Struktura bucketów

| Bucket | Purpose | Storage class | Lifecycle |
| :---- | :---- | :---- | :---- |
| `superwizor-audio-prod-eu2` | Surowe audio z sesji | Standard | **OLM: delete after 48h** |
| `superwizor-backups-prod-eu2` | Backupy bazy, exporty | Nearline | 90 dni |
| `superwizor-assets-prod-eu2` | Statyczne assety (logo, i18n) | Standard | — |

Wszystkie buckety: `location=europe-central2`, CMEK przez Cloud KMS, uniform bucket-level access, public access prevention ON.

### 7.2 Polisa OLM (Dead Man's Switch)

resource "google\_storage\_bucket" "audio" {

  name                        \= "superwizor-audio-prod-eu2"

  location                    \= "europe-central2"

  storage\_class               \= "STANDARD"

  uniform\_bucket\_level\_access \= true

  public\_access\_prevention    \= "enforced"

  encryption {

    default\_kms\_key\_name \= google\_kms\_crypto\_key.audio.id

  }

  versioning { enabled \= false }  \# NIE wersjonujemy audio

  lifecycle\_rule {

    condition { age \= 2 }  \# dni

    action    { type \= "Delete" }

  }

  logging {

    log\_bucket \= google\_storage\_bucket.audit\_logs.name

  }

}

### 7.3 Signed URL — kontrakt

// ingestion-svc: generowanie ticketu uploadowego

func (s \*IngestionService) RequestUploadTicket(ctx context.Context, req \*pb.UploadRequest) (\*pb.UploadTicket, error) {

    // 1\. Authz \+ quota check (billing-svc)

    if err := s.billing.ReserveCredit(ctx, req.OrganizationId, req.SessionId); err \!= nil {

        return nil, status.Errorf(codes.ResourceExhausted, "quota exceeded: %v", err)

    }

    // 2\. Zapis ticketu do PG (idempotencja: PK \= idempotency\_key)

    if err := s.repo.CreateTicket(ctx, req.IdempotencyKey, req.SessionId); err \!= nil {

        if errors.Is(err, repo.ErrDuplicate) {

            return s.repo.GetExistingTicket(ctx, req.IdempotencyKey)

        }

        return nil, err

    }

    // 3\. Signed URL (V4, 15 min, constraint na Content-Type i rozmiar)

    objectPath := fmt.Sprintf("audio\_uploads/%s/%s/session.m4a", req.TherapistId, req.SessionId)

    url, err := s.storage.SignedURL(s.audioBucket, objectPath, \&storage.SignedURLOptions{

        Method:  "PUT",

        Expires: time.Now().Add(15 \* time.Minute),

        Headers: \[\]string{

            "Content-Type:audio/m4a",

            "x-goog-content-length-range:0,314572800",

        },

    })

    if err \!= nil {

        return nil, err

    }

    return \&pb.UploadTicket{UploadUrl: url, ExpiresAt: timestamppb.New(time.Now().Add(15 \* time.Minute))}, nil

}

---

## 8\. PIPELINE AI — PUB/SUB \+ VERTEX AI

### 8.1 Topiki Pub/Sub

| Topic | Producer | Consumer | Retention | DLQ |
| :---- | :---- | :---- | :---- | :---- |
| `audio.uploaded` | Eventarc (GCS) | `stt-worker` | 7 dni | `audio.uploaded.dlq` |
| `transcript.ready` | `stt-worker` | `llm-worker` | 7 dni | `transcript.ready.dlq` |
| `report.ready` | `llm-worker` | `memory-compactor-worker`, `notification-svc`, `analytics-svc` | 7 dni | per-subscription DLQ |
| `session.status_changed` | dowolny | `notification-svc` (Firestore sync) | 3 dni | jest |

### 8.2 Konfiguracja subskrypcji (kluczowe decyzje)

resource "google\_pubsub\_subscription" "llm\_worker" {

  name  \= "llm-worker-sub"

  topic \= google\_pubsub\_topic.transcript\_ready.id

  ack\_deadline\_seconds \= 600  \# 10 min — max czas obróbki Gemini

  retry\_policy {

    minimum\_backoff \= "10s"

    maximum\_backoff \= "600s"

  }

  dead\_letter\_policy {

    dead\_letter\_topic     \= google\_pubsub\_topic.transcript\_ready\_dlq.id

    max\_delivery\_attempts \= 6

  }

  message\_retention\_duration \= "604800s"  \# 7 dni

  expiration\_policy { ttl \= "" }  \# never expires

  enable\_message\_ordering \= false  \# kolejność nie ma znaczenia; idempotencja per session\_id

}

### 8.3 Flow pipeline'u — diagram sekwencji

Flutter          ingestion-svc     GCS         Eventarc      Pub/Sub       stt-worker

  │                    │            │             │            │              │

  │─req ticket────────►│            │             │            │              │

  │◄────signed URL─────│            │             │            │              │

  │                    │            │             │            │              │

  │────PUT audio──────────────────►│             │            │              │

  │                                 │─finalize──►│            │              │

  │                                 │            │─publish───►│              │

  │                                 │            │            │──pull───────►│

  │                                 │            │            │              │

  │                                 │            │            │    \[Chirp 2\] │

  │                                 │            │            │    \[INSERT\]  │

  │                                 │◄───delete audio────────────────────────│

  │                                 │            │            │              │

  │                                 │            │            │◄─ACK─────────│

  │                                 │            │            │

  │                                 │            │            │ ──pub transcript.ready──► llm-worker

  │                                 │            │            │

  │                                 │            │            │                           \[RAG\]

  │                                 │            │            │                           \[Gemini\]

  │                                 │            │            │                           \[parse JSON\]

  │                                 │            │            │                           \[INSERT reports\]

  │                                 │            │            │

  │                                 │            │            │ ◄─pub report.ready── (fan-out)

  │                                 │            │            │

  │                                 │            │            │    ─► memory-compactor

  │                                 │            │            │    ─► analytics-svc

  │                                 │            │            │    ─► notification-svc

  │                                 │            │            │                │

  │                                 │            │            │                ├─► FCM push

  │ ◄───────────── Firestore listener update ──────────────────────────────────┤

  │                                                                            └─► Firestore

### 8.4 Vertex AI — konfiguracja

**Chirp 2 (STT):**

// stt-worker

req := \&speechpb.BatchRecognizeRequest{

    Recognizer: "projects/" \+ projectID \+ "/locations/europe-west4/recognizers/\_", // Chirp 2 region

    Config: \&speechpb.RecognitionConfig{

        DecodingConfig: \&speechpb.RecognitionConfig\_AutoDecodingConfig{},

        Model:          "chirp\_2",

        LanguageCodes:  \[\]string{"pl-PL"},

        Features: \&speechpb.RecognitionFeatures{

            DiarizationConfig: \&speechpb.SpeakerDiarizationConfig{

                MinSpeakerCount: 2,

                MaxSpeakerCount: 2,  // terapia indywidualna; dla par/rodzin zwiększamy

            },

            EnableWordTimeOffsets: true,

            EnableAutomaticPunctuation: true,

        },

    },

    Files: \[\]\*speechpb.BatchRecognizeFileMetadata{

        {AudioSource: \&speechpb.BatchRecognizeFileMetadata\_Uri{Uri: gcsURI}},

    },

}

**Ważne:** Chirp 2 jest dostępny w wybranych regionach. `europe-west4` jest najbliższy dla `europe-central2` pod kątem latency (\~20 ms). Dane audio fizycznie przechodzą przez `europe-west4` podczas przetwarzania — **musimy udokumentować to w polityce prywatności**. Alternatywa: użycie `chirp` v1 (gorsza diarizacja) w `europe-central2`.

**Gemini 3.1 PRO z Structured Outputs:**

// llm-worker

schema := \&genai.Schema{Type: genai.TypeObject, Properties: map\[string\]\*genai.Schema{

    "public\_reports":            {Type: genai.TypeObject, /\* ... \*/},

    "safety\_alerts":             {Type: genai.TypeArray, Items: /\* ... \*/},

    "rag\_updates":               {Type: genai.TypeObject, /\* ... \*/},

    "hidden\_horizontal\_metrics": {Type: genai.TypeObject, /\* ... \*/},

}, Required: \[\]string{"public\_reports", "safety\_alerts", "rag\_updates", "hidden\_horizontal\_metrics"}}

model := client.GenerativeModel("gemini-3.1-pro")

model.ResponseMIMEType \= "application/json"

model.ResponseSchema \= schema

model.GenerationConfig.Temperature \= genai.Ptr\[float32\](0.2)  // stabilność klinicznej analizy

resp, err := model.GenerateContent(ctx, genai.Text(megaPrompt))

**Walidacja JSON w Go:** używamy `github.com/santhosh-tekuri/jsonschema/v5`. Jeśli walidacja padnie, wywołujemy **second-pass** — nowy request do Gemini z promptem „napraw ten JSON zgodnie ze schematem X, błąd walidacji: Y". Max 1 retry (chronimy się przed pętlą kosztu).

**Odpowiedź na pytanie Macieja („jak to sie stanie to co sie technicznie stanie?"):** Gemini przetwarza cały prompt jeszcze raz — nie umie „skupić się na fragmencie". Dlatego second-pass ma mniejszy prompt: tylko broken JSON \+ schema \+ instrukcja naprawy, bez oryginalnego transkryptu. Koszt naprawy \~5% kosztu głównego requestu.

---

## 9\. KOMUNIKACJA MIĘDZY SERWISAMI

### 9.1 Synchroniczna — gRPC

- **Protokół:** gRPC z `google.golang.org/grpc` \+ `protoc-gen-go`.  
- **Definicje .proto:** w monorepo w `/proto`, generowane do `/gen/go/...` przez `buf` (szybsze i lepsze niż ręczny `protoc`).  
- **Uwierzytelnianie service-to-service:** Cloud Run natywnie wspiera IAM — każdy serwis ma SA, a wywołanie gRPC dodaje `Authorization: Bearer <id-token>` podpisany przez metadata server. Serwis docelowy ma `roles/run.invoker` dla SA wywołującego.  
- **Deadlines:** każde wywołanie musi mieć `context.WithTimeout` (domyślnie 5 s dla read, 10 s dla write). Brak deadline \= błąd w code review.  
- **Retry:** klient gRPC ma `grpc.WithDefaultServiceConfig(retryPolicyJSON)` z retry tylko dla `UNAVAILABLE` i `DEADLINE_EXCEEDED`, max 3 próby, jittered backoff.

### 9.2 Asynchroniczna — Pub/Sub

- **Klient Go:** `cloud.google.com/go/pubsub` (StreamingPull, nie HTTP push).  
- **Message format:** Protobuf (te same definicje co gRPC) zakodowany binarnie w `Data`. Atrybuty wiadomości (`Attributes map[string]string`) zawierają tylko metadane routingu (`session_id`, `idempotency_key`, `trace_id`).  
- **Idempotencja:** każdy handler zaczyna od `SELECT ... FOR UPDATE SKIP LOCKED` na rekordzie sesji; jeśli stan już przeszedł dalej, ACK bez pracy.

### 9.3 Tabela wyborów

| Scenariusz | Protokół | Przykład |
| :---- | :---- | :---- |
| Request-response, \<1s | gRPC unary | `clinical-svc.GetSession` |
| Long-running, fire-and-forget | Pub/Sub | `audio.uploaded` → `stt-worker` |
| Streaming stan sesji | gRPC server streaming \+ Firestore | aplikacja w foreground → gRPC; w tle → Firestore |
| Push do klienta w tle | FCM przez `notification-svc` | powiadomienie „raport gotowy" |

---

## 10\. BEZPIECZEŃSTWO, IAM I CMEK

### 10.1 Model IAM

**Zasada:** każdy mikroserwis ma dedykowany SA. Brak współdzielenia. Brak `roles/editor`.

| Serwis | SA | Role |
| :---- | :---- | :---- |
| `identity-svc` | `identity-svc@...` | `roles/cloudsql.client`, `roles/secretmanager.secretAccessor`, `roles/firebase.auth.viewer` |
| `clinical-svc` | `clinical-svc@...` | `roles/cloudsql.client`, `roles/run.invoker` (do identity-svc, billing-svc) |
| `ingestion-svc` | `ingestion-svc@...` | `roles/storage.objectAdmin` (tylko bucket audio), `roles/cloudsql.client` |
| `ai-pipeline-svc` | `ai-pipeline-svc@...` | `roles/aiplatform.user`, `roles/cloudsql.client`, `roles/storage.objectAdmin` (tylko delete na bucket audio), `roles/pubsub.publisher` \+ `roles/pubsub.subscriber` |
| `analytics-svc` | `analytics-svc@...` | `roles/cloudsql.client` **tylko do read replica**, brak dostępu do bucketów audio |
| `notification-svc` | `notification-svc@...` | `roles/firebase.admin` (Firestore write), `roles/firebasecloudmessaging.admin` |
| `billing-svc` | `billing-svc@...` | `roles/cloudsql.client`, `roles/secretmanager.secretAccessor` (Stripe secret) |

### 10.2 CMEK (Customer-Managed Encryption Keys)

Cloud KMS keyring `superwizor-prod` z kluczami:

- `audio-bucket-key` (rotacja 90 dni) — szyfruje bucket audio.  
- `database-key` — używany przez Cloud SQL (encryption at rest).  
- `secrets-key` — dla Secret Manager.  
- `backup-key` — dla bucketu backupów.  
- `app-data-key` — dla envelope encryption w aplikacji (DEK szyfrowane tym KEK).

**Rotacja:** automatyczna, ale ze względu na wersjonowanie kluczy — stare dane pozostają odszyfrowywalne.

### 10.3 VPC i sieć

- Jeden Shared VPC `superwizor-prod-vpc` z subnet `europe-central2/10.0.0.0/20`.  
- Cloud Run używa Serverless VPC Access Connector dla połączeń do Cloud SQL (prywatne IP).  
- Cloud SQL **nie ma publicznego IP**.  
- Wszystkie API calls do Vertex AI idą przez Private Google Access (brak traffic przez internet).  
- VPC Service Controls — perimetr chroni Cloud SQL, GCS bucket audio, KMS.

### 10.4 Cloud Armor \+ Load Balancer

- Global HTTPS LB z managed SSL certyfikatem.  
- Cloud Armor policy:  
  - Rate limiting: 100 req/min per IP.  
  - WAF rules: preconfigured OWASP Top 10 (XSS, SQLi).  
  - Geo-restriction: allow only PL, UA, DE, EU w pierwszej fazie (ekspansja na komendę biznesową).  
  - reCAPTCHA Enterprise na endpoincie rejestracji.

### 10.5 Secrets

- **Secret Manager** dla wszystkich sekretów (DB password, Stripe key, Firebase service account).  
- **Never in code, never in env vars at build time** — tylko injection przy starcie Cloud Run (`value_source.secret_key_ref`).  
- Rotacja:  
  - DB password — co 180 dni (skrypt w Cloud Functions triggerowany Cloud Schedulerem).  
  - Stripe webhook secret — manualnie przy rotacji po stronie Stripe.

### 10.6 Audit Logging

- **Cloud Audit Logs** włączone dla wszystkich serwisów: Admin Activity (zawsze), Data Access (tylko dla PostgreSQL, GCS audio, KMS).  
- Logi trafiają do dedykowanego bucketu `superwizor-audit-logs-eu2` z 7-letnim retention (wymogi MedTech).  
- Alerty w Cloud Monitoring na wrażliwe eventy (np. pobranie klucza KMS przez nieoczekiwane SA).

---

## 11\. OBSERVABILITY

### 11.1 Logging

- **Cloud Logging** ze strukturyzowanymi logami JSON.  
- Biblioteka Go: `log/slog` z custom handlerem emitującym w formacie Cloud Logging (`severity`, `trace`, `spanId`, `httpRequest`).  
- **Zero PII policy:** własny middleware w gRPC interceptorze filtruje pola transkryptu, imion, JSON raportów. Automatyczny lintchek w CI: `grep -r "transcript\|patientName" internal/ | grep -i "log" → failure`.

### 11.2 Tracing

- **Cloud Trace** z OpenTelemetry.  
- Biblioteka Go: `go.opentelemetry.io/otel` \+ `opentelemetry-operator-grpc`.  
- Każdy request HTTP/gRPC dostaje `trace_id` propagowany przez nagłówek `traceparent`. Pub/Sub przenosi go w atrybucie wiadomości `trace_id`.  
- Sampling: 100% dla prod (mamy mały ruch — pełna widoczność jest tańsza niż blind debugging).

### 11.3 Metrics

- **Cloud Monitoring** — metryki custom \+ Cloud Run built-in.  
- Kluczowe metryki biznesowe:  
  - `pipeline.session.end_to_end_duration_seconds` (histogram)  
  - `pipeline.stage.duration_seconds{stage="stt|llm|compactor"}` (histogram)  
  - `pipeline.failure.count{stage, error_type}` (counter)  
  - `gemini.tokens.consumed{type="prompt|completion"}` (counter)  
  - `quota.sessions.remaining{organization_id}` (gauge)

### 11.4 SLO i alerting

| SLO | Target | Alert threshold |
| :---- | :---- | :---- |
| API availability (Cloud Run) | 99,9% | \<99% w 1h |
| Pipeline success rate (end-to-end) | 98% | \<95% w 1h |
| Pipeline latency (P95) | \<180 s | \>300 s w 15 min |
| Audio krematorium (% plików skasowanych w ciągu 5 min po STT) | 100% | \<100% |
| OLM fallback (% plików żyjących \>48h) | 0% | \>0% (critical) |

Alerty routowane do **PagerDuty** (prod) \+ Slack `#alerts-superwizor` (wszystkie środowiska).

### 11.5 Error tracking

- **Cloud Error Reporting** (automatyczne grupowanie stack traces z Cloud Logging).  
- Każdy Go service emituje panic z pełnym stack trace do Logging (severity ERROR) → Error Reporting grupuje.

### 11.6 Dashboardy

Dashboardy Cloud Monitoring w Terraform (`google_monitoring_dashboard`):

- **Ops Dashboard** — latencje, błędy, CPU/RAM per serwis.  
- **Pipeline Dashboard** — funnel sesji: uploaded → transcribed → analyzed → delivered; P50/P95/P99 per etap.  
- **Business Dashboard** — aktywne sesje/dzień, nowi terapeuci, użycie per plan.  
- **Cost Dashboard** — Vertex AI tokens, Cloud Run CPU-seconds, Cloud SQL disk, per organizacja.

---

## 12\. CI/CD I INFRASTRUCTURE AS CODE

### 12.1 Stack

- **Terraform 1.7+** — IaC dla całej infrastruktury GCP. State w GCS bucket `superwizor-tfstate-eu2` z versioning i state locking.  
- **Terragrunt** — DRY dla środowisk (staging/prod) z modułami per serwis.  
- **Cloud Build** — CI/CD. Trigger na push do `main` (staging) i tag semver (prod).  
- **Artifact Registry** — docker images \+ npm/go private modules.  
- **Cloud Deploy** — canary deployments (1% → 25% → 100%) z automatycznym rollback na bazie SLO.

### 12.2 Struktura Terraform

infra/

├── modules/

│   ├── cloud-run-service/

│   ├── cloud-run-job/

│   ├── pubsub-topic-with-dlq/

│   ├── cloud-sql-postgres/

│   ├── kms-keyring/

│   └── iam-service-account/

├── environments/

│   ├── staging/

│   │   ├── main.tf

│   │   ├── terragrunt.hcl

│   │   └── variables.tf

│   └── prod/

│       ├── main.tf

│       ├── terragrunt.hcl

│       └── variables.tf

└── organization/

    ├── org-policies.tf         \# region=europe-central2 wymuszony

    ├── vpc-service-controls.tf

    └── audit-logs.tf

### 12.3 Pipeline CI (Cloud Build)

\# cloudbuild.yaml (per serwis)

steps:

  \# 1\. Lint \+ format

  \- name: 'golangci/golangci-lint:v1.60'

    args: \['run', './...'\]

  \# 2\. Unit tests z coverage gate (min 80%)

  \- name: 'golang:1.23'

    args: \['go', 'test', '-race', '-coverprofile=cov.out', './...'\]

  \- name: 'golang:1.23'

    entrypoint: 'bash'

    args:

      \- '-c'

      \- |

        COVERAGE=$(go tool cover \-func=cov.out | grep total | awk '{print $3}' | sed 's/%//')

        \[ "$(echo "$COVERAGE \>= 80" | bc)" \= "1" \] || exit 1

  \# 3\. Integration tests (Testcontainers z Postgresem)

  \- name: 'golang:1.23'

    args: \['go', 'test', '-tags=integration', './...'\]

  \# 4\. Build obrazu

  \- name: 'gcr.io/cloud-builders/docker'

    args: \['build', '-t', '${\_REGION}-docker.pkg.dev/${PROJECT\_ID}/services/${\_SERVICE}:${SHORT\_SHA}', '.'\]

  \# 5\. Vulnerability scan

  \- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'

    args: \['gcloud', 'artifacts', 'docker', 'images', 'scan', '${\_REGION}-docker.pkg.dev/${PROJECT\_ID}/services/${\_SERVICE}:${SHORT\_SHA}'\]

  \# 6\. Push

  \- name: 'gcr.io/cloud-builders/docker'

    args: \['push', '${\_REGION}-docker.pkg.dev/${PROJECT\_ID}/services/${\_SERVICE}:${SHORT\_SHA}'\]

  \# 7\. Deploy (Cloud Deploy release)

  \- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'

    args: \['gcloud', 'deploy', 'releases', 'create', 'rel-${SHORT\_SHA}', '--delivery-pipeline=${\_SERVICE}', '--region=${\_REGION}'\]

### 12.4 Canary deployments

\# cloud-deploy/clouddeploy.yaml

apiVersion: deploy.cloud.google.com/v1

kind: DeliveryPipeline

metadata:

  name: clinical-svc

serialPipeline:

  stages:

    \- targetId: staging

      profiles: \[staging\]

    \- targetId: prod

      profiles: \[prod\]

      strategy:

        canary:

          runtimeConfig:

            cloudRun:

              automaticTrafficControl: true

          canaryDeployment:

            percentages: \[1, 25, 50\]

            verify: true

Verification hook: Cloud Build zadanie, które przez 5 min sprawdza SLO na canary (latencja, error rate). Jeśli regresja — auto-rollback.

---

## 13\. STOS BIBLIOTECZNY GO

### 13.1 Wersje i toolchain

- **Go 1.23** (najnowszy stable).  
- **Go workspaces** (go.work) dla monorepo.  
- **Linter:** `golangci-lint` z custom config (wymuszenie `errcheck`, `gosec`, `bodyclose`, `contextcheck`).  
- **Tests:** standard lib \+ `testify/require` (asercje) \+ `mocktail` ekwiwalent → **`gomock` v0.4** (official).  
- **Integration tests:** `testcontainers-go` dla Postgres, fake-gcs-server dla Cloud Storage emulacji.

### 13.2 Biblioteki — per obszar

| Obszar | Biblioteka | Uzasadnienie |
| :---- | :---- | :---- |
| HTTP server (gdzie potrzebne) | `go-chi/chi/v5` | Lekkie, standard lib-compatible, middleware-friendly |
| gRPC | `google.golang.org/grpc` | Oficjalna |
| Proto generation | `buf` | 10× szybsze niż protoc, wbudowany lint, breaking change detection |
| PostgreSQL | `jackc/pgx/v5` \+ `pgxpool` | Najszybszy driver Go dla PG, natywne LISTEN/NOTIFY |
| Cloud SQL IAM connection | `cloud.google.com/go/cloudsqlconn` | Bez Cloud SQL Proxy sidecara |
| Migrations | `golang-migrate/migrate/v4` | Standard, obsługa up/down, CLI |
| Pub/Sub | `cloud.google.com/go/pubsub` | Oficjalna, StreamingPull |
| Cloud Storage | `cloud.google.com/go/storage` | Oficjalna |
| Vertex AI | `cloud.google.com/go/aiplatform` \+ `google.golang.org/genai` | Oficjalne dla Gemini |
| Logging | `log/slog` (stdlib) \+ custom GCP handler | Od Go 1.21 w standard lib |
| Tracing | `go.opentelemetry.io/otel` \+ GCP exporter | Standard OpenTelemetry |
| Metrics | `go.opentelemetry.io/otel/metric` \+ GCP exporter | J/w |
| Config | `knadh/koanf/v2` | Hierarchiczny (env \+ file \+ secret), typed |
| Validation | `go-playground/validator/v10` | Standard w Go |
| JSON Schema | `santhosh-tekuri/jsonschema/v5` | Walidacja odpowiedzi Gemini |
| Crypto (envelope encryption) | `google.golang.org/api/cloudkms/v1` \+ `tink-go` | Google-backed, bezpieczne defaults |
| UUID | `google/uuid` | Standard |
| Circuit breaker | `sony/gobreaker` | Proste, dobrze utrzymywane |
| Rate limiting | `golang.org/x/time/rate` | Stdlib-adjacent |
| Testy — containers | `testcontainers/testcontainers-go` | Postgres w CI |
| Testy — mocki | `go.uber.org/mock` (mockgen) | Oficjalny następca golang/mock |

### 13.3 Wzorce domyślne

**Layout serwisu:**

services/clinical-svc/

├── cmd/server/main.go

├── internal/

│   ├── domain/          \# entity, value objects, domain services

│   ├── app/             \# use cases (application services)

│   ├── adapters/

│   │   ├── grpc/        \# gRPC handlers (transport)

│   │   ├── postgres/    \# repository impl

│   │   └── pubsub/      \# publisher impl

│   └── config/

├── proto/               \# symlink lub copy do global /proto

└── Dockerfile

Zgodne z **Hexagonal Architecture** — domena nie wie o Postgres, gRPC ani Pub/Sub.

**Middleware gRPC (obowiązkowe dla każdego serwisu):**

1. Panic recovery.  
2. Logging (z trace\_id).  
3. Metrics (prometheus-style).  
4. Auth (walidacja tokenów z `identity-svc`).  
5. Audit (dla mutacji — zapis do tabeli `audit_events`).

---

## 14\. ORGANIZACJA REPOZYTORIÓW (MONOREPO)

superwizor-backend/                        \# monorepo

├── go.work                                \# Go workspaces

├── Makefile                               \# jedno-linijkowe komendy: make test, make deploy

├── proto/                                 \# kontrakty gRPC

│   ├── identity/v1/\*.proto

│   ├── billing/v1/\*.proto

│   ├── clinical/v1/\*.proto

│   ├── ingestion/v1/\*.proto

│   ├── analytics/v1/\*.proto

│   ├── notification/v1/\*.proto

│   └── events/v1/\*.proto                  \# Pub/Sub event schemas

├── gen/go/                                \# wygenerowane stuby (commit)

├── pkg/                                   \# współdzielone biblioteki

│   ├── authz/

│   ├── cryptobox/                         \# envelope encryption wrapper

│   ├── errors/

│   ├── idempotency/

│   ├── logging/

│   ├── observability/

│   ├── pubsubx/                           \# wrapper Pub/Sub z retry, OTel

│   └── testutil/

├── services/

│   ├── identity-svc/

│   ├── billing-svc/

│   ├── clinical-svc/

│   ├── ingestion-svc/

│   ├── analytics-svc/

│   ├── notification-svc/

│   └── ai-pipeline-svc/

│       ├── cmd/stt-worker/

│       ├── cmd/llm-worker/

│       └── cmd/memory-compactor-worker/

├── migrations/                            \# SQL migrations (shared DB)

│   ├── 0001\_initial.up.sql

│   └── 0001\_initial.down.sql

├── infra/                                 \# Terraform

│   ├── modules/

│   └── environments/

├── docs/

│   ├── adr/                               \# Architecture Decision Records

│   ├── runbooks/                          \# operacje: jak reagować na alerty

│   └── diagrams/

├── .github/

│   └── workflows/                         \# (jeśli używamy GitHub Actions obok Cloud Build)

└── cloudbuild.yaml                        \# trigger top-level

**Dlaczego monorepo, a nie multi-repo:**

- Kontrakty `.proto` muszą być spójne — w multi-repo to koszmar wersjonowania.  
- Zmiany cross-serwisowe (np. nowy typ eventu) w jednym PR, z jednym code review.  
- Wspólne `pkg/` (observability, cryptobox) — bez konieczności publikacji jako biblioteka.  
- Koszt: wolniejszy CI przy dużym repo — mitigujemy przez Cloud Build trigger filters (`includedFiles`).

---

## 15\. ESTYMACJA KOSZTÓW PER TIER KLIENTÓW

### 15.1 Założenia modelu

- Rok 1, docelowo 500 aktywnych terapeutów, 50 sesji/terapeuta/miesiąc \= **25 000 sesji/mc**.  
- Średnia długość sesji: 50 min.  
- Audio 16kHz mono m4a: \~30 MB/sesja.  
- Transkrypt: \~10k znaków.  
- Prompt do Gemini: \~15k tokenów wejścia, \~8k wyjścia.

### 15.2 Koszt zmiennej — per sesja

| Komponent | Koszt / sesja | Uzasadnienie |
| :---- | :---- | :---- |
| Cloud Storage (upload \+ 48h retention) | \~$0,0005 | 30 MB × 2 dni × $0,020/GB/mc |
| Chirp 2 (STT) | \~$0,036 | 50 min × $0,00072/s |
| Gemini 3.1 PRO input | \~$0,019 | 15k tokens × $1,25 / 1M |
| Gemini 3.1 PRO output | \~$0,040 | 8k tokens × $5,00 / 1M |
| Embeddings (text-embedding-005) | \~$0,001 | 10k tokens × $0,025 / 1M |
| Pub/Sub \+ Cloud Run CPU/RAM | \~$0,002 | Nominalne |
| Cloud SQL writes | \~$0,0001 | \~20 rows × $0,01/100k |
| **Razem zmiennych / sesja** | **\~$0,099** | **\~0,40 PLN** |

### 15.3 Koszty stałe (infrastruktura)

| Komponent | Koszt / miesiąc |
| :---- | :---- |
| Cloud SQL (db-custom-4-16384, HA, 100GB SSD) | \~$420 |
| Cloud SQL read replica (db-custom-2-7680) | \~$160 |
| Cloud Run (6 serwisów, min=1, typowy ruch) | \~$180 |
| Cloud KMS | \~$10 |
| Cloud Load Balancer \+ Armor | \~$25 |
| Cloud Logging \+ Monitoring \+ Trace | \~$100 |
| Artifact Registry \+ Cloud Build | \~$40 |
| Firestore (session\_states \+ notifications) | \~$20 |
| Cloud Storage (backupy \+ audyty) | \~$30 |
| Egress (CDN \+ API) | \~$50 |
| **Razem stałych** | **\~$1 035** |

### 15.4 Model ceny dla terapeuty (weryfikacja marży)

| Plan | Cena sprzedaży | Sesje/mc | Koszt AI | Marża brutto |
| :---- | :---- | :---- | :---- | :---- |
| Solo | 299 PLN | 30 | \~12 PLN | 287 PLN (96%) |
| Pro | 499 PLN | 80 | \~32 PLN | 467 PLN (94%) |
| Klinika (20 terapeutów) | 5 999 PLN | 1 500 | \~600 PLN | 5 399 PLN (90%) |

**Break-even stałych kosztów:** \~20 terapeutów w planie Solo lub 7 w Pro.

### 15.5 Koszty przy skalowaniu (1 000 terapeutów, 50 000 sesji/mc)

- Zmienne: 50k × $0,099 \= **\~$4 950/mc**  
- Stałe (z upgrade'em Cloud SQL do db-custom-8-32768): **\~$1 800/mc**  
- **Łącznie: \~$6 750/mc ≈ 27 000 PLN** przy przychodzie \~400 000 PLN → marża \~93%.

**Wniosek:** architektura jest skalowalna kosztowo. Głównym ryzykiem kosztowym jest **Gemini PRO** — jeśli wyjdzie, że PRO jest over-spec dla zadania, migracja na Flash redukuje zmienny koszt o \~60%.

---

## 16\. ROADMAPA IMPLEMENTACJI (12 TYGODNI DO MVP)

### Faza 0 — Fundament (tydzień 1–2)

- [ ] Setup projektu GCP (staging \+ prod), Org Policies, Shared VPC, Cloud DNS.  
- [ ] Monorepo z go.work, `buf` config, pierwszy `.proto`.  
- [ ] Terraform modules (cloud-run-service, cloud-sql, kms, iam).  
- [ ] Cloud Build pipeline (lint → test → build → deploy do staging).  
- [ ] Cloud SQL PG 16 z pgvector, pierwsza migracja (schema core).

### Faza 1 — Tożsamość i dane (tydzień 3–4)

- [ ] `identity-svc` — integracja Firebase Auth, weryfikacja JWT, RBAC.  
- [ ] `clinical-svc` — CRUD PatientFile, Session, Modality (bez raportów).  
- [ ] Flutter integracja: logowanie, lista kartotek, lista sesji.  
- [ ] **Test E2E:** terapeuta loguje się, tworzy kartotekę, widzi ją.

### Faza 2 — Ingestion i audio (tydzień 5–6)

- [ ] `ingestion-svc` — signed URLs, tickets, idempotencja.  
- [ ] `billing-svc` v1 — liczniki sesji, integracja Stripe (tylko test mode).  
- [ ] Flutter: moduł nagrywania (wakelock, chunking, upload queue).  
- [ ] **Test E2E:** sesja kończy się uploadem do GCS, audit log widzi upload.

### Faza 3 — Pipeline AI (tydzień 7–9)

- [ ] `stt-worker` — Chirp 2, zapis transkryptu, delete audio z GCS.  
- [ ] `llm-worker` — Gemini 3.1 PRO z Structured Outputs, parsing, zapis raportu.  
- [ ] `memory-compactor-worker` — update LTM i recent\_vectors.  
- [ ] pgvector embeddings dla RAG.  
- [ ] **Test E2E:** sesja → transkrypt → raport → Firestore update → FCM push.

### Faza 4 — Obserwabilność i odporność (tydzień 10\)

- [ ] Cloud Monitoring dashboardy \+ SLO \+ alerty.  
- [ ] DLQ dla każdego topiku, runbook reakcji.  
- [ ] Chaos testing: kill random Cloud Run instance w staging.  
- [ ] Load test: 100 równoczesnych uploadów, pomiar P95 end-to-end.

### Faza 5 — Security hardening (tydzień 11\)

- [ ] Penetration test (zewnętrzny partner).  
- [ ] Review IAM, VPC SC, Cloud Armor rules.  
- [ ] GDPR: data processing agreement, privacy policy, prawo do zapomnienia (endpoint DELETE wszystkich danych terapeuty).

### Faza 6 — Beta z 5 terapeutami (tydzień 12\)

- [ ] Onboarding 5 zaufanych terapeutów.  
- [ ] Daily retro \+ hotfixes.  
- [ ] Feedback loop → priorytety na fazę 2 (analytics-svc, HiTOP, dashboardy B2B).

---

## 17\. RYZYKA ARCHITEKTONICZNE I MITIGACJE

| \# | Ryzyko | Prawdopodobieństwo | Impact | Mitigacja |
| :---- | :---- | :---- | :---- | :---- |
| R1 | **Gemini 3.1 PRO niedostępny w `europe-central2`** | Wysokie | Wysoki | Użycie `europe-west4` (najbliższy) i jawna informacja w polityce prywatności. Rozważenie Flash jako fallback. |
| R2 | **Chirp 2 diarizacja myli głosy przy cichym pacjencie** | Średnie | Wysoki | Kalibracja mikrofonu w Flutterze; threshold VAD po stronie aplikacji. W kolejnej iteracji — własny model post-processingu. |
| R3 | **Zbyt długi cold start Cloud Run (P99 \> 2s)** | Średnie | Średni | `min_instances=1` dla prod, `startup_cpu_boost`, mały binary Go (\<20 MB). |
| R4 | **Gemini halucynuje strukturę JSON mimo Structured Outputs** | Niskie | Wysoki | Walidacja JSON Schema, second-pass repair prompt, monitoring `json_repair_count`. |
| R5 | **Pub/Sub exactly-once niezabezpieczone** | Średnie | Wysoki | Twarda idempotencja w DB (`ON CONFLICT DO NOTHING` \+ `FOR UPDATE SKIP LOCKED`); klucz idempotentności z klienta. |
| R6 | **Cloud SQL connection exhaustion przy spike ruchu** | Średnie | Średni | Cloud SQL PgBouncer w trybie transaction pooling; rate limiting w Cloud Armor. |
| R7 | **Utrata klucza CMEK** | Bardzo niskie | Krytyczny | Automatyczna rotacja, zachowanie 3 ostatnich wersji, backup klucza w osobnym projekcie GCP. |
| R8 | **Akumulacja kosztów Gemini przez atak / bug** | Niskie | Wysoki | Cloud Billing budget alerts (50%, 80%, 100% miesięcznego budżetu → automatyczne wyłączenie `ai-pipeline-svc` przez Cloud Function). |
| R9 | **Vendor lock-in GCP** | Wysokie | Niski | Akceptujemy świadomie; alternatywy (AWS) podwajają czas MVP. Warstwa `pkg/` abstrahuje GCP SDK od logiki domenowej — teoretyczna migracja to przepisanie adapterów. |
| R10 | **Koszt egress Firestore przy dużej liczbie listenerów** | Niskie | Średni | Limit subskrypcji per user (max 50 aktywnych listeners), cleanup po 24h nieaktywności. |

---

## 18\. PUNKTY OTWARTE (WYMAGAJĄ DECYZJI PRODUKTOWEJ)

W trakcie projektowania pojawiły się kwestie wymagające decyzji poza architektem:

1. **HiTOP enum w JSON Schema** — konstytucja mówi o "zamkniętej ontologii". Potrzebujemy **klinicznego konsultanta**, który ukonkretni listę 50–200 objawów z definicjami operacyjnymi. Propozycja: sfinansować warsztat z konsorcjum HiTOP (koszt \~5–15k PLN za 3 dni pracy specjalisty).  
     
2. **Chirp 2 vs własny model STT** — Chirp 2 to black-box Google'a. Dla Enterprise klientów z wymogiem on-premise (kliniki państwowe) docelowo potrzebny **self-hosted Whisper Large v3** na GKE. Ale to \+3 miesiące pracy — w MVP zostajemy na Chirp 2\.  
     
3. **Retencja raportów** — konstytucja nie mówi, *jak długo* trzymamy raporty AI po deactywacji konta terapeuty. Rekomendacja: 5 lat (zgodnie z polską ustawą o zawodzie psychologa — prowadzenie dokumentacji). Po 5 latach automatyczny hard delete przez Cloud Scheduler → Cloud Function.  
     
4. **Plan B2B (rozdzielenie paneli terapeuta/pacjent)** — sugestia z dokumentu bazowego. Architektura jest gotowa (RBAC \+ osobna `patient_view`), ale UI i prompty trzeba zaprojektować. Pozostawiamy jako **feature fazy 2**.  
     
5. **Tryb Notatki Głosowej** (brak zgody pacjenta na nagrywanie) — konstytucja oznacza to jako „later feature". Technicznie to ten sam pipeline, inne prompty \+ krótsze audio. Zakładamy w fazie 2\.

---

## 📎 ZAŁĄCZNIKI

### A. Glosariusz

- **PHI** — Protected Health Information. Dane zdrowotne pod ochroną HIPAA / RODO art. 9\.  
- **PII** — Personally Identifiable Information.  
- **CMEK** — Customer-Managed Encryption Keys. Klucze szyfrujące w kontroli klienta (my), hostowane w Cloud KMS.  
- **DLQ** — Dead Letter Queue. Topic Pub/Sub dla wiadomości, które po X próbach nie zostały pomyślnie przetworzone.  
- **OLM** — Object Lifecycle Management. Polisa Cloud Storage automatycznie usuwająca obiekty po zadanym czasie.  
- **LTM / STM** — Long-Term / Short-Term Memory (pamięć długo- i krótkotrwała w kontekście RAG).  
- **RAG** — Retrieval-Augmented Generation. Wzbogacanie promptu LLM-a o kontekst wyszukany w bazie.  
- **SAGA** — Wzorzec transakcji rozproszonych (sekwencja lokalnych transakcji z compensating actions).  
- **Structured Outputs** — Wymuszenie przez LLM schematu JSON w odpowiedzi (Gemini feature).

### B. Referencje

- [Cloud Run — best practices for Go](https://cloud.google.com/run/docs/tips/go)  
- [Vertex AI Chirp 2 documentation](https://cloud.google.com/vertex-ai/docs/speech/recognizers/chirp-2)  
- [Gemini Structured Outputs](https://ai.google.dev/gemini-api/docs/structured-output)  
- [pgvector documentation](https://github.com/pgvector/pgvector)  
- [HiTOP Consortium](https://hitop-system.org)  
- [Kotov et al. 2017 — HiTOP manifest](https://doi.org/10.1037/abn0000258)

---

**Koniec dokumentu v1.0**

*Ten dokument jest żywy — każda zmiana architektoniczna wymaga ADR (Architecture Decision Record) w `/docs/adr/`. Zmiany dotyczące sekcji 5 (dane) i 10 (bezpieczeństwo) wymagają dodatkowego review Data Protection Officer.*  
