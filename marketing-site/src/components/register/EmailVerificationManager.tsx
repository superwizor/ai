"use client";

import { useEffect, useRef, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { useTranslations, useLocale } from "next-intl";
import { useAuth } from "@/lib/firebase/auth-provider";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { identityClient } from "@/lib/connect/clients";
import { ConnectError, Code } from "@connectrpc/connect";

const POLL_INTERVAL_MS = 5_000;

type Status = "idle" | "sending" | "sent" | "verified";

function Inner() {
  const t = useTranslations("register.verifyEmail");
  const locale = useLocale();
  const params = useSearchParams();
  const { user, status: authStatus } = useAuth();
  const [status, setStatus] = useState<Status>("idle");
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Email editing state
  const [isEditingEmail, setIsEditingEmail] = useState(false);
  const [newEmail, setNewEmail] = useState("");
  const [editError, setEditError] = useState<string | null>(null);
  const [editSuccess, setEditSuccess] = useState(false);

  const prefix = locale === "en" ? "/en" : "";
  const onboardingUrl = `/${locale}/onboarding/`;
  const dashboardUrl = `/${locale}/dashboard/`;

  // Post-verification target (docs/38): therapists invited to an org
  // already picked their nurt (default modality) on the accept-invite
  // password screen — sending them through /onboarding again would ask
  // twice. If the profile has a modality, go straight to the dashboard;
  // otherwise (self-serve signup) onboarding proceeds as before. On any
  // lookup error fall back to onboarding — its own guard is harmless.
  const redirectAfterVerification = async () => {
    try {
      const me = await identityClient.getMyProfile(create(EmptySchema, {}));
      window.location.replace(me.defaultModalityId ? dashboardUrl : onboardingUrl);
    } catch {
      window.location.replace(onboardingUrl);
    }
  };

  // Base email display falls back to query param if user hasn't hydrated/loaded yet
  const displayEmail = user?.email || params?.get("email") || "";

  // Poll for verification
  useEffect(() => {
    if (!user || status === "verified" || isEditingEmail || user.emailVerified) return;

    const check = async () => {
      try {
        await user.reload();
        if (user.emailVerified) {
          setStatus("verified");
          // Small delay so user sees the "verified" state before redirecting
          setTimeout(() => {
            void redirectAfterVerification();
          }, 1500);
        }
      } catch {
        // Network blip / token refresh failure — try again next tick.
      }
    };

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
  }, [user, status, onboardingUrl, isEditingEmail]);

  // Immediate redirect if already verified on mount/hydration
  useEffect(() => {
    if (user && user.emailVerified) {
      void redirectAfterVerification();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  const onResend = async () => {
    if (!user?.email) return;
    setStatus("sending");
    try {
      await identityClient.resendVerificationEmail({
        email: user.email,
      });
      setStatus("sent");
      // Revert back to idle after 10 seconds so button becomes clickable again
      setTimeout(() => setStatus("idle"), 10000);
    } catch (err) {
      console.error("[verify-email] resendVerificationEmail failed:", err);
      setStatus("idle");
    }
  };

  const handleSaveEmail = async () => {
    if (!user || !newEmail.trim()) return;

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(newEmail.trim())) {
      setEditError(t("invalidEmail"));
      return;
    }

    setEditError(null);
    setEditSuccess(false);

    try {
      // 1. Call backend to update email and send new verification link
      await identityClient.updateMyEmail({
        newEmail: newEmail.trim(),
      });

      // 2. Force reload and token refresh in Firebase Auth so client picks up the new email
      await user.reload();
      await user.getIdToken(true);

      setEditSuccess(true);
      setIsEditingEmail(false);
      
      // Auto-hide success message after 5 seconds
      setTimeout(() => setEditSuccess(false), 5000);
    } catch (err: any) {
      console.error("[verify-email] updateMyEmail failed:", err);
      if (err instanceof ConnectError && err.code === Code.AlreadyExists) {
        setEditError(t("emailInUse"));
      } else if (err.code === "auth/requires-recent-login") {
        setEditError(t("sessionExpired"));
      } else if (err.code === "auth/email-already-in-use") {
        setEditError(t("emailInUse"));
      } else {
        setEditError(t("saveError"));
      }
    }
  };

  // Render loading state
  if (authStatus === "loading" || user?.emailVerified) {
    return (
      <div className="flex flex-col items-center justify-center p-8 min-h-[200px]">
        <div className="w-8 h-8 rounded-full border-2 border-frost/10 border-t-ember animate-spin" />
      </div>
    );
  }

  // Handle signed-out state elegantly
  if (authStatus === "signed-out" || !user) {
    return (
      <div className="mt-2 w-full p-6 rounded-2xl border border-magma/20 bg-magma/[0.03] backdrop-blur-sm flex flex-col gap-4 text-center items-center shadow-lg">
        <div className="w-12 h-12 rounded-full bg-magma/10 flex items-center justify-center text-error border border-magma/20 shadow-[0_0_15px_rgba(239,68,68,0.1)]">
          <svg className="w-6 h-6 text-error animate-pulse" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
        </div>
        <div className="flex flex-col gap-1.5">
          <h3 className="font-display text-frost text-base font-semibold">
            {t("signedOutHeading")}
          </h3>
          <p className="font-sans text-mist/75 text-xs leading-relaxed max-w-xs">
            {t("signedOutBody")}
          </p>
        </div>
        <a
          href={`${prefix}/login?redirect=${encodeURIComponent("/register/therapist/verify-email")}`}
          className="inline-flex items-center justify-center rounded-xl bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs px-6 py-3 hover:brightness-110 active:scale-95 transition-all w-full shadow-[0_4px_12px_rgba(252,174,47,0.15)]"
        >
          {t("logIn")}
        </a>
      </div>
    );
  }

  // Verified state
  if (status === "verified") {
    return (
      <div className="flex flex-col gap-4 items-center justify-center py-6" role="status">
        <div className="w-16 h-16 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400 shadow-[0_0_20px_rgba(16,185,129,0.15)] animate-bounce mb-2">
          <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
          </svg>
        </div>
        <div className="flex flex-col gap-1">
          <h3 className="font-display text-frost text-xl font-bold">
            {t("verifiedHeading")}
          </h3>
          <p className="font-sans text-mist/80 text-sm">{t("verifiedBody")}</p>
        </div>
        <a
          href={onboardingUrl}
          onClick={(e) => {
            e.preventDefault();
            void redirectAfterVerification();
          }}
          className="inline-flex items-center justify-center rounded-xl bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs px-6 py-3.5 mt-2 shadow-[0_4px_14px_rgba(252,174,47,0.25)] hover:brightness-115 active:scale-95 transition-all"
        >
          {t("verifiedGoToAccount")}
        </a>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6 w-full text-center">
      {/* Intro Text */}
      <p className="font-sans text-mist text-sm sm:text-base leading-relaxed max-w-sm mx-auto">
        {t("intro")}
      </p>

      {/* Premium Highlighted Email Display / Inline Edit Card */}
      <div className="relative overflow-hidden rounded-2xl bg-frost/[0.02] border border-frost/10 p-5 backdrop-blur-md group transition-all duration-300 hover:border-ember/25 hover:bg-frost/[0.04] shadow-[inset_0_2px_4px_rgba(0,0,0,0.3)] flex flex-col items-center justify-center w-full max-w-[400px] mx-auto min-h-[110px]">
        {/* Subtle hover gradient */}
        <div className="absolute -inset-10 -z-10 opacity-0 group-hover:opacity-10 blur-[30px] bg-gradient-to-r from-ember via-[#F5A623] to-[#2F6B62] transition-opacity duration-500 pointer-events-none" />

        {!isEditingEmail ? (
          <div className="flex flex-col items-center gap-2 w-full">
            <span className="font-sans text-xs font-medium text-mist/75 select-none">
              {t("recipientEmail")}
            </span>
            
            <span className="font-sans text-base sm:text-lg font-semibold text-frost/95 break-all select-all tracking-wide px-2 py-0.5 selection:bg-ember selection:text-obsidian transition-colors">
              {displayEmail || "..."}
            </span>
            
            <button
              onClick={() => {
                setNewEmail(displayEmail);
                setIsEditingEmail(true);
                setEditError(null);
                setEditSuccess(false);
              }}
              className="mt-3 inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-lg bg-frost/5 border border-frost/15 text-xs text-mist hover:text-ember hover:bg-frost/10 hover:border-ember/30 transition-all shadow-sm font-medium cursor-pointer"
            >
              <svg className="w-3.5 h-3.5 opacity-70" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
              <span>{t("changeEmail")}</span>
            </button>
          </div>
        ) : (
          <div className="w-full flex flex-col gap-3 text-left">
            <div className="flex flex-col gap-1 w-full">
              <span className="font-sans text-xs font-medium text-mist/75 select-none mb-1">
                {t("newEmailLabel")}
              </span>
              <input
                type="email"
                value={newEmail}
                onChange={(e) => setNewEmail(e.target.value)}
                className="w-full rounded-xl bg-obsidian/70 border border-frost/20 px-3.5 py-2 font-sans text-sm text-frost focus:outline-none focus:border-ember focus:ring-1 focus:ring-ember/40 transition-all shadow-[inset_0_2px_4px_rgba(0,0,0,0.5)]"
                placeholder="user@example.com"
                autoFocus
              />
            </div>
            {editError && (
              <p role="alert" className="text-[11px] text-[#FF6B6B] font-medium leading-normal">
                {editError}
              </p>
            )}
            <div className="flex gap-2 justify-end w-full">
              <button
                type="button"
                onClick={() => setIsEditingEmail(false)}
                className="px-3.5 py-1.5 rounded-lg border border-frost/15 text-xs text-mist hover:bg-frost/5 transition cursor-pointer"
              >
                {t("cancel")}
              </button>
              <button
                type="button"
                onClick={handleSaveEmail}
                className="px-3.5 py-1.5 rounded-lg bg-ember text-obsidian font-bold text-xs hover:brightness-110 active:scale-95 transition-all shadow-[0_4px_12px_rgba(252,174,47,0.15)] cursor-pointer"
              >
                {t("saveAndSend")}
              </button>
            </div>
          </div>
        )}
      </div>

      {editSuccess && (
        <p className="text-xs text-ember font-medium animate-fade-in -mt-3">
          ✓ {t("emailUpdated")}
        </p>
      )}

      {/* Troubleshooting & Actions Section */}
      <div className="flex flex-col items-center gap-4 mt-2 pt-6 border-t border-frost/5 w-full">
        <p className="font-sans text-mist/65 text-xs leading-relaxed max-w-sm mx-auto">
          {t("noEmail")}
        </p>

        {/* Polling/Automatic Status Check dot */}
        <div className="flex items-center gap-2.5 px-4 py-2 rounded-full bg-frost/[0.01] border border-frost/5 shadow-sm">
          <span className="flex gap-1 items-center shrink-0">
            <span className="w-1.5 h-1.5 rounded-full bg-ember animate-bounce" style={{ animationDelay: '0ms' }} />
            <span className="w-1.5 h-1.5 rounded-full bg-ember animate-bounce" style={{ animationDelay: '150ms' }} />
            <span className="w-1.5 h-1.5 rounded-full bg-ember animate-bounce" style={{ animationDelay: '300ms' }} />
          </span>
          <span className="text-[11px] font-medium tracking-wide text-mist/60">
            {t("checkingStatus")}
          </span>
        </div>

        <button
          onClick={onResend}
          disabled={status === "sending" || isEditingEmail}
          className="w-full max-w-[280px] inline-flex items-center justify-center rounded-xl bg-ember text-obsidian font-sans uppercase tracking-wider text-xs font-bold py-3.5 shadow-[0_4px_14px_rgba(252,174,47,0.18)] hover:brightness-110 active:scale-[0.98] transition-all disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
        >
          {status === "sending"
            ? t("resending")
            : status === "sent"
            ? t("resent")
            : t("resend")}
        </button>
      </div>
    </div>
  );
}

export function EmailVerificationManager() {
  return (
    <Suspense fallback={
      <div className="animate-pulse flex flex-col gap-6 my-4 w-full max-w-[400px] mx-auto min-h-[300px] rounded-2xl bg-frost/5 border border-frost/10 p-6" />
    }>
      <Inner />
    </Suspense>
  );
}
