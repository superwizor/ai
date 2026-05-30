// Universal login form for the marketing-site origin.
//
// Pre-2026-05-29 every "Log in" CTA in the marketing-site was a plain
// <a href="https://superwizor-app.web.app/"> redirect — Firebase Auth
// IndexedDB is origin-scoped (docs/18 §5 R3) and we deliberately did
// not bridge sessions. That worked for therapists (they sign in on
// the Flutter origin where their console lives) but blocked
// SUPERWIZOR_ADMIN access entirely, because /admin/* lives on the
// marketing origin and there was nowhere to sign in here.
//
// This form is the universal entry point now. It signs the user in on
// THIS origin via Firebase Auth (email, Google, or Apple), then calls
// identity.GetMyProfile to inspect their role and routes:
//
//   SUPERWIZOR_ADMIN  →  /pl/admin/  (or /en/admin/)
//   anything else     →  /pl/account/ (therapist account page — from
//                        there the user clicks "Otwórz kartoteki" which
//                        uses MintAppLoginToken SSO bridge to open the
//                        Flutter app without re-login)
//
// Social login routing (Google / Apple):
//   User exists in identity-svc → same role-based routing as above.
//   User doesn't exist           → redirect to /register/therapist/finish
//                                  to collect missing Superwizor fields.
//
// Errors render inline:
//   - bad-credentials: Firebase signals via "invalid-credential",
//     "wrong-password", "user-not-found", "invalid-email".
//   - GetMyProfile NotFound: their Firebase account exists but no
//     identity-svc row — copy points them at support.
//   - any other error: generic try-again message + console.error for
//     devtools.

"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { FirebaseError } from "firebase/app";
import { ConnectError, Code } from "@connectrpc/connect";

import { sendPasswordResetEmail } from "firebase/auth";

import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient } from "@/lib/connect/clients";
import { UserRole } from "@superwizor/proto-ts/identity/v1/identity_pb";
import { getFirebaseAuth } from "@/lib/firebase/init";

// APP_URL kept as a comment for grep — the post-login Flutter-app
// bounce moved to the /account page's "Otwórz kartoteki" CTA, so
// LoginForm itself no longer redirects across origins.
// const APP_URL = "https://superwizor-app.web.app/";

type Phase = "idle" | "submitting" | "redirect_admin" | "redirect_app";

