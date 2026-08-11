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

import { useState, useEffect, useRef } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { FirebaseError } from "firebase/app";
import { ConnectError, Code } from "@connectrpc/connect";

import { sendPasswordResetEmail } from "firebase/auth";

import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient } from "@/lib/connect/clients";
import { UserRole, CheckEmailExistsRequestSchema } from "@superwizor/proto-ts/identity/v1/identity_pb";
import { getFirebaseAuth } from "@/lib/firebase/init";
import { openAppWithSso } from "@/lib/auth/open-app-sso";

// Therapists stay on this origin post-login (the app bounce lives on
// /account's "Otwórz kartoteki" CTA), but CLIENTS have no surface here
// at all — their panel lives on the app origin, so PATIENT logins hand
// off via openAppWithSso (same SSO path as accept-invite).

type Phase = "idle" | "submitting" | "redirect_admin" | "redirect_app";

export function LoginForm() {
  const t = useTranslations("login");
  const locale = useLocale();
  const adminPrefix = locale === "en" ? "/en" : "/pl";
  const router = useRouter();
  const searchParams = useSearchParams();
  const errParam = searchParams.get("err");
  const { signInWithEmail, signInWithGoogle, signInWithApple } = useAuth();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const emailRef = useRef<HTMLInputElement>(null);
  const passwordRef = useRef<HTMLInputElement>(null);
  const [phase, setPhase] = useState<Phase>("idle");
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  useEffect(() => {
    if (errParam === "reauth") {
      setError(t("errorReauth"));
    }
    // Wysyła tu strażnik /onboarding, gdy w TYM oknie nie ma sesji.
    // Po zalogowaniu wracamy do kreatora automatycznie — niżej w tym
    // pliku niedokończony profil kieruje na /onboarding/.
    if (errParam === "session") {
      setError(t("errorSessionRequired"));
    }
  }, [errParam, t]);

  // After any sign-in (email or social) we resolve the user's role and
  // route accordingly. Returns false if we redirected to register/finish.
  const resolveAndRoute = async (): Promise<boolean> => {
    let me;
    try {
      me = await identityClient.getMyProfile(create(EmptySchema, {}));
    } catch (err) {
      if (err instanceof ConnectError && err.code === Code.NotFound) {
        // The Firebase account exists but has no Superwizor profile — a
        // half-finished registration (signup abandoned after the email
        // step) or an old social account. Route to finish-registration to
        // create the profile, exactly like the social-login path, instead
        // of dead-ending. The user just authenticated, so it's their email.
        const u = getFirebaseAuth().currentUser;
        const dn = u?.displayName ?? "";
        const [firstName = "", ...rest] = dn.split(" ");
        const params = new URLSearchParams({
          firstName,
          lastName: rest.join(" "),
          email: u?.email ?? "",
        });
        setPhase("redirect_app");
        router.push(`${adminPrefix}/register/therapist/finish?${params.toString()}`);
        return false;
      }
      throw err;
    }

    // Role-based routing (live-fix 2026-07-04: a CLIENT signing in from
    // the marketing login landed on the THERAPIST onboarding because the
    // only branches were admin / no-modality / dashboard).
    //   SUPERWIZOR_ADMIN → /admin/
    //   PATIENT          → client panel on the app origin (SSO handoff)
    //   ORG_ADMIN        → /org/
    //   THERAPIST        → /onboarding/ (no modality yet) or /dashboard/
    const role = me.role as unknown;
    const is = (enumVal: UserRole, name: string) =>
      role === enumVal || role === name;

    if (is(UserRole.SUPERWIZOR_ADMIN, "USER_ROLE_SUPERWIZOR_ADMIN")) {
      setPhase("redirect_admin");
      router.push(`${adminPrefix}/admin/`);
    } else if (is(UserRole.PATIENT, "USER_ROLE_PATIENT")) {
      setPhase("redirect_app");
      await openAppWithSso(me.email);
    } else if (is(UserRole.ORG_ADMIN, "USER_ROLE_ORG_ADMIN")) {
      setPhase("redirect_app");
      router.push(`${adminPrefix}/org/`);
    } else if (!me.defaultModalityId) {
      setPhase("redirect_app");
      router.push(`${adminPrefix}/onboarding/`);
    } else {
      setPhase("redirect_app");
      router.push(`${adminPrefix}/dashboard/`);
    }
    return true;
  };

  useEffect(() => {
    const isDemo = searchParams.get("demo") === "1" || searchParams.get("demo") === "true";
    if (isDemo && phase === "idle") {
      const runAutoLogin = async () => {
        setPhase("submitting");
        setError(null);
        setInfo(locale === "pl" ? "Logowanie do konta demonstracyjnego..." : "Logging into demonstration account...");
        try {
          await signInWithEmail("demo@superwizor.ai", "SuperwizorDemo123!");
          await resolveAndRoute();
        } catch (e) {
          console.error("[login] autologin error", e);
          setError(locale === "pl" ? "Nie udało się zalogować automatycznie." : "Auto-login failed.");
          setPhase("idle");
        }
      };
      runAutoLogin();
    }
  }, [searchParams, phase]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    setPhase("submitting");

    const finalEmail = (emailRef.current?.value || email || "").trim().toLowerCase();
    const finalPassword = passwordRef.current?.value || password || "";

    try {
      await signInWithEmail(finalEmail, finalPassword);
      await resolveAndRoute();
    } catch (e) {
      if (
        e instanceof FirebaseError &&
        (e.code === "auth/invalid-credential" ||
          e.code === "auth/wrong-password" ||
          e.code === "auth/user-not-found" ||
          e.code === "auth/invalid-email")
      ) {
        try {
          const checkResp = await identityClient.checkEmailExists(
            create(CheckEmailExistsRequestSchema, { email: email.trim().toLowerCase() })
          );
          if (checkResp.exists && checkResp.isPendingDeletion) {
            setError(t("errorPendingDeletion"));
          } else {
            setError(t("errorBadCreds"));
          }
        } catch (checkErr) {
          setError(t("errorBadCreds"));
        }
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
  const homeLink = locale === "en" ? "/en/" : "/pl/";

  return (
    <div className="grid gap-5">
      {/* Back Arrow Button */}
      <div className="flex justify-start mb-2">
        <a
          href={homeLink}
          className="inline-flex items-center gap-2 text-ember hover:text-ember/80 font-sans text-xs font-semibold uppercase tracking-wider transition group cursor-pointer"
        >
          <svg
            className="w-4 h-4 transition-transform group-hover:-translate-x-1"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2.5}
          >
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
          {locale === "pl" ? "Wróć do strony głównej" : "Back to home"}
        </a>
      </div>

      {/* ── Option 1: social sign-in (mirrors the client-invite
             layout — two clearly labeled sections, live-feedback
             2026-07-04) ───────────────────────────────────────── */}
      <section className="rounded-button border border-frost/15 bg-frost/[0.03] p-5 grid gap-3">
        <h2 className="font-display text-frost text-sm font-semibold">
          {t("option1Title")}
        </h2>
        {/* Google */}
        <button
          type="button"
          disabled={disabled}
          onClick={() => onSocial(signInWithGoogle)}
          className="w-full flex items-center justify-center gap-3 py-3 px-4 rounded-xl bg-frost/5 border border-frost/20 hover:bg-frost/10 hover:border-frost/40 text-frost font-sans font-semibold text-sm transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer group"
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
          className="w-full flex items-center justify-center gap-3 py-3 px-4 rounded-xl bg-frost/5 border border-frost/20 hover:bg-frost/10 hover:border-frost/40 text-frost font-sans font-semibold text-sm transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer group"
        >
          <svg aria-hidden width="17" height="20" viewBox="0 0 814 1000" fill="currentColor">
            <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105.3-57.8-155.5-127.4C46 790.9 0 663.1 0 541.8c0-207.6 135.4-317.3 268.9-317.3 71.6 0 131 46.5 175.4 46.5 42.8 0 109.6-49.5 190.5-49.5 30.8 0 108.2 2.6 164.4 100.5zm-234.4-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z"/>
          </svg>
          {t("signInWithApple")}
        </button>
      </section>

      {/* ── "Or use email" divider ───────────────────────────── */}
      <div className="relative">
        <div className="absolute inset-0 flex items-center" aria-hidden>
          <span className="w-full border-t border-frost/10"></span>
        </div>
        <div className="relative flex justify-center">
          <span className="bg-evergreen px-3 font-sans text-[10px] font-bold uppercase tracking-[var(--tracking-label)] text-mist/60">
            {t("orUseEmail")}
          </span>
        </div>
      </div>

      {/* ── Option 2: e-mail / password form ─────────────────── */}
      <form
        onSubmit={onSubmit}
        className="rounded-button border border-frost/15 bg-frost/[0.03] p-5 grid gap-5"
        noValidate
      >
        <h2 className="font-display text-frost text-sm font-semibold">
          {t("option2Title")}
        </h2>
        <label className="grid gap-2">
          <span className="font-sans text-[10px] font-semibold uppercase tracking-[var(--tracking-label)] text-mist">
            {t("emailLabel")}
          </span>
          <input
            ref={emailRef}
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            disabled={disabled}
            className="rounded-button bg-frost/10 border border-frost/20 px-3.5 py-2.5 font-sans text-base text-frost focus:outline-none focus:border-ember focus:bg-frost/15 disabled:opacity-60 placeholder:text-mist/50 transition"
          />
        </label>

        <label className="grid gap-2">
          <span className="font-sans text-[10px] font-semibold uppercase tracking-[var(--tracking-label)] text-mist">
            {t("passwordLabel")}
          </span>
          <input
            ref={passwordRef}
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            disabled={disabled}
            className="rounded-button bg-frost/10 border border-frost/20 px-3.5 py-2.5 font-sans text-base text-frost focus:outline-none focus:border-ember focus:bg-frost/15 disabled:opacity-60 placeholder:text-mist/50 transition"
          />
        </label>

        {error && (
          <p
            role="alert"
            className="rounded-button border border-magma/40 bg-magma/10 px-3.5 py-2.5 font-sans text-sm text-frost"
          >
            {error}
          </p>
        )}
        {info && (
          <p
            role="status"
            className="rounded-button border border-aurora/40 bg-aurora/10 px-3.5 py-2.5 font-sans text-sm text-frost"
          >
            {info}
          </p>
        )}

        <button
          type="submit"
          disabled={disabled}
          className="w-full flex items-center justify-center gap-3 py-4 px-6 rounded-xl bg-ember text-obsidian shadow-[0_4px_14px_rgba(252,174,47,0.4)] hover:brightness-115 hover:shadow-[0_6px_20px_rgba(252,174,47,0.6)] hover:-translate-y-0.5 transition-all duration-300 group cursor-pointer font-sans text-[18px] font-semibold text-obsidian disabled:opacity-60 disabled:cursor-not-allowed disabled:transform-none disabled:shadow-none"
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
          className="font-sans text-[10px] font-semibold uppercase tracking-[var(--tracking-label)] text-mist hover:text-ember transition disabled:opacity-60"
        >
          {t("forgotPassword")}
        </button>

        <p className="font-sans text-sm text-mist/75 text-center">
          {t("noAccount")}{" "}
          <a
            href={`${adminPrefix}/register/therapist/`}
            className="text-ember font-semibold hover:underline"
          >
            {t("createAccount")}
          </a>
        </p>
      </form>
    </div>
  );
}
