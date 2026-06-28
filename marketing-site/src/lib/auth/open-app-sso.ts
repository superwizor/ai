"use client";

// Cross-origin SSO handoff into the Flutter web app (docs/20 §6.3).
//
// Firebase Auth's IndexedDB is origin-scoped, so a user signed in on the
// marketing origin has NO session on the Flutter origin. Opening the app with a
// plain link therefore dumps the user on the Flutter login screen — the
// "login propagation stopped working" bug. Every "open app / kartoteki" CTA
// must go through this helper instead of a bare href so the session carries
// over.
//
// Security (per docs/security/SECURITY_REMEDIATION_PLAN.md + docs/20 §9.4):
//   - identity-svc.MintAppLoginToken mints ONLY for the caller's own verified
//     firebase_uid (FIREBASE_USER class) — no uid in the request, no escalation.
//   - Token rides the URL *fragment* (#auth_token=…): never sent to Hosting,
//     not in the Referer header, stripped after redemption. ~1h, single-use.
//   - Graceful degradation: any failure falls back to a plain ?email= open so
//     the user can still log in by hand. No IAM/invoker changes.

import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";

import { identityClient } from "@/lib/connect/clients";

// Canonical Flutter web origin (Firebase Hosting site `superwizor-app`). Must
// stay in: Firebase authorizedDomains, the reCAPTCHA Enterprise key domains,
// and every backend service's CORS_ALLOWED_ORIGINS (so the app can load data
// after the SSO sign-in). `superwizor-app.web.app` is the origin the backend
// CORS allowlist was fixed for (docs/agents/11 mode 3).
export const APP_URL = "https://superwizor-app.web.app/";

/**
 * Open the Flutter web app with an SSO custom-token handoff so the user lands
 * already signed in. Safe to call from any "open app" CTA.
 *
 * The popup is opened synchronously inside the click handler so Safari permits
 * it (window.open after an `await` is blocked as a non-user-gesture popup).
 */
export async function openAppWithSso(email?: string): Promise<void> {
  const popup = window.open("about:blank", "_blank");
  const emailQuery = email ? `?email=${encodeURIComponent(email)}` : "";
  const go = (url: string) => {
    if (popup && !popup.closed) popup.location.href = url;
    else window.location.href = url;
  };
  try {
    const res = await identityClient.mintAppLoginToken(create(EmptySchema, {}));
    const token = res?.token ?? "";
    const emailFragment = email ? `&email=${encodeURIComponent(email)}` : "";
    go(
      token
        ? `${APP_URL}#auth_token=${encodeURIComponent(token)}${emailFragment}`
        : `${APP_URL}${emailQuery}`,
    );
  } catch (err) {
    console.error("[sso] openAppWithSso: mintAppLoginToken failed", err);
    go(`${APP_URL}${emailQuery}`);
  }
}
