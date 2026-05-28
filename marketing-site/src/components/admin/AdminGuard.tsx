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
    return (
      <ForbiddenCard
        title={t("signinRequired")}
        body=""
        cta={{ label: t("signinCta"), href: "https://app.superwizor.ai/login" }}
      />
    );
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
      <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist">
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
          <p className="font-serif text-mist mt-3 text-sm leading-relaxed">
            {body}
          </p>
        )}
        <a
          href={cta.href}
          className="mt-6 inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition"
        >
          {cta.label}
        </a>
      </div>
    </main>
  );
}
