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
// THIS origin via Firebase Auth, then calls identity.GetMyProfile to
// inspect their role and routes:
//
//   SUPERWIZOR_ADMIN  →  /pl/admin/  (or /en/admin/)
//   anything else     →  https://superwizor-app.web.app/?email=<email>
//                        (the therapist console lives on the Flutter
//                        origin; the email querystring lets the
//                        Flutter login screen pre-fill, so the user
//                        only has to retype their password — the
//                        unavoidable cost of origin discipline)
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

const APP_URL = "https://superwizor-app.web.app/";

type Phase = "idle" | "submitting" | "redirect_admin" | "redirect_app";

export function LoginForm() {
  const t = useTranslations("login");
  const locale = useLocale();
  const adminPrefix = locale === "en" ? "/en" : "/pl";
  const router = useRouter();
  const { signInWithEmail } = useAuth();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [phase, setPhase] = useState<Phase>("idle");
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    setPhase("submitting");

    try {
      await signInWithEmail(email.trim().toLowerCase(), password);

      // The auth-provider's onAuthStateChanged will rehydrate; we can
      // call GetMyProfile right away because the bearer interceptor
      // grabs the freshly-minted ID token from auth.currentUser.
      let me;
      try {
        me = await identityClient.getMyProfile(create(EmptySchema, {}));
      } catch (err) {
        if (err instanceof ConnectError && err.code === Code.NotFound) {
          setError(t("errorNoProfile"));
          setPhase("idle");
          return;
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
        // Pass the email so the Flutter login screen can pre-fill;
        // the user still has to retype the password because Firebase
        // Auth IndexedDB doesn't bridge origins.
        window.location.href =
          `${APP_URL}?email=${encodeURIComponent(email.trim().toLowerCase())}`;
      }
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
  );
}
