// Route-level gate + shell wrapper for /admin/* (docs/18 §7).
//
// Combined into one client component so the parent layout (a Server
// Component) can pass plain JSX children without crossing a function
// boundary — Next.js refuses to serialise function children from
// server → client. The shell + guard responsibilities are still
// separate at the React level: <AdminGuardAndShell> handles auth
// gating, and <AdminShell> handles the chrome once authorised.
//
// Three terminal states drive what we render:
//   - loading: Firebase Auth still hydrating + GetMyProfile in flight.
//   - signed-out: no Firebase user → "must sign in" panel + link
//     to the app-origin login.
//   - signed-in but role != SUPERWIZOR_ADMIN → 403 panel. We do not
//     404 — the route exists, just not for this user; a clear
//     forbidden message is clearer + lets accidental access self-
//     diagnose. Backend re-validates every RPC regardless.
//   - signed-in + SUPERWIZOR_ADMIN → render the AdminShell + children.

"use client";

import { useEffect, useState, type ReactNode } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { FirebaseError } from "firebase/app";
import type { User } from "@superwizor/proto-ts/identity/v1/identity_pb";
import { UserRole } from "@superwizor/proto-ts/identity/v1/identity_pb";

import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient } from "@/lib/connect/clients";
import { AdminShell } from "./AdminShell";

type Status = "loading" | "signed-out" | "forbidden" | "allowed";

export function AdminGuardAndShell({ children }: { children: ReactNode }) {
  const t = useTranslations("admin");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";
  const { status: authStatus, user: fbUser } = useAuth();

  const [status, setStatus] = useState<Status>("loading");
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    if (authStatus === "loading") {
      setStatus("loading");
      return;
    }
    if (authStatus === "signed-out" || !fbUser) {
      setStatus("signed-out");
      return;
    }

    let cancelled = false;
    (async () => {
      try {
        const me = await identityClient.getMyProfile(create(EmptySchema, {}));
        if (cancelled) return;
        setUser(me);
        setStatus(
          // Connect-Web JSON serialises enums as proto names; accept
          // both numeric and string forms for forward-compat (same
          // pattern as the Slice 3 Playwright assertion).
          (me.role as unknown) === UserRole.SUPERWIZOR_ADMIN ||
            (me.role as unknown) === "USER_ROLE_SUPERWIZOR_ADMIN"
            ? "allowed"
            : "forbidden",
        );
      } catch {
        if (!cancelled) setStatus("forbidden");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [authStatus, fbUser]);

  if (status === "loading") {
    return <CenteredMessage>{t("loading")}</CenteredMessage>;
  }

  if (status === "signed-out") {
    // Marketing-site (this origin) and the Flutter app (superwizor-app
    // origin) deliberately keep separate Firebase Auth sessions per
    // docs/18 §5 R3 — IndexedDB is origin-scoped and we don't bridge.
    // So even an admin who's signed in on the Flutter origin starts
    // here as "signed-out". Render an inline sign-in form so the
    // admin can authenticate ON this origin without needing the
    // public marketing pages to grow a login surface.
    return <AdminSignInForm />;
  }

  if (status === "forbidden") {
    return (
      <ForbiddenCard
        title={t("forbiddenTitle")}
        body={t("forbiddenBody")}
        cta={{ label: t("backToLanding"), href: `${prefix}/` }}
      />
    );
  }

  return <AdminShell user={user!}>{children}</AdminShell>;
}

function CenteredMessage({ children }: { children: ReactNode }) {
  return (
    <main className="flex flex-1 items-center justify-center px-4 py-16">
      <p className="font-sans text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist">
        {children}
      </p>
    </main>
  );
}

function ForbiddenCard({
  title,
  body,
  cta,
}: {
  title: string;
  body: string;
  cta: { label: string; href: string };
}) {
  return (
    <main className="flex flex-1 items-center justify-center px-4 py-16">
      <div className="max-w-md rounded-glass border border-glass-border/40 bg-frost/[0.04] p-8 text-center">
        <h1 className="font-display text-frost text-2xl font-semibold tracking-[var(--tracking-display)]">
          {title}
        </h1>
        {body && (
          <p className="font-sans text-mist mt-3 text-sm leading-relaxed">
            {body}
          </p>
        )}
        <a
          href={cta.href}
          className="mt-6 inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-sans uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition"
        >
          {cta.label}
        </a>
      </div>
    </main>
  );
}

// Inline email/password sign-in surface shown ONLY inside /admin/* when
// the visitor isn't signed in on this origin. On success the auth-
// provider's onAuthStateChanged fires, the parent AdminGuard's useEffect
// re-runs, and the panel hydrates. No redirect; no cross-origin session
// bridging. If the signed-in account isn't SUPERWIZOR_ADMIN the parent
// will swap to the forbidden card on the next render — same exit as
// before.
function AdminSignInForm() {
  const t = useTranslations("admin");
  const { signInWithEmail } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await signInWithEmail(email.trim().toLowerCase(), password);
      // AuthProvider will fire onAuthStateChanged and AdminGuard's
      // useEffect re-runs with authStatus=signed-in → GetMyProfile
      // → "allowed" or "forbidden". No manual reload.
    } catch (e) {
      if (
        e instanceof FirebaseError &&
        (e.code === "auth/invalid-credential" ||
          e.code === "auth/wrong-password" ||
          e.code === "auth/user-not-found" ||
          e.code === "auth/invalid-email")
      ) {
        setError(t("signinErrorBadCreds"));
      } else {
        setError(t("signinErrorGeneric"));
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="flex flex-1 items-center justify-center px-4 py-16">
      <form
        onSubmit={onSubmit}
        className="w-full max-w-sm rounded-glass border border-glass-border/40 bg-frost/[0.04] p-8 grid gap-5"
        noValidate
      >
        <h1 className="font-display text-frost text-2xl font-semibold tracking-[var(--tracking-display)] text-center">
          {t("signinRequired")}
        </h1>

        <label className="grid gap-2">
          <span className="font-sans text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
            {t("signinEmailLabel")}
          </span>
          <input
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            className="rounded-button bg-obsidian border border-frost/25 px-3 py-2 font-sans text-sm text-frost focus:outline-none focus:border-ember"
          />
        </label>

        <label className="grid gap-2">
          <span className="font-sans text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
            {t("signinPasswordLabel")}
          </span>
          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            className="rounded-button bg-obsidian border border-frost/25 px-3 py-2 font-sans text-sm text-frost focus:outline-none focus:border-ember"
          />
        </label>

        {error && (
          <p
            role="alert"
            className="rounded-button border border-magma/40 bg-magma/10 px-3 py-2 font-sans text-xs text-frost"
          >
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={submitting}
          className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-sans uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-60 disabled:cursor-not-allowed"
        >
          {submitting ? t("signinSubmitting") : t("signinSubmit")}
        </button>
      </form>
    </main>
  );
}
