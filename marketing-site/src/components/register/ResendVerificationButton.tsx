// Email-verification gate (Slice 3 feature 5).
//
// Started life in feature 1 as a one-shot "Resend verification"
// button. Feature 5 extends it into a full polling panel that:
//   - polls auth.currentUser.reload() every 5s,
//   - listens for tab visibilitychange to force an immediate
//     reload when the user returns from clicking the email link,
//   - on emailVerified=true → auto-redirects to /{locale}/account/
//     on this origin, while showing a "Verified · redirecting"
//     intermediate state so the user understands what just happened,
//   - keeps the Resend button available the whole time.
//
// Why land on /account/ on the marketing origin (2026-05-29 — switched
// from the Flutter app at superwizor-app.web.app): the new therapist
// account page lives here, on the same origin where Firebase Auth
// signed them in. Bouncing to the Flutter origin required a re-login
// (Auth is origin-scoped) and the post-signup tasks (Profil + Org
// edit, Subskrypcja) are now first-class on this origin. The Flutter
// app is still reachable from the "Otwórz kartoteki" CTA on /account.

"use client";

import { useEffect, useRef, useState } from "react";
import { sendEmailVerification } from "firebase/auth";
import { useTranslations, useLocale } from "next-intl";
import { useAuth } from "@/lib/firebase/auth-provider";

const POLL_INTERVAL_MS = 5_000;

type Status = "idle" | "sending" | "sent" | "verified";

export function ResendVerificationButton() {
  const t = useTranslations("register.verifyEmail");
  const locale = useLocale();
  const { user } = useAuth();
  const [status, setStatus] = useState<Status>("idle");
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Post-verification destination on the same origin. Same-origin
  // relative path so this works in dev (localhost), preview channels,
  // and prod without per-env config.
  const onboardingUrl = `/${locale}/onboarding/`;

  // Poll for verification. We use auth.currentUser.reload() because
  // the Firebase JS SDK doesn't push email-verified changes
  // automatically — onAuthStateChanged fires for sign-in/out only.
  // The reload() call refreshes the ID token's email_verified claim
  // and updates user.emailVerified in place.
  useEffect(() => {
    if (!user || status === "verified") return;

    const check = async () => {
      try {
        await user.reload();
        if (user.emailVerified) {
          setStatus("verified");
          // Small delay so users see the "verified" state flicker
          // before the redirect — better UX than instant
          // window.location change with no feedback.
          setTimeout(() => {
            window.location.href = onboardingUrl;
          }, 1500);
        }
      } catch {
        // Network blip / token refresh failure — try again next tick.
      }
    };

    // Fire immediately so a user who clicked the link in another tab
    // and came back sees the result without waiting up to 5s.
    void check();

    pollRef.current = setInterval(check, POLL_INTERVAL_MS);
    const onVisible = () => {
      if (document.visibilityState === "visible") void check();
    };
    document.addEventListener("visibilitychange", onVisible);

    return () => {
      if (pollRef.current) clearInterval(pollRef.current);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [user, status, onboardingUrl]);

  const onResend = async () => {
    if (!user) return;
    setStatus("sending");
    try {
      await sendEmailVerification(user);
      setStatus("sent");
    } catch {
      setStatus("idle");
    }
  };

  // Verified state — render its own button so the user can manually
  // continue if the auto-redirect fails (e.g. blocked window).
  if (status === "verified") {
    return (
      <div className="flex flex-col gap-3 items-center" role="status">
        <p className="font-display text-frost text-lg font-semibold">
          ✓ {t("verifiedHeading")}
        </p>
        <p className="font-sans text-mist text-sm">{t("verifiedBody")}</p>
        <a
          href={onboardingUrl}
          className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-sans uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition"
        >
          {t("verifiedGoToAccount")}
        </a>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2 items-center">
      {user && (
        <p
          aria-live="polite"
          className="font-sans text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/60"
        >
          {t("verifyingStatus")}
        </p>
      )}
      <button
        onClick={onResend}
        disabled={!user || status === "sending"}
        className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-sans uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {status === "sending"
          ? t("resending")
          : status === "sent"
          ? t("resent")
          : t("resend")}
      </button>
    </div>
  );
}
