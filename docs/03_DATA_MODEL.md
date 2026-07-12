---
type: System Documentation
title: "️ SuperWizor AI — Data Model v4.3"
description: "Version: 4.3 (English, Stripe-ready, pgvector RAG, HiTOP closed ontology, Report Feedback domain, Invoicing extracted to external system) Database: PostgreSQ..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/03_DATA_MODEL.md
tags: []
timestamp: 2026-05-27T14:25:11+02:00
---

# 🗄️ SuperWizor AI — Data Model v4.3

**Version:** 4.3 (English, Stripe-ready, pgvector RAG, HiTOP closed ontology, Report Feedback domain, **Invoicing extracted to external system**) **Database:** PostgreSQL 16 \+ pgvector 0.7+ on Cloud SQL (`europe-central2`) **Language:** Go 1.23 (sqlc-compatible structs) **Status:** Single source of truth for the relational model. Replaces the ER diagram from `01_Architektura` (Konstytucja v3.0, section 5).

**Naming conventions:**

- Tables: `snake_case`, plural (`patient_files`, `sessions`)  
- Columns: `snake_case`, descriptive (`encrypted_dek`, not `dek`)  
- Primary keys: `id UUID DEFAULT gen_random_uuid()`  
- Foreign keys: `<entity>_id` (e.g., `therapist_id`, `patient_file_id`)  
- Timestamps: always `TIMESTAMPTZ`, suffix `_at` (e.g., `created_at`, `deleted_at`)  
- Booleans: prefix `is_` / `has_` / `can_` (e.g., `is_active`, `has_consent`)  
- Encrypted fields: suffix `_ciphertext` \+ companion `_encrypted_dek BYTEA`  
- Soft deletes: `deleted_at TIMESTAMPTZ NULL`

---

## 📋 Table of Contents

1. Overview & Architectural Decisions  
2. ER Diagram (Mermaid)  
3. Domain Areas & Module Map  
4. PostgreSQL DDL (full schema)  
5. Indexes & Performance Notes  
6. Go Structs (sqlc-style)  
7. Sample Queries (sqlc-annotated)  
8. Migration Strategy  
9. Closed-Ontology Lookup Tables (HiTOP)  
10. **Report Feedback Domain** *(new in v4.2)*  
11. Versioning & Change Log

---

## 1\. Overview & Architectural Decisions

### 1.1 Domain Areas (8 modules)

The schema is split into **8 logical domains**, each owned by a specific microservice:

| Domain | Owner Service | Tables |
| :---- | :---- | :---- |
| **Identity** | `identity-svc` | `users`, `organizations`, `addresses`, `user_roles` |
| **Billing** | `billing-svc` | `subscription_plans`, `subscriptions`, `payment_events`, `usage_counters` |
| **Clinical** | `clinical-svc` | `modalities`, `patient_files`, `therapist_patient_relations` |
| **Sessions** | `clinical-svc` | `sessions`, `transcripts`, `therapist_reports`, `patient_views`, `upload_tickets` |
| **Memory (RAG)** | `ai-pipeline-svc` | `clinical_memory`, `memory_revisions`, `embedding_chunks` |
| **Analytics (HiTOP)** | `analytics-svc` | `hitop_dimensions`, `hitop_symptoms`, `hitop_measurements`, `process_metrics` |
| **Feedback** | `clinical-svc` | `report_feedback`, `feedback_categories`, `report_feedback_categories` |
| **Audit & Ops** | shared | `audit_events`, `idempotency_keys` (the `outbox_events` table was retired 2026-05-27 with billing-svc Phase C — migration 000034 dropped it) |

**Note on invoicing:** Invoice generation, KSeF submission, VAT records and PDF rendering are handled by an **external invoicing system** (e.g. Fakturownia, iFirma, or similar SaaS). This database stores only the **`payment_events`** stream from Stripe/P24 webhooks — sufficient for subscription state management, revenue reporting, and reconciliation. The external system is the source of truth for legal accounting documents.

### 1.2 Key Design Decisions

| ADR | Decision | Rationale |
| :---- | :---- | :---- |
| **ADR-DM-001** | UUID v4 PKs (not bigserial) | Globally unique, safe for distributed gen, no info leak |
| **ADR-DM-002** | Envelope encryption for PHI columns | CMEK in Cloud KMS wraps DEK; DEK encrypts data column |
| **ADR-DM-003** | Soft delete via `deleted_at` (not hard delete) | GDPR `right to be forgotten` requires audit trail; hard delete via cron after retention |
| **ADR-DM-004** | RBAC via `users.role` enum (not separate roles table) | Two roles only: `THERAPIST`, `PATIENT`. Future: split if `ADMIN` etc. |
| **ADR-DM-005** | Therapist-Patient relations as M:N | Patient can change therapist; therapist has many patients |
| **ADR-DM-006** | HiTOP as closed ontology (lookup tables) | Prevents LLM hallucination; enables longitudinal tracking |
| **ADR-DM-007** | Optimistic locking via `revision_number` on memory | Prevents race conditions when AI pipeline updates LTM |
| **ADR-DM-008** | Patient-facing data isolated to `patient_views` | Prevents accidental exposure of therapist-only fields |
| **ADR-DM-009** | Outbox pattern for Pub/Sub publishing | Transactional consistency between DB writes and events |
| **ADR-DM-010** | All FKs `ON DELETE RESTRICT` (default) | Forces explicit cascade; prevents accidental data loss |
| **ADR-DM-011** *(v4.2)* | Feedback as separate domain (not columns on `therapist_reports`) | Append-only history, multi-rater extension, separate retention/RBAC, GDPR isolation |
| **ADR-DM-012** *(v4.2)* | Feedback categories as closed ontology (lookup table) | Structured signal for AI improvement; prevents free-text taxonomy chaos |
| **ADR-DM-013** *(v4.2)* | Per-section \+ overall feedback granularity | "OVERALL" is the always-present quick action; per-section is drill-down on low ratings |
| **ADR-DM-014** *(v4.2)* | Cloud DLP redaction on free-text comments | Therapists may inadvertently leak PHI in comments; DLP redacts before storage |
| **ADR-DM-015** *(v4.2)* | 18-month TTL on comment text (ratings persist) | Quantitative signal stays for trends; qualitative text expires for GDPR minimization |
| **ADR-DM-016** *(v4.3)* | Invoicing delegated to external system; only `payment_events` retained | Polish KSeF compliance, VAT calculations, PDF rendering, accounting integration are non-trivial; commercial SaaS (Fakturownia, iFirma) handles this for \~50 PLN/mo. We keep only the raw payment event stream for subscription logic and reconciliation. |

### 1.3 Encryption Strategy (envelope pattern)

Sensitive PHI columns use **two columns**:

- `<field>_ciphertext BYTEA NOT NULL` — AEAD-encrypted data  
- `<field>_encrypted_dek BYTEA NOT NULL` — DEK wrapped by KMS KEK

Encrypted columns:

- `transcripts.diarized_text_ciphertext`  
- `therapist_reports.report_payload_ciphertext`  
- `patient_views.report_payload_ciphertext`  
- `clinical_memory.long_term_memory_ciphertext`  
- `patient_views.private_journal_ciphertext`

---

## 2\. ER Diagram (Mermaid)

