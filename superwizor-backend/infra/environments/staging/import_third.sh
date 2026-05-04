#!/bin/bash
terraform import module.artifact_registry.google_artifact_registry_repository.services projects/superwizor-ai-25ecd/locations/europe-central2/repositories/services
terraform import module.cloud_sql.google_secret_manager_secret.db_password projects/superwizor-ai-25ecd/secrets/superwizor-db-password
