# Phase 1 deploy notes — new fail-closed env vars

Phase 1 of the security remediation (SECURITY_REMEDIATION_PLAN.md §5) makes
three services **refuse to start** unless new env vars are set. This is
deliberate (fail-closed). Set them at deploy time:

| Service | New REQUIRED env var | Value | Deploy path |
|---------|----------------------|-------|-------------|
| billing-svc | `INTERNAL_ALLOWED_SAS` | `clinical-svc@<P>,ingestion-svc@<P>,stt-worker@<P>` | ✅ wired in `scripts/deploy-webapp-backend.sh` + `cloudbuild-webapp-backend.yaml` |
| ingestion-svc | `IDENTITY_SVC_URL` | identity-svc Cloud Run URL | ⚠️ manual (see below) |
| notification-svc | `INTERNAL_ALLOWED_SAS` | `identity-svc@<P>,clinical-svc@<P>,billing-svc@<P>` | ⚠️ manual (see below) |

`<P>` = `superwizor-ai-25ecd.iam.gserviceaccount.com`. The SA emails are the
runtime service accounts from `infra/environments/staging/service-accounts.tf`.

`INTERNAL_OIDC_AUDIENCE` is **optional** defense-in-depth (the callee's own
Cloud Run URL, comma-separated for multiple URL forms). Left unset, the
SA-email gate is the control. Pin it once the exact URL form the callers mint
(`idtoken.NewTokenSource(audience=<callee URL>)`) is confirmed from the live
caller env (`gcloud run services describe clinical-svc --format='value(spec.template.spec.containers[0].env)'`).

## ingestion-svc + notification-svc are deployed manually

Their `cloudbuild-*.yaml` only builds + pushes; env vars are set imperatively
on the Cloud Run revision. After pushing a new image, deploy with:

```bash
P=superwizor-ai-25ecd; R=europe-central2

# ingestion-svc — now REQUIRES IDENTITY_SVC_URL (validates the Firebase token
# on every upload RPC). Keep the existing vars; add IDENTITY_SVC_URL.
gcloud run deploy ingestion-svc --project "$P" --region "$R" \
  --image=europe-central2-docker.pkg.dev/$P/services/superwizor-ingestion:<TAG> \
  --update-env-vars=IDENTITY_SVC_URL=https://identity-svc-e3f32b232q-lm.a.run.app

# notification-svc — now REQUIRES INTERNAL_ALLOWED_SAS (the email RPCs are
# internal-only; callers identity/clinical/billing authenticate via OIDC).
gcloud run deploy notification-svc --project "$P" --region "$R" \
  --image=europe-central2-docker.pkg.dev/$P/services/superwizor-notification:<TAG> \
  --update-env-vars="^|^INTERNAL_ALLOWED_SAS=identity-svc@$P.iam.gserviceaccount.com,clinical-svc@$P.iam.gserviceaccount.com,billing-svc@$P.iam.gserviceaccount.com"
```

## Staging verification (allow + deny)

After deploy, confirm both that legitimate flows still work and that attacks
are now rejected:

- **ingestion (allow)**: a real Flutter upload still issues a signed URL.
- **ingestion (deny)**: an anonymous `grpcurl` `CreateAudioUpload` → `Unauthenticated`.
- **billing admin (deny)**: native `grpcurl` `AdminResetTokens` with a forged
  `-H 'x-superwizor-role: SUPERWIZOR_ADMIN'` → `Unauthenticated` ("not available
  on this transport").
- **billing admin (allow)**: the browser `/admin` console still resets tokens
  (Connect path, Firebase admin token).
- **billing quota (allow)**: a real recording flow still reserves/commits credit
  (clinical/ingestion/stt OIDC).
- **notification (deny)**: anonymous `grpcurl` `SendInvitationEmail` → `Unauthenticated`.
- **notification (allow)**: a real org invite still sends its email (identity-svc OIDC).

## Rollback

If S2S traffic breaks (e.g. an OIDC audience mismatch surfaces), the SA-email
gate may be rejecting a caller whose SA isn't listed — add it to
`INTERNAL_ALLOWED_SAS` and redeploy. Do **not** roll back to the unauthenticated
build; widen the allowlist instead.