erDiagram

    %% \============================================

    %% IDENTITY DOMAIN

    %% \============================================

    addresses ||--o{ organizations : "headquarters"

    addresses ||--o{ users : "billing address"

    organizations ||--o{ users : "employs"

    %% \============================================

    %% BILLING DOMAIN

    %% \============================================

    organizations ||--o{ subscriptions : "has"

    subscription\_plans ||--o{ subscriptions : "defines"

    subscriptions ||--o{ payment\_events : "generates"

    subscriptions ||--o{ usage\_counters : "tracks"

    %% \============================================

    %% CLINICAL DOMAIN

    %% \============================================

    modalities ||--o{ users : "default modality"

    modalities ||--o{ patient\_files : "applied to"

    users ||--o{ therapist\_patient\_relations : "as therapist"

    users ||--o{ therapist\_patient\_relations : "as patient"

    therapist\_patient\_relations ||--|| patient\_files : "creates"

    %% \============================================

    %% SESSIONS DOMAIN

    %% \============================================

    patient\_files ||--o{ sessions : "contains"

    patient\_files ||--|| clinical\_memory : "aggregates"

    sessions ||--|| upload\_tickets : "uploaded via"

    sessions ||--|| transcripts : "transcribed to"

    sessions ||--|| therapist\_reports : "analyzed as"

    sessions ||--o| patient\_views : "shared with patient"

    %% \============================================

    %% MEMORY (RAG) DOMAIN

    %% \============================================

    clinical\_memory ||--o{ memory\_revisions : "history"

    clinical\_memory ||--o{ embedding\_chunks : "vectorized"

    sessions ||--o{ embedding\_chunks : "source"

    %% \============================================

    %% HiTOP ANALYTICS DOMAIN

    %% \============================================

    hitop\_dimensions ||--o{ hitop\_symptoms : "categorizes"

    hitop\_symptoms ||--o{ hitop\_measurements : "measured"

    sessions ||--o{ hitop\_measurements : "produces"

    sessions ||--o{ process\_metrics : "produces"

    %% \============================================

    %% FEEDBACK DOMAIN (v4.2)

    %% \============================================

    therapist\_reports ||--o{ report\_feedback : "rated by"

    sessions ||--o{ report\_feedback : "context"

    users ||--o{ report\_feedback : "rates"

    feedback\_categories ||--o{ report\_feedback\_categories : "tags"

    report\_feedback ||--o{ report\_feedback\_categories : "tagged with"

    %% \============================================

    %% AUDIT DOMAIN

    %% \============================================

    users ||--o{ audit\_events : "performs"

    organizations ||--o{ audit\_events : "scoped to"

    addresses {

        uuid id PK

        varchar country\_code

        varchar region

        varchar city

        varchar postal\_code

        varchar street\_line

        varchar building\_number

        varchar unit\_number

        text directions

        timestamptz created\_at

    }

    organizations {

        uuid id PK

        varchar legal\_name

        varchar tax\_id "NIP / VAT ID"

        varchar vat\_id\_eu

        uuid headquarters\_address\_id FK

        uuid primary\_admin\_user\_id FK

        organization\_type type

        timestamptz created\_at

        timestamptz deleted\_at

    }

    users {

        uuid id PK

        user\_role role "THERAPIST | PATIENT"

        uuid organization\_id FK

        uuid default\_modality\_id FK

        uuid billing\_address\_id FK

        varchar firebase\_uid UK

        varchar email UK

        varchar phone\_number

        boolean is\_email\_verified

        varchar first\_name

        varchar last\_name

        varchar professional\_title

        varchar credentials\_number

        text biography

        varchar avatar\_url

        varchar ui\_language

        varchar timezone

        boolean has\_accepted\_tos

        boolean has\_marketing\_consent

        timestamptz created\_at

        timestamptz deleted\_at

    }

    subscription\_plans {

        uuid id PK

        plan\_tier tier "SOLO|PRO|CLINIC|PATIENT"

        billing\_cycle cycle "MONTHLY|SEMI\_ANNUAL|ANNUAL"

        varchar display\_name

        numeric price\_gross

        char currency\_code

        int sessions\_limit

        int licenses\_limit

        boolean has\_b2b\_dashboard

        text marketing\_description

        varchar stripe\_price\_id

        varchar p24\_plan\_id

        varchar apple\_product\_id

        varchar google\_product\_id

        boolean is\_active

    }

    subscriptions {

        uuid id PK

        uuid organization\_id FK

        uuid plan\_id FK

        payment\_provider provider "STRIPE|P24|APPLE\_IAP|GOOGLE\_IAP"

        varchar provider\_subscription\_id UK

        subscription\_status status

        timestamptz current\_period\_start

        timestamptz current\_period\_end

        boolean cancel\_at\_period\_end

        timestamptz canceled\_at

        timestamptz trial\_end\_at

        timestamptz created\_at

    }

    payment\_events {

        uuid id PK

        uuid subscription\_id FK

        payment\_provider provider

        varchar provider\_event\_id UK "for idempotency"

        varchar event\_type

        numeric amount\_gross

        numeric amount\_net

        numeric vat\_rate

        char currency\_code

        jsonb raw\_payload

        timestamptz received\_at

    }

    usage\_counters {

        uuid id PK

        uuid subscription\_id FK

        date period\_start

        date period\_end

        int sessions\_used

        int sessions\_limit

        timestamptz updated\_at

    }

    modalities {

        uuid id PK

        varchar system\_code UK "UNIV|CBT|PSYCHO|GESTALT|PPT|ST|SYS|EFT|COACH"

        varchar display\_name

        jsonb therapist\_ai\_general\_prompt

        jsonb therapist\_ai\_section\_prompts

        jsonb patient\_ai\_general\_prompt

        jsonb patient\_ai\_section\_prompts

        boolean is\_supported

        timestamptz created\_at

    }

    therapist\_patient\_relations {

        uuid id PK

        uuid therapist\_id FK

        uuid patient\_id FK

        relation\_status status "INVITED|ACTIVE|PAUSED|TERMINATED"

        timestamptz invited\_at

        timestamptz activated\_at

        timestamptz terminated\_at

    }

    patient\_files {

        uuid id PK

        uuid therapist\_id FK

        uuid patient\_id FK

        uuid relation\_id FK

        uuid modality\_id FK

        varchar working\_alias

        process\_type process\_type "INDIVIDUAL|COUPLE|FAMILY"

        text initial\_complaint

        boolean is\_process\_closed

        boolean has\_recording\_consent

        timestamptz consent\_given\_at

        timestamptz first\_consultation\_at

        text private\_therapist\_notes

        timestamptz created\_at

        timestamptz deleted\_at

    }

    sessions {

        uuid id PK

        uuid patient\_file\_id FK

        uuid therapist\_id FK

        timestamptz session\_start\_at

        timestamptz session\_end\_at

        int duration\_seconds

        contact\_form contact\_form "OFFICE|ONLINE|FIELD|PHONE"

        varchar audio\_storage\_path

        timestamptz audio\_destroyed\_at

        session\_status processing\_status

        varchar error\_code\_ui

        numeric processing\_cost

        varchar idempotency\_key UK

        timestamptz created\_at

    }

    upload\_tickets {

        uuid id PK

        uuid session\_id FK

        uuid therapist\_id FK

        varchar idempotency\_key UK

        upload\_status status "PENDING|UPLOADED|PROCESSING|FAILED"

        bigint expected\_size\_bytes

        varchar signed\_url\_path

        timestamptz signed\_url\_expires\_at

        timestamptz uploaded\_at

        timestamptz created\_at

    }

    transcripts {

        uuid id PK

        uuid session\_id FK

        bytea diarized\_text\_ciphertext

        bytea diarized\_text\_encrypted\_dek

        int character\_count

        int identified\_speaker\_count

        int stt\_duration\_ms

        varchar stt\_model\_version

        timestamptz created\_at

    }

    therapist\_reports {

        uuid id PK

        uuid session\_id FK

        uuid modality\_used\_id FK

        bytea report\_payload\_ciphertext

        bytea report\_payload\_encrypted\_dek

        text reasoning\_scratchpad

        int prompt\_tokens\_used

        int completion\_tokens\_used

        varchar llm\_model\_version

        timestamptz created\_at

    }

    patient\_views {

        uuid id PK

        uuid session\_id FK

        uuid modality\_used\_id FK

        bytea report\_payload\_ciphertext

        bytea report\_payload\_encrypted\_dek

        bytea private\_journal\_ciphertext

        bytea private\_journal\_encrypted\_dek

        text next\_session\_agenda

        int post\_session\_mood\_rating

        timestamptz agenda\_filled\_at

        timestamptz created\_at

    }

    clinical\_memory {

        uuid id PK

        uuid patient\_file\_id FK

        bytea long\_term\_memory\_ciphertext

        bytea long\_term\_memory\_encrypted\_dek

        int long\_term\_memory\_token\_count

        vector long\_term\_memory\_embedding "vector(768)"

        jsonb recent\_fact\_vectors

        int revision\_number

        timestamptz last\_synthesized\_at

        timestamptz created\_at

        timestamptz updated\_at

    }

    memory\_revisions {

        uuid id PK

        uuid clinical\_memory\_id FK

        int revision\_number

        bytea snapshot\_ciphertext

        bytea snapshot\_encrypted\_dek

        varchar trigger\_session\_id

        varchar compressor\_model\_version

        timestamptz created\_at

    }

    embedding\_chunks {

        uuid id PK

        uuid clinical\_memory\_id FK

        uuid source\_session\_id FK

        text chunk\_text\_redacted "no PHI"

        vector chunk\_embedding "vector(768)"

        int chunk\_index

        embedding\_chunk\_type chunk\_type

        timestamptz created\_at

    }

    hitop\_dimensions {

        uuid id PK

        varchar code UK "INTERNALIZING|DETACHMENT|ANTAGONISM|DISINHIBITION|THOUGHT\_DISORDER|SOMATOFORM"

        varchar display\_name

        text behavioral\_definition

        int hierarchy\_level "1=spectrum, 2=subfactor, 3=syndrome"

        uuid parent\_dimension\_id FK

        boolean is\_active

    }

    hitop\_symptoms {

        uuid id PK

        uuid dimension\_id FK

        varchar code UK "ANHEDONIA|RUMINATION|SOCIAL\_WITHDRAWAL|..."

        varchar display\_name

        text operational\_definition

        text behavioral\_indicators

        boolean is\_active

    }

    hitop\_measurements {

        uuid id PK

        uuid session\_id FK

        uuid symptom\_id FK

        int severity "1-10"

        numeric confidence\_score "0.0-1.0"

        text supporting\_evidence\_redacted

        timestamptz measured\_at

    }

    process\_metrics {

        uuid id PK

        uuid session\_id FK

        int therapeutic\_alliance "1-10"

        int patient\_insight\_level "1-10"

        int emotional\_intensity "1-10"

        numeric cognitive\_rigidity "0.0-1.0"

        numeric agency\_locus "0.0-1.0 (passive→active)"

        timestamptz measured\_at

    }

    report\_feedback {

        uuid id PK

        uuid therapist\_report\_id FK

        uuid session\_id FK

        feedback\_target\_type target\_type "OVERALL|TRANSCRIPT|SUMMARY|..."

        uuid rater\_user\_id FK

        feedback\_source rater\_source "THERAPIST|PATIENT|SUPERVISOR"

        smallint rating "1-5 stars"

        text comment

        timestamptz comment\_redacted\_at

        timestamptz created\_at

        timestamptz updated\_at

        timestamptz deleted\_at

    }

    feedback\_categories {

        uuid id PK

        varchar code UK "HALLUCINATION|TOO\_GENERIC|ACCURATE\_ANALYSIS|..."

        varchar display\_name

        text description

        feedback\_category\_polarity polarity "POSITIVE|NEGATIVE|NEUTRAL"

        boolean is\_active

        int sort\_order

    }

    report\_feedback\_categories {

        uuid feedback\_id FK

        uuid category\_id FK

        timestamptz created\_at

    }

    audit\_events {

        uuid id PK

        uuid actor\_user\_id FK

        uuid organization\_id FK

        varchar action

        varchar resource\_type

        uuid resource\_id

        jsonb metadata

        inet ip\_address

        text user\_agent

        timestamptz occurred\_at

    }

    idempotency\_keys {

        varchar key PK

        varchar service\_name

        varchar operation

        jsonb response\_payload

        int response\_status

        timestamptz created\_at

        timestamptz expires\_at

    }

    outbox\_events {

        uuid id PK

        varchar aggregate\_type

        uuid aggregate\_id

        varchar event\_type

        jsonb payload

        outbox\_status status "PENDING|PUBLISHED|FAILED"

        int retry\_count

        timestamptz created\_at

        timestamptz published\_at

    }

---

## 3\. Domain Areas & Module Map

┌──────────────────────────────────────────────────────────────┐

│  IDENTITY              │  BILLING                            │

│  ─ addresses           │  ─ subscription\_plans               │

│  ─ organizations       │  ─ subscriptions                    │

│  ─ users               │  ─ payment\_events (Stripe webhooks) │

│  ─ user\_roles (enum)   │  ─ usage\_counters                   │

│                        │                                     │

│                        │  Note: invoices/VAT/PDF handled by  │

│                        │  external SaaS (Fakturownia, etc.)  │

├────────────────────────┼─────────────────────────────────────┤

│  CLINICAL              │  SESSIONS                           │

│  ─ modalities          │  ─ sessions                         │

│  ─ therapist\_patient\_  │  ─ upload\_tickets                   │

│    relations           │  ─ transcripts                      │

│  ─ patient\_files       │  ─ therapist\_reports                │

│                        │  ─ patient\_views                    │

├────────────────────────┼─────────────────────────────────────┤

│  MEMORY (RAG)          │  ANALYTICS (HiTOP)                  │

│  ─ clinical\_memory     │  ─ hitop\_dimensions                 │

│  ─ memory\_revisions    │  ─ hitop\_symptoms                   │

│  ─ embedding\_chunks    │  ─ hitop\_measurements               │

│                        │  ─ process\_metrics                  │

├────────────────────────┼─────────────────────────────────────┤

│  FEEDBACK              │  AUDIT & OPS                        │

│  ─ report\_feedback     │  ─ audit\_events                     │

│  ─ feedback\_categories │  ─ idempotency\_keys                 │

│  ─ report\_feedback\_    │  ─ outbox\_events                    │

│    categories          │                                     │

└────────────────────────┴─────────────────────────────────────┘

---

## 4\. PostgreSQL DDL — Full Schema

### 4.1 Extensions & Setup

\-- Enable required extensions

CREATE EXTENSION IF NOT EXISTS "pgcrypto";       \-- gen\_random\_uuid()

CREATE EXTENSION IF NOT EXISTS "vector";         \-- pgvector for RAG

CREATE EXTENSION IF NOT EXISTS "btree\_gin";      \-- composite GIN indexes

CREATE EXTENSION IF NOT EXISTS "pg\_trgm";        \-- trigram fuzzy search

\-- Set default timezone

SET timezone \= 'UTC';

### 4.2 Custom Types (ENUMs)

CREATE TYPE user\_role AS ENUM ('THERAPIST', 'PATIENT');

CREATE TYPE organization\_type AS ENUM ('SOLO', 'CLINIC', 'ENTERPRISE');

CREATE TYPE plan\_tier AS ENUM ('SOLO', 'PRO', 'CLINIC', 'PATIENT');

CREATE TYPE billing\_cycle AS ENUM ('MONTHLY', 'SEMI\_ANNUAL', 'ANNUAL');

CREATE TYPE payment\_provider AS ENUM ('STRIPE', 'P24', 'APPLE\_IAP', 'GOOGLE\_IAP', 'MANUAL');

CREATE TYPE subscription\_status AS ENUM (

    'TRIALING',

    'ACTIVE',

    'PAST\_DUE',

    'CANCELED',

    'INCOMPLETE',

    'PAUSED'

);

CREATE TYPE relation\_status AS ENUM ('INVITED', 'ACTIVE', 'PAUSED', 'TERMINATED');

CREATE TYPE process\_type AS ENUM ('INDIVIDUAL', 'COUPLE', 'FAMILY', 'GROUP');

CREATE TYPE contact\_form AS ENUM ('OFFICE', 'ONLINE', 'FIELD', 'PHONE');

CREATE TYPE session\_status AS ENUM (

    'CREATED',

    'RECORDING',

    'UPLOADING',

    'TRANSCRIBING',

    'ANALYZING',

    'COMPLETED',

    'FAILED',

    'CANCELED'

);

CREATE TYPE upload\_status AS ENUM ('PENDING', 'UPLOADED', 'PROCESSING', 'FAILED', 'EXPIRED');

CREATE TYPE embedding\_chunk\_type AS ENUM (

    'SESSION\_SUMMARY',

    'KEY\_FACT',

    'EMOTIONAL\_EVENT',

    'INSIGHT',

    'ACTION\_POINT'

);

CREATE TYPE outbox\_status AS ENUM ('PENDING', 'PUBLISHED', 'FAILED', 'EXPIRED');

\-- Feedback domain enums (v4.2)

CREATE TYPE feedback\_target\_type AS ENUM (

    'OVERALL',           \-- aggregate rating of the whole report

    'TRANSCRIPT',        \-- per-section ratings

    'SUMMARY',

    'ANALYSIS',

    'HYPOTHESES',

    'MECHANISMS',

    'ACTION\_POINTS',

    'SAFETY\_ALERTS',

    'PATIENT\_VIEW'       \-- rating of the patient-facing report

);

CREATE TYPE feedback\_source AS ENUM (

    'THERAPIST',

    'PATIENT',

    'SUPERVISOR'         \-- B2B clinic supervisor (future)

);

CREATE TYPE feedback\_category\_polarity AS ENUM ('POSITIVE', 'NEGATIVE', 'NEUTRAL');

### 4.3 IDENTITY Domain

\-- \============================================================

\-- ADDRESSES (shared by users and organizations)

\-- \============================================================

CREATE TABLE addresses (

    id                    UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    country\_code          CHAR(2) NOT NULL,                   \-- ISO 3166-1 alpha-2

    region                VARCHAR(100),                       \-- voivodeship/state

    city                  VARCHAR(100) NOT NULL,

    postal\_code           VARCHAR(20) NOT NULL,

    street\_line           VARCHAR(255) NOT NULL,

    building\_number       VARCHAR(20) NOT NULL,

    unit\_number           VARCHAR(20),

    directions            TEXT,

    created\_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk\_country\_code\_iso CHECK (country\_code \~ '^\[A-Z\]{2}$')

);

\-- \============================================================

\-- ORGANIZATIONS (clinic, solo therapist's "company of one")

\-- \============================================================

CREATE TABLE organizations (

    id                       UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    legal\_name               VARCHAR(255) NOT NULL,

    tax\_id                   VARCHAR(50),                     \-- NIP for PL

    vat\_id\_eu                VARCHAR(20),                     \-- EU VAT ID for VIES

    headquarters\_address\_id  UUID REFERENCES addresses(id) ON DELETE RESTRICT,

    primary\_admin\_user\_id    UUID,                            \-- FK added after users table created

    type                     organization\_type NOT NULL DEFAULT 'SOLO',

    created\_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    deleted\_at               TIMESTAMPTZ

);

CREATE INDEX idx\_organizations\_tax\_id ON organizations(tax\_id) WHERE deleted\_at IS NULL;

CREATE INDEX idx\_organizations\_vat\_id\_eu ON organizations(vat\_id\_eu) WHERE deleted\_at IS NULL;

\-- \============================================================

\-- USERS (therapists and patients)

\-- \============================================================

CREATE TABLE users (

    id                     UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    role                   user\_role NOT NULL,

    organization\_id        UUID REFERENCES organizations(id) ON DELETE RESTRICT,

    default\_modality\_id    UUID,                              \-- FK added after modalities

    billing\_address\_id     UUID REFERENCES addresses(id) ON DELETE SET NULL,

    \-- Auth & contact

    firebase\_uid           VARCHAR(128) NOT NULL UNIQUE,      \-- from Firebase Auth

    email                  VARCHAR(255) NOT NULL UNIQUE,

    phone\_number           VARCHAR(20),

    is\_email\_verified      BOOLEAN NOT NULL DEFAULT FALSE,

    \-- Profile

    first\_name             VARCHAR(100) NOT NULL,

    last\_name              VARCHAR(100) NOT NULL,

    professional\_title     VARCHAR(255),                      \-- "Certified CBT Psychotherapist"

    credentials\_number     VARCHAR(50),                       \-- license number

    biography              TEXT,

    avatar\_url             VARCHAR(500),

    \-- Preferences

    ui\_language            VARCHAR(10) NOT NULL DEFAULT 'pl',

    timezone               VARCHAR(50) NOT NULL DEFAULT 'Europe/Warsaw',

    \-- Consent

    has\_accepted\_tos       BOOLEAN NOT NULL DEFAULT FALSE,

    has\_marketing\_consent  BOOLEAN NOT NULL DEFAULT FALSE,

    \-- Lifecycle

    created\_at             TIMESTAMPTZ NOT NULL DEFAULT now(),

    deleted\_at             TIMESTAMPTZ,

    CONSTRAINT chk\_users\_email\_format CHECK (email \~\* '^\[a-zA-Z0-9.\_%+-\]+@\[a-zA-Z0-9.-\]+\\.\[a-zA-Z\]{2,}$')

);

CREATE INDEX idx\_users\_firebase\_uid ON users(firebase\_uid) WHERE deleted\_at IS NULL;

CREATE INDEX idx\_users\_organization\_id ON users(organization\_id) WHERE deleted\_at IS NULL;

CREATE INDEX idx\_users\_role ON users(role) WHERE deleted\_at IS NULL;

\-- Add deferred FK from organizations

ALTER TABLE organizations

    ADD CONSTRAINT fk\_organizations\_primary\_admin

    FOREIGN KEY (primary\_admin\_user\_id) REFERENCES users(id) ON DELETE RESTRICT;

### 4.4 BILLING Domain

\-- \============================================================

\-- SUBSCRIPTION PLANS

\-- \============================================================

CREATE TABLE subscription\_plans (

    id                      UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    tier                    plan\_tier NOT NULL,

    cycle                   billing\_cycle NOT NULL,

    display\_name            VARCHAR(100) NOT NULL,            \-- "Solo Monthly"

    price\_gross             NUMERIC(10,2) NOT NULL,

    currency\_code           CHAR(3) NOT NULL DEFAULT 'PLN',

    \-- Limits

    sessions\_limit          INT,                              \-- NULL \= unlimited

    licenses\_limit          INT,                              \-- for B2B clinic plans

    \-- Features

    has\_b2b\_dashboard       BOOLEAN NOT NULL DEFAULT FALSE,

    marketing\_description   TEXT,

    \-- Provider mappings

    stripe\_price\_id         VARCHAR(100),

    p24\_plan\_id             VARCHAR(100),

    apple\_product\_id        VARCHAR(100),

    google\_product\_id       VARCHAR(100),

    \-- Lifecycle

    is\_active               BOOLEAN NOT NULL DEFAULT TRUE,

    created\_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk\_plans\_currency CHECK (currency\_code \~ '^\[A-Z\]{3}$'),

    CONSTRAINT chk\_plans\_price CHECK (price\_gross \>= 0\)

);

CREATE UNIQUE INDEX idx\_plans\_tier\_cycle\_active ON subscription\_plans(tier, cycle)

    WHERE is\_active \= TRUE;

\-- \============================================================

\-- SUBSCRIPTIONS

\-- \============================================================

CREATE TABLE subscriptions (

    id                          UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    organization\_id             UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,

    plan\_id                     UUID NOT NULL REFERENCES subscription\_plans(id) ON DELETE RESTRICT,

    \-- Provider info

    provider                    payment\_provider NOT NULL,

    provider\_subscription\_id    VARCHAR(255) NOT NULL,

    provider\_customer\_id        VARCHAR(255),                \-- Stripe customer\_id, etc.

    \-- State

    status                      subscription\_status NOT NULL,

    current\_period\_start        TIMESTAMPTZ NOT NULL,

    current\_period\_end          TIMESTAMPTZ NOT NULL,

    cancel\_at\_period\_end        BOOLEAN NOT NULL DEFAULT FALSE,

    canceled\_at                 TIMESTAMPTZ,

    trial\_end\_at                TIMESTAMPTZ,

    created\_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated\_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (provider, provider\_subscription\_id)

);

CREATE INDEX idx\_subscriptions\_org\_status ON subscriptions(organization\_id, status);

CREATE INDEX idx\_subscriptions\_period\_end ON subscriptions(current\_period\_end)

    WHERE status IN ('ACTIVE', 'TRIALING');

\-- \============================================================

\-- PAYMENT EVENTS (event log, append-only)

\-- Source of truth for subscription lifecycle changes from Stripe/P24.

\-- These are raw webhook events; invoice generation is delegated to

\-- an external system (Fakturownia/iFirma/etc.) which reads this stream

\-- via outbox events or directly from Stripe.

\-- \============================================================

CREATE TABLE payment\_events (

    id                    UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    subscription\_id       UUID REFERENCES subscriptions(id) ON DELETE RESTRICT,

    provider              payment\_provider NOT NULL,

    provider\_event\_id     VARCHAR(255) NOT NULL,             \-- for idempotency

    event\_type            VARCHAR(100) NOT NULL,             \-- Stripe taxonomy: "invoice.paid", "customer.subscription.updated", etc.

    amount\_gross          NUMERIC(10,2),

    amount\_net            NUMERIC(10,2),

    vat\_rate              NUMERIC(5,4),                      \-- 0.2300 \= 23%

    currency\_code         CHAR(3),

    raw\_payload           JSONB NOT NULL,                    \-- complete webhook body — external invoicing system reads from here

    received\_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (provider, provider\_event\_id)                     \-- idempotency guard

);

CREATE INDEX idx\_payment\_events\_subscription ON payment\_events(subscription\_id, received\_at DESC);

CREATE INDEX idx\_payment\_events\_type ON payment\_events(event\_type, received\_at DESC);

\-- \============================================================

\-- USAGE COUNTERS (per billing period)

\-- \============================================================

CREATE TABLE usage\_counters (

    id                UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    subscription\_id   UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,

    period\_start      DATE NOT NULL,

    period\_end        DATE NOT NULL,

    sessions\_used     INT NOT NULL DEFAULT 0,

    sessions\_limit    INT,                                   \-- snapshot from plan

    updated\_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (subscription\_id, period\_start)

);

CREATE INDEX idx\_usage\_counters\_period ON usage\_counters(period\_start, period\_end);

### 4.5 CLINICAL Domain

\-- \============================================================

\-- MODALITIES (CBT, Schema, EFT, etc.)

\-- \============================================================

CREATE TABLE modalities (

    id                              UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    system\_code                     VARCHAR(20) NOT NULL UNIQUE,

    display\_name                    VARCHAR(100) NOT NULL,

    \-- AI prompts (JSONB allows hot-update without code deploy)

    therapist\_ai\_general\_prompt     JSONB NOT NULL DEFAULT '{}'::jsonb,

    therapist\_ai\_section\_prompts    JSONB NOT NULL DEFAULT '{}'::jsonb,

    patient\_ai\_general\_prompt       JSONB NOT NULL DEFAULT '{}'::jsonb,

    patient\_ai\_section\_prompts      JSONB NOT NULL DEFAULT '{}'::jsonb,

    is\_supported                    BOOLEAN NOT NULL DEFAULT TRUE,

    created\_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated\_at                      TIMESTAMPTZ NOT NULL DEFAULT now()

);

\-- Add deferred FK from users

ALTER TABLE users

    ADD CONSTRAINT fk\_users\_default\_modality

    FOREIGN KEY (default\_modality\_id) REFERENCES modalities(id) ON DELETE SET NULL;

\-- \============================================================

\-- THERAPIST-PATIENT RELATIONS (M:N)

\-- \============================================================

CREATE TABLE therapist\_patient\_relations (

    id              UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    therapist\_id    UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    patient\_id      UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    status          relation\_status NOT NULL DEFAULT 'INVITED',

    invited\_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    activated\_at    TIMESTAMPTZ,

    terminated\_at   TIMESTAMPTZ,

    CONSTRAINT chk\_relation\_different\_users CHECK (therapist\_id \!= patient\_id)

);

\-- A therapist-patient pair can only have ONE active relation at a time

CREATE UNIQUE INDEX idx\_relations\_unique\_active

    ON therapist\_patient\_relations(therapist\_id, patient\_id)

    WHERE status IN ('INVITED', 'ACTIVE');

CREATE INDEX idx\_relations\_therapist ON therapist\_patient\_relations(therapist\_id, status);

CREATE INDEX idx\_relations\_patient ON therapist\_patient\_relations(patient\_id, status);

\-- \============================================================

\-- PATIENT FILES (clinical case)

\-- \============================================================

CREATE TABLE patient\_files (

    id                          UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    therapist\_id                UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    patient\_id                  UUID REFERENCES users(id) ON DELETE RESTRICT,

    relation\_id                 UUID REFERENCES therapist\_patient\_relations(id) ON DELETE RESTRICT,

    modality\_id                 UUID NOT NULL REFERENCES modalities(id) ON DELETE RESTRICT,

    \-- Anonymous identification (no PII\!)

    working\_alias               VARCHAR(255) NOT NULL,        \-- "Woman, 34, social anxiety"

    process\_type                process\_type NOT NULL DEFAULT 'INDIVIDUAL',

    initial\_complaint           TEXT,

    \-- Consent & lifecycle

    is\_process\_closed           BOOLEAN NOT NULL DEFAULT FALSE,

    has\_recording\_consent       BOOLEAN NOT NULL DEFAULT FALSE,

    consent\_given\_at            TIMESTAMPTZ,

    first\_consultation\_at       TIMESTAMPTZ,

    \-- Therapist's private notes

    private\_therapist\_notes     TEXT,

    created\_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated\_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    deleted\_at                  TIMESTAMPTZ

);

CREATE INDEX idx\_patient\_files\_therapist ON patient\_files(therapist\_id) WHERE deleted\_at IS NULL;

CREATE INDEX idx\_patient\_files\_patient ON patient\_files(patient\_id) WHERE deleted\_at IS NULL;

CREATE INDEX idx\_patient\_files\_modality ON patient\_files(modality\_id) WHERE deleted\_at IS NULL;

### 4.6 SESSIONS Domain

\-- \============================================================

\-- SESSIONS (the core clinical event)

\-- \============================================================

CREATE TABLE sessions (

    id                       UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    patient\_file\_id          UUID NOT NULL REFERENCES patient\_files(id) ON DELETE RESTRICT,

    therapist\_id             UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    \-- Timing

    session\_start\_at         TIMESTAMPTZ NOT NULL,

    session\_end\_at           TIMESTAMPTZ,

    duration\_seconds         INT,

    \-- Context

    contact\_form             contact\_form NOT NULL DEFAULT 'OFFICE',

    \-- Audio lifecycle (the "radioactive" data path)

    audio\_storage\_path       VARCHAR(500),

    audio\_destroyed\_at       TIMESTAMPTZ,                    \-- when audio was deleted

    \-- Pipeline state

    processing\_status        session\_status NOT NULL DEFAULT 'CREATED',

    error\_code\_ui            VARCHAR(50),                    \-- localized error key

    processing\_cost          NUMERIC(10,4),                  \-- USD cost of pipeline

    \-- Idempotency (CRITICAL — generated client-side)

    idempotency\_key          VARCHAR(128) NOT NULL UNIQUE,

    created\_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated\_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk\_session\_duration CHECK (

        duration\_seconds IS NULL OR (duration\_seconds \> 0 AND duration\_seconds \<= 7200\)

    ),

    CONSTRAINT chk\_session\_times CHECK (

        session\_end\_at IS NULL OR session\_end\_at \> session\_start\_at

    )

);

CREATE INDEX idx\_sessions\_patient\_file ON sessions(patient\_file\_id, session\_start\_at DESC);

CREATE INDEX idx\_sessions\_therapist\_date ON sessions(therapist\_id, session\_start\_at DESC);

CREATE INDEX idx\_sessions\_status ON sessions(processing\_status)

    WHERE processing\_status IN ('UPLOADING', 'TRANSCRIBING', 'ANALYZING');

\-- \============================================================

\-- UPLOAD TICKETS (signed URL lifecycle)

\-- \============================================================

CREATE TABLE upload\_tickets (

    id                       UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    session\_id               UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,

    therapist\_id             UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    idempotency\_key          VARCHAR(128) NOT NULL UNIQUE,

    status                   upload\_status NOT NULL DEFAULT 'PENDING',

    expected\_size\_bytes      BIGINT,

    signed\_url\_path          VARCHAR(500),

    signed\_url\_expires\_at    TIMESTAMPTZ,

    uploaded\_at              TIMESTAMPTZ,

    created\_at               TIMESTAMPTZ NOT NULL DEFAULT now()

);

CREATE INDEX idx\_upload\_tickets\_session ON upload\_tickets(session\_id);

CREATE INDEX idx\_upload\_tickets\_status ON upload\_tickets(status, signed\_url\_expires\_at)

    WHERE status \= 'PENDING';

\-- \============================================================

\-- TRANSCRIPTS (encrypted)

\-- \============================================================

CREATE TABLE transcripts (

    id                              UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    session\_id                      UUID NOT NULL UNIQUE REFERENCES sessions(id) ON DELETE RESTRICT,

    \-- Envelope encryption

    diarized\_text\_ciphertext        BYTEA NOT NULL,

    diarized\_text\_encrypted\_dek     BYTEA NOT NULL,

    \-- Metadata (non-sensitive)

    character\_count                 INT NOT NULL,

    identified\_speaker\_count        INT NOT NULL,

    stt\_duration\_ms                 INT,

    stt\_model\_version               VARCHAR(50),              \-- "chirp\_2\_v20260101"

    created\_at                      TIMESTAMPTZ NOT NULL DEFAULT now()

);

\-- \============================================================

\-- THERAPIST REPORTS (encrypted, structured AI output)

\-- \============================================================

CREATE TABLE therapist\_reports (

    id                              UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    session\_id                      UUID NOT NULL UNIQUE REFERENCES sessions(id) ON DELETE RESTRICT,

    modality\_used\_id                UUID NOT NULL REFERENCES modalities(id) ON DELETE RESTRICT,

    \-- Encrypted JSONB report (7 sections \+ safety alerts)

    report\_payload\_ciphertext       BYTEA NOT NULL,

    report\_payload\_encrypted\_dek    BYTEA NOT NULL,

    \-- AI metadata

    reasoning\_scratchpad            TEXT,                    \-- Chain-of-thought (optional, RODO-deletable)

    prompt\_tokens\_used              INT,

    completion\_tokens\_used          INT,

    llm\_model\_version               VARCHAR(50),             \-- "gemini-3.1-pro-20260101"

    created\_at                      TIMESTAMPTZ NOT NULL DEFAULT now()

);

\-- \============================================================

\-- PATIENT VIEWS (sanitized version for patient access)

\-- \============================================================

CREATE TABLE patient\_views (

    id                              UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    session\_id                      UUID NOT NULL UNIQUE REFERENCES sessions(id) ON DELETE RESTRICT,

    modality\_used\_id                UUID NOT NULL REFERENCES modalities(id) ON DELETE RESTRICT,

    \-- Patient-facing report (neutral, no AI interpretation)

    report\_payload\_ciphertext       BYTEA NOT NULL,

    report\_payload\_encrypted\_dek    BYTEA NOT NULL,

    \-- Patient's private content

    private\_journal\_ciphertext      BYTEA,

    private\_journal\_encrypted\_dek   BYTEA,

    next\_session\_agenda             TEXT,                    \-- topics to discuss next

    \-- Self-rating

    post\_session\_mood\_rating        INT,                     \-- 1-10

    agenda\_filled\_at                TIMESTAMPTZ,

    created\_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk\_mood\_rating CHECK (

        post\_session\_mood\_rating IS NULL OR

        (post\_session\_mood\_rating BETWEEN 1 AND 10\)

    )

);

### 4.7 MEMORY (RAG) Domain

\-- \============================================================

\-- CLINICAL MEMORY (Living Case Formulation \+ RAG vectors)

\-- \============================================================

CREATE TABLE clinical\_memory (

    id                                UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    patient\_file\_id                   UUID NOT NULL UNIQUE REFERENCES patient\_files(id) ON DELETE CASCADE,

    \-- Long-Term Memory (encrypted Living Case Formulation)

    long\_term\_memory\_ciphertext       BYTEA NOT NULL,

    long\_term\_memory\_encrypted\_dek    BYTEA NOT NULL,

    long\_term\_memory\_token\_count      INT NOT NULL DEFAULT 0,

    \-- LTM embedding for semantic search (Vertex AI text-embedding-005, 768 dims)

    long\_term\_memory\_embedding        vector(768) NOT NULL,

    \-- Recent fact vectors (sliding window of last N session digests)

    recent\_fact\_vectors               JSONB NOT NULL DEFAULT '\[\]'::jsonb,

    \-- Concurrency control

    revision\_number                   INT NOT NULL DEFAULT 0,

    last\_synthesized\_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    created\_at                        TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated\_at                        TIMESTAMPTZ NOT NULL DEFAULT now()

);

\-- HNSW index for fast vector similarity search

CREATE INDEX idx\_clinical\_memory\_ltm\_embedding\_hnsw

    ON clinical\_memory USING hnsw (long\_term\_memory\_embedding vector\_cosine\_ops)

    WITH (m \= 16, ef\_construction \= 64);

\-- Optimistic locking trigger

CREATE OR REPLACE FUNCTION fn\_increment\_memory\_revision()

RETURNS TRIGGER AS $$

BEGIN

    NEW.revision\_number := OLD.revision\_number \+ 1;

    NEW.updated\_at := now();

    RETURN NEW;

END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER trg\_clinical\_memory\_revision

    BEFORE UPDATE ON clinical\_memory

    FOR EACH ROW EXECUTE FUNCTION fn\_increment\_memory\_revision();

\-- \============================================================

\-- MEMORY REVISIONS (audit trail of LTM changes)

\-- \============================================================

CREATE TABLE memory\_revisions (

    id                          UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    clinical\_memory\_id          UUID NOT NULL REFERENCES clinical\_memory(id) ON DELETE CASCADE,

    revision\_number             INT NOT NULL,

    \-- Snapshot of LTM at this revision

    snapshot\_ciphertext         BYTEA NOT NULL,

    snapshot\_encrypted\_dek      BYTEA NOT NULL,

    \-- Provenance

    trigger\_session\_id          UUID REFERENCES sessions(id) ON DELETE SET NULL,

    compressor\_model\_version    VARCHAR(50),

    created\_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (clinical\_memory\_id, revision\_number)

);

CREATE INDEX idx\_memory\_revisions\_memory ON memory\_revisions(clinical\_memory\_id, revision\_number DESC);

\-- \============================================================

\-- EMBEDDING CHUNKS (RAG retrieval index, redacted text only)

\-- \============================================================

CREATE TABLE embedding\_chunks (

    id                       UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    clinical\_memory\_id       UUID NOT NULL REFERENCES clinical\_memory(id) ON DELETE CASCADE,

    source\_session\_id        UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,

    \-- Redacted summary (NO PHI — safe for retrieval)

    chunk\_text\_redacted      TEXT NOT NULL,

    chunk\_embedding          vector(768) NOT NULL,

    chunk\_index              INT NOT NULL,

    chunk\_type               embedding\_chunk\_type NOT NULL,

    created\_at               TIMESTAMPTZ NOT NULL DEFAULT now()

);

CREATE INDEX idx\_embedding\_chunks\_memory ON embedding\_chunks(clinical\_memory\_id);

CREATE INDEX idx\_embedding\_chunks\_session ON embedding\_chunks(source\_session\_id);

CREATE INDEX idx\_embedding\_chunks\_hnsw

    ON embedding\_chunks USING hnsw (chunk\_embedding vector\_cosine\_ops)

    WITH (m \= 16, ef\_construction \= 64);

### 4.8 ANALYTICS (HiTOP) Domain

\-- \============================================================

\-- HiTOP DIMENSIONS (closed ontology — top of hierarchy)

\-- Reference: Kotov et al. 2017, 2021 — Annual Review of Clinical Psychology

\-- \============================================================

CREATE TABLE hitop\_dimensions (

    id                       UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    code                     VARCHAR(50) NOT NULL UNIQUE,

    display\_name             VARCHAR(255) NOT NULL,

    behavioral\_definition    TEXT NOT NULL,                  \-- operational definition for LLM

    hierarchy\_level          INT NOT NULL,                   \-- 1=spectrum, 2=subfactor, 3=syndrome

    parent\_dimension\_id      UUID REFERENCES hitop\_dimensions(id) ON DELETE RESTRICT,

    is\_active                BOOLEAN NOT NULL DEFAULT TRUE,

    created\_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk\_hitop\_hierarchy\_level CHECK (hierarchy\_level BETWEEN 1 AND 3\)

);

CREATE INDEX idx\_hitop\_dimensions\_parent ON hitop\_dimensions(parent\_dimension\_id);

CREATE INDEX idx\_hitop\_dimensions\_level ON hitop\_dimensions(hierarchy\_level);

\-- \============================================================

\-- HiTOP SYMPTOMS (closed ontology — leaf items)

\-- \============================================================

CREATE TABLE hitop\_symptoms (

    id                          UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    dimension\_id                UUID NOT NULL REFERENCES hitop\_dimensions(id) ON DELETE RESTRICT,

    code                        VARCHAR(100) NOT NULL UNIQUE,

    display\_name                VARCHAR(255) NOT NULL,

    operational\_definition      TEXT NOT NULL,

    behavioral\_indicators       TEXT,                       \-- bullet list of observable behaviors

    is\_active                   BOOLEAN NOT NULL DEFAULT TRUE,

    created\_at                  TIMESTAMPTZ NOT NULL DEFAULT now()

);

CREATE INDEX idx\_hitop\_symptoms\_dimension ON hitop\_symptoms(dimension\_id);

\-- \============================================================

\-- HiTOP MEASUREMENTS (per session, validated against ontology)

\-- \============================================================

CREATE TABLE hitop\_measurements (

    id                              UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    session\_id                      UUID NOT NULL REFERENCES sessions(id) ON DELETE RESTRICT,

    symptom\_id                      UUID NOT NULL REFERENCES hitop\_symptoms(id) ON DELETE RESTRICT,

    \-- Measurement

    severity                        INT NOT NULL,           \-- 1-10

    confidence\_score                NUMERIC(4,3) NOT NULL,  \-- 0.000-1.000

    supporting\_evidence\_redacted    TEXT,                   \-- safe excerpt, no PHI

    measured\_at                     TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (session\_id, symptom\_id),

    CONSTRAINT chk\_hitop\_severity CHECK (severity BETWEEN 1 AND 10),

    CONSTRAINT chk\_hitop\_confidence CHECK (confidence\_score BETWEEN 0 AND 1\)

);

CREATE INDEX idx\_hitop\_measurements\_session ON hitop\_measurements(session\_id);

CREATE INDEX idx\_hitop\_measurements\_symptom ON hitop\_measurements(symptom\_id, measured\_at DESC);

\-- \============================================================

\-- PROCESS METRICS (Common Factors — modality-independent)

\-- \============================================================

CREATE TABLE process\_metrics (

    id                          UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    session\_id                  UUID NOT NULL UNIQUE REFERENCES sessions(id) ON DELETE RESTRICT,

    \-- Process measures (1-10)

    therapeutic\_alliance        INT NOT NULL,

    patient\_insight\_level       INT NOT NULL,

    emotional\_intensity         INT NOT NULL,

    \-- Linguistic biomarkers (0.0-1.0)

    cognitive\_rigidity          NUMERIC(4,3) NOT NULL,      \-- always/never overuse

    agency\_locus                NUMERIC(4,3) NOT NULL,      \-- passive (0) → active (1)

    measured\_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk\_process\_alliance CHECK (therapeutic\_alliance BETWEEN 1 AND 10),

    CONSTRAINT chk\_process\_insight CHECK (patient\_insight\_level BETWEEN 1 AND 10),

    CONSTRAINT chk\_process\_intensity CHECK (emotional\_intensity BETWEEN 1 AND 10),

    CONSTRAINT chk\_process\_rigidity CHECK (cognitive\_rigidity BETWEEN 0 AND 1),

    CONSTRAINT chk\_process\_agency CHECK (agency\_locus BETWEEN 0 AND 1\)

);

### 4.9 FEEDBACK Domain *(new in v4.2)*

\-- \============================================================

\-- FEEDBACK CATEGORIES (closed ontology of qualitative tags)

\-- Seeded data, not user-editable.

\-- \============================================================

CREATE TABLE feedback\_categories (

    id              UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    code            VARCHAR(50) NOT NULL UNIQUE,

    display\_name    VARCHAR(100) NOT NULL,

    description     TEXT,

    polarity        feedback\_category\_polarity NOT NULL,

    is\_active       BOOLEAN NOT NULL DEFAULT TRUE,

    sort\_order      INT NOT NULL DEFAULT 0,

    created\_at      TIMESTAMPTZ NOT NULL DEFAULT now()

);

CREATE INDEX idx\_feedback\_categories\_polarity

    ON feedback\_categories(polarity, sort\_order)

    WHERE is\_active \= TRUE;

\-- \============================================================

\-- REPORT FEEDBACK (ratings \+ optional comments)

\-- One row per (report, rater, target\_type) — supports OVERALL \+ per-section.

\-- \============================================================

CREATE TABLE report\_feedback (

    id                    UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    \-- Target of feedback

    therapist\_report\_id   UUID NOT NULL REFERENCES therapist\_reports(id) ON DELETE CASCADE,

    session\_id            UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,

    target\_type           feedback\_target\_type NOT NULL,

    \-- Who gave the feedback

    rater\_user\_id         UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    rater\_source          feedback\_source NOT NULL,

    \-- The rating itself (1-5 stars)

    rating                SMALLINT NOT NULL,

    comment               TEXT,                              \-- optional, DLP-redacted before storage

    comment\_redacted\_at   TIMESTAMPTZ,                       \-- NULL \= not redacted, value \= when redaction happened

    \-- Lifecycle

    created\_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated\_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

    deleted\_at            TIMESTAMPTZ,

    \-- Constraints

    CONSTRAINT chk\_rating\_range CHECK (rating BETWEEN 1 AND 5),

    CONSTRAINT chk\_comment\_length CHECK (

        comment IS NULL OR char\_length(comment) \<= 2000

    )

);

\-- One feedback per (report, rater, target\_type) — idempotent updates

CREATE UNIQUE INDEX idx\_report\_feedback\_unique

    ON report\_feedback (therapist\_report\_id, rater\_user\_id, target\_type)

    WHERE deleted\_at IS NULL;

\-- Indexes for analytics & lookup

CREATE INDEX idx\_report\_feedback\_report

    ON report\_feedback(therapist\_report\_id)

    WHERE deleted\_at IS NULL;

CREATE INDEX idx\_report\_feedback\_session

    ON report\_feedback(session\_id)

    WHERE deleted\_at IS NULL;

CREATE INDEX idx\_report\_feedback\_rater

    ON report\_feedback(rater\_user\_id, created\_at DESC);

CREATE INDEX idx\_report\_feedback\_target\_rating

    ON report\_feedback(target\_type, rating)

    WHERE deleted\_at IS NULL;

\-- For Product Team review of negative feedback

CREATE INDEX idx\_report\_feedback\_negative\_recent

    ON report\_feedback(created\_at DESC)

    WHERE rating \<= 2 AND deleted\_at IS NULL;

\-- For TTL cleanup of comments (18-month retention)

CREATE INDEX idx\_report\_feedback\_comment\_retention

    ON report\_feedback(created\_at)

    WHERE comment IS NOT NULL AND comment\_redacted\_at IS NULL AND deleted\_at IS NULL;

\-- Trigram fuzzy search on comments (for Product Team analysis)

CREATE INDEX idx\_report\_feedback\_comment\_trgm

    ON report\_feedback USING gin (comment gin\_trgm\_ops)

    WHERE comment IS NOT NULL AND deleted\_at IS NULL;

\-- \============================================================

\-- REPORT FEEDBACK CATEGORIES (junction: M:N feedback ↔ categories)

\-- \============================================================

CREATE TABLE report\_feedback\_categories (

    feedback\_id     UUID NOT NULL REFERENCES report\_feedback(id) ON DELETE CASCADE,

    category\_id     UUID NOT NULL REFERENCES feedback\_categories(id) ON DELETE RESTRICT,

    created\_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (feedback\_id, category\_id)

);

CREATE INDEX idx\_rfc\_category ON report\_feedback\_categories(category\_id);

\-- Auto-update updated\_at trigger on report\_feedback

CREATE OR REPLACE FUNCTION fn\_touch\_report\_feedback\_updated\_at()

RETURNS TRIGGER AS $$

BEGIN

    NEW.updated\_at := now();

    RETURN NEW;

END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER trg\_report\_feedback\_updated\_at

    BEFORE UPDATE ON report\_feedback

    FOR EACH ROW EXECUTE FUNCTION fn\_touch\_report\_feedback\_updated\_at();

### 4.10 AUDIT & OPS Domain

\-- \============================================================

\-- AUDIT EVENTS (regulatory compliance, 400-day retention)

\-- \============================================================

CREATE TABLE audit\_events (

    id                  UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    actor\_user\_id       UUID REFERENCES users(id) ON DELETE SET NULL,

    organization\_id     UUID REFERENCES organizations(id) ON DELETE SET NULL,

    action              VARCHAR(100) NOT NULL,             \-- "session.create", "report.read"

    resource\_type       VARCHAR(50) NOT NULL,              \-- "session", "patient\_file"

    resource\_id         UUID,

    metadata            JSONB NOT NULL DEFAULT '{}'::jsonb,

    ip\_address          INET,

    user\_agent          TEXT,

    occurred\_at         TIMESTAMPTZ NOT NULL DEFAULT now()

);

\-- Partitioned by month for efficient archival

CREATE INDEX idx\_audit\_events\_actor ON audit\_events(actor\_user\_id, occurred\_at DESC);

CREATE INDEX idx\_audit\_events\_resource ON audit\_events(resource\_type, resource\_id);

CREATE INDEX idx\_audit\_events\_occurred ON audit\_events(occurred\_at DESC);

\-- \============================================================

\-- IDEMPOTENCY KEYS (for at-least-once webhook handling)

\-- \============================================================

CREATE TABLE idempotency\_keys (

    key                 VARCHAR(255) PRIMARY KEY,

    service\_name        VARCHAR(50) NOT NULL,

    operation           VARCHAR(100) NOT NULL,

    response\_payload    JSONB,

    response\_status     INT,

    created\_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    expires\_at          TIMESTAMPTZ NOT NULL                \-- TTL cleanup

);

CREATE INDEX idx\_idempotency\_keys\_expires ON idempotency\_keys(expires\_at);

\-- \============================================================

\-- OUTBOX EVENTS (transactional Pub/Sub publishing)

\-- \============================================================

CREATE TABLE outbox\_events (

    id                  UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

    aggregate\_type      VARCHAR(50) NOT NULL,              \-- "session", "subscription"

    aggregate\_id        UUID NOT NULL,

    event\_type          VARCHAR(100) NOT NULL,             \-- "session.completed"

    payload             JSONB NOT NULL,

    status              outbox\_status NOT NULL DEFAULT 'PENDING',

    retry\_count         INT NOT NULL DEFAULT 0,

    last\_error          TEXT,

    created\_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    published\_at        TIMESTAMPTZ

);

CREATE INDEX idx\_outbox\_pending ON outbox\_events(created\_at)

    WHERE status \= 'PENDING';

---

## 5\. Indexes & Performance Notes

### 5.1 Index strategy summary

| Index Type | Use Case | Example |
| :---- | :---- | :---- |
| **B-tree** (default) | Equality, range queries on FKs | `idx_sessions_therapist_date` |
| **Partial** | Filtered queries (e.g., `WHERE deleted_at IS NULL`) | `idx_users_firebase_uid` |
| **Composite** | Multi-column WHERE \+ ORDER BY | `(therapist_id, session_start_at DESC)` |
| **HNSW** (pgvector) | Vector similarity search | `idx_clinical_memory_ltm_embedding_hnsw` |
| **Unique** | Deduplication (idempotency) | `(provider, provider_event_id)` |
| **GIN** (JSONB) | JSON field queries | *added on demand* |

### 5.2 Vacuum & maintenance

- **Auto-vacuum** tuned aggressively for `sessions`, `audit_events`, `outbox_events` (high-churn tables).  
- **Manual REINDEX CONCURRENTLY** on HNSW indexes monthly (vector indexes degrade with updates).  
- **Partition `audit_events`** by month after table reaches 100M rows (\~year 2 of production).

### 5.3 Connection pooling

- Cloud SQL **PgBouncer** in transaction mode.  
- Per-service pool size: 10 connections.  
- Max instances × 10 \= 500 connections (well within PG max 400 with PgBouncer multiplexing).

---

## 6\. Go Structs (sqlc-style)

These structs match the schema 1:1 and can be generated by [sqlc](https://sqlc.dev) from the DDL above. Below is the **reference layout** — `sqlc` will produce these automatically.

### 6.1 Identity domain

package model

import (

    "time"

    "github.com/google/uuid"

    "github.com/jackc/pgx/v5/pgtype"

)

// UserRole enum

type UserRole string

const (

    UserRoleTherapist UserRole \= "THERAPIST"

    UserRolePatient   UserRole \= "PATIENT"

)

// OrganizationType enum

type OrganizationType string

const (

    OrganizationTypeSolo       OrganizationType \= "SOLO"

    OrganizationTypeClinic     OrganizationType \= "CLINIC"

    OrganizationTypeEnterprise OrganizationType \= "ENTERPRISE"

)

type Address struct {

    ID             uuid.UUID

    CountryCode    string

    Region         pgtype.Text

    City           string

    PostalCode     string

    StreetLine     string

    BuildingNumber string

    UnitNumber     pgtype.Text

    Directions     pgtype.Text

    CreatedAt      time.Time

}

type Organization struct {

    ID                       uuid.UUID

    LegalName                string

    TaxID                    pgtype.Text

    VatIDEU                  pgtype.Text

    HeadquartersAddressID    pgtype.UUID

    PrimaryAdminUserID       pgtype.UUID

    Type                     OrganizationType

    CreatedAt                time.Time

    DeletedAt                pgtype.Timestamptz

}

type User struct {

    ID                   uuid.UUID

    Role                 UserRole

    OrganizationID       pgtype.UUID

    DefaultModalityID    pgtype.UUID

    BillingAddressID     pgtype.UUID

    FirebaseUID          string

    Email                string

    PhoneNumber          pgtype.Text

    IsEmailVerified      bool

    FirstName            string

    LastName             string

    ProfessionalTitle    pgtype.Text

    CredentialsNumber    pgtype.Text

    Biography            pgtype.Text

    AvatarURL            pgtype.Text

    UILanguage           string

    Timezone             string

    HasAcceptedToS       bool

    HasMarketingConsent  bool

    CreatedAt            time.Time

    DeletedAt            pgtype.Timestamptz

}

### 6.2 Billing domain

package model

type PlanTier string

const (

    PlanTierSolo    PlanTier \= "SOLO"

    PlanTierPro     PlanTier \= "PRO"

    PlanTierClinic  PlanTier \= "CLINIC"

    PlanTierPatient PlanTier \= "PATIENT"

)

type BillingCycle string

const (

    BillingCycleMonthly     BillingCycle \= "MONTHLY"

    BillingCycleSemiAnnual  BillingCycle \= "SEMI\_ANNUAL"

    BillingCycleAnnual      BillingCycle \= "ANNUAL"

)

type PaymentProvider string

const (

    PaymentProviderStripe    PaymentProvider \= "STRIPE"

    PaymentProviderP24       PaymentProvider \= "P24"

    PaymentProviderAppleIAP  PaymentProvider \= "APPLE\_IAP"

    PaymentProviderGoogleIAP PaymentProvider \= "GOOGLE\_IAP"

    PaymentProviderManual    PaymentProvider \= "MANUAL"

)

type SubscriptionStatus string

const (

    SubscriptionStatusTrialing   SubscriptionStatus \= "TRIALING"

    SubscriptionStatusActive     SubscriptionStatus \= "ACTIVE"

    SubscriptionStatusPastDue    SubscriptionStatus \= "PAST\_DUE"

    SubscriptionStatusCanceled   SubscriptionStatus \= "CANCELED"

    SubscriptionStatusIncomplete SubscriptionStatus \= "INCOMPLETE"

    SubscriptionStatusPaused     SubscriptionStatus \= "PAUSED"

)

type SubscriptionPlan struct {

    ID                    uuid.UUID

    Tier                  PlanTier

    Cycle                 BillingCycle

    DisplayName           string

    PriceGross            pgtype.Numeric

    CurrencyCode          string

    SessionsLimit         pgtype.Int4

    LicensesLimit         pgtype.Int4

    HasB2BDashboard       bool

    MarketingDescription  pgtype.Text

    StripePriceID         pgtype.Text

    P24PlanID             pgtype.Text

    AppleProductID        pgtype.Text

    GoogleProductID       pgtype.Text

    IsActive              bool

    CreatedAt             time.Time

}

type Subscription struct {

    ID                       uuid.UUID

    OrganizationID           uuid.UUID

    PlanID                   uuid.UUID

    Provider                 PaymentProvider

    ProviderSubscriptionID   string

    ProviderCustomerID       pgtype.Text

    Status                   SubscriptionStatus

    CurrentPeriodStart       time.Time

    CurrentPeriodEnd         time.Time

    CancelAtPeriodEnd        bool

    CanceledAt               pgtype.Timestamptz

    TrialEndAt               pgtype.Timestamptz

    CreatedAt                time.Time

    UpdatedAt                time.Time

}

type PaymentEvent struct {

    ID                  uuid.UUID

    SubscriptionID      pgtype.UUID

    Provider            PaymentProvider

    ProviderEventID     string

    EventType           string

    AmountGross         pgtype.Numeric

    AmountNet           pgtype.Numeric

    VatRate             pgtype.Numeric

    CurrencyCode        pgtype.Text

    RawPayload          \[\]byte // JSONB

    ReceivedAt          time.Time

}

type UsageCounter struct {

    ID              uuid.UUID

    SubscriptionID  uuid.UUID

    PeriodStart     pgtype.Date

    PeriodEnd       pgtype.Date

    SessionsUsed    int32

    SessionsLimit   pgtype.Int4

    UpdatedAt       time.Time

}

### 6.3 Clinical & Sessions domain

package model

type ProcessType string

const (

    ProcessTypeIndividual ProcessType \= "INDIVIDUAL"

    ProcessTypeCouple     ProcessType \= "COUPLE"

    ProcessTypeFamily     ProcessType \= "FAMILY"

    ProcessTypeGroup      ProcessType \= "GROUP"

)

type ContactForm string

const (

    ContactFormOffice ContactForm \= "OFFICE"

    ContactFormOnline ContactForm \= "ONLINE"

    ContactFormField  ContactForm \= "FIELD"

    ContactFormPhone  ContactForm \= "PHONE"

)

type SessionStatus string

const (

    SessionStatusCreated      SessionStatus \= "CREATED"

    SessionStatusRecording    SessionStatus \= "RECORDING"

    SessionStatusUploading    SessionStatus \= "UPLOADING"

    SessionStatusTranscribing SessionStatus \= "TRANSCRIBING"

    SessionStatusAnalyzing    SessionStatus \= "ANALYZING"

    SessionStatusCompleted    SessionStatus \= "COMPLETED"

    SessionStatusFailed       SessionStatus \= "FAILED"

    SessionStatusCanceled     SessionStatus \= "CANCELED"

)

type Modality struct {

    ID                            uuid.UUID

    SystemCode                    string

    DisplayName                   string

    TherapistAIGeneralPrompt      \[\]byte // JSONB

    TherapistAISectionPrompts     \[\]byte // JSONB

    PatientAIGeneralPrompt        \[\]byte // JSONB

    PatientAISectionPrompts       \[\]byte // JSONB

    IsSupported                   bool

    CreatedAt                     time.Time

    UpdatedAt                     time.Time

}

type PatientFile struct {

    ID                       uuid.UUID

    TherapistID              uuid.UUID

    PatientID                pgtype.UUID

    RelationID               pgtype.UUID

    ModalityID               uuid.UUID

    WorkingAlias             string

    ProcessType              ProcessType

    InitialComplaint         pgtype.Text

    IsProcessClosed          bool

    HasRecordingConsent      bool

    ConsentGivenAt           pgtype.Timestamptz

    FirstConsultationAt      pgtype.Timestamptz

    PrivateTherapistNotes    pgtype.Text

    CreatedAt                time.Time

    UpdatedAt                time.Time

    DeletedAt                pgtype.Timestamptz

}

type Session struct {

    ID                  uuid.UUID

    PatientFileID       uuid.UUID

    TherapistID         uuid.UUID

    SessionStartAt      time.Time

    SessionEndAt        pgtype.Timestamptz

    DurationSeconds     pgtype.Int4

    ContactForm         ContactForm

    AudioStoragePath    pgtype.Text

    AudioDestroyedAt    pgtype.Timestamptz

    ProcessingStatus    SessionStatus

    ErrorCodeUI         pgtype.Text

    ProcessingCost      pgtype.Numeric

    IdempotencyKey      string

    CreatedAt           time.Time

    UpdatedAt           time.Time

}

type Transcript struct {

    ID                          uuid.UUID

    SessionID                   uuid.UUID

    DiarizedTextCiphertext      \[\]byte

    DiarizedTextEncryptedDek    \[\]byte

    CharacterCount              int32

    IdentifiedSpeakerCount      int32

    SttDurationMs               pgtype.Int4

    SttModelVersion             pgtype.Text

    CreatedAt                   time.Time

}

type TherapistReport struct {

    ID                          uuid.UUID

    SessionID                   uuid.UUID

    ModalityUsedID              uuid.UUID

    ReportPayloadCiphertext     \[\]byte

    ReportPayloadEncryptedDek   \[\]byte

    ReasoningScratchpad         pgtype.Text

    PromptTokensUsed            pgtype.Int4

    CompletionTokensUsed        pgtype.Int4

    LlmModelVersion             pgtype.Text

    CreatedAt                   time.Time

}

type PatientView struct {

    ID                            uuid.UUID

    SessionID                     uuid.UUID

    ModalityUsedID                uuid.UUID

    ReportPayloadCiphertext       \[\]byte

    ReportPayloadEncryptedDek     \[\]byte

    PrivateJournalCiphertext      \[\]byte

    PrivateJournalEncryptedDek    \[\]byte

    NextSessionAgenda             pgtype.Text

    PostSessionMoodRating         pgtype.Int4

    AgendaFilledAt                pgtype.Timestamptz

    CreatedAt                     time.Time

}

### 6.4 Memory (RAG) domain

package model

import "github.com/pgvector/pgvector-go"

type ClinicalMemory struct {

    ID                            uuid.UUID

    PatientFileID                 uuid.UUID

    LongTermMemoryCiphertext      \[\]byte

    LongTermMemoryEncryptedDek    \[\]byte

    LongTermMemoryTokenCount      int32

    LongTermMemoryEmbedding       pgvector.Vector // 768-dim

    RecentFactVectors             \[\]byte // JSONB

    RevisionNumber                int32

    LastSynthesizedAt             time.Time

    CreatedAt                     time.Time

    UpdatedAt                     time.Time

}

type EmbeddingChunkType string

const (

    ChunkTypeSessionSummary  EmbeddingChunkType \= "SESSION\_SUMMARY"

    ChunkTypeKeyFact         EmbeddingChunkType \= "KEY\_FACT"

    ChunkTypeEmotionalEvent  EmbeddingChunkType \= "EMOTIONAL\_EVENT"

    ChunkTypeInsight         EmbeddingChunkType \= "INSIGHT"

    ChunkTypeActionPoint     EmbeddingChunkType \= "ACTION\_POINT"

)

type EmbeddingChunk struct {

    ID                  uuid.UUID

    ClinicalMemoryID    uuid.UUID

    SourceSessionID     uuid.UUID

    ChunkTextRedacted   string

    ChunkEmbedding      pgvector.Vector

    ChunkIndex          int32

    ChunkType           EmbeddingChunkType

    CreatedAt           time.Time

}

### 6.5 HiTOP Analytics domain

package model

type HitopDimension struct {

    ID                      uuid.UUID

    Code                    string

    DisplayName             string

    BehavioralDefinition    string

    HierarchyLevel          int32

    ParentDimensionID       pgtype.UUID

    IsActive                bool

    CreatedAt               time.Time

}

type HitopSymptom struct {

    ID                      uuid.UUID

    DimensionID             uuid.UUID

    Code                    string

    DisplayName             string

    OperationalDefinition   string

    BehavioralIndicators    pgtype.Text

    IsActive                bool

    CreatedAt               time.Time

}

type HitopMeasurement struct {

    ID                              uuid.UUID

    SessionID                       uuid.UUID

    SymptomID                       uuid.UUID

    Severity                        int32

    ConfidenceScore                 pgtype.Numeric

    SupportingEvidenceRedacted      pgtype.Text

    MeasuredAt                      time.Time

}

type ProcessMetric struct {

    ID                      uuid.UUID

    SessionID               uuid.UUID

    TherapeuticAlliance     int32

    PatientInsightLevel     int32

    EmotionalIntensity      int32

    CognitiveRigidity       pgtype.Numeric

    AgencyLocus             pgtype.Numeric

    MeasuredAt              time.Time

}

### 6.6 Feedback domain *(new in v4.2)*

package model

import (

    "time"

    "github.com/google/uuid"

    "github.com/jackc/pgx/v5/pgtype"

)

// FeedbackTargetType — what part of the report is being rated

type FeedbackTargetType string

const (

    FeedbackTargetOverall      FeedbackTargetType \= "OVERALL"

    FeedbackTargetTranscript   FeedbackTargetType \= "TRANSCRIPT"

    FeedbackTargetSummary      FeedbackTargetType \= "SUMMARY"

    FeedbackTargetAnalysis     FeedbackTargetType \= "ANALYSIS"

    FeedbackTargetHypotheses   FeedbackTargetType \= "HYPOTHESES"

    FeedbackTargetMechanisms   FeedbackTargetType \= "MECHANISMS"

    FeedbackTargetActionPoints FeedbackTargetType \= "ACTION\_POINTS"

    FeedbackTargetSafetyAlerts FeedbackTargetType \= "SAFETY\_ALERTS"

    FeedbackTargetPatientView  FeedbackTargetType \= "PATIENT\_VIEW"

)

// FeedbackSource — who provides the rating

type FeedbackSource string

const (

    FeedbackSourceTherapist  FeedbackSource \= "THERAPIST"

    FeedbackSourcePatient    FeedbackSource \= "PATIENT"

    FeedbackSourceSupervisor FeedbackSource \= "SUPERVISOR"

)

// FeedbackCategoryPolarity — semantic direction of a category

type FeedbackCategoryPolarity string

const (

    FeedbackPolarityPositive FeedbackCategoryPolarity \= "POSITIVE"

    FeedbackPolarityNegative FeedbackCategoryPolarity \= "NEGATIVE"

    FeedbackPolarityNeutral  FeedbackCategoryPolarity \= "NEUTRAL"

)

// ReportFeedback — main rating record (1-5 stars \+ optional comment)

type ReportFeedback struct {

    ID                  uuid.UUID

    TherapistReportID   uuid.UUID

    SessionID           uuid.UUID

    TargetType          FeedbackTargetType

    RaterUserID         uuid.UUID

    RaterSource         FeedbackSource

    Rating              int16              // 1-5

    Comment             pgtype.Text

    CommentRedactedAt   pgtype.Timestamptz

    CreatedAt           time.Time

    UpdatedAt           time.Time

    DeletedAt           pgtype.Timestamptz

}

// FeedbackCategory — closed ontology of qualitative tags

type FeedbackCategory struct {

    ID           uuid.UUID

    Code         string

    DisplayName  string

    Description  pgtype.Text

    Polarity     FeedbackCategoryPolarity

    IsActive     bool

    SortOrder    int32

    CreatedAt    time.Time

}

// ReportFeedbackCategory — junction table (M:N)

type ReportFeedbackCategory struct {

    FeedbackID  uuid.UUID

    CategoryID  uuid.UUID

    CreatedAt   time.Time

}

// FeedbackSubmittedEvent — outbox event payload published to Pub/Sub

// Topic: feedback.submitted

type FeedbackSubmittedEvent struct {

    FeedbackID         uuid.UUID            \`json:"feedback\_id"\`

    TherapistReportID  uuid.UUID            \`json:"therapist\_report\_id"\`

    SessionID          uuid.UUID            \`json:"session\_id"\`

    RaterUserID        uuid.UUID            \`json:"rater\_user\_id"\`

    RaterSource        FeedbackSource       \`json:"rater\_source"\`

    TargetType         FeedbackTargetType   \`json:"target\_type"\`

    Rating             int16                \`json:"rating"\`

    HasComment         bool                 \`json:"has\_comment"\`

    CommentWasRedacted bool                 \`json:"comment\_was\_redacted"\`

    CategoryCodes      \[\]string             \`json:"category\_codes"\`

    SubmittedAt        time.Time            \`json:"submitted\_at"\`

}

### 6.7 Audit & Ops domain

package model

type OutboxStatus string

const (

    OutboxStatusPending   OutboxStatus \= "PENDING"

    OutboxStatusPublished OutboxStatus \= "PUBLISHED"

    OutboxStatusFailed    OutboxStatus \= "FAILED"

    OutboxStatusExpired   OutboxStatus \= "EXPIRED"

)

type AuditEvent struct {

    ID              uuid.UUID

    ActorUserID     pgtype.UUID

    OrganizationID  pgtype.UUID

    Action          string

    ResourceType    string

    ResourceID      pgtype.UUID

    Metadata        \[\]byte // JSONB

    IPAddress       \*netip.Addr

    UserAgent       pgtype.Text

    OccurredAt      time.Time

}

type IdempotencyKey struct {

    Key             string

    ServiceName     string

    Operation       string

    ResponsePayload \[\]byte // JSONB

    ResponseStatus  pgtype.Int4

    CreatedAt       time.Time

    ExpiresAt       time.Time

}

type OutboxEvent struct {

    ID              uuid.UUID

    AggregateType   string

    AggregateID     uuid.UUID

    EventType       string

    Payload         \[\]byte // JSONB

    Status          OutboxStatus

    RetryCount      int32

    LastError       pgtype.Text

    CreatedAt       time.Time

    PublishedAt     pgtype.Timestamptz

}

---

## 7\. Sample Queries (sqlc-annotated)

These are example sqlc query definitions that generate type-safe Go methods.

### 7.1 Identity queries

\-- name: GetUserByFirebaseUID :one

SELECT \* FROM users

WHERE firebase\_uid \= $1 AND deleted\_at IS NULL;

\-- name: ListTherapistsByOrganization :many

SELECT u.\* FROM users u

WHERE u.organization\_id \= $1

  AND u.role \= 'THERAPIST'

  AND u.deleted\_at IS NULL

ORDER BY u.last\_name, u.first\_name;

\-- name: CreateUser :one

INSERT INTO users (

    role, organization\_id, firebase\_uid, email,

    first\_name, last\_name, ui\_language, timezone

) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)

RETURNING \*;

\-- name: SoftDeleteUser :exec

UPDATE users SET deleted\_at \= now() WHERE id \= $1;

### 7.2 Sessions & Idempotency

\-- name: CreateSessionWithIdempotency :one

INSERT INTO sessions (

    patient\_file\_id, therapist\_id, session\_start\_at,

    contact\_form, idempotency\_key, processing\_status

) VALUES ($1, $2, $3, $4, $5, 'CREATED')

ON CONFLICT (idempotency\_key) DO UPDATE SET id \= sessions.id

RETURNING \*;

\-- name: UpdateSessionStatus :one

UPDATE sessions

SET processing\_status \= $2, updated\_at \= now()

WHERE id \= $1

RETURNING \*;

\-- name: ListRecentSessionsByTherapist :many

SELECT s.\*, pf.working\_alias

FROM sessions s

JOIN patient\_files pf ON pf.id \= s.patient\_file\_id

WHERE s.therapist\_id \= $1

  AND s.created\_at \> $2

ORDER BY s.session\_start\_at DESC

LIMIT $3;

\-- name: LockSessionForProcessing :one

SELECT \* FROM sessions

WHERE id \= $1 FOR UPDATE SKIP LOCKED;

### 7.3 RAG retrieval (pgvector)

\-- name: SearchSimilarChunks :many

\-- Returns top-K most similar chunks for a given embedding

SELECT

    ec.id,

    ec.chunk\_text\_redacted,

    ec.chunk\_type,

    ec.source\_session\_id,

    1 \- (ec.chunk\_embedding \<=\> $2) AS similarity

FROM embedding\_chunks ec

WHERE ec.clinical\_memory\_id \= $1

ORDER BY ec.chunk\_embedding \<=\> $2

LIMIT $3;

\-- name: GetClinicalMemoryByPatientFile :one

SELECT \* FROM clinical\_memory

WHERE patient\_file\_id \= $1;

\-- name: UpdateClinicalMemoryWithRevisionCheck :one

\-- Optimistic lock: only update if revision matches

UPDATE clinical\_memory

SET

    long\_term\_memory\_ciphertext \= $2,

    long\_term\_memory\_encrypted\_dek \= $3,

    long\_term\_memory\_token\_count \= $4,

    long\_term\_memory\_embedding \= $5,

    last\_synthesized\_at \= now()

WHERE id \= $1 AND revision\_number \= $6

RETURNING \*;

### 7.4 HiTOP analytics

\-- name: GetSymptomTrendForPatient :many

\-- Returns severity over time for a specific symptom

SELECT

    hm.severity,

    hm.confidence\_score,

    hm.measured\_at,

    s.session\_start\_at

FROM hitop\_measurements hm

JOIN sessions s ON s.id \= hm.session\_id

JOIN patient\_files pf ON pf.id \= s.patient\_file\_id

WHERE pf.id \= $1 AND hm.symptom\_id \= $2

ORDER BY hm.measured\_at ASC;

\-- name: GetOrganizationDimensionAggregates :many

\-- For B2B dashboards (clinic owner view)

SELECT

    hd.code AS dimension\_code,

    hd.display\_name,

    AVG(hm.severity)::numeric(4,2) AS avg\_severity,

    COUNT(DISTINCT s.id) AS session\_count

FROM hitop\_measurements hm

JOIN hitop\_symptoms hs ON hs.id \= hm.symptom\_id

JOIN hitop\_dimensions hd ON hd.id \= hs.dimension\_id

JOIN sessions s ON s.id \= hm.session\_id

JOIN users u ON u.id \= s.therapist\_id

WHERE u.organization\_id \= $1

  AND s.session\_start\_at \> $2

GROUP BY hd.code, hd.display\_name

ORDER BY avg\_severity DESC;

\-- name: ValidateSymptomCode :one

\-- LLM output validation: is this a known symptom?

SELECT EXISTS(

    SELECT 1 FROM hitop\_symptoms

    WHERE code \= $1 AND is\_active \= TRUE

);

### 7.5 Outbox pattern for events — **retired 2026-05-27**

> The `outbox_events` table + in-process poller pattern was introduced for billing-svc fan-out and retired with Phase C of `feat/billing-svc-refactor`. Migration 000034 dropped the table; no service in the current codebase writes to it. The pattern documentation below stays as reference — if a future service needs transactional Pub/Sub guarantees, ADR-DM-009 is still the right shape, just recreate the table fresh.
>
> Current quota-state propagation: `state_after` embedded on every `ReserveCredit` / `CommitUsage` response + `clinical-svc.GetMyBillingState` on Flutter cold start. See `docs/17_BILLING_IMPLEMENTATION_FLOW.md` §5.

\-- name: EnqueueOutboxEvent :one

INSERT INTO outbox\_events (aggregate\_type, aggregate\_id, event\_type, payload)

VALUES ($1, $2, $3, $4)

RETURNING \*;

\-- name: FetchPendingOutboxEvents :many

SELECT \* FROM outbox\_events

WHERE status \= 'PENDING'

ORDER BY created\_at ASC

LIMIT $1

FOR UPDATE SKIP LOCKED;

\-- name: MarkOutboxEventPublished :exec

UPDATE outbox\_events

SET status \= 'PUBLISHED', published\_at \= now()

WHERE id \= $1;

### 7.6 Feedback queries *(new in v4.2)*

\-- \========================================================

\-- SUBMISSION (idempotent upsert)

\-- \========================================================

\-- name: UpsertReportFeedback :one

\-- Creates or updates feedback for a (report, rater, target\_type) triple.

\-- Used for both initial submission and rating changes.

INSERT INTO report\_feedback (

    therapist\_report\_id, session\_id, target\_type,

    rater\_user\_id, rater\_source, rating, comment, comment\_redacted\_at

) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)

ON CONFLICT (therapist\_report\_id, rater\_user\_id, target\_type)

    WHERE deleted\_at IS NULL

DO UPDATE SET

    rating \= EXCLUDED.rating,

    comment \= EXCLUDED.comment,

    comment\_redacted\_at \= EXCLUDED.comment\_redacted\_at,

    updated\_at \= now()

RETURNING \*;

\-- name: ReplaceFeedbackCategories :exec

\-- Atomic replacement of all categories for a feedback record

WITH deleted AS (

    DELETE FROM report\_feedback\_categories WHERE feedback\_id \= $1

)

INSERT INTO report\_feedback\_categories (feedback\_id, category\_id)

SELECT $1, category\_id FROM unnest($2::uuid\[\]) AS t(category\_id)

ON CONFLICT DO NOTHING;

\-- name: SoftDeleteFeedback :exec

UPDATE report\_feedback

SET deleted\_at \= now(), updated\_at \= now()

WHERE id \= $1 AND rater\_user\_id \= $2;  \-- only rater can delete their own

\-- \========================================================

\-- READS (per-user, per-report)

\-- \========================================================

\-- name: GetFeedbackByReportAndRater :many

\-- Returns all feedback (overall \+ per-section) given by one rater for one report

SELECT rf.\*,

       COALESCE(

           array\_agg(fc.code) FILTER (WHERE fc.code IS NOT NULL),

           '{}'::varchar\[\]

       ) AS category\_codes

FROM report\_feedback rf

LEFT JOIN report\_feedback\_categories rfc ON rfc.feedback\_id \= rf.id

LEFT JOIN feedback\_categories fc ON fc.id \= rfc.category\_id

WHERE rf.therapist\_report\_id \= $1

  AND rf.rater\_user\_id \= $2

  AND rf.deleted\_at IS NULL

GROUP BY rf.id

ORDER BY rf.target\_type;

\-- name: GetMyRecentFeedback :many

SELECT rf.id, rf.rating, rf.target\_type, rf.created\_at,

       s.id AS session\_id, s.session\_start\_at

FROM report\_feedback rf

JOIN sessions s ON s.id \= rf.session\_id

WHERE rf.rater\_user\_id \= $1

  AND rf.deleted\_at IS NULL

ORDER BY rf.created\_at DESC

LIMIT $2;

\-- \========================================================

\-- ANALYTICS (Product Team & B2B dashboards)

\-- \========================================================

\-- name: GetCategoryFrequencyByModality :many

\-- "Which categories are flagged most often per modality?"

SELECT

    m.system\_code AS modality,

    fc.code AS category\_code,

    fc.display\_name,

    fc.polarity,

    COUNT(\*) AS feedback\_count,

    AVG(rf.rating)::numeric(3,2) AS avg\_rating\_when\_tagged

FROM report\_feedback rf

JOIN report\_feedback\_categories rfc ON rfc.feedback\_id \= rf.id

JOIN feedback\_categories fc ON fc.id \= rfc.category\_id

JOIN therapist\_reports tr ON tr.id \= rf.therapist\_report\_id

JOIN modalities m ON m.id \= tr.modality\_used\_id

WHERE rf.deleted\_at IS NULL

  AND rf.created\_at \> $1

GROUP BY m.system\_code, fc.code, fc.display\_name, fc.polarity

ORDER BY feedback\_count DESC;

\-- name: GetWeakestSectionsForModality :many

\-- "Which report sections have the lowest avg rating?"

SELECT

    rf.target\_type,

    AVG(rf.rating)::numeric(3,2) AS avg\_rating,

    COUNT(\*) AS sample\_size,

    COUNT(\*) FILTER (WHERE rf.rating \<= 2\) AS low\_rating\_count

FROM report\_feedback rf

JOIN therapist\_reports tr ON tr.id \= rf.therapist\_report\_id

WHERE tr.modality\_used\_id \= $1

  AND rf.target\_type \!= 'OVERALL'

  AND rf.deleted\_at IS NULL

  AND rf.created\_at \> $2

GROUP BY rf.target\_type

HAVING COUNT(\*) \>= 10  \-- min sample size to avoid noise

ORDER BY avg\_rating ASC;

\-- name: GetRecentNegativeFeedbackForReview :many

\-- For Product Team weekly review of bad feedback

SELECT

    rf.id,

    rf.rating,

    rf.comment,

    rf.created\_at,

    rf.target\_type,

    array\_agg(fc.code) FILTER (WHERE fc.code IS NOT NULL) AS categories,

    s.id AS session\_id,

    m.system\_code AS modality,

    tr.llm\_model\_version

FROM report\_feedback rf

LEFT JOIN report\_feedback\_categories rfc ON rfc.feedback\_id \= rf.id

LEFT JOIN feedback\_categories fc ON fc.id \= rfc.category\_id

JOIN therapist\_reports tr ON tr.id \= rf.therapist\_report\_id

JOIN sessions s ON s.id \= rf.session\_id

JOIN modalities m ON m.id \= tr.modality\_used\_id

WHERE rf.rating \<= 2

  AND rf.deleted\_at IS NULL

  AND rf.created\_at \> $1

GROUP BY rf.id, s.id, m.system\_code, tr.llm\_model\_version

ORDER BY rf.created\_at DESC

LIMIT $2;

\-- name: GetTherapistFeedbackStats :one

\-- Aggregate stats per therapist (for personal dashboard \+ Firestore sync)

SELECT

    rf.rater\_user\_id,

    AVG(rf.rating)::numeric(3,2) AS avg\_rating\_given,

    COUNT(\*) AS total\_feedbacks,

    COUNT(\*) FILTER (WHERE rf.created\_at \> now() \- INTERVAL '30 days') AS last\_30\_days\_count,

    AVG(rf.rating) FILTER (WHERE rf.created\_at \> now() \- INTERVAL '30 days')::numeric(3,2)

        AS avg\_rating\_last\_30\_days

FROM report\_feedback rf

WHERE rf.rater\_user\_id \= $1

  AND rf.target\_type \= 'OVERALL'

  AND rf.deleted\_at IS NULL

GROUP BY rf.rater\_user\_id;

\-- name: GetTherapistFeedbackProfile :one

\-- "What does this therapist value? Used for prompt personalization."

SELECT

    rf.rater\_user\_id,

    AVG(rf.rating)::numeric(3,2) AS avg\_rating\_given,

    COUNT(\*) AS total\_feedbacks,

    array\_agg(DISTINCT fc.code) FILTER (

        WHERE fc.polarity \= 'NEGATIVE'

    ) AS frequent\_complaints,

    array\_agg(DISTINCT fc.code) FILTER (

        WHERE fc.polarity \= 'POSITIVE'

    ) AS frequent\_praises

FROM report\_feedback rf

LEFT JOIN report\_feedback\_categories rfc ON rfc.feedback\_id \= rf.id

LEFT JOIN feedback\_categories fc ON fc.id \= rfc.category\_id

WHERE rf.rater\_user\_id \= $1

  AND rf.deleted\_at IS NULL

  AND rf.created\_at \> now() \- INTERVAL '90 days'

GROUP BY rf.rater\_user\_id;

\-- name: GetOrganizationFeedbackTrend :many

\-- For B2B clinic dashboards (Looker Studio source)

SELECT

    date\_trunc('week', rf.created\_at)::date AS week\_start,

    AVG(rf.rating)::numeric(3,2) AS avg\_rating,

    COUNT(\*) AS feedback\_count,

    COUNT(DISTINCT rf.rater\_user\_id) AS active\_raters

FROM report\_feedback rf

JOIN users u ON u.id \= rf.rater\_user\_id

WHERE u.organization\_id \= $1

  AND rf.target\_type \= 'OVERALL'

  AND rf.deleted\_at IS NULL

  AND rf.created\_at \> $2

GROUP BY week\_start

ORDER BY week\_start;

\-- \========================================================

\-- COMMENT RETENTION (18-month TTL cleanup cron)

\-- \========================================================

\-- name: RedactExpiredComments :execrows

\-- Run nightly: drop comment text \>18 months old, keep ratings

UPDATE report\_feedback

SET comment \= NULL,

    comment\_redacted\_at \= now(),

    updated\_at \= now()

WHERE comment IS NOT NULL

  AND comment\_redacted\_at IS NULL

  AND created\_at \< now() \- INTERVAL '18 months'

  AND deleted\_at IS NULL;

\-- \========================================================

\-- VALIDATION (closed ontology check)

\-- \========================================================

\-- name: ListActiveFeedbackCategories :many

SELECT id, code, display\_name, polarity, sort\_order

FROM feedback\_categories

WHERE is\_active \= TRUE

ORDER BY polarity, sort\_order;

\-- name: ValidateCategoryCodes :one

\-- Returns count of valid codes; if not equal to input length, some are invalid

SELECT COUNT(\*) FROM feedback\_categories

WHERE code \= ANY($1::varchar\[\])

  AND is\_active \= TRUE;

---

## 8\. Migration Strategy

### 8.1 Tooling

- **Tool:** `golang-migrate/migrate` v4  
- **Format:** plain `.sql` files in `/migrations`  
- **Naming:** `{version}_{description}.{up|down}.sql`  
- **Versioning:** sequential 4-digit prefix (e.g., `0001_initial.up.sql`)

### 8.2 Initial migration sequence

migrations/

├── 0001\_extensions.up.sql                    \# CREATE EXTENSION

├── 0001\_extensions.down.sql

├── 0002\_enums.up.sql                         \# CREATE TYPE (incl. feedback enums)

├── 0003\_identity.up.sql                      \# addresses, organizations, users

├── 0004\_billing.up.sql                       \# plans, subscriptions, payment\_events, usage\_counters

├── 0005\_clinical.up.sql                      \# modalities, relations, patient\_files

├── 0006\_sessions.up.sql                      \# sessions, transcripts, reports, views

├── 0007\_memory.up.sql                        \# clinical\_memory \+ pgvector indexes

├── 0008\_hitop\_dimensions.up.sql              \# closed ontology \- dimensions

├── 0009\_hitop\_symptoms.up.sql                \# closed ontology \- symptoms

├── 0010\_hitop\_measurements.up.sql            \# measurements \+ process metrics

├── 0011\_feedback.up.sql                      \# feedback\_categories, report\_feedback (v4.2)

├── 0012\_audit.up.sql                         \# audit\_events, idempotency, outbox

├── 0013\_seed\_modalities.up.sql               \# initial CBT/Schema/EFT data

├── 0014\_seed\_hitop\_ontology.up.sql           \# initial HiTOP catalog

└── 0015\_seed\_feedback\_categories.up.sql      \# initial feedback taxonomy (v4.2)

**Note:** Earlier drafts (≤ v4.2) included `0005_invoicing.up.sql` covering `invoices`, `invoice_line_items`, `tax_records`. As of v4.3, invoicing is delegated to an external SaaS (see ADR-DM-016) and these migrations are removed from the sequence.

### 8.3 Zero-downtime migration rules

For any column rename / removal, follow **Expand-Contract**:

1. **Expand:** Add new column. Code writes to both old and new. Reads from old.  
2. **Backfill:** Background job copies data old → new.  
3. **Switch reads:** Code reads from new column. Still writes to both.  
4. **Contract:** Drop old column.

This applies even for "trivial" renames in production.

### 8.4 pgvector index considerations

- **HNSW indexes are slow to build** (\~30 minutes for 1M vectors).  
- Build them **CONCURRENTLY** in production:

CREATE INDEX CONCURRENTLY idx\_embedding\_chunks\_hnsw

    ON embedding\_chunks USING hnsw (chunk\_embedding vector\_cosine\_ops);

- Plan rebuild during low-traffic window (3-5 AM UTC).

---

## 9\. Closed-Ontology Lookup Tables (HiTOP)

The HiTOP catalog is **seeded data** — not user-editable. It's the foundation of measurable analytics.

### 9.1 Hierarchy structure (per Kotov et al. 2017, 2021\)

Level 1 (SPECTRA — top of hierarchy):

├── INTERNALIZING        (anxiety, depression, fear, distress)

├── DETACHMENT           (social withdrawal, anhedonia, restricted affect)

├── ANTAGONISM           (aggression, manipulativeness, callousness)

├── DISINHIBITION        (impulsivity, irresponsibility, recklessness)

├── THOUGHT\_DISORDER     (psychotic symptoms, dissociation, mania)

└── SOMATOFORM           (bodily symptoms, health anxiety)

Level 2 (SUBFACTORS — examples):

├── INTERNALIZING

│   ├── DISTRESS         (depression, GAD, dysthymia)

│   ├── FEAR             (panic, phobias, OCD-like)

│   └── EATING\_PATHOLOGY

├── DETACHMENT

│   ├── SOCIAL\_DETACHMENT

│   └── ANHEDONIA\_FACET

└── ...

Level 3 (SYMPTOMS — leaf level):

├── DISTRESS

│   ├── DEPRESSED\_MOOD          (sustained sadness)

│   ├── ANHEDONIA               (loss of interest/pleasure)

│   ├── RUMINATION              (repetitive negative thinking)

│   ├── EXCESSIVE\_WORRY         (uncontrollable anxiety)

│   ├── SLEEP\_DISTURBANCE       (insomnia/hypersomnia)

│   ├── FATIGUE                 (energy depletion)

│   ├── CONCENTRATION\_DEFICIT

│   └── ...

└── ...

### 9.2 Sample seed data

\-- Spectra (Level 1\)

INSERT INTO hitop\_dimensions (code, display\_name, behavioral\_definition, hierarchy\_level, parent\_dimension\_id) VALUES

    ('INTERNALIZING', 'Internalizing',

     'Pervasive negative emotionality directed inward — characterized by sustained dysphoric mood, anxiety, and excessive self-focus.',

     1, NULL),

    ('DETACHMENT', 'Detachment',

     'Withdrawal from interpersonal interactions, restricted affective experience, and reduced motivation for social or pleasurable activities.',

     1, NULL),

    ('THOUGHT\_DISORDER', 'Thought Disorder',

     'Disturbances in thought process, content, or perception — including psychotic-like experiences, dissociation, or manic-spectrum phenomena.',

     1, NULL);

\-- Subfactors (Level 2\) — example for INTERNALIZING

INSERT INTO hitop\_dimensions (code, display\_name, behavioral\_definition, hierarchy\_level, parent\_dimension\_id)

SELECT 'DISTRESS', 'Distress',

       'Subfactor of internalizing characterized by depressive symptoms, generalized anxiety, and stress-related responses.',

       2, id

FROM hitop\_dimensions WHERE code \= 'INTERNALIZING';

\-- Symptoms (Level 3\) — leaf items the LLM can match against

INSERT INTO hitop\_symptoms (dimension\_id, code, display\_name, operational\_definition, behavioral\_indicators)

SELECT

    d.id,

    'DEPRESSED\_MOOD',

    'Depressed Mood',

    'Sustained subjective experience of sadness, emptiness, or hopelessness lasting most of the day, more days than not, for at least two weeks.',

    'Reports feeling "down", "sad", "empty"; tearfulness; expressions of hopelessness; references to losing interest in life; flat affect during session.'

FROM hitop\_dimensions d WHERE d.code \= 'DISTRESS';

INSERT INTO hitop\_symptoms (dimension\_id, code, display\_name, operational\_definition, behavioral\_indicators)

SELECT

    d.id,

    'ANHEDONIA',

    'Anhedonia',

    'Markedly diminished interest or pleasure in activities that were previously enjoyable, observed across multiple life domains.',

    'Reports loss of interest in hobbies, social activities, or work; inability to feel pleasure ("I just don''t care anymore"); withdrawal from previously rewarding contexts.'

FROM hitop\_dimensions d WHERE d.code \= 'DISTRESS';

INSERT INTO hitop\_symptoms (dimension\_id, code, display\_name, operational\_definition, behavioral\_indicators)

SELECT

    d.id,

    'RUMINATION',

    'Rumination',

    'Repetitive, passive focus on negative emotional states, their causes, and consequences, without constructive problem-solving.',

    'Reports being "stuck" thinking about events; circular reasoning during session; phrases like "I keep going over and over...", "why did this happen?"; difficulty redirecting topic.'

FROM hitop\_dimensions d WHERE d.code \= 'DISTRESS';

### 9.3 Why this matters for the LLM pipeline

When `llm-worker` calls Gemini with structured outputs, the JSON schema for HiTOP measurements uses **enum** constrained to valid `hitop_symptoms.code` values:

// In llm-worker, schema is generated from DB:

hitopSymptomCodes := q.ListActiveSymptomCodes(ctx)

// → \["DEPRESSED\_MOOD", "ANHEDONIA", "RUMINATION", ...\]

schema := \&genai.Schema{

    Type: genai.TypeArray,

    Items: \&genai.Schema{

        Type: genai.TypeObject,

        Properties: map\[string\]\*genai.Schema{

            "symptom\_code": {

                Type: genai.TypeString,

                Enum: hitopSymptomCodes, // \<-- CLOSED VOCABULARY

            },

            "severity": {Type: genai.TypeInteger, Minimum: 1, Maximum: 10},

            "confidence": {Type: genai.TypeNumber, Minimum: 0, Maximum: 1},

        },

        Required: \[\]string{"symptom\_code", "severity", "confidence"},

    },

}

This **physically prevents** Gemini from inventing symptom names. If model tries to output "FEELING\_BLUE" instead of "DEPRESSED\_MOOD", Vertex AI returns validation error before our code sees it.

### 9.4 Backend validation layer

Even with schema-enforced enum, we double-check on backend (defense in depth):

// pkg/hitop/validator.go

func (v \*Validator) ValidateMeasurement(ctx context.Context, m HitopMeasurement) error {

    exists, err := v.queries.ValidateSymptomCode(ctx, m.SymptomCode)

    if err \!= nil {

        return fmt.Errorf("validation failed: %w", err)

    }

    if \!exists {

        return ErrUnknownSymptomCode  // shouldn't happen, but guard anyway

    }

    if m.Severity \< 1 || m.Severity \> 10 {

        return ErrSeverityOutOfRange

    }

    if m.Confidence \< 0 || m.Confidence \> 1 {

        return ErrConfidenceOutOfRange

    }

    return nil

}

---

## 10\. Report Feedback Domain *(new in v4.2)*

This section provides the deep-dive design rationale and seed data for the feedback domain introduced in v4.2.

### 10.1 Purpose & business value

The feedback domain enables therapists (and later, patients and supervisors) to rate AI-generated clinical reports on a 5-star scale with optional structured tags and free-text comments. This is **not** a "nice to have" — it is the **foundation of the AI improvement loop**.

**Three core value streams:**

1. **AI improvement signal:** Negative feedback with category tags (e.g., `HALLUCINATION`, `TOO_GENERIC`) directly feeds Gemini prompt iteration and future fine-tuning datasets.  
2. **B2B sales artifact:** Aggregated quality metrics (e.g., "average rating 4.5/5 across CBT modality") become a measurable proof of clinical utility for clinic procurement decisions.  
3. **Per-therapist personalization:** Repeated complaints from a specific user (e.g., "always too generic") inform per-user prompt biasing in the LLM pipeline.

### 10.2 Granularity model

Two levels of feedback granularity, adopted simultaneously but exposed gradually in UX:

| Level | Target | UX trigger | Friction |
| :---- | :---- | :---- | :---- |
| **OVERALL** | Whole report | Always shown after report view | Low (1 click) |
| **Per-section** | One of 7 report sections \+ patient view | Drill-down only when overall ≤ 3 stars | Higher (up to 7 ratings) |

This **proportional friction** principle ensures terapeutas with positive experience commit minimal effort, while frustrated users have a structured way to provide rich diagnostic signal.

### 10.3 UX flow specification

┌──── Step 1: Always shown ─────────────────────┐

│ "Was this report helpful?"                    │

│ ⭐ ⭐ ⭐ ⭐ ⭐                                   │

│ (optional) \[comment textarea\]                 │

└───────────────────────────────────────────────┘

              │

       rating ≤ 3?

              │

              ▼

┌──── Step 2: Drill-down (conditional) ─────────┐

│ "Which section needs improvement?"            │

│                                               │

│ Transcript      ⭐⭐⭐⭐⭐  \[skip\]              │

│ Summary         ⭐⭐⭐⭐⭐  \[skip\]              │

│ Analysis        ⭐⭐⭐⭐⭐  \[skip\]              │

│ Hypotheses      ⭐⭐⭐⭐⭐  \[skip\]              │

│ Mechanisms      ⭐⭐⭐⭐⭐  \[skip\]              │

│ Action Points   ⭐⭐⭐⭐⭐  \[skip\]              │

│ Safety Alerts   ⭐⭐⭐⭐⭐  \[skip\]              │

│                                               │

│ Categories:                                   │

│ ☐ HALLUCINATION                               │

│ ☐ TOO\_GENERIC                                 │

│ ☐ MISSED\_KEY\_THEME                            │

│ ☐ ... (closed ontology)                       │

│                                               │

│ (optional) \[free-text comment\]                │

└───────────────────────────────────────────────┘

### 10.4 Privacy strategy (4 layers)

Free-text comments are the highest-risk surface for accidental PHI leakage. Four-layer defense:

1. **UI prevention:** Placeholder text warns "do not include patient names or identifying details"; inline regex flags likely PII patterns before submit.  
2. **Backend Cloud DLP redaction:** Before storage, comments pass through Google Cloud DLP API with `PERSON_NAME`, `POLAND_PESEL`, `PHONE_NUMBER`, `EMAIL_ADDRESS`, `STREET_ADDRESS` info types replaced with tokens (e.g., `[NAME]`).  
3. **Schema flag:** `comment_redacted_at TIMESTAMPTZ` marks comments touched by DLP for audit purposes.  
4. **18-month TTL:** Comment text is nullified after 18 months by nightly cron job (`RedactExpiredComments` query). Quantitative ratings persist; qualitative text expires.

### 10.5 Seed data — closed ontology of 14 categories

The category taxonomy is **versioned seed data**, not user-editable. Adding a new category requires a migration \+ product decision.

\-- \============================================================

\-- POSITIVE CATEGORIES (4 codes)

\-- \============================================================

INSERT INTO feedback\_categories (code, display\_name, description, polarity, sort\_order) VALUES

    ('ACCURATE\_ANALYSIS',

     'Accurate analysis',

     'AI correctly interpreted the therapeutic process and clinical material.',

     'POSITIVE', 10),

    ('USEFUL\_HYPOTHESES',

     'Useful hypotheses',

     'Hypotheses expanded my understanding of the patient.',

     'POSITIVE', 11),

    ('GOOD\_ACTION\_POINTS',

     'Good recommendations',

     'Action points were specific, actionable, and clinically relevant.',

     'POSITIVE', 12),

    ('SAFETY\_ALERT\_HELPFUL',

     'Helpful safety alert',

     'AI identified an important risk indicator I had missed.',

     'POSITIVE', 13);

\-- \============================================================

\-- NEGATIVE CATEGORIES — content quality (6 codes)

\-- \============================================================

INSERT INTO feedback\_categories (code, display\_name, description, polarity, sort\_order) VALUES

    ('HALLUCINATION',

     'Hallucination',

     'AI fabricated facts or events that were not present in the session.',

     'NEGATIVE', 100),

    ('TOO\_GENERIC',

     'Too generic',

     'Analysis applies to any patient; lacks specificity to this case.',

     'NEGATIVE', 101),

    ('MISSED\_KEY\_THEME',

     'Missed key theme',

     'AI failed to identify an important topic or thread from the session.',

     'NEGATIVE', 102),

    ('INCORRECT\_INTERPRETATION',

     'Incorrect interpretation',

     'AI misinterpreted patient utterances or therapeutic dynamics.',

     'NEGATIVE', 103),

    ('WRONG\_MODALITY\_FRAME',

     'Wrong modality framing',

     'Analysis does not align with my therapeutic orientation.',

     'NEGATIVE', 104),

    ('UNSAFE\_RECOMMENDATION',

     'Unsafe recommendation',

     'A suggestion was clinically inappropriate or potentially harmful.',

     'NEGATIVE', 105);

\-- \============================================================

\-- NEGATIVE CATEGORIES — process quality (4 codes)

\-- \============================================================

INSERT INTO feedback\_categories (code, display\_name, description, polarity, sort\_order) VALUES

    ('TRANSCRIPT\_ERRORS',

     'Transcription errors',

     'Significant transcription errors or speaker confusion.',

     'NEGATIVE', 200),

    ('FORMATTING\_ISSUES',

     'Formatting issues',

     'Report is poorly formatted, hard to read or navigate.',

     'NEGATIVE', 201),

    ('TOO\_LONG',

     'Too verbose',

     'Report is unnecessarily long; key information is buried.',

     'NEGATIVE', 202),

    ('TOO\_SHORT',

     'Too brief',

     'Report omits substantive content from the session.',

     'NEGATIVE', 203);

### 10.6 Architecture integration

The feedback domain is owned by `clinical-svc` (no new microservice). The service exposes 5 new gRPC endpoints:

| Endpoint | Purpose | Auth |
| :---- | :---- | :---- |
| `SubmitFeedback` | Create or update feedback (idempotent on rater \+ report \+ target) | THERAPIST role, owns the report |
| `UpdateFeedbackCategories` | Replace category tags atomically | Same |
| `GetFeedbackForReport` | Fetch one's own feedback for a report | Same |
| `ListMyRecentFeedback` | Personal feedback history | Self only |
| `DeleteFeedback` | Soft-delete a feedback record | Self only |

**Outbox event** `feedback.submitted` is published transactionally with the DB write. Subscribers:

| Subscriber | Action |
| :---- | :---- |
| `analytics-svc` | Update aggregates per modality, per section |
| `notification-svc` | Slack alert if rating ≤ 2 \+ critical category |
| `prompt-tuner-worker` *(phase 2\)* | Add to LLM training data corpus |
| `audit-svc` | Compliance audit log entry |

**Firestore sync:** `analytics-svc` recomputes per-therapist aggregate stats hourly and pushes to `user_stats/{uid}` document for Flutter app to subscribe to.

### 10.7 RBAC and Firestore rules

| Operation | Permission |
| :---- | :---- |
| `SubmitFeedback` on own report | THERAPIST owner ✅ |
| `ReadFeedback` on own report | THERAPIST owner ✅ |
| `ReadFeedback` on another therapist's report | NEVER ❌ |
| `ReadAggregates` (per-modality) | ADMIN of organization (Looker Studio) ✅ |
| `ReadAllFeedback` | Anthropic / SuperWizor Product team only ✅ |

Firestore rules for read-only stats sync:

match /user\_stats/{userId} {

  allow read: if request.auth.uid \== userId;

  allow write: if false;  // only backend

}

### 10.8 Implementation roadmap

| Sprint | Deliverable | Duration |
| :---- | :---- | :---- |
| **Sprint 1** | DDL migration \+ `report_feedback` only (OVERALL ratings \+ comments) | 1 week |
| **Sprint 2** | `feedback_categories` ontology \+ per-section drill-down UX | 1 week |
| **Sprint 3** | Cloud DLP redaction \+ 18-month TTL cron | 3 days |
| **Sprint 4** | Looker Studio dashboard \+ Slack alerts on negative feedback | 1 week |
| **Phase 2** | Per-therapist personalization in LLM pipeline | TBD |

### 10.9 Risk mitigations

| Risk | Mitigation |
| :---- | :---- |
| **Survivor bias** in ratings | Cross-reference with retention metrics (do users renew?) |
| **Rating inflation** over time | Use relative metrics (section A vs B same week) over absolute trends |
| **Feedback bombing** by disgruntled users | Rate limit: max 5 feedbacks/day/user; outlier detection in analytics |
| **Inconsistent rating \+ categories** | UI warns: if rating ≥ 4 but NEGATIVE categories selected, ask "is this intentional?" |
| **Feedback fatigue** | Show impact ("your feedback helped improve X"); ask every 3rd report after 50+ feedbacks |
| **PHI leakage in comments** | 4-layer defense: UI warning \+ DLP redaction \+ audit flag \+ 18-month TTL |

---

## 11\. Versioning & Change Log

### 11.1 Schema versioning

The schema is versioned via migration files. Major architectural changes are documented in this file with explicit version bump.

| Version | Date | Author | Changes |
| :---- | :---- | :---- | :---- |
| 4.0 | 2026-01 | initial Konstytucja | Original Polish ER diagram |
| 4.1 | 2026-04 | architecture review | English naming, Stripe billing, pgvector RAG, HiTOP closed ontology, outbox pattern, idempotency keys, audit events |
| 4.2 | 2026-04 | product feedback feature | Report Feedback domain (`report_feedback`, `feedback_categories`, junction table); 9th domain; closed ontology of 14 categories; Cloud DLP comment redaction; 18-month TTL on comments; ADRs DM-011 to DM-015; new gRPC endpoints in `clinical-svc`; new Pub/Sub topic `feedback.submitted` |
| **4.3** | **2026-04** | **architecture decision** | **Removed Invoicing domain (`invoices`, `invoice_line_items`, `tax_records`, `invoice_status` enum). Invoice generation, KSeF submission, VAT records and PDF rendering now delegated to external SaaS (e.g., Fakturownia). Retained `payment_events` for subscription state and reconciliation. ADR-DM-016 added. `invoicing-svc` removed from microservice topology. DDL sections renumbered (4.5–4.10). Migration sequence renumbered (0005 onward).** |

### 11.2 Backward compatibility commitments

- **Column additions:** always backward-compatible (clients ignore unknown).  
- **Column removals:** require Expand-Contract migration over 2 releases.  
- **Type changes:** require dual-write window, never direct ALTER.  
- **FK additions:** require backfill \+ validation phase.

---

## 📎 Appendix A — Naming Cheatsheet

| Concept | Convention | Example |
| :---- | :---- | :---- |
| Table | `snake_case`, plural | `patient_files` |
| Column | `snake_case` | `working_alias` |
| Primary key | `id` | `id UUID` |
| Foreign key | `<entity>_id` | `therapist_id` |
| Boolean | `is_` / `has_` / `can_` prefix | `is_active`, `has_consent` |
| Timestamp | `_at` suffix | `created_at`, `deleted_at` |
| Counter | `_count` suffix | `character_count` |
| Encrypted | `_ciphertext` \+ `_encrypted_dek` | `report_payload_ciphertext` |
| Enum type | `snake_case` | `session_status` |
| Index | `idx_<table>_<columns>` | `idx_sessions_therapist_date` |
| Unique constraint | `uq_<table>_<columns>` | implicit via UNIQUE |
| Check constraint | `chk_<table>_<rule>` | `chk_session_duration` |
| Trigger | `trg_<table>_<action>` | `trg_clinical_memory_revision` |
| Function | `fn_<verb>_<object>` | `fn_increment_memory_revision` |

---

**End of Document v4.3**

*This data model is the canonical source for SuperWizor AI's relational schema. All microservice repositories, ORM definitions, and Looker Studio data sources must conform to it. Changes require ADR \+ migration plan \+ version bump in this file.*  
