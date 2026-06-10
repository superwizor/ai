// Social-provider buttons for the registration pages.
//
// docs/18 §8.1: Google + Apple buttons at the top of every registration
// form + a "Use email instead" divider that leads to the email/password
// form below. Microsoft is wired in auth-provider but not shown until
// that Firebase Console toggle is enabled.
//
// Google + Apple are live (manual ops complete 2026-05-30):
//   - Google: enabled in Firebase Console + account linking on.
//   - Apple:  Services ID ai.superwizor.signin configured, key
//             72VSU8L7LZ uploaded to Firebase. Private Email Relay
//             registered for superwizor.ai (SPF ✅).
//
// After social sign-in we check identity-svc for an existing user row:
//   - Found   → bounce to the Flutter app (user already registered).
//   - NotFound → redirect to /register/<flow>/finish to collect
//               Superwizor-specific fields (modality, ui_language, ToS).
//
// Apple caveat: displayName is provided only on the FIRST sign-in.
// Subsequent logins return null — pass empty strings defensively;
// TherapistFinishForm lets the user fill in their name manually.

"use client";

import { useState } from "react";
import { useSearchParams } from "next/navigation";
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
  const searchParams = useSearchParams();
  const planSlug = searchParams.get("plan");

  // Shared post-social-sign-in routing.
  const handleSocialUser = async (user: {
    uid: string;
    displayName: string | null;
    email: string | null;
  }) => {
    try {
      await identityClient.getUserByFirebaseUID({ firebaseUid: user.uid });
      window.location.href = prefix ? `${prefix}/dashboard/` : "/dashboard/";
      return;
    } catch (e) {
      if (!(e instanceof ConnectError) || e.code !== Code.NotFound) {
        throw e;
      }
    }

    // New user → finish-profile.
    const dn = user.displayName ?? "";
    const [firstName = "", ...rest] = dn.split(" ");
    const lastName = rest.join(" ");
    const params = new URLSearchParams({
      firstName,
      lastName,
      email: user.email ?? "",
      ...(planSlug ? { plan: planSlug } : {}),
    });
    window.location.href = `${prefix}/register/${flow}/finish?${params}`;
  };

  const onGoogle = async () => {
    setBusy(true);
    setErr(null);
    try {
      const user = await auth.signInWithGoogle();
      await handleSocialUser(user);
    } catch (e) {
      if (e instanceof FirebaseError && e.code === "auth/popup-closed-by-user") {
        return;
      }
      console.error("[social-auth] Google sign-in failed:", e);
      setErr(tErr("unknown"));
    } finally {
      setBusy(false);
    }
  };

  const onApple = async () => {
    setBusy(true);
    setErr(null);
    try {
      const user = await auth.signInWithApple();
      await handleSocialUser(user);
    } catch (e) {
      if (e instanceof FirebaseError && e.code === "auth/popup-closed-by-user") {
        return;
      }
      console.error("[social-auth] Apple sign-in failed:", e);
      setErr(tErr("unknown"));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid gap-3">
      {/* Google */}
      <button
        type="button"
        onClick={onGoogle}
        disabled={busy}
        className="inline-flex items-center justify-center gap-3 rounded-button border border-frost/20 bg-frost/5 hover:bg-frost/10 text-frost font-display text-sm px-4 py-3 transition disabled:opacity-50 disabled:cursor-not-allowed"
      >
        <svg aria-hidden width="18" height="18" viewBox="0 0 18 18" fill="currentColor">
          <path d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84c-.21 1.13-.84 2.08-1.79 2.72v2.26h2.9c1.7-1.56 2.69-3.87 2.69-6.62z" opacity=".9" />
          <path d="M9 18c2.43 0 4.47-.81 5.96-2.18l-2.9-2.26c-.81.54-1.84.86-3.06.86-2.36 0-4.36-1.59-5.07-3.74H.96v2.34A9 9 0 0 0 9 18z" opacity=".7" />
          <path d="M3.93 10.71A5.4 5.4 0 0 1 3.64 9c0-.6.1-1.18.29-1.71V4.96H.96A9 9 0 0 0 0 9c0 1.45.35 2.83.96 4.04l2.97-2.33z" opacity=".55" />
          <path d="M9 3.58c1.32 0 2.51.45 3.44 1.35l2.58-2.58A9 9 0 0 0 9 0 9 9 0 0 0 .96 4.96l2.97 2.33C4.64 5.17 6.64 3.58 9 3.58z" opacity=".85" />
        </svg>
        {t("google")}
      </button>

      {/* Apple */}
      <button
        type="button"
        onClick={onApple}
        disabled={busy}
        className="inline-flex items-center justify-center gap-3 rounded-button border border-frost/20 bg-frost/5 hover:bg-frost/10 text-frost font-display text-sm px-4 py-3 transition disabled:opacity-50 disabled:cursor-not-allowed"
      >
        <svg aria-hidden width="17" height="20" viewBox="0 0 814 1000" fill="currentColor">
          <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105.3-57.8-155.5-127.4C46 790.9 0 663.1 0 541.8c0-207.6 135.4-317.3 268.9-317.3 71.6 0 131 46.5 175.4 46.5 42.8 0 109.6-49.5 190.5-49.5 30.8 0 108.2 2.6 164.4 100.5zm-234.4-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z"/>
        </svg>
        {t("apple")}
      </button>

      {err && (
        <p
          role="alert"
          className="rounded-button border border-magma/40 bg-magma/10 px-4 py-2 font-sans text-sm text-frost text-center"
        >
          {err}
        </p>
      )}

      <div className="relative my-2">
        <div className="absolute inset-0 flex items-center" aria-hidden>
          <span className="w-full border-t border-frost/10"></span>
        </div>
        <div className="relative flex justify-center">
          <span className="bg-evergreen px-3 font-sans text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/60">
            {t("or")}
          </span>
        </div>
      </div>
    </div>
  );
}
