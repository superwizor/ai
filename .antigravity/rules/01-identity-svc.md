---
description: Loads when editing identity-svc (Firebase Auth, user/org CRUD, RBAC).
globs:
  - "superwizor-backend/services/identity-svc/**"
  - "superwizor-backend/proto/identity/**"
  - "superwizor-backend/gen/go/identity/**"
  - "superwizor-backend/migrations/*identity*.sql"
alwaysApply: false
---

# identity-svc

**Read [`docs/agents/01_identity-svc.md`](../../docs/agents/01_identity-svc.md) before editing.**

Quick orientation:

- **Mission:** validate Firebase ID tokens; CRUD users/organizations; answer permission questions for every other service.
- **Tables owned:** `users`, `organizations`, `addresses`, `user_roles`.
- **Bottom of dep tree** — never add a dependency on clinical-svc or any peer service.
- **Two roles only:** `THERAPIST`, `PATIENT` (ADR-DM-004). Schema migration + RBAC review required to add more.
- **Soft delete** via `deleted_at` (ADR-DM-003); always filter `WHERE deleted_at IS NULL` on user queries.
- **Audience claim** on Firebase tokens must match Firebase project ID `superwizor-ai-25ecd`.
- Public Cloud Run service: `allUsers → roles/run.invoker` at infra layer; Firebase token validated in app layer.
