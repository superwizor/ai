---
type: System Documentation
title: "🆔 Faza 1 --- Tożsamość i dane (Tygodnie 3-4)"
description: "Wersja: 1.0 Status: Implementation guide. Zgodne z architekturą 02ARCHITEKTURATECHNICZNA.md, modelem danych 03DATAMODEL.md v4.3, oraz fundamentem z 04FAZA0FU..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/05_FAZA_1_TOZSAMOSC_DANE.md
tags: [ai, analytics, billing, crm, database, frontend, identity, infrastructure, ingestion, notifications, phase-1, security, testing]
timestamp: 2026-05-02T15:37:35+02:00
---

# 🆔 Faza 1 --- Tożsamość i dane (Tygodnie 3-4)

**Wersja:** 1.0 **Status:** Implementation guide. Zgodne z architekturą
02_ARCHITEKTURA_TECHNICZNA.md, modelem danych 03_DATA_MODEL.md v4.3,
oraz fundamentem z 04_FAZA_0_FUNDAMENT.md. **Owner:** Senior Backend +
Flutter dev **Czas trwania:** 10 dni roboczych (2 tygodnie) **Cel
fazy:** Postawić **identity-svc** i **clinical-svc** + integracja z
Firebase Auth + minimalna aplikacja Flutter wykonująca login + listę
pustych kartotek. Po Fazie 1 mamy działający system uwierzytelniania
E2E.

> **🤖 AI INSTRUCTION / WAŻNE DLA FLUTTERA:**
> Kiedykolwiek agent (Ty) pisze lub modyfikuje kod we **Flutterze**, musi od razu stosować dobry design system i dobre praktyki. 
> W tym celu **BEZWZGLĘDNIE** używaj pliku:
> `/Users/maciekckoklormam91/Desktop/APP - Superwizor AI/docs/B_05_ui_ux_design_system.md`
> Ponadto, w celu weryfikacji i sprawdzania designu, **MUSISZ** używać pliku:
> `/Users/maciekckoklormam91/Desktop/APP - Superwizor AI/docs/B_08_design_checker.md`

## 📋 Spis treści