export function LoginForm() {
  const t = useTranslations("login");
  const locale = useLocale();
  const adminPrefix = locale === "en" ? "/en" : "/pl";
  const router = useRouter();
  const { signInWithEmail, signInWithGoogle, signInWithApple } = useAuth();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [phase, setPhase] = useState<Phase>("idle");
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  // After any sign-in (email or social) we resolve the user's role and
  // route accordingly. Returns false if we redirected to register/finish.
  const resolveAndRoute = async (): Promise<boolean> => {
    let me;
    try {
      me = await identityClient.getMyProfile(create(EmptySchema, {}));
    } catch (err) {
      if (err instanceof ConnectError && err.code === Code.NotFound) {
        setError(t("errorNoProfile"));
        setPhase("idle");
        return false;
      }
      throw err;
    }

    const isAdmin =
      (me.role as unknown) === UserRole.SUPERWIZOR_ADMIN ||
      (me.role as unknown) === "USER_ROLE_SUPERWIZOR_ADMIN";

    if (isAdmin) {
      setPhase("redirect_admin");
      router.push(`${adminPrefix}/admin/`);
    } else {
      setPhase("redirect_app");
      router.push(`${adminPrefix}/account/`);
    }
    return true;
  };

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    setPhase("submitting");

    try {
      await signInWithEmail(email.trim().toLowerCase(), password);
      await resolveAndRoute();
    } catch (e) {
      if (
        e instanceof FirebaseError &&
        (e.code === "auth/invalid-credential" ||
          e.code === "auth/wrong-password" ||
          e.code === "auth/user-not-found" ||
          e.code === "auth/invalid-email")
      ) {
        setError(t("errorBadCreds"));
      } else {
        console.error("[login] unexpected error", e);
        setError(t("errorGeneric"));
      }
      setPhase("idle");
    }
  }

  // Social sign-in shared handler — used by Google and Apple buttons.
  // If the user doesn't have an identity-svc row yet (new social user),
  // redirect to /register/therapist/finish to collect missing fields.
  const onSocial = async (
    signIn: () => Promise<{ uid: string; displayName: string | null; email: string | null }>
  ) => {
    setError(null);
    setInfo(null);
    setPhase("submitting");
    try {
      const user = await signIn();

      // Check if user already exists in identity-svc.
      try {
        await identityClient.getMyProfile(create(EmptySchema, {}));
      } catch (err) {
        if (err instanceof ConnectError && err.code === Code.NotFound) {
          // New social user — redirect to finish-profile registration.
          const dn = user.displayName ?? "";
          const [firstName = "", ...rest] = dn.split(" ");
          const lastName = rest.join(" ");
          const params = new URLSearchParams({
            firstName,
            lastName,
            email: user.email ?? "",
          });
          router.push(`${adminPrefix}/register/therapist/finish?${params}`);
          return;
        }
        throw err;
      }

      await resolveAndRoute();
    } catch (e) {
      if (
        e instanceof FirebaseError &&
        (e.code === "auth/popup-closed-by-user" ||
          e.code === "canceled" ||
          e.code === "user-cancelled")
      ) {
        // Silent — user dismissed the popup.
        setPhase("idle");
        return;
      }
      console.error("[login] social error", e);
      setError(t("errorGeneric"));
      setPhase("idle");
    }
  };

  async function onForgotPassword() {
    setError(null);
    setInfo(null);
    const trimmed = email.trim().toLowerCase();
    if (!trimmed) {
      setError(t("resetNeedEmail"));
      return;
    }
    try {
      await sendPasswordResetEmail(getFirebaseAuth(), trimmed);
      setInfo(t("resetSent"));
    } catch (e) {
      console.error("[login] reset error", e);
      setError(t("errorGeneric"));
    }
  }

  const disabled = phase !== "idle";

  return (
    <div className="grid gap-5">
      {/* ── Social sign-in ───────────────────────────────────── */}
      <div className="grid gap-3">
        {/* Google */}
        <button
          type="button"
          disabled={disabled}
          onClick={() => onSocial(signInWithGoogle)}
          className="inline-flex items-center justify-center gap-3 rounded-button border border-frost/20 bg-frost/5 hover:bg-frost/10 text-frost font-display text-sm px-4 py-3 transition disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <svg aria-hidden width="18" height="18" viewBox="0 0 18 18" fill="currentColor">
            <path d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84c-.21 1.13-.84 2.08-1.79 2.72v2.26h2.9c1.7-1.56 2.69-3.87 2.69-6.62z" opacity=".9" />
            <path d="M9 18c2.43 0 4.47-.81 5.96-2.18l-2.9-2.26c-.81.54-1.84.86-3.06.86-2.36 0-4.36-1.59-5.07-3.74H.96v2.34A9 9 0 0 0 9 18z" opacity=".7" />
            <path d="M3.93 10.71A5.4 5.4 0 0 1 3.64 9c0-.6.1-1.18.29-1.71V4.96H.96A9 9 0 0 0 0 9c0 1.45.35 2.83.96 4.04l2.97-2.33z" opacity=".55" />
            <path d="M9 3.58c1.32 0 2.51.45 3.44 1.35l2.58-2.58A9 9 0 0 0 9 0 9 9 0 0 0 .96 4.96l2.97 2.33C4.64 5.17 6.64 3.58 9 3.58z" opacity=".85" />
          </svg>
          {t("signInWithGoogle")}
        </button>

        {/* Apple */}
        <button
          type="button"
          disabled={disabled}
          onClick={() => onSocial(signInWithApple)}
          className="inline-flex items-center justify-center gap-3 rounded-button border border-frost/20 bg-frost/5 hover:bg-frost/10 text-frost font-display text-sm px-4 py-3 transition disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <svg aria-hidden width="17" height="20" viewBox="0 0 814 1000" fill="currentColor">
            <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105.3-57.8-155.5-127.4C46 790.9 0 663.1 0 541.8c0-207.6 135.4-317.3 268.9-317.3 71.6 0 131 46.5 175.4 46.5 42.8 0 109.6-49.5 190.5-49.5 30.8 0 108.2 2.6 164.4 100.5zm-234.4-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z"/>
          </svg>
          {t("signInWithApple")}
        </button>
      </div>

      {/* ── "Or use email" divider ───────────────────────────── */}
      <div className="relative">
        <div className="absolute inset-0 flex items-center" aria-hidden>
          <span className="w-full border-t border-frost/10"></span>
        </div>
        <div className="relative flex justify-center">
          <span className="bg-evergreen px-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist/60">
            {t("orUseEmail")}
          </span>
        </div>
      </div>

      {/* ── Email / password form ────────────────────────────── */}
      <form onSubmit={onSubmit} className="grid gap-5" noValidate>
        <label className="grid gap-2">
          <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
            {t("emailLabel")}
          </span>
          <input
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            disabled={disabled}
            className="rounded-button bg-frost/5 border border-frost/15 px-3 py-2 font-mono text-sm text-frost focus:outline-none focus:border-ember disabled:opacity-60"
          />
        </label>

        <label className="grid gap-2">
          <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
            {t("passwordLabel")}
          </span>
          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            disabled={disabled}
            className="rounded-button bg-frost/5 border border-frost/15 px-3 py-2 font-mono text-sm text-frost focus:outline-none focus:border-ember disabled:opacity-60"
          />
        </label>

        {error && (
          <p
            role="alert"
            className="rounded-button border border-magma/40 bg-magma/10 px-3 py-2 font-serif text-xs text-frost"
          >
            {error}
          </p>
        )}
        {info && (
          <p
            role="status"
            className="rounded-button border border-aurora/40 bg-aurora/10 px-3 py-2 font-serif text-xs text-frost"
          >
            {info}
          </p>
        )}

        <button
          type="submit"
          disabled={disabled}
          className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-60 disabled:cursor-not-allowed"
        >
          {phase === "submitting"
            ? t("submitting")
            : phase === "redirect_admin"
            ? t("redirectingAdmin")
            : phase === "redirect_app"
            ? t("redirectingApp")
            : t("submit")}
        </button>

        <button
          type="button"
          onClick={onForgotPassword}
          disabled={disabled}
          className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist hover:text-ember transition disabled:opacity-60"
        >
          {t("forgotPassword")}
        </button>

        <p className="font-serif text-sm text-mist text-center">
          {t("noAccount")}{" "}
          <a
            href={`${adminPrefix}/register/therapist/`}
            className="text-ember underline"
          >
            {t("createAccount")}
          </a>
        </p>
      </form>
    </div>
  );
}
