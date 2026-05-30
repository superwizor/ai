# Superwizor AI - Architektura Techniczna i Decyzje
Wersja: 1.0 Stos: Google Cloud Platform + Go 1.23 + Cloud Run + PostgreSQL 16 + pgvector Region: europe-central2 (Warszawa)
Powiązane dokumenty: 01_Architektura (Konstytucja Projektu v3.0)

*(Dokument wygenerowany przez AI na podstawie wytycznych użytkownika).*

## 1. EXECUTIVE SUMMARY I DECYZJE ARCHITEKTONICZNE
### 1.1 Pryncypia (niepodważalne)
- **P1: Zero Data Loss** - Idempotencja na każdym kroku pipeline'u, at-least-once delivery w Pub/Sub, zapasowe mechanizmy (OLM 48h).
- **P2: Zero Trust** - Każdy serwis ma dedykowane konto usługi (SA), minimum uprawnień, komunikacja tylko przez VPC Connector lub prywatne IP.
- **P3: Żelazna Lokalizacja** - Wszystkie zasoby w europe-central2.
- **P4: Flutter → read-only na raporty AI** - Reguły Firestore + IAM + kontrakty gRPC wymuszają brak zapisu raportów z aplikacji mobilnej.
- **P5: Czytelność > mikrooptymalizacja kosztu DB** - Znormalizowany schemat PostgreSQL, osobne tabele dla therapist_view i patient_view.

### 1.2 Decyzje architektoniczne (ADR)
- **ADR-001 (Cloud Run)**: Jedyny compute, scale-to-zero. Timeout 60 min dla synchronicznego API; pipeline AI asynchronicznie.
- **ADR-002 (Cloud SQL PostgreSQL 16 + pgvector)**: Model ER, pgvector dla RAG (eliminuje osobny vector store jak np. Pinecone).
- **ADR-003 (Go 1.23)**: Footprint RAM. Szybki zimny start na Cloud Run.
- **ADR-004 (Pub/Sub dla AI)**: At-least-once delivery, retry policy, asynchroniczny przepływ z Vertex AI.
- **ADR-005 (gRPC)**: Wywołania synchroniczne, streaming, silne typowanie.
- **ADR-006 (Firestore)**: Wyłącznie synchronizacja mobilna jako replikacja read-only statusów.
- **ADR-007 (Monorepo)**: 7 serwisów Go z wspólnym protobuf.
- **ADR-008 (Terraform + Cloud Build)**: Zabezpieczenie IaC, canary deployment.

## 2. Podział na Mikroserwisy (Cloud Run)
1. **identity-svc**: RBAC, JWT (Firebase Auth), obsługa profilów User / Organization. 
2. **billing-svc**: Rozliczenia, limity użycia, Stripe webhook.
3. **clinical-svc**: Rdzeń kliniczny, Pacjenci, Sesje i pobieranie raportów dla Flutter.
4. **ingestion-svc**: Zapisywanie V4 signed URLs do GCS.
5. **ai-pipeline-svc**: Joby Cloud Run:
   - `stt-worker` (Chirp 2, konwersja audio)
   - `llm-worker` (Gemini 3.1 flash, zrzuty do JSON schema)
   - `memory-compactor-worker` (kompresja pamięci Living Case Formulation)
6. **analytics-svc**: Agregaty B2B, Dashboard kliniczny The HiTOP. 
7. **notification-svc**: FCM Push z Firebase, live updates do Firestore po stronie `session_states/`.

## 3. Storage i "Krematorium Audio"
Struktura bucketów to `superwizor-audio-prod-eu2` z retencją (OLM) na 48 godzin, po których nadchodzi twardy *DELETE* (Dead Man's Switch). Szyfrowanie KMS CMEK kluczami (rotacja co 90 dni).
