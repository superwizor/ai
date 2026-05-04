#!/bin/bash
terraform import module.kms.google_kms_key_ring.main projects/superwizor-ai-25ecd/locations/europe-central2/keyRings/superwizor-keyring
terraform import module.pubsub.google_pubsub_subscription.audio_uploaded_debug projects/superwizor-ai-25ecd/subscriptions/audio.uploaded.debug
