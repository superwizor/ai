---
type: Guide Index
title: "Agent Context — SuperWizor AI"
description: "Purpose: focused per-area context files for coding agents iterating on this codebase. Each file is designed to fit a single agent's context window and be eno..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/agents/00_README.md
tags: [agents]
timestamp: 2026-06-05T21:15:46+02:00
---

# Agent Context — SuperWizor AI

**Purpose:** focused per-area context files for coding agents iterating on this codebase. Each file is designed to fit a single agent's context window and be enough to make safe changes in that area without re-reading the full architecture docs.

## How to use

1. **Always start with [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md)** — non-negotiable principles, ADR baseline, repo layout, encryption pattern. Everything below assumes you've read this.
2. Pick the focused file for the area you're touching:

| File | Area | When to use |
| :--- | :--- | :--- |
| [`01_identity-svc.md`](./01_identity-svc.md) | Identity / RBAC service | Firebase Auth integration, user/org CRUD, permission checks |
| [`02_clinical-svc.md`](./02_clinical-svc.md) | Clinical core | Patient files, sessions, reports, modalities, speaker labels |
| [`03_billing-svc.md`](./03_billing-svc.md) | Billing (stub in Phase 2) | Quota checks, usage counters; full Stripe integration is Phase 3 |
| [`04_ingestion-svc.md`](./04_ingestion-svc.md) | Audio ingestion | Signed URLs, upload tickets, GCS lifecycle, OLM 48h policy |
| [`05_ai-pipeline-svc.md`](./05_ai-pipeline-svc.md) | AI pipeline | stt-worker (Chirp 3), llm-worker (Gemini 2.5 PRO), chunker, RAG, HiTOP |
| [`06_flutter-therapist-app.md`](./06_flutter-therapist-app.md) | Flutter therapist app | gRPC clients, Firebase Auth on client, riverpod providers, web vs native |
| [`07_devops-cicd.md`](./07_devops-cicd.md) | CI/CD | GitHub Actions workflow, Cloud Build, image tagging, deploy strategy |
| [`08_infrastructure-terraform.md`](./08_infrastructure-terraform.md) | Infrastructure | Terragrunt + modules, state, drift, WIF, KMS, Cloud SQL, Pub/Sub |
| [`09_testing.md`](./09_testing.md) | Testing (E2E + integration + unit) | Test pyramid, priority-ordered E2E scenarios, auth in tests, common gotchas |
| [`10_notification-svc.md`](./10_notification-svc.md) | Notification service (Phase 3 — not yet built) | FCM push, Firestore mirror, multi-token-per-user, status events, no-PHI-in-FCM rule |
| [`11_web_deploy_invoker_drift.md`](./11_web_deploy_invoker_drift.md) | Runbook: browser→backend "unknown error" | Public Cloud Run `allUsers` invoker drift, CORS preflight 403, `Code.Unknown`, deploy/Terraform-apply drift — diagnosis + fix + prevention |
| [`12_web_file_upload_deferred.md`](./12_web_file_upload_deferred.md) | Deferred: web file upload | Browser upload non-functional; Flutter frontend done, backend TODO (ingestion-svc gRPC-web/Connect refactor + CORS + GCS bucket CORS) |

3. **Source docs** (long-form, 1.7k–4.7k lines each) are at `docs/01_ARCHITEKTURA_TECHNICZNA.md`, `docs/02_DATA_MODEL.md`, `docs/04_FAZA_1_TOZSAMOSC_DANE.md`, `docs/05_FAZA_2_INGESTION_AI.md`. Each per-area file references the relevant sections by line number so you can drill into specifics.

## Maintenance

These files are **derived** from the source architecture docs and the actual repo state as of 2026-05-07. When the source docs change or significant code changes land, refresh the relevant per-area file. Do not duplicate content from `00_GLOBAL_CONTEXT.md` into per-area files — link to it.

When in doubt, the order of authority is:
1. **Code in the repo** (what actually runs)
2. **`docs/0[2,3,5,6]_*.md`** (canonical architecture)
3. **These agent docs** (curated context, may lag)
