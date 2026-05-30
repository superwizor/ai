# Superwizor AI - Model Danych i Data Flow

Poniżej znajduje się oficjalny model relacyjny (ERD) oraz definicje struktur bazodanowych w aplikacji Superwizor AI. Baza danych docelowa to Cloud SQL PostgreSQL 16.

## Diagram ER (Zależności encji)

```mermaid
erDiagram
   %% LEVEL 1: BUSINESS FRAMEWORK AND ACCOUNT
   SUBSCRIPTION_PLAN ||--o{ SUBSCRIPTION : "defines package"
   ORGANIZATION ||--o{ USER : "employs"
   ORGANIZATION ||--o{ SUBSCRIPTION : "owns"
   ADDRESS ||--o{ ORGANIZATION : "indicates headquarters"
   ADDRESS ||--o{ USER : "indicates billing address"

   %% LEVEL 2: THERAPEUTIC CONFIGURATION
   MODALITY ||--o{ USER : "default workflow"
   MODALITY ||--o{ PATIENT_RECORD : "modality assigned to process"
  
   %% LEVEL 3: PROCESS AXIS
   USER ||--o{ PATIENT_RECORD : "conducts / participates"
   PATIENT_RECORD ||--o{ CLINICAL_MEMORY : "aggregates long-term context"
   PATIENT_RECORD ||--o{ SESSION : "contains meetings"
  
   %% LEVEL 4: SESSION BRANCHES
   SESSION ||--|| TRANSCRIPTION : "has text record"
   SESSION ||--|| THERAPIST_REPORT : "generates 7-section analysis"
   SESSION ||--o| PATIENT_VIEW : "generates secure client view"

   SUBSCRIPTION_PLAN {
       string id PK
       string name "e.g. Solo, Pro, Enterprise, Patient"
       float gross_price_monthly "Monthly cost"
       string currency "PLN, EUR"
       int monthly_session_limit "Maximum number of sessions"
       boolean is_b2b_panel_available "Analytical options for Enterprise"
       string marketing_description "Target audience and benefits"
   }

   SUBSCRIPTION {
       string id PK
       string organization_id "FK to ORGANIZATION table"
       string plan_id "FK to SUBSCRIPTION_PLAN table"
       string status "ACTIVE, SUSPENDED, CANCELED"
       datetime start_date "Start date"
       datetime expiration_date "End date"
       string external_provider_id "Agnostic ID from payment gateway"
       boolean is_auto_renewal "Auto-renewal flag"
       int active_licenses_limit "Maximum number of therapists"
   }

   ADDRESS {
       string id PK
       string country "ISO 3166-1 alpha-2 code"
       string region_state_province "Key for foreign markets"
       string city "City/Town"
       string postal_code "Postal code"
       string street "Street name"
       string building_number "Building number"
       string apartment_number "Apartment number (optional)"
       text driving_directions "Optional additional instructions"
   }

   ORGANIZATION {
       string id PK
       string company_name "Clinic / corporation name"
       string tax_id_number "Tax Identification Number (NIP)"
       string headquarters_address_id "FK to ADDRESS table"
       string main_administrator_id "FK: User managing licenses"
   }

   USER {
       string id PK
       string account_role "THERAPIST, PATIENT, CLINIC_ADMIN"
       string organization_id "FK: If belongs to a clinic"
       string default_modality_id "FK: Default modality for new patients"
       string billing_address_id "FK to ADDRESS table"
      
       string login_email "Email"
       string phone_number "For SMS and 2FA"
       boolean is_email_verified "Verification status"
      
       string first_name "First name"
       string last_name "Last name"
      
       string professional_title "e.g. Certified CBT Psychotherapist"
       string license_number "Certificate number, License"
       text bio_description "Short info about the expert"
       string profile_picture_url "Link to photo"
      
       string ui_language "pl, en, uk"
       string timezone "Europe/Warsaw"
       boolean medical_terms_consent "Terms acceptance"
       boolean marketing_consent "Marketing consent"
       datetime account_creation_date "Registration moment"
   }

   MODALITY {
       string id PK
       string system_code "UNIV, CBT, PSYCHO, SCHEMA, SYSTEM, EFT"
       string display_name "Full modality name"
       json detailed_prompt_therapist_ai "Full structure description for a given block"
       json general_instruction_therapist_ai "Main AI prompt"
       json general_instruction_client_ai "Main AI prompt"
       json detailed_prompt_client_ai "Full structure description for a given block"
       boolean is_supported "Modality activity flag"
   }

   PATIENT_RECORD {
       string id PK
       string therapist_id "FK: Record owner"
       string patient_account_id "FK: Patient"
       string assigned_modality_id "FK: Can be different from default"
      
       string working_alias "e.g. Female, 34 years old, Social anxiety"
       string process_type "Individual, Couples, Families"
       string main_complaint_topic "Primary reason for visit"
       boolean is_process_closed "Status flag"
       boolean audio_recording_consent "Consent flag"
       datetime consent_date "Date consent given"

       datetime first_consultation_date "Date work started"
      
       text therapist_technical_notebook "Private notes"
   }

   CLINICAL_MEMORY {
       string id PK
       string patient_record_id "FK to PATIENT_RECORD table"
       text long_term_memory_ai "Living Case Formulation"
       json short_term_memory_ai "Recent fact vectors from session"
       int revision_number "Overwriting protection"
       datetime last_synthesis_date "Profile update date"
   }

   SESSION {
       string id PK
       string patient_record_id "FK to PATIENT_RECORD table"
       string therapist_id "FK to USER table"
      
       datetime session_start_time "Start"
       datetime session_end_time "End"
       int duration_seconds "Total time"
       string contact_form "OFFICE, ONLINE, FIELD, PHONE"
       string audio_storage_path "path to audio file for destruction"
       datetime audio_destruction_date "audio file destruction date"
       string processing_status "Pipeline status"
       string ui_error_identifier "Error key"
       float session_cost "Optional billing"
       string idempotency_key "key preventing duplicate recording processing"   
   }

   TRANSCRIPTION {
       string id PK
       string session_id "FK to SESSION table"
       text diarized_text "Conversation record"
       int character_count "Text length"
       int identified_speakers_count "Number of speakers"
       int stt_execution_time_ms "Transcription time"
   }

   THERAPIST_REPORT {
       string id PK
       string session_id "FK to SESSION table"
       string used_modality_id "FK to MODALITY"
      
       json report_result "Generated content for all sections"
             
       text ai_workspace "Chain of Thought"
       int prompt_tokens_used "Prompt tokens used"
       int generated_tokens "Generated tokens"
   }

   PATIENT_VIEW {
       string id PK
       string session_id "FK to SESSION table"
       string used_modality_id "FK to MODALITY"
       json report_result "Important fragments from session"
       text patient_private_journal "Own notes"
       text agenda_for_next_session "Reported topics"
       int mood_rating_after_session "Scale from 1 to 10"
       datetime agenda_completion_date "Completion date"
   }
```
