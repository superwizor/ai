// Email-verification gate (Slice 3 feature 5).
//
// Started life in feature 1 as a one-shot "Resend verification"
// button. Feature 5 extends it into a full polling panel that:
//   - polls auth.currentUser.reload() every 5s,
//   - listens for tab visibilitychange to force an immediate
//     reload when the user returns from clicking the email link,
//   - on emailVerified=true → auto-redirects to the app origin,
//     while showing a "Verified · redirecting" intermediate state
//     so the user understands what just happened,
//   - keeps the Resend button available the whole time.
//
// Why on the marketing origin: Firebase's verification email lands
// the user on whichever URL is configured in the Firebase project
// (typically https://app.superwizor.ai/__/auth/action which then
// returns them to the action's `continueUrl`). For now we set
// continueUrl back to the marketing verify-email page so the user
// can see verified-then-redirect on the same origin they started
// on. Slice 5 may move the continueUrl to the app origin directly.

"use client";

import { useEffect, useRef, useState } from "react";
import { sendEmailVerification } from "firebase/auth";
import { useTranslations } from "next-intl";
import { useAuth } from "@/lib/firebase/auth-provider";

const POLL_INTERVAL_MS = 5_000;
const APP_HOME_URL = "https://app.superwizor.ai/login";

type Status = "idle" | "sending" | "sent" | "verified";

export function ResendVerificationButton() {
  const t = useTranslations("register.verifyEmail");
  const { user } = useAuth();
  const [status, setStatus] = useState<Status>("idle");
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

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
            window.location.href = APP_HOME_URL;
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
  }, [user, status]);

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
        <p className="font-serif text-mist text-sm">{t("verifiedBody")}</p>
        <a
          href={APP_HOME_URL}
          className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition"
        >
          {t("verifiedGoToApp")}
        </a>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2 items-center">
      {user && (
        <p
          aria-live="polite"
          className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/60"
        >
          {t("verifyingStatus")}
        </p>
      )}
      <button
        onClick={onResend}
        disabled={!user || status === "sending"}
        className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-50 disabled:cursor-not-allowed"
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