- [x] 1.  [Definition of Done dla całej fazy](#definition-of-done-dla-całej-fazy)
- [x] 2.  [Sprint planning i timeline](#sprint-planning-i-timeline)
- [x] 3.  [Prerequisites](#prerequisites)
- [x] 4.  [Sprint 1.1 --- Migracje DDL: Identity + Clinical (Dni 1-2)](#sprint-11--migracje-ddl-identity--clinical)
- [x] 5.  [Sprint 1.2 --- identity-svc (Dni 3-5)](#sprint-12--identity-svc)
- [x] 6.  [Sprint 1.3 --- clinical-svc (Dni 6-8)](#sprint-13--clinical-svc)
- [x] 7.  [Sprint 1.4 --- Flutter integration (Dzień 9)](#sprint-14--flutter-integration)
- [x] 8.  [Sprint 1.5 --- E2E test + observability (Dzień 10)](#sprint-15--e2e-test--observability)
- [x] 9.  [Troubleshooting cookbook](#troubleshooting-cookbook)
- [x] 10. [Pre-Faza 2 checklist](#pre-faza-2-checklist)

## Definition of Done dla całej fazy

Faza 1 jest "done" kiedy spełnione są WSZYSTKIE poniższe:

- Migracje SQL 000002_enums.up.sql, 000003_identity.up.sql,
  000005_clinical.up.sql zaaplikowane na staging DB (000004_billing skip
  do Fazy 2).

  Firebase project z włączonym Email/Password + Phone Auth.

  **identity-svc** deployowany na staging Cloud Run, gRPC endpoints
  działają:

  - ValidateToken weryfikuje Firebase JWT.

  - GetUser zwraca profil z PostgreSQL.

  - UpdateProfile mutuje profil.

  **clinical-svc** deployowany na staging Cloud Run, gRPC endpoints
  działają:

  - CreatePatientFile tworzy kartotekę.

  - ListPatientFiles zwraca listę dla zalogowanego terapeuty.

  - GetPatientFile zwraca jedną kartotekę (z RBAC check).

  **Flutter app** w trybie debug:

  - Logowanie przez Firebase Auth (email/password).

  - Lista kartotek (puste albo z 1-2 demo records).

  - Tworzenie nowej kartoteki.

  **Cloud Logging** + **Cloud Trace** integracja: logi z trace_id
  widoczne w UI.

  **E2E test:** Flutter user_42 → identity-svc.ValidateToken →
  clinical-svc.CreatePatientFile → DB INSERT → Flutter receives 200.

  **Audit events** loggowane przy patient_file.create.

  Test coverage ≥ 75% dla obu serwisów.

## Sprint planning i timeline

Tydzień 3 Tydzień 4

┌─────────────┬─────────────┐ ┌─────────────┬─────────────┐

│ Pn-Wt │ Śr-Pt │ │ Pn-Śr │ Czw-Pt │

│ Sprint 1.1 │ Sprint 1.2 │ │ Sprint 1.3 │ 1.4 + 1.5 │

│ Migracje DDL│ identity-svc│ │ clinical-svc│ Flutter+E2E │

└─────────────┴─────────────┘ └─────────────┴─────────────┘

### Dependencies

Sprint 1.1 (DDL)

│

├──► Sprint 1.2 (identity-svc)

│ │

│ └──► Sprint 1.3 (clinical-svc, używa identity-svc dla RBAC)

│ │

│ └──► Sprint 1.4 (Flutter)

│ │

│ └──► Sprint 1.5 (E2E + observability)

### Owner & accountability

  -----------------------------------------------------------------------
  **Sprint**        **Primary owner** **Reviewer**      **Estimate**
  ----------------- ----------------- ----------------- -----------------
  1.1 Migracje      DevOps + Senior   Tech lead         2 dni
                    backend                             

  1.2 identity-svc  Senior backend    DevOps            3 dni

  1.3 clinical-svc  Senior backend    Tech lead         3 dni

  1.4 Flutter       Flutter dev       Tech lead         1 dzień

  1.5 E2E + obs     DevOps            Senior backend    1 dzień
  -----------------------------------------------------------------------

## Prerequisites

**Z Fazy 0 musisz mieć:**

- Cloud SQL PostgreSQL 16 z pgvector działa.

  Hello-world service deployowany na staging Cloud Run.

  GitHub Actions CI przechodzi.

  WIF + Artifact Registry skonfigurowane.

**Nowe rzeczy do dodania:**

- **Firebase project** stworzony i podłączony do superwizor-ai-25ecd
  (instrukcje w Sprint 1.2).

  **sqlc** zainstalowany lokalnie:

> brew install sqlc
>
> sqlc version \# >= 1.27

- **grpcurl** dla testowania gRPC endpoints:

> brew install grpcurl

- **Flutter SDK** (>= 3.24):

> brew install --cask flutter
>
> flutter --version

## Sprint 1.1 --- Migracje DDL: Identity + Clinical

**Czas:** 2 dni **Cel:** Stworzyć i zaaplikować migracje SQL z
03_DATA_MODEL.md v4.3 dla domen Identity i Clinical.

### Task 1.1.1 --- Migracja 000002: Enums

make migrate-create NAME=enums

cat > migrations/000002_enums.up.sql <<'EOF'

-- ============================================

-- IDENTITY ENUMS

-- ============================================

CREATE TYPE user_role AS ENUM ('THERAPIST', 'PATIENT');

CREATE TYPE organization_type AS ENUM ('SOLO', 'CLINIC',
'ENTERPRISE');

-- ============================================

-- BILLING ENUMS (potrzebne dla FK z users.organization_id)

-- ============================================

CREATE TYPE plan_tier AS ENUM ('SOLO', 'PRO', 'CLINIC',
'PATIENT');

CREATE TYPE billing_cycle AS ENUM ('MONTHLY', 'SEMI_ANNUAL',
'ANNUAL');

CREATE TYPE payment_provider AS ENUM (

'STRIPE', 'P24', 'APPLE_IAP', 'GOOGLE_IAP', 'MANUAL'

);

CREATE TYPE subscription_status AS ENUM (

'TRIALING', 'ACTIVE', 'PAST_DUE', 'CANCELED', 'INCOMPLETE',
'PAUSED'

);

-- ============================================

-- CLINICAL ENUMS

-- ============================================

CREATE TYPE relation_status AS ENUM (

'INVITED', 'ACTIVE', 'PAUSED', 'TERMINATED'

);

CREATE TYPE process_type AS ENUM (

'INDIVIDUAL', 'COUPLE', 'FAMILY', 'GROUP'

);

CREATE TYPE contact_form AS ENUM ('OFFICE', 'ONLINE', 'FIELD',
'PHONE');

CREATE TYPE session_status AS ENUM (

'CREATED', 'RECORDING', 'UPLOADING', 'TRANSCRIBING',

'ANALYZING', 'COMPLETED', 'FAILED', 'CANCELED'

);

CREATE TYPE upload_status AS ENUM (

'PENDING', 'UPLOADED', 'PROCESSING', 'FAILED', 'EXPIRED'

);

-- ============================================

-- AUDIT ENUMS

-- ============================================

CREATE TYPE outbox_status AS ENUM (

'PENDING', 'PUBLISHED', 'FAILED', 'EXPIRED'

);

EOF

cat > migrations/000002_enums.down.sql <<'EOF'

DROP TYPE IF EXISTS outbox_status;

DROP TYPE IF EXISTS upload_status;

DROP TYPE IF EXISTS session_status;

DROP TYPE IF EXISTS contact_form;

DROP TYPE IF EXISTS process_type;

DROP TYPE IF EXISTS relation_status;

DROP TYPE IF EXISTS subscription_status;

DROP TYPE IF EXISTS payment_provider;

DROP TYPE IF EXISTS billing_cycle;

DROP TYPE IF EXISTS plan_tier;

DROP TYPE IF EXISTS organization_type;

DROP TYPE IF EXISTS user_role;

EOF

### Task 1.1.2 --- Migracja 000003: Identity Domain

make migrate-create NAME=identity

cat > migrations/000003_identity.up.sql <<'EOF'

-- ============================================

-- ADDRESSES

-- ============================================

CREATE TABLE addresses (

id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

country_code CHAR(2) NOT NULL,

region VARCHAR(100),

city VARCHAR(100) NOT NULL,

postal_code VARCHAR(20) NOT NULL,

street_line VARCHAR(255) NOT NULL,

building_number VARCHAR(20) NOT NULL,

unit_number VARCHAR(20),

directions TEXT,

created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

CONSTRAINT chk_country_code_iso CHECK (country_code ~
'^[A-Z]{2}$')

);

-- ============================================

-- ORGANIZATIONS

-- ============================================

CREATE TABLE organizations (

id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

legal_name VARCHAR(255) NOT NULL,

tax_id VARCHAR(50),

vat_id_eu VARCHAR(20),

headquarters_address_id UUID REFERENCES addresses(id) ON DELETE
RESTRICT,

primary_admin_user_id UUID,

type organization_type NOT NULL DEFAULT 'SOLO',

created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

deleted_at TIMESTAMPTZ

);

CREATE INDEX idx_organizations_tax_id ON organizations(tax_id) WHERE
deleted_at IS NULL;

CREATE INDEX idx_organizations_vat_id_eu ON organizations(vat_id_eu)
WHERE deleted_at IS NULL;

-- ============================================

-- USERS

-- ============================================

CREATE TABLE users (

id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

role user_role NOT NULL,

organization_id UUID REFERENCES organizations(id) ON DELETE RESTRICT,

default_modality_id UUID,

billing_address_id UUID REFERENCES addresses(id) ON DELETE SET NULL,

firebase_uid VARCHAR(128) NOT NULL UNIQUE,

email VARCHAR(255) NOT NULL UNIQUE,

phone_number VARCHAR(20),

is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,

first_name VARCHAR(100) NOT NULL,

last_name VARCHAR(100) NOT NULL,

professional_title VARCHAR(255),

credentials_number VARCHAR(50),

biography TEXT,

avatar_url VARCHAR(500),

ui_language VARCHAR(10) NOT NULL DEFAULT 'pl',

timezone VARCHAR(50) NOT NULL DEFAULT 'Europe/Warsaw',

has_accepted_tos BOOLEAN NOT NULL DEFAULT FALSE,

has_marketing_consent BOOLEAN NOT NULL DEFAULT FALSE,

created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

deleted_at TIMESTAMPTZ,

CONSTRAINT chk_users_email_format CHECK (

email ~*
'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$'

)

);

CREATE INDEX idx_users_firebase_uid ON users(firebase_uid) WHERE
deleted_at IS NULL;

CREATE INDEX idx_users_organization_id ON users(organization_id) WHERE
deleted_at IS NULL;

CREATE INDEX idx_users_role ON users(role) WHERE deleted_at IS NULL;

-- Deferred FK

ALTER TABLE organizations

ADD CONSTRAINT fk_organizations_primary_admin

FOREIGN KEY (primary_admin_user_id) REFERENCES users(id) ON DELETE
RESTRICT;

EOF

cat > migrations/000003_identity.down.sql <<'EOF'

ALTER TABLE organizations DROP CONSTRAINT IF EXISTS
fk_organizations_primary_admin;

DROP TABLE IF EXISTS users;

DROP TABLE IF EXISTS organizations;

DROP TABLE IF EXISTS addresses;

EOF

### Task 1.1.3 --- Migracja 000005: Clinical Domain (skip 000004 dla Fazy 2)

\# 000004 zostawiamy puste dla billing --- wypełnimy w Fazie 2

touch migrations/000004_billing.up.sql

touch migrations/000004_billing.down.sql

make migrate-create NAME=clinical

cat > migrations/000005_clinical.up.sql <<'EOF'

-- ============================================

-- MODALITIES

-- ============================================

CREATE TABLE modalities (

id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

system_code VARCHAR(20) NOT NULL UNIQUE,

display_name VARCHAR(100) NOT NULL,

therapist_ai_general_prompt JSONB NOT NULL DEFAULT '{}'::jsonb,

therapist_ai_section_prompts JSONB NOT NULL DEFAULT '{}'::jsonb,

patient_ai_general_prompt JSONB NOT NULL DEFAULT '{}'::jsonb,

patient_ai_section_prompts JSONB NOT NULL DEFAULT '{}'::jsonb,

is_supported BOOLEAN NOT NULL DEFAULT TRUE,

created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

updated_at TIMESTAMPTZ NOT NULL DEFAULT now()

);

-- Deferred FK z users

ALTER TABLE users

ADD CONSTRAINT fk_users_default_modality

FOREIGN KEY (default_modality_id) REFERENCES modalities(id) ON DELETE
SET NULL;

-- ============================================

-- THERAPIST-PATIENT RELATIONS

-- ============================================

CREATE TABLE therapist_patient_relations (

id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

therapist_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

patient_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

status relation_status NOT NULL DEFAULT 'INVITED',

invited_at TIMESTAMPTZ NOT NULL DEFAULT now(),

activated_at TIMESTAMPTZ,

terminated_at TIMESTAMPTZ,

CONSTRAINT chk_relation_different_users CHECK (therapist_id !=
patient_id)

);

CREATE UNIQUE INDEX idx_relations_unique_active

ON therapist_patient_relations(therapist_id, patient_id)

WHERE status IN ('INVITED', 'ACTIVE');

CREATE INDEX idx_relations_therapist

ON therapist_patient_relations(therapist_id, status);

CREATE INDEX idx_relations_patient

ON therapist_patient_relations(patient_id, status);

-- ============================================

-- PATIENT FILES

-- ============================================

CREATE TABLE patient_files (

id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

therapist_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

patient_id UUID REFERENCES users(id) ON DELETE RESTRICT,

relation_id UUID REFERENCES therapist_patient_relations(id) ON DELETE
RESTRICT,

modality_id UUID NOT NULL REFERENCES modalities(id) ON DELETE RESTRICT,

working_alias VARCHAR(255) NOT NULL,

process_type process_type NOT NULL DEFAULT 'INDIVIDUAL',

initial_complaint TEXT,

is_process_closed BOOLEAN NOT NULL DEFAULT FALSE,

has_recording_consent BOOLEAN NOT NULL DEFAULT FALSE,

consent_given_at TIMESTAMPTZ,

first_consultation_at TIMESTAMPTZ,

private_therapist_notes TEXT,

created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

deleted_at TIMESTAMPTZ

);

CREATE INDEX idx_patient_files_therapist

ON patient_files(therapist_id) WHERE deleted_at IS NULL;

CREATE INDEX idx_patient_files_patient

ON patient_files(patient_id) WHERE deleted_at IS NULL;

CREATE INDEX idx_patient_files_modality

ON patient_files(modality_id) WHERE deleted_at IS NULL;

-- ============================================

-- AUDIT EVENTS (basic, dla Fazy 1)

-- ============================================

CREATE TABLE audit_events (

id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,

organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,

action VARCHAR(100) NOT NULL,

resource_type VARCHAR(50) NOT NULL,

resource_id UUID,

metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

ip_address INET,

user_agent TEXT,

occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()

);

CREATE INDEX idx_audit_events_actor ON audit_events(actor_user_id,
occurred_at DESC);

CREATE INDEX idx_audit_events_resource ON audit_events(resource_type,
resource_id);

CREATE INDEX idx_audit_events_occurred ON audit_events(occurred_at
DESC);

EOF

cat > migrations/000005_clinical.down.sql <<'EOF'

DROP TABLE IF EXISTS audit_events;

DROP TABLE IF EXISTS patient_files;

DROP TABLE IF EXISTS therapist_patient_relations;

ALTER TABLE users DROP CONSTRAINT IF EXISTS fk_users_default_modality;

DROP TABLE IF EXISTS modalities;

EOF

### Task 1.1.4 --- Seed data (3 modalities)

make migrate-create NAME=seed_modalities

cat > migrations/000006_seed_modalities.up.sql <<'EOF'

INSERT INTO modalities (system_code, display_name,
therapist_ai_general_prompt, is_supported)

VALUES

(

'UNIV',

'Universal (modality-agnostic)',

'{"system": "You are a clinical supervision assistant analyzing
therapy session transcripts. Provide observations grounded in evidence
from the session, using neutral therapeutic language."}',

TRUE

),

(

'CBT',

'Cognitive Behavioral Therapy',

'{"system": "You are a CBT-trained clinical supervision assistant.
Analyze session transcripts through the lens of cognitive distortions,
behavioral patterns, and the cognitive triangle
(thoughts-feelings-behaviors). Reference Beck, Ellis, and Beck CBT
frameworks."}',

TRUE

),

(

'PSYCHO',

'Psychodynamic',

'{"system": "You are a psychodynamically-oriented clinical
supervision assistant. Analyze session transcripts through the lens of
unconscious dynamics, transference, defense mechanisms, and object
relations. Reference Freud, Klein, and Kohut frameworks."}',

TRUE

);

EOF

cat > migrations/000006_seed_modalities.down.sql <<'EOF'

DELETE FROM modalities WHERE system_code IN ('UNIV', 'CBT',
'PSYCHO');

EOF

### Task 1.1.5 --- Apply wszystkie migracje

\# Pobierz hasło i connection

POSTGRES_PASSWORD=$(gcloud secrets versions access latest \\

--secret=postgres-password --project=superwizor-ai-25ecd)

CONNECTION_NAME=$(cd infra/environments/staging && terragrunt output
-raw sql_connection_name)

\# Start proxy

./cloud-sql-proxy ${CONNECTION_NAME} --port=5432 &

PROXY_PID=$!

sleep 5

\# Apply migrations

DB_USER=postgres DB_PASSWORD="${POSTGRES_PASSWORD}" make migrate-up

\# Sanity check

psql -h 127.0.0.1 -U postgres -d superwizor <<'EOF'

\\dt

SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 5;

SELECT system_code, display_name FROM modalities;

EOF

kill ${PROXY_PID}

**Spodziewany output:**

List of relations

Schema \| Name \| Type

\-\-\-\-\-\---+\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\---+\-\-\-\-\---

public \| addresses \| table

public \| audit_events \| table

public \| modalities \| table

public \| organizations \| table

public \| patient_files \| table

public \| schema_migrations \| table

public \| therapist_patient_relations \| table

public \| users \| table

version \| dirty

\-\-\-\-\-\-\---+\-\-\-\-\---

6 \| f

5 \| f

3 \| f

2 \| f

1 \| f

system_code \| display_name

\-\-\-\-\-\-\-\-\-\-\---+\-\-\-\-\-\-\-\-\-\-\-\-\-\---

UNIV \| Universal (modality-agnostic)

CBT \| Cognitive Behavioral Therapy

PSYCHO \| Psychodynamic

## Sprint 1.2 --- identity-svc

**Czas:** 3 dni **Cel:** Implementacja identity-svc z gRPC API, Firebase
Auth integration, JWT validation, sqlc-generated PostgreSQL access.

### Task 1.2.1 --- Firebase project setup

\# Instaluj Firebase CLI

npm install -g firebase-tools

\# Login

firebase login

\# Init Firebase w infra/firebase/

mkdir -p infra/firebase

cd infra/firebase

firebase projects:create superwizor-ai-25ecd --display-name "SuperWizor
Staging"

\# Linkuj z istniejącym GCP project

firebase use --add superwizor-ai-25ecd

\# Włącz Email/Password authentication

gcloud config set project superwizor-ai-25ecd

gcloud identitytoolkit projects update
--enabled-providers=password,phone

\# (Opcjonalnie) Włącz Phone auth dla 2FA

firebase auth:export users.json \# backup (puste na początek)

### Task 1.2.2 --- Proto definition dla identity-svc

cat > proto/identity/v1/identity.proto <<'EOF'

syntax = "proto3";

package identity.v1;

import "google/protobuf/timestamp.proto";

import "google/protobuf/empty.proto";

option go_package =
"github.com/superwizor-ai/backend/gen/go/identity/v1;identityv1";

service IdentityService {

// Validates Firebase JWT and returns user context

rpc ValidateToken(ValidateTokenRequest) returns (UserContext);

// Returns user profile by ID

rpc GetUser(GetUserRequest) returns (User);

// Returns user profile by Firebase UID (after login)

rpc GetUserByFirebaseUID(GetUserByFirebaseUIDRequest) returns (User);

// Creates user on first login (called from Firebase Auth trigger)

rpc CreateUser(CreateUserRequest) returns (User);

// Updates own profile

rpc UpdateProfile(UpdateProfileRequest) returns (User);

// RBAC: check permission on resource

rpc CheckPermission(CheckPermissionRequest) returns
(PermissionDecision);

// Health check

rpc HealthCheck(google.protobuf.Empty) returns (HealthCheckResponse);

}

enum UserRole {

USER_ROLE_UNSPECIFIED = 0;

USER_ROLE_THERAPIST = 1;

USER_ROLE_PATIENT = 2;

}

message User {

string id = 1;

UserRole role = 2;

string organization_id = 3;

string firebase_uid = 4;

string email = 5;

string phone_number = 6;

bool is_email_verified = 7;

string first_name = 8;

string last_name = 9;

string professional_title = 10;

string credentials_number = 11;

string ui_language = 12;

string timezone = 13;

bool has_accepted_tos = 14;

google.protobuf.Timestamp created_at = 15;

}

message UserContext {

string user_id = 1;

string firebase_uid = 2;

UserRole role = 3;

string organization_id = 4;

string email = 5;

}

message ValidateTokenRequest {

string firebase_id_token = 1;

}

message GetUserRequest {

string user_id = 1;

}

message GetUserByFirebaseUIDRequest {

string firebase_uid = 1;

}

message CreateUserRequest {

string firebase_uid = 1;

string email = 2;

UserRole role = 3;

string first_name = 4;

string last_name = 5;

string ui_language = 6;

string timezone = 7;

bool has_accepted_tos = 8;

}

message UpdateProfileRequest {

string user_id = 1;

string first_name = 2;

string last_name = 3;

string professional_title = 4;

string credentials_number = 5;

string biography = 6;

string phone_number = 7;

}

message CheckPermissionRequest {

string user_id = 1;

string resource_type = 2; // "patient_file", "session", etc.

string resource_id = 3;

string action = 4; // "read", "write", "delete"

}

message PermissionDecision {

bool allowed = 1;

string reason = 2; // human-readable reason if denied

}

message HealthCheckResponse {

string status = 1;

string version = 2;

}

EOF

\# Wygeneruj Go stubs

make proto

### Task 1.2.3 --- sqlc setup

cd services/identity-svc

cat > sqlc.yaml <<'EOF'

version: "2"

sql:

\- engine: "postgresql"

queries: "internal/adapters/postgres/queries"

schema: "../../migrations"

gen:

go:

package: "db"

out: "internal/adapters/postgres/db"

sql_package: "pgx/v5"

emit_json_tags: true

emit_pointers_for_null_types: true

emit_prepared_queries: false

EOF

mkdir -p internal/adapters/postgres/queries

cat > internal/adapters/postgres/queries/users.sql <<'EOF'

-- name: GetUserByID :one

SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL;

-- name: GetUserByFirebaseUID :one

SELECT * FROM users WHERE firebase_uid = $1 AND deleted_at IS NULL;

-- name: GetUserByEmail :one

SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL;

-- name: CreateUser :one

INSERT INTO users (

role, firebase_uid, email,

first_name, last_name, ui_language, timezone, has_accepted_tos

) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)

RETURNING *;

-- name: UpdateProfile :one

UPDATE users SET

first_name = COALESCE(NULLIF($2, ''), first_name),

last_name = COALESCE(NULLIF($3, ''), last_name),

professional_title = NULLIF($4, ''),

credentials_number = NULLIF($5, ''),

biography = NULLIF($6, ''),

phone_number = NULLIF($7, '')

WHERE id = $1 AND deleted_at IS NULL

RETURNING *;

-- name: SoftDeleteUser :exec

UPDATE users SET deleted_at = now() WHERE id = $1;

-- name: ListTherapistsByOrganization :many

SELECT * FROM users

WHERE organization_id = $1

AND role = 'THERAPIST'

AND deleted_at IS NULL

ORDER BY last_name, first_name;

EOF

\# Generate Go code

sqlc generate

### Task 1.2.4 --- Implementation: domain layer

\# Domain: user.go

mkdir -p internal/domain

cat > internal/domain/user.go <<'EOF'

package domain

import (

"time"

"github.com/google/uuid"

)

type UserRole string

const (

UserRoleTherapist UserRole = "THERAPIST"

UserRolePatient UserRole = "PATIENT"

)

type User struct {

ID uuid.UUID

Role UserRole

OrganizationID *uuid.UUID

FirebaseUID string

Email string

PhoneNumber *string

IsEmailVerified bool

FirstName string

LastName string

ProfessionalTitle *string

CredentialsNumber *string

Biography *string

UILanguage string

Timezone string

HasAcceptedToS bool

HasMarketingConsent bool

CreatedAt time.Time

}

type UserContext struct {

UserID uuid.UUID

FirebaseUID string

Role UserRole

OrganizationID *uuid.UUID

Email string

}

EOF

\# Domain errors

cat > internal/domain/errors.go <<'EOF'

package domain

import "errors"

var (

ErrUserNotFound = errors.New("user not found")

ErrUserAlreadyExists = errors.New("user already exists")

ErrInvalidToken = errors.New("invalid firebase token")

ErrTokenExpired = errors.New("firebase token expired")

ErrPermissionDenied = errors.New("permission denied")

ErrInvalidInput = errors.New("invalid input")

)

EOF

### Task 1.2.5 --- Implementation: Firebase Auth adapter

mkdir -p internal/adapters/firebase

cat > internal/adapters/firebase/auth.go <<'EOF'

package firebase

import (

"context"

"fmt"

firebase "firebase.google.com/go/v4"

"firebase.google.com/go/v4/auth"

"google.golang.org/api/option"

"github.com/superwizor-ai/backend/services/identity-svc/internal/domain"

)

type AuthClient struct {

client *auth.Client

}

func NewAuthClient(ctx context.Context, projectID string) (*AuthClient,
error) {

conf := &firebase.Config{ProjectID: projectID}

// Use Application Default Credentials w GCP

app, err := firebase.NewApp(ctx, conf, option.WithoutAuthentication())

if err != nil {

return nil, fmt.Errorf("init firebase app: %w", err)

}

authClient, err := app.Auth(ctx)

if err != nil {

return nil, fmt.Errorf("init auth client: %w", err)

}

return &AuthClient{client: authClient}, nil

}

// VerifyToken validates Firebase ID token and returns Firebase UID +
claims.

func (a *AuthClient) VerifyToken(ctx context.Context, idToken string)
(string, map[string]any, error) {

token, err := a.client.VerifyIDToken(ctx, idToken)

if err != nil {

// Firebase SDK returns specific error types

if auth.IsIDTokenExpired(err) {

return "", nil, domain.ErrTokenExpired

}

return "", nil, domain.ErrInvalidToken

}

return token.UID, token.Claims, nil

}

EOF

### Task 1.2.6 --- Implementation: gRPC handler

mkdir -p internal/adapters/grpc

cat > internal/adapters/grpc/server.go <<'EOF'

package grpc

import (

"context"

"errors"

"github.com/google/uuid"

"google.golang.org/grpc/codes"

"google.golang.org/grpc/status"

"google.golang.org/protobuf/types/known/emptypb"

"google.golang.org/protobuf/types/known/timestamppb"

identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"

"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/firebase"

"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"

"github.com/superwizor-ai/backend/services/identity-svc/internal/domain"

)

type Server struct {

identityv1.UnimplementedIdentityServiceServer

queries *db.Queries

auth *firebase.AuthClient

version string

}

func NewServer(queries *db.Queries, auth *firebase.AuthClient, version
string) *Server {

return &Server{queries: queries, auth: auth, version: version}

}

func (s *Server) HealthCheck(ctx context.Context, _ *emptypb.Empty)
(*identityv1.HealthCheckResponse, error) {

return &identityv1.HealthCheckResponse{

Status: "OK",

Version: s.version,

}, nil

}

func (s *Server) ValidateToken(ctx context.Context, req
*identityv1.ValidateTokenRequest) (*identityv1.UserContext, error) {

if req.FirebaseIdToken == "" {

return nil, status.Error(codes.InvalidArgument, "firebase_id_token is
required")

}

firebaseUID, _, err := s.auth.VerifyToken(ctx, req.FirebaseIdToken)

if err != nil {

if errors.Is(err, domain.ErrTokenExpired) {

return nil, status.Error(codes.Unauthenticated, "token expired")

}

return nil, status.Error(codes.Unauthenticated, "invalid token")

}

user, err := s.queries.GetUserByFirebaseUID(ctx, firebaseUID)

if err != nil {

return nil, status.Error(codes.NotFound, "user not registered")

}

resp := &identityv1.UserContext{

UserId: user.ID.String(),

FirebaseUid: user.FirebaseUID,

Role: toProtoRole(user.Role),

Email: user.Email,

}

if user.OrganizationID != nil {

resp.OrganizationId = user.OrganizationID.String()

}

return resp, nil

}

func (s *Server) GetUser(ctx context.Context, req
*identityv1.GetUserRequest) (*identityv1.User, error) {

id, err := uuid.Parse(req.UserId)

if err != nil {

return nil, status.Error(codes.InvalidArgument, "invalid user_id")

}

user, err := s.queries.GetUserByID(ctx, id)

if err != nil {

return nil, status.Error(codes.NotFound, "user not found")

}

return toProtoUser(user), nil

}

func (s *Server) CreateUser(ctx context.Context, req
*identityv1.CreateUserRequest) (*identityv1.User, error) {

// Walidacja

if req.FirebaseUid == "" \|\| req.Email == "" {

return nil, status.Error(codes.InvalidArgument, "firebase_uid and email
required")

}

if !req.HasAcceptedTos {

return nil, status.Error(codes.FailedPrecondition, "must accept ToS")

}

dbRole := db.UserRole("THERAPIST")

if req.Role == identityv1.UserRole_USER_ROLE_PATIENT {

dbRole = db.UserRole("PATIENT")

}

user, err := s.queries.CreateUser(ctx, db.CreateUserParams{

Role: dbRole,

FirebaseUID: req.FirebaseUid,

Email: req.Email,

FirstName: req.FirstName,

LastName: req.LastName,

UILanguage: req.UiLanguage,

Timezone: req.Timezone,

HasAcceptedToS: req.HasAcceptedTos,

})

if err != nil {

return nil, status.Error(codes.Internal, err.Error())

}

return toProtoUser(user), nil

}

func (s *Server) UpdateProfile(ctx context.Context, req
*identityv1.UpdateProfileRequest) (*identityv1.User, error) {

id, err := uuid.Parse(req.UserId)

if err != nil {

return nil, status.Error(codes.InvalidArgument, "invalid user_id")

}

user, err := s.queries.UpdateProfile(ctx, db.UpdateProfileParams{

ID: id,

FirstName: req.FirstName,

LastName: req.LastName,

ProfessionalTitle: req.ProfessionalTitle,

CredentialsNumber: req.CredentialsNumber,

Biography: req.Biography,

PhoneNumber: req.PhoneNumber,

})

if err != nil {

return nil, status.Error(codes.Internal, err.Error())

}

return toProtoUser(user), nil

}

func (s *Server) CheckPermission(ctx context.Context, req
*identityv1.CheckPermissionRequest) (*identityv1.PermissionDecision,
error) {

// Faza 1: tylko basic checks

// Faza 2 doda full RBAC z conditions

if req.UserId == "" \|\| req.ResourceType == "" \|\| req.Action ==
"" {

return nil, status.Error(codes.InvalidArgument, "missing required
fields")

}

// W Fazie 1: tylko właściciel ma dostęp do swoich rzeczy

// Detail logic jest po stronie clinical-svc --- identity-svc tylko
zwraca user info

return &identityv1.PermissionDecision{

Allowed: true,

Reason: "ok",

}, nil

}

// Helpers

func toProtoRole(r db.UserRole) identityv1.UserRole {

switch r {

case "THERAPIST":

return identityv1.UserRole_USER_ROLE_THERAPIST

case "PATIENT":

return identityv1.UserRole_USER_ROLE_PATIENT

}

return identityv1.UserRole_USER_ROLE_UNSPECIFIED

}

func toProtoUser(u db.User) *identityv1.User {

resp := &identityv1.User{

Id: u.ID.String(),

Role: toProtoRole(u.Role),

FirebaseUid: u.FirebaseUID,

Email: u.Email,

IsEmailVerified: u.IsEmailVerified,

FirstName: u.FirstName,

LastName: u.LastName,

UiLanguage: u.UILanguage,

Timezone: u.Timezone,

HasAcceptedTos: u.HasAcceptedToS,

CreatedAt: timestamppb.New(u.CreatedAt),

}

if u.OrganizationID != nil {

resp.OrganizationId = u.OrganizationID.String()

}

if u.PhoneNumber != nil {

resp.PhoneNumber = *u.PhoneNumber

}

if u.ProfessionalTitle != nil {

resp.ProfessionalTitle = *u.ProfessionalTitle

}

if u.CredentialsNumber != nil {

resp.CredentialsNumber = *u.CredentialsNumber

}

return resp

}

EOF

### Task 1.2.7 --- Main + config

cat > cmd/server/main.go <<'EOF'

package main

import (

"context"

"fmt"

"log/slog"

"net"

"os"

"github.com/jackc/pgx/v5/pgxpool"

"google.golang.org/grpc"

"google.golang.org/grpc/health"

healthpb "google.golang.org/grpc/health/grpc_health_v1"

"google.golang.org/grpc/reflection"

identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"

"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/firebase"

grpcadapter
"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/grpc"

"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"

)

func main() {

logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{

Level: slog.LevelInfo,

}))

slog.SetDefault(logger)

port := getEnv("PORT", "8080")

projectID := getEnv("GCP_PROJECT_ID", "superwizor-ai-25ecd")

dbDSN := os.Getenv("DATABASE_URL")

version := getEnv("VERSION", "dev")

if dbDSN == "" {

slog.Error("DATABASE_URL is required")

os.Exit(1)

}

ctx := context.Background()

// DB pool

pool, err := pgxpool.New(ctx, dbDSN)

if err != nil {

slog.Error("failed to connect to db", "error", err)

os.Exit(1)

}

defer pool.Close()

if err := pool.Ping(ctx); err != nil {

slog.Error("db ping failed", "error", err)

os.Exit(1)

}

queries := db.New(pool)

// Firebase

authClient, err := firebase.NewAuthClient(ctx, projectID)

if err != nil {

slog.Error("firebase init failed", "error", err)

os.Exit(1)

}

// gRPC server

lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))

if err != nil {

slog.Error("listen failed", "error", err)

os.Exit(1)

}

grpcServer := grpc.NewServer()

// Register identity service

identityv1.RegisterIdentityServiceServer(grpcServer,
grpcadapter.NewServer(queries, authClient, version))

// Health checks (Cloud Run probe)

healthServer := health.NewServer()

healthServer.SetServingStatus("",
healthpb.HealthCheckResponse_SERVING)

healthpb.RegisterHealthServer(grpcServer, healthServer)

// Reflection (dla grpcurl debug)

reflection.Register(grpcServer)

slog.Info("identity-svc starting", "port", port, "version",
version)

if err := grpcServer.Serve(lis); err != nil {

slog.Error("serve failed", "error", err)

os.Exit(1)

}

}

func getEnv(key, fallback string) string {

if v := os.Getenv(key); v != "" {

return v

}

return fallback

}

EOF

### Task 1.2.8 --- Dockerfile

cat > Dockerfile <<'EOF'

FROM golang:1.23-alpine AS builder

WORKDIR /app

\# Copy workspace files

COPY go.work go.work.sum ./

COPY services/identity-svc services/identity-svc

COPY pkg/ pkg/

COPY gen/ gen/

WORKDIR /app/services/identity-svc

RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server
./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /server /server

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/server"]

EOF

### Task 1.2.9 --- Unit tests

mkdir -p internal/adapters/grpc

cat > internal/adapters/grpc/server_test.go <<'EOF'

package grpc

import (

"context"

"testing"

"github.com/google/uuid"

"github.com/stretchr/testify/assert"

"github.com/stretchr/testify/require"

identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"

"github.com/superwizor-ai/backend/services/identity-svc/internal/adapters/postgres/db"

)

// TestHealthCheck verifies basic server liveness

func TestHealthCheck(t *testing.T) {

srv := NewServer(nil, nil, "test-1.0")

resp, err := srv.HealthCheck(context.Background(), nil)

require.NoError(t, err)

assert.Equal(t, "OK", resp.Status)

assert.Equal(t, "test-1.0", resp.Version)

}

func TestToProtoRole(t *testing.T) {

tests := []struct {

dbRole db.UserRole

expected identityv1.UserRole

}{

{"THERAPIST", identityv1.UserRole_USER_ROLE_THERAPIST},

{"PATIENT", identityv1.UserRole_USER_ROLE_PATIENT},

{"UNKNOWN", identityv1.UserRole_USER_ROLE_UNSPECIFIED},

}

for _, tt := range tests {

t.Run(string(tt.dbRole), func(t *testing.T) {

assert.Equal(t, tt.expected, toProtoRole(tt.dbRole))

})

}

}

func TestToProtoUser(t *testing.T) {

id := uuid.New()

orgID := uuid.New()

user := db.User{

ID: id,

Role: "THERAPIST",

OrganizationID: &orgID,

FirebaseUID: "firebase-uid-123",

Email: "test@example.com",

FirstName: "Anna",

LastName: "Kowalska",

UILanguage: "pl",

Timezone: "Europe/Warsaw",

HasAcceptedToS: true,

}

proto := toProtoUser(user)

assert.Equal(t, id.String(), proto.Id)

assert.Equal(t, identityv1.UserRole_USER_ROLE_THERAPIST, proto.Role)

assert.Equal(t, orgID.String(), proto.OrganizationId)

assert.Equal(t, "test@example.com", proto.Email)

assert.Equal(t, "Anna", proto.FirstName)

}

EOF

\# Run tests

cd services/identity-svc

go mod tidy

go test ./\...

### Task 1.2.10 --- Deploy do Cloud Run

cd ../..

\# Build i push

gcloud builds submit \\

--tag
europe-central2-docker.pkg.dev/superwizor-ai-25ecd/services/identity-svc:v0.1.0
\\

--project=superwizor-ai-25ecd \\

--region=europe-central2 \\

-f services/identity-svc/Dockerfile

\# Deploy

gcloud run deploy identity-svc \\

--image=europe-central2-docker.pkg.dev/superwizor-ai-25ecd/services/identity-svc:v0.1.0
\\

--region=europe-central2 \\

--project=superwizor-ai-25ecd \\

--no-allow-unauthenticated \\

--vpc-connector=swvpc-connector \\

--vpc-egress=private-ranges-only \\

--max-instances=5 \\

--min-instances=0 \\

--memory=512Mi \\

--cpu=1 \\

--use-http2 \\

--set-env-vars="GCP_PROJECT_ID=superwizor-ai-25ecd,VERSION=v0.1.0" \\

--set-secrets="DATABASE_URL=postgres-database-url:latest"

### Smoke test Sprint 1.2

\# Test gRPC HealthCheck via grpcurl (przez Cloud Run authentication)

TOKEN=$(gcloud auth print-identity-token)

SERVICE_URL=$(gcloud run services describe identity-svc \\

--region=europe-central2 --project=superwizor-ai-25ecd \\

--format="value(status.url)" \| sed 's\|https://\|\|')

grpcurl -H "authorization: Bearer ${TOKEN}" \\

${SERVICE_URL}:443 \\

identity.v1.IdentityService/HealthCheck

\# Spodziewany output: {"status": "OK", "version": "v0.1.0"}

## Sprint 1.3 --- clinical-svc

**Czas:** 3 dni **Cel:** Implementacja clinical-svc dla CRUD kartotek
pacjentów z RBAC delegowanym do identity-svc.

### Task 1.3.1 --- Proto definition

cat > proto/clinical/v1/clinical.proto <<'EOF'

syntax = "proto3";

package clinical.v1;

import "google/protobuf/timestamp.proto";

import "google/protobuf/empty.proto";

option go_package =
"github.com/superwizor-ai/backend/gen/go/clinical/v1;clinicalv1";

service ClinicalService {

rpc CreatePatientFile(CreatePatientFileRequest) returns (PatientFile);

rpc GetPatientFile(GetPatientFileRequest) returns (PatientFile);

rpc ListPatientFiles(ListPatientFilesRequest) returns
(ListPatientFilesResponse);

rpc UpdatePatientFile(UpdatePatientFileRequest) returns (PatientFile);

rpc DeletePatientFile(DeletePatientFileRequest) returns
(google.protobuf.Empty);

rpc ListModalities(google.protobuf.Empty) returns
(ListModalitiesResponse);

rpc HealthCheck(google.protobuf.Empty) returns (HealthCheckResponse);

}

enum ProcessType {

PROCESS_TYPE_UNSPECIFIED = 0;

PROCESS_TYPE_INDIVIDUAL = 1;

PROCESS_TYPE_COUPLE = 2;

PROCESS_TYPE_FAMILY = 3;

PROCESS_TYPE_GROUP = 4;

}

message PatientFile {

string id = 1;

string therapist_id = 2;

string patient_id = 3;

string modality_id = 4;

string modality_code = 5; // resolved

string working_alias = 6;

ProcessType process_type = 7;

string initial_complaint = 8;

bool is_process_closed = 9;

bool has_recording_consent = 10;

google.protobuf.Timestamp consent_given_at = 11;

google.protobuf.Timestamp first_consultation_at = 12;

string private_therapist_notes = 13;

google.protobuf.Timestamp created_at = 14;

google.protobuf.Timestamp updated_at = 15;

}

message Modality {

string id = 1;

string system_code = 2;

string display_name = 3;

bool is_supported = 4;

}

message CreatePatientFileRequest {

string therapist_id = 1; // walidowany przeciw token JWT

string modality_code = 2; // "CBT", "PSYCHO", "UNIV"

string working_alias = 3;

ProcessType process_type = 4;

string initial_complaint = 5;

bool has_recording_consent = 6;

string idempotency_key = 7;

}

message GetPatientFileRequest {

string patient_file_id = 1;

}

message ListPatientFilesRequest {

string therapist_id = 1;

int32 page_size = 2;

string page_token = 3;

}

message ListPatientFilesResponse {

repeated PatientFile patient_files = 1;

string next_page_token = 2;

}

message UpdatePatientFileRequest {

string patient_file_id = 1;

string working_alias = 2;

string initial_complaint = 3;

string private_therapist_notes = 4;

bool is_process_closed = 5;

}

message DeletePatientFileRequest {

string patient_file_id = 1;

}

message ListModalitiesResponse {

repeated Modality modalities = 1;

}

message HealthCheckResponse {

string status = 1;

string version = 2;

}

EOF

make proto

### Task 1.3.2 --- sqlc queries

cd services/clinical-svc

cat > sqlc.yaml <<'EOF'

version: "2"

sql:

\- engine: "postgresql"

queries: "internal/adapters/postgres/queries"

schema: "../../migrations"

gen:

go:

package: "db"

out: "internal/adapters/postgres/db"

sql_package: "pgx/v5"

emit_json_tags: true

emit_pointers_for_null_types: true

EOF

mkdir -p internal/adapters/postgres/queries

cat > internal/adapters/postgres/queries/patient_files.sql <<'EOF'

-- name: CreatePatientFile :one

INSERT INTO patient_files (

therapist_id, modality_id, working_alias,

process_type, initial_complaint, has_recording_consent

) VALUES ($1, $2, $3, $4, $5, $6)

RETURNING *;

-- name: GetPatientFile :one

SELECT * FROM patient_files

WHERE id = $1 AND deleted_at IS NULL;

-- name: ListPatientFilesByTherapist :many

SELECT * FROM patient_files

WHERE therapist_id = $1 AND deleted_at IS NULL

ORDER BY created_at DESC

LIMIT $2 OFFSET $3;

-- name: CountPatientFilesByTherapist :one

SELECT COUNT(*) FROM patient_files

WHERE therapist_id = $1 AND deleted_at IS NULL;

-- name: UpdatePatientFile :one

UPDATE patient_files SET

working_alias = COALESCE(NULLIF($2, ''), working_alias),

initial_complaint = NULLIF($3, ''),

private_therapist_notes = NULLIF($4, ''),

is_process_closed = $5,

updated_at = now()

WHERE id = $1 AND deleted_at IS NULL

RETURNING *;

-- name: SoftDeletePatientFile :exec

UPDATE patient_files SET deleted_at = now()

WHERE id = $1 AND therapist_id = $2;

EOF

cat > internal/adapters/postgres/queries/modalities.sql <<'EOF'

-- name: ListSupportedModalities :many

SELECT id, system_code, display_name, is_supported

FROM modalities

WHERE is_supported = TRUE

ORDER BY display_name;

-- name: GetModalityByCode :one

SELECT id, system_code, display_name, is_supported

FROM modalities

WHERE system_code = $1 AND is_supported = TRUE;

EOF

cat > internal/adapters/postgres/queries/audit.sql <<'EOF'

-- name: CreateAuditEvent :exec

INSERT INTO audit_events (

actor_user_id, organization_id, action, resource_type, resource_id,
metadata

) VALUES ($1, $2, $3, $4, $5, $6);

EOF

sqlc generate

### Task 1.3.3 --- Server implementation

mkdir -p internal/adapters/grpc

cat > internal/adapters/grpc/server.go <<'EOF'

package grpc

import (

"context"

"encoding/json"

"github.com/google/uuid"

"google.golang.org/grpc/codes"

"google.golang.org/grpc/status"

"google.golang.org/protobuf/types/known/emptypb"

"google.golang.org/protobuf/types/known/timestamppb"

clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"

identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"

"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"

)

type Server struct {

clinicalv1.UnimplementedClinicalServiceServer

queries *db.Queries

identity identityv1.IdentityServiceClient

version string

}

func NewServer(queries *db.Queries, identity
identityv1.IdentityServiceClient, version string) *Server {

return &Server{queries: queries, identity: identity, version: version}

}

func (s *Server) HealthCheck(ctx context.Context, _ *emptypb.Empty)
(*clinicalv1.HealthCheckResponse, error) {

return &clinicalv1.HealthCheckResponse{

Status: "OK",

Version: s.version,

}, nil

}

func (s *Server) ListModalities(ctx context.Context, _
*emptypb.Empty) (*clinicalv1.ListModalitiesResponse, error) {

modalities, err := s.queries.ListSupportedModalities(ctx)

if err != nil {

return nil, status.Error(codes.Internal, err.Error())

}

resp := &clinicalv1.ListModalitiesResponse{}

for _, m := range modalities {

resp.Modalities = append(resp.Modalities, &clinicalv1.Modality{

Id: m.ID.String(),

SystemCode: m.SystemCode,

DisplayName: m.DisplayName,

IsSupported: m.IsSupported,

})

}

return resp, nil

}

func (s *Server) CreatePatientFile(ctx context.Context, req
*clinicalv1.CreatePatientFileRequest) (*clinicalv1.PatientFile, error)
{

therapistID, err := uuid.Parse(req.TherapistId)

if err != nil {

return nil, status.Error(codes.InvalidArgument, "invalid
therapist_id")

}

if req.WorkingAlias == "" \|\| req.ModalityCode == "" {

return nil, status.Error(codes.InvalidArgument, "working_alias and
modality_code required")

}

// Resolve modality

modality, err := s.queries.GetModalityByCode(ctx, req.ModalityCode)

if err != nil {

return nil, status.Errorf(codes.InvalidArgument, "unknown modality:
%s", req.ModalityCode)

}

// Map process type

dbProcessType := db.ProcessType("INDIVIDUAL")

switch req.ProcessType {

case clinicalv1.ProcessType_PROCESS_TYPE_COUPLE:

dbProcessType = "COUPLE"

case clinicalv1.ProcessType_PROCESS_TYPE_FAMILY:

dbProcessType = "FAMILY"

case clinicalv1.ProcessType_PROCESS_TYPE_GROUP:

dbProcessType = "GROUP"

}

// Create

pf, err := s.queries.CreatePatientFile(ctx, db.CreatePatientFileParams{

TherapistID: therapistID,

ModalityID: modality.ID,

WorkingAlias: req.WorkingAlias,

ProcessType: dbProcessType,

InitialComplaint: &req.InitialComplaint,

HasRecordingConsent: req.HasRecordingConsent,

})

if err != nil {

return nil, status.Error(codes.Internal, err.Error())

}

// Audit log (async w produkcji; synchroniczne w MVP)

auditMeta, _ := json.Marshal(map[string]any{

"modality_code": modality.SystemCode,

"alias": req.WorkingAlias,

})

_ = s.queries.CreateAuditEvent(ctx, db.CreateAuditEventParams{

ActorUserID: &therapistID,

Action: "patient_file.create",

ResourceType: "patient_file",

ResourceID: &pf.ID,

Metadata: auditMeta,

})

return toProtoPatientFile(pf, modality.SystemCode), nil

}

func (s *Server) GetPatientFile(ctx context.Context, req
*clinicalv1.GetPatientFileRequest) (*clinicalv1.PatientFile, error) {

id, err := uuid.Parse(req.PatientFileId)

if err != nil {

return nil, status.Error(codes.InvalidArgument, "invalid
patient_file_id")

}

pf, err := s.queries.GetPatientFile(ctx, id)

if err != nil {

return nil, status.Error(codes.NotFound, "patient file not found")

}

// TODO Faza 2: pobrać modality_code dla wyświetlenia

return toProtoPatientFile(pf, ""), nil

}

func (s *Server) ListPatientFiles(ctx context.Context, req
*clinicalv1.ListPatientFilesRequest)
(*clinicalv1.ListPatientFilesResponse, error) {

therapistID, err := uuid.Parse(req.TherapistId)

if err != nil {

return nil, status.Error(codes.InvalidArgument, "invalid
therapist_id")

}

pageSize := req.PageSize

if pageSize <= 0 \|\| pageSize > 100 {

pageSize = 25

}

files, err := s.queries.ListPatientFilesByTherapist(ctx,
db.ListPatientFilesByTherapistParams{

TherapistID: therapistID,

Limit: pageSize,

Offset: 0, // simple paging w MVP, page_token w Fazie 2

})

if err != nil {

return nil, status.Error(codes.Internal, err.Error())

}

resp := &clinicalv1.ListPatientFilesResponse{}

for _, pf := range files {

resp.PatientFiles = append(resp.PatientFiles, toProtoPatientFile(pf,
""))

}

return resp, nil

}

// Helpers

func toProtoPatientFile(pf db.PatientFile, modalityCode string)
*clinicalv1.PatientFile {

resp := &clinicalv1.PatientFile{

Id: pf.ID.String(),

TherapistId: pf.TherapistID.String(),

ModalityId: pf.ModalityID.String(),

ModalityCode: modalityCode,

WorkingAlias: pf.WorkingAlias,

ProcessType: toProtoProcessType(pf.ProcessType),

IsProcessClosed: pf.IsProcessClosed,

HasRecordingConsent: pf.HasRecordingConsent,

CreatedAt: timestamppb.New(pf.CreatedAt),

UpdatedAt: timestamppb.New(pf.UpdatedAt),

}

if pf.PatientID != nil {

resp.PatientId = pf.PatientID.String()

}

if pf.InitialComplaint != nil {

resp.InitialComplaint = *pf.InitialComplaint

}

if pf.PrivateTherapistNotes != nil {

resp.PrivateTherapistNotes = *pf.PrivateTherapistNotes

}

return resp

}

func toProtoProcessType(p db.ProcessType) clinicalv1.ProcessType {

switch p {

case "INDIVIDUAL":

return clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL

case "COUPLE":

return clinicalv1.ProcessType_PROCESS_TYPE_COUPLE

case "FAMILY":

return clinicalv1.ProcessType_PROCESS_TYPE_FAMILY

case "GROUP":

return clinicalv1.ProcessType_PROCESS_TYPE_GROUP

}

return clinicalv1.ProcessType_PROCESS_TYPE_UNSPECIFIED

}

EOF

### Task 1.3.4 --- Main + Dockerfile (analogicznie do identity-svc)

cat > cmd/server/main.go <<'EOF'

package main

import (

"context"

"fmt"

"log/slog"

"net"

"os"

"github.com/jackc/pgx/v5/pgxpool"

"google.golang.org/grpc"

"google.golang.org/grpc/credentials/oauth"

"google.golang.org/grpc/health"

healthpb "google.golang.org/grpc/health/grpc_health_v1"

"google.golang.org/grpc/reflection"

"google.golang.org/idtoken"

clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"

identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"

grpcadapter
"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/grpc"

"github.com/superwizor-ai/backend/services/clinical-svc/internal/adapters/postgres/db"

)

func main() {

logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

slog.SetDefault(logger)

port := getEnv("PORT", "8080")

dbDSN := os.Getenv("DATABASE_URL")

identityURL := os.Getenv("IDENTITY_SVC_URL")

version := getEnv("VERSION", "dev")

if dbDSN == "" \|\| identityURL == "" {

slog.Error("DATABASE_URL and IDENTITY_SVC_URL required")

os.Exit(1)

}

ctx := context.Background()

// DB

pool, err := pgxpool.New(ctx, dbDSN)

if err != nil {

slog.Error("db connect failed", "error", err)

os.Exit(1)

}

defer pool.Close()

// gRPC client → identity-svc with Cloud Run service-to-service auth

tokenSource, err := idtoken.NewTokenSource(ctx, identityURL)

if err != nil {

slog.Error("token source failed", "error", err)

os.Exit(1)

}

identityConn, err := grpc.Dial(

identityURL,

grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: tokenSource}),

)

if err != nil {

slog.Error("identity dial failed", "error", err)

os.Exit(1)

}

defer identityConn.Close()

identityClient := identityv1.NewIdentityServiceClient(identityConn)

// Server

queries := db.New(pool)

srv := grpcadapter.NewServer(queries, identityClient, version)

lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))

if err != nil {

slog.Error("listen failed", "error", err)

os.Exit(1)

}

grpcServer := grpc.NewServer()

clinicalv1.RegisterClinicalServiceServer(grpcServer, srv)

// Health

healthServer := health.NewServer()

healthServer.SetServingStatus("",
healthpb.HealthCheckResponse_SERVING)

healthpb.RegisterHealthServer(grpcServer, healthServer)

reflection.Register(grpcServer)

slog.Info("clinical-svc starting", "port", port)

if err := grpcServer.Serve(lis); err != nil {

slog.Error("serve failed", "error", err)

os.Exit(1)

}

}

func getEnv(key, fallback string) string {

if v := os.Getenv(key); v != "" {

return v

}

return fallback

}

EOF

### Task 1.3.5 --- Deploy clinical-svc

\# Build

gcloud builds submit \\

--tag
europe-central2-docker.pkg.dev/superwizor-ai-25ecd/services/clinical-svc:v0.1.0
\\

--project=superwizor-ai-25ecd \\

--region=europe-central2 \\

-f services/clinical-svc/Dockerfile

\# Deploy

IDENTITY_URL=$(gcloud run services describe identity-svc \\

--region=europe-central2 --project=superwizor-ai-25ecd \\

--format="value(status.url)")

gcloud run deploy clinical-svc \\

--image=europe-central2-docker.pkg.dev/superwizor-ai-25ecd/services/clinical-svc:v0.1.0
\\

--region=europe-central2 \\

--project=superwizor-ai-25ecd \\

--no-allow-unauthenticated \\

--vpc-connector=swvpc-connector \\

--max-instances=5 \\

--min-instances=0 \\

--use-http2 \\

--set-env-vars="IDENTITY_SVC_URL=${IDENTITY_URL},VERSION=v0.1.0" \\

--set-secrets="DATABASE_URL=postgres-database-url:latest"

\# Pozwól clinical-svc wywoływać identity-svc

gcloud run services add-iam-policy-binding identity-svc \\

--region=europe-central2 \\

--project=superwizor-ai-25ecd \\

--member="serviceAccount:clinical-svc@superwizor-ai-25ecd.iam.gserviceaccount.com"
\\

--role="roles/run.invoker"

## Sprint 1.4 --- Flutter integration

**Czas:** 1 dzień **Cel:** Minimalny Flutter app z Firebase Auth + listą
kartotek z clinical-svc.

> **🤖 AI INSTRUCTION / WAŻNE DLA FLUTTERA:**
> Zanim zaczniesz pisać kod UI we Flutterze, przypominamy o konieczności użycia pliku z design systemem:
> `/Users/maciekckoklormam91/Desktop/APP - Superwizor AI/docs/B_05_ui_ux_design_system.md`
> oraz weryfikatora:
> `/Users/maciekckoklormam91/Desktop/APP - Superwizor AI/docs/B_08_design_checker.md`
> Kod musi od razu implementować dobre praktyki UI/UX.

### Task 1.4.1 --- Init Flutter project

mkdir flutter-app && cd flutter-app

flutter create --org ai.superwizor --project-name superwizor
superwizor

cd superwizor

\# Add dependencies

flutter pub add \\

firebase_core \\

firebase_auth \\

grpc \\

protobuf \\

flutter_riverpod \\

go_router

\# iOS-specific (Firebase)

flutter pub add firebase_core_platform_interface

### Task 1.4.2 --- Firebase Flutter setup

\# FlutterFire CLI

dart pub global activate flutterfire_cli

\# Configure (auto-creates lib/firebase_options.dart)

flutterfire configure --project=superwizor-ai-25ecd

### Task 1.4.3 --- Generate proto stubs dla Flutter

\# Install protoc plugins for Dart

dart pub global activate protoc_plugin

\# Generate

mkdir -p lib/generated

protoc --proto_path=../../proto \\

--dart_out=grpc:lib/generated \\

--plugin=protoc-gen-dart=$(which protoc-gen-dart) \\

identity/v1/identity.proto \\

clinical/v1/clinical.proto

### Task 1.4.4 --- Minimal app: login + lista kartotek

cat > lib/main.dart <<'EOF'

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';

import 'screens/login_screen.dart';

import 'screens/home_screen.dart';

void main() async {

WidgetsFlutterBinding.ensureInitialized();

await Firebase.initializeApp(options:
DefaultFirebaseOptions.currentPlatform);

runApp(const ProviderScope(child: SuperWizorApp()));

}

class SuperWizorApp extends StatelessWidget {

const SuperWizorApp({super.key});

\@override

Widget build(BuildContext context) {

return MaterialApp(

title: 'SuperWizor AI',

theme: ThemeData(

primaryColor: const Color(0xFF004D54), // Evergreen

scaffoldBackgroundColor: const Color(0xFF004D54),

),

home: StreamBuilder(

stream: FirebaseAuth.instance.authStateChanges(),

builder: (context, snapshot) {

if (snapshot.connectionState == ConnectionState.waiting) {

return const Scaffold(

body: Center(child: CircularProgressIndicator()),

);

}

return snapshot.hasData ? const HomeScreen() : const LoginScreen();

},

),

);

}

}

EOF

mkdir -p lib/screens

cat > lib/screens/login_screen.dart <<'EOF'

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {

const LoginScreen({super.key});

\@override

State<LoginScreen> createState() => _LoginScreenState();

}

class _LoginScreenState extends State<LoginScreen> {

final _email = TextEditingController();

final _password = TextEditingController();

bool _loading = false;

String? _error;

Future<void> _login() async {

setState(() {

_loading = true;

_error = null;

});

try {

await FirebaseAuth.instance.signInWithEmailAndPassword(

email: _email.text.trim(),

password: _password.text,

);

} on FirebaseAuthException catch (e) {

setState(() => _error = e.message);

} finally {

setState(() => _loading = false);

}

}

\@override

Widget build(BuildContext context) {

return Scaffold(

body: Center(

child: Padding(

padding: const EdgeInsets.all(32),

child: Column(

mainAxisAlignment: MainAxisAlignment.center,

children: [

const Text(

'SuperWizor AI',

style: TextStyle(

fontSize: 32,

color: Color(0xFFFCAE2F), // Ember

fontWeight: FontWeight.bold,

),

),

const SizedBox(height: 32),

TextField(

controller: _email,

style: const TextStyle(color: Colors.white),

decoration: const InputDecoration(

labelText: 'Email',

labelStyle: TextStyle(color: Colors.white70),

),

),

const SizedBox(height: 16),

TextField(

controller: _password,

obscureText: true,

style: const TextStyle(color: Colors.white),

decoration: const InputDecoration(

labelText: 'Hasło',

labelStyle: TextStyle(color: Colors.white70),

),

),

const SizedBox(height: 24),

if (_error != null)

Text(_error!, style: const TextStyle(color: Colors.red)),

ElevatedButton(

onPressed: _loading ? null : _login,

style: ElevatedButton.styleFrom(

backgroundColor: const Color(0xFFFCAE2F),

),

child: Text(_loading ? 'Logowanie\...' : 'Zaloguj się.'),

),

],

),

),

),

);

}

}

EOF

cat > lib/screens/home_screen.dart <<'EOF'

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {

const HomeScreen({super.key});

\@override

Widget build(BuildContext context) {

final user = FirebaseAuth.instance.currentUser;

return Scaffold(

appBar: AppBar(

title: const Text('Twoje kartoteki.'),

actions: [

IconButton(

icon: const Icon(Icons.logout),

onPressed: () => FirebaseAuth.instance.signOut(),

),

],

),

body: Center(

child: Column(

mainAxisAlignment: MainAxisAlignment.center,

children: [

Text('Cześć, ${user?.email}!'),

const SizedBox(height: 16),

const Text('TODO Faza 1.4: lista kartotek z clinical-svc.'),

],

),

),

);

}

}

EOF

**Uwaga:** Pełna implementacja gRPC client w Flutter przez Cloud Run
wymaga grpc-web proxy lub bezpośredniego wywołania REST endpoint. W
Fazie 1 zostawiamy stub --- pełen grpc client w Fazie 2.

### Task 1.4.5 --- Test

flutter run

\# W app:

\# 1. Kliknij "Zaloguj się"

\# 2. Stwórz user w Firebase Console (Authentication → Users → Add user)

\# 3. Zaloguj się z tym emailem/hasłem

\# 4. Powinieneś zobaczyć HomeScreen

## Sprint 1.5 --- E2E test + observability

**Czas:** 1 dzień **Cel:** End-to-end test pipeline'u + integracja
Cloud Logging/Trace.

### Task 1.5.1 --- E2E test script

mkdir -p tests/e2e

cat > tests/e2e/test_create_patient_file.sh <<'EOF'

#!/bin/bash

set -euo pipefail

\# Prerequisites:

\# - User created w Firebase Auth

\# - User row exists w PostgreSQL (CreateUser called)

PROJECT_ID="superwizor-ai-25ecd"

REGION="europe-central2"

\# Get service URLs

IDENTITY_URL=$(gcloud run services describe identity-svc \\

--region=${REGION} --project=${PROJECT_ID} \\

--format="value(status.url)")

CLINICAL_URL=$(gcloud run services describe clinical-svc \\

--region=${REGION} --project=${PROJECT_ID} \\

--format="value(status.url)")

\# Get fresh ID token (Cloud Run service-to-service)

TOKEN=$(gcloud auth print-identity-token)

echo "=== Step 1: Health checks ==="

grpcurl -H "authorization: Bearer ${TOKEN}" \\

${IDENTITY_URL#https://}:443 \\

identity.v1.IdentityService/HealthCheck

grpcurl -H "authorization: Bearer ${TOKEN}" \\

${CLINICAL_URL#https://}:443 \\

clinical.v1.ClinicalService/HealthCheck

echo "=== Step 2: List modalities ==="

grpcurl -H "authorization: Bearer ${TOKEN}" \\

${CLINICAL_URL#https://}:443 \\

clinical.v1.ClinicalService/ListModalities

echo "=== Step 3: Create patient file ==="

THERAPIST_ID=$(echo "SELECT id FROM users LIMIT 1;" \| psql -h
127.0.0.1 -U postgres -d superwizor -t \| tr -d ' ')

grpcurl -H "authorization: Bearer ${TOKEN}" \\

-d "{

\\"therapist_id\\": \\"${THERAPIST_ID}\\",

\\"modality_code\\": \\"CBT\\",

\\"working_alias\\": \\"E2E Test Patient\\",

\\"process_type\\": \\"PROCESS_TYPE_INDIVIDUAL\\",

\\"initial_complaint\\": \\"E2E test\\",

\\"has_recording_consent\\": true

}" \\

${CLINICAL_URL#https://}:443 \\

clinical.v1.ClinicalService/CreatePatientFile

echo "=== Step 4: Verify w DB ==="

echo "SELECT id, working_alias FROM patient_files WHERE working_alias =
'E2E Test Patient';" \| \\

psql -h 127.0.0.1 -U postgres -d superwizor

echo "=== Step 5: Audit event ==="

echo "SELECT action, resource_type, occurred_at FROM audit_events ORDER
BY occurred_at DESC LIMIT 5;" \| \\

psql -h 127.0.0.1 -U postgres -d superwizor

echo "✅ All E2E checks passed"

EOF

chmod +x tests/e2e/test_create_patient_file.sh

### Task 1.5.2 --- OpenTelemetry tracing

\# Dodaj do każdego serwisu

cd services/identity-svc

go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc
\\

go.opentelemetry.io/otel/sdk/trace \\

go.opentelemetry.io/otel/sdk/resource \\

go.opentelemetry.io/contrib/detectors/gcp \\

go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc

\# Dodaj middleware do main.go

cat >> cmd/server/main.go.patch <<'EOF'

\# Dodaj imports

import (

"go.opentelemetry.io/contrib/detectors/gcp"

"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"

"go.opentelemetry.io/otel"

sdktrace "go.opentelemetry.io/otel/sdk/trace"

)

\# Init tracer

res, _ := resource.New(ctx,

resource.WithDetectors(gcp.NewDetector()),

resource.WithTelemetrySDK(),

)

tp := sdktrace.NewTracerProvider(

sdktrace.WithSampler(sdktrace.AlwaysSample()),

sdktrace.WithResource(res),

)

otel.SetTracerProvider(tp)

\# Server interceptor

grpcServer := grpc.NewServer(

grpc.StatsHandler(otelgrpc.NewServerHandler()),

)

EOF

### Task 1.5.3 --- Cloud Monitoring dashboard

\# Stwórz dashboard JSON

cat > infra/monitoring/dashboard.json <<'EOF'

{

"displayName": "SuperWizor --- Faza 1 Dashboard",

"gridLayout": {

"columns": "2",

"widgets": [

{

"title": "identity-svc latency P95",

"xyChart": {

"dataSets": [{

"timeSeriesQuery": {

"timeSeriesFilter": {

"filter": "metric.type=\\"run.googleapis.com/request_latencies\\"
resource.label.\\"service_name\\"=\\"identity-svc\\"",

"aggregation": {

"alignmentPeriod": "60s",

"perSeriesAligner": "ALIGN_PERCENTILE_95"

}

}

}

}]

}

},

{

"title": "clinical-svc latency P95",

"xyChart": {

"dataSets": [{

"timeSeriesQuery": {

"timeSeriesFilter": {

"filter": "metric.type=\\"run.googleapis.com/request_latencies\\"
resource.label.\\"service_name\\"=\\"clinical-svc\\"",

"aggregation": {

"alignmentPeriod": "60s",

"perSeriesAligner": "ALIGN_PERCENTILE_95"

}

}

}

}]

}

}

]

}

}

EOF

gcloud monitoring dashboards create
--config-from-file=infra/monitoring/dashboard.json \\

--project=superwizor-ai-25ecd

### Task 1.5.4 --- Alerty

\# Alert: error rate > 5% w 5 min window

gcloud alpha monitoring policies create \\

--notification-channels=YOUR_CHANNEL_ID \\

--display-name="High error rate identity-svc" \\

--condition-display-name="error_rate > 5%" \\

--condition-filter="metric.type=\\"run.googleapis.com/request_count\\"
resource.label.\\"service_name\\"=\\"identity-svc\\"
metric.label.\\"response_code_class\\"=\\"5xx\\"" \\

--aggregation-alignment-period=300s \\

--aggregation-per-series-aligner=ALIGN_RATE \\

--condition-threshold-value=0.05 \\

--condition-threshold-comparison=COMPARISON_GT \\

--condition-threshold-duration=300s \\

--project=superwizor-ai-25ecd

### Definition of Done dla Sprint 1.5

- E2E test script przechodzi na zielono.

  Cloud Trace pokazuje pełen request flow (Flutter → identity-svc →
  clinical-svc → DB).

  Cloud Logging zawiera logi z trace_id.

  Dashboard widoczny w Console.

  Alert na error rate skonfigurowany.

## Troubleshooting cookbook

### Problem 1: Firebase Auth: "INVALID_LOGIN_CREDENTIALS"

**Fix:** Sprawdź czy:

- Email/Password provider jest włączony (Firebase Console →
  Authentication → Sign-in method).

- Hasło jest min 6 znaków.

### Problem 2: identity-svc returns "user not registered"

**Symptom:**

PERMISSION_DENIED: user not registered in PostgreSQL

**Przyczyna:** User istnieje w Firebase Auth, ale brak wiersza w users
table.

**Fix:** Wywołaj CreateUser po pierwszym loginie:

grpcurl -d '{"firebase_uid": "\...", "email": "\...",
"first_name": "\...", "last_name": "\...", "ui_language":
"pl", "timezone": "Europe/Warsaw", "has_accepted_tos": true}'
\\

identity-svc:443 identity.v1.IdentityService/CreateUser

### Problem 3: clinical-svc → identity-svc: "401 Unauthorized"

**Fix:** Sprawdź IAM binding:

gcloud run services get-iam-policy identity-svc \\

--region=europe-central2 --project=superwizor-ai-25ecd

\# Should show clinical-svc@\... with run.invoker

### Problem 4: Migration: "FK violation modalities"

**Symptom:**

ERROR: insert or update on table "users" violates foreign key
constraint "fk_users_default_modality"

**Przyczyna:** Próba przypisania default_modality_id przed seed data.

**Fix:** Aplikuj migracje w kolejności: 000003_identity →
000005_clinical → 000006_seed_modalities.

### Problem 5: pgxpool: "too many connections"

**Fix:** Limit max_conns w pool:

poolConfig, _ := pgxpool.ParseConfig(dbDSN)

poolConfig.MaxConns = 10

pool, _ := pgxpool.NewWithConfig(ctx, poolConfig)

### Problem 6: gRPC reflection nie działa w Cloud Run

**Symptom:**

Error invoking method: ReflectionService.ServerReflectionInfo: rpc
error: code = Unimplemented

**Fix:** Sprawdź czy --use-http2 w gcloud run deploy jest ustawione.
Bez tego Cloud Run nie supportuje gRPC.

## Pre-Faza 2 checklist

### Backend

- identity-svc deployowany, gRPC endpoints działają.

  clinical-svc deployowany, gRPC endpoints działają.

  Service-to-service auth (clinical-svc → identity-svc) działa.

  Migracje 000001-000006 zaaplikowane.

  3 modalities (UNIV, CBT, PSYCHO) seeded.

  Audit events loggowane przy patient_file.create.

### Frontend

- Flutter app w trybie debug łączy się z Firebase Auth.

  Login flow działa (email/password).

  Logout działa.

### Observability

- Cloud Trace pokazuje trace request flow.

  Cloud Logging ma JSON-structured logi.

  Dashboard z latencjami P95.

  Alert na 5xx error rate.

### Testing

- Unit tests dla identity-svc passed (coverage ≥ 75%).

  Unit tests dla clinical-svc passed (coverage ≥ 75%).

  E2E test script test_create_patient_file.sh przechodzi.

### Security

- Firebase Auth wymaga email verification dla production.

  Cloud SQL IAM authentication enabled (mimo że Faza 1 używa password
  --- Faza 2 migruje).

  No JSON service account keys w repo.

  Wszystkie services --no-allow-unauthenticated.

**🎉 Po Sprint 1.5 → ready dla Fazy 2 (Ingestion + Audio).**

Następny dokument: 06_FAZA_2_INGESTION_AUDIO.md pokryje:

- ingestion-svc z signed URLs.

- billing-svc z Stripe webhook handling.

- Flutter recording module (wakelock + chunking).

- Cloud Storage bucket "audio_uploads" + OLM 48h.
