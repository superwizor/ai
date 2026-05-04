#!/bin/bash
terraform import google_service_account.llm_worker projects/superwizor-ai-25ecd/serviceAccounts/llm-worker-sa@superwizor-ai-25ecd.iam.gserviceaccount.com
terraform import google_service_account.ingestion_svc projects/superwizor-ai-25ecd/serviceAccounts/ingestion-svc-sa@superwizor-ai-25ecd.iam.gserviceaccount.com
terraform import google_service_account.stt_worker projects/superwizor-ai-25ecd/serviceAccounts/stt-worker-sa@superwizor-ai-25ecd.iam.gserviceaccount.com

terraform import module.pubsub.google_pubsub_topic.audio_uploaded projects/superwizor-ai-25ecd/topics/audio.uploaded
terraform import module.pubsub.google_pubsub_topic.audio_uploaded_dlq projects/superwizor-ai-25ecd/topics/audio.uploaded.dlq
terraform import module.pubsub.google_pubsub_topic.transcript_completed projects/superwizor-ai-25ecd/topics/transcript.completed
terraform import module.pubsub.google_pubsub_topic.transcript_completed_dlq projects/superwizor-ai-25ecd/topics/transcript.completed.dlq
terraform import module.pubsub.google_pubsub_topic.report_generated projects/superwizor-ai-25ecd/topics/report.generated

terraform import module.storage.google_storage_bucket.audio_uploads superwizor-staging-audio-uploads
terraform import module.artifact_registry.google_artifact_registry_repository.services projects/superwizor-ai-25ecd/locations/europe-central2/repositories/superwizor-services
terraform import module.vpc.google_compute_network.main projects/superwizor-ai-25ecd/global/networks/superwizor-vpc

terraform import module.wif.google_iam_workload_identity_pool.github_pool projects/superwizor-ai-25ecd/locations/global/workloadIdentityPools/github-actions-pool
terraform import module.wif.google_iam_workload_identity_pool_provider.github_provider projects/superwizor-ai-25ecd/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider

