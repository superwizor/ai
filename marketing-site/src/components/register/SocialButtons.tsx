// Social-provider buttons for the registration pages.
//
// docs/18 §8.1 spec: three buttons at the top of every registration
// form (Google / Apple / Microsoft) + a "Use email instead" disclosure
// that expands to the email/password form below.
//
// Slice 3 feature 2 + 4 ships the Google button live; Apple +
// Microsoft are wired in the auth-provider but throw at click time
// until the Firebase Console toggles for those providers flip on
// (manual op tracked separately — Google + account linking are
// already on per the user, feature 2's scope).
//
// On successful Google sign-in we check identity-svc for an existing
// user row and either:
//   - bounce to the app origin if they're already registered, OR
//   - hand off to /register/<flow>/finish to collect Superwizor-
//     specific fields (modality, ui_language, ToS) that Google
//     doesn't surface.

"use client";

import { useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { FirebaseError } from "firebase/app";
import { ConnectError, Code } from "@connectrpc/connect";

import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient } from "@/lib/connect/clients";

type FlowKind = "therapist" | "organization";

export function SocialButtons({ flow }: { flow: FlowKind }) {
  const t = useTranslations("register.common");
  const tErr = useTranslations("register.errors");
  const auth = useAuth();
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const onGoogle = async () => {
    setBusy(true);
    setErr(null);
    try {
      const user = await auth.signInWithGoogle();

      // Existing user? Bounce to the app origin's login flow — they
      // already have everything they need server-side; no extra
      // profile collection required.
      try {
        await identityClient.getUserByFirebaseUID({ firebaseUid: user.uid });
        // Send the existing user to the Flutter app where the console
        // lives. Firebase Auth is origin-scoped so they'll have to
        // sign in again on the Flutter origin — unavoidable cost of
        // R3 origin discipline. DNS for app.superwizor.ai isn't wired
        // up yet; web.app subdomain is the live host.
        window.location.href = "https://superwizor-app.web.app/";
        return;
      } catch (e) {
        if (!(e instanceof ConnectError) || e.code !== Code.NotFound) {
          // Real RPC failure — surface to user, don't proceed to
          // finish-profile (we'd risk creating a duplicate row).
          throw e;
        }
      }

      // New user — hand off to the finish-profile page. Carry the
      // Google-provided first/last name through query so the page
      // can render a personalised "Hi {firstName}" greeting.
      const dn = user.displayName ?? "";
      const [firstName = "", ...rest] = dn.split(" ");
      const lastName = rest.join(" ");
      const params = new URLSearchParams({
        firstName,
        lastName,
        email: user.email ?? "",
      });
      window.location.href = `${prefix}/register/${flow}/finish?${params}`;
    } catch (e) {
      if (e instanceof FirebaseError && e.code === "auth/popup-closed-by-user") {
        // User dismissed the popup — silent, normal cancel.
        setBusy(false);
        return;
      }
      setErr(tErr("unknown"));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid gap-3">
      <button
        type="button"
        onClick={onGoogle}
        disabled={busy}
        className="inline-flex items-center justify-center gap-3 rounded-button border border-frost/20 bg-frost/5 hover:bg-frost/10 text-frost font-display text-sm px-4 py-3 transition disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {/* Google G mark, monochrome to fit dark surface */}
        <svg aria-hidden width="18" height="18" viewBox="0 0 18 18" fill="currentColor">
          <path d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84c-.21 1.13-.84 2.08-1.79 2.72v2.26h2.9c1.7-1.56 2.69-3.87 2.69-6.62z" opacity=".9" />
          <path d="M9 18c2.43 0 4.47-.81 5.96-2.18l-2.9-2.26c-.81.54-1.84.86-3.06.86-2.36 0-4.36-1.59-5.07-3.74H.96v2.34A9 9 0 0 0 9 18z" opacity=".7" />
          <path d="M3.93 10.71A5.4 5.4 0 0 1 3.64 9c0-.6.1-1.18.29-1.71V4.96H.96A9 9 0 0 0 0 9c0 1.45.35 2.83.96 4.04l2.97-2.33z" opacity=".55" />
          <path d="M9 3.58c1.32 0 2.51.45 3.44 1.35l2.58-2.58A9 9 0 0 0 9 0 9 9 0 0 0 .96 4.96l2.97 2.33C4.64 5.17 6.64 3.58 9 3.58z" opacity=".85" />
        </svg>
        {t("google")}
      </button>

      {err && (
        <p
          role="alert"
          className="rounded-button border border-magma/40 bg-magma/10 px-4 py-2 font-serif text-sm text-frost text-center"
        >
          {err}
        </p>
      )}

      <div className="relative my-2">
        <div className="absolute inset-0 flex items-center" aria-hidden>
          <span className="w-full border-t border-frost/10"></span>
        </div>
        <div className="relative flex justify-center">
          <span className="bg-evergreen px-3 font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/60">
            {t("or")}
          </span>
        </div>
      </div>
    </div>
  );
}
