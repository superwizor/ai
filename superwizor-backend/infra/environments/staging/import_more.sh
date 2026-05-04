#!/bin/bash
terraform import module.kms.google_kms_crypto_key.audio_bucket projects/superwizor-ai-25ecd/locations/europe-central2/keyRings/superwizor-keyring/cryptoKeys/audio-bucket-key
terraform import module.kms.google_kms_crypto_key.database projects/superwizor-ai-25ecd/locations/europe-central2/keyRings/superwizor-keyring/cryptoKeys/database-key
terraform import module.kms.google_kms_crypto_key.secrets projects/superwizor-ai-25ecd/locations/europe-central2/keyRings/superwizor-keyring/cryptoKeys/secrets-key
terraform import module.kms.google_kms_crypto_key.app_data projects/superwizor-ai-25ecd/locations/europe-central2/keyRings/superwizor-keyring/cryptoKeys/app-data-key
terraform import module.storage.google_storage_bucket.audio_uploads superwizor-ai-25ecd-audio-uploads
terraform import google_service_account.llm_worker projects/superwizor-ai-25ecd/serviceAccounts/llm-worker@superwizor-ai-25ecd.iam.gserviceaccount.com
terraform import google_service_account.stt_worker projects/superwizor-ai-25ecd/serviceAccounts/stt-worker@superwizor-ai-25ecd.iam.gserviceaccount.com
terraform import google_service_account.ingestion_svc projects/superwizor-ai-25ecd/serviceAccounts/ingestion-svc@superwizor-ai-25ecd.iam.gserviceaccount.com
terraform import module.artifact_registry.google_artifact_registry_repository.services projects/superwizor-ai-25ecd/locations/europe-central2/repositories/superwizor-services
