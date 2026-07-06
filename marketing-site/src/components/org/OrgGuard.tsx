// Route-level gate + light chrome for /org (docs/38 §6).
//
// Mirrors AdminGuardAndShell but for role=ORG_ADMIN. Same three
// terminal states (loading / signed-out / forbidden) + a slim header
// instead of the full admin nav — the org panel is a single page with
// tabs. Backend re-validates every RPC regardless.

"use client";

import { useEffect, useState, type ReactNode } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import type { User } from "@superwizor/proto-ts/identity/v1/identity_pb";
import { UserRole } from "@superwizor/proto-ts/identity/v1/identity_pb";

import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient } from "@/lib/connect/clients";

type Status = "loading" | "signed-out" | "forbidden" | "allowed";

export function OrgGuardAndShell({ children }: { children: ReactNode }) {
  const t = useTranslations("org.guard");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";
  const { status: authStatus, user: fbUser, signOut } = useAuth();

  const onSignOut = async () => {
    await signOut();
    window.location.href = `${prefix}/`;
  };

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
          (me.role as unknown) === UserRole.ORG_ADMIN ||
            (me.role as unknown) === "USER_ROLE_ORG_ADMIN"
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
    return (
      <div className="min-h-screen bg-evergreen flex items-center justify-center">
        <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70">
          {t("loading")}
        </p>
      </div>
    );
  }

  if (status === "signed-out") {
    return (
      <div className="min-h-screen bg-evergreen flex items-center justify-center px-4">
        <div className="text-center max-w-sm">
          <p className="font-serif text-frost">{t("signinRequired")}</p>
          <a
            href={`${prefix}/login?next=${encodeURIComponent(`${prefix}/org`)}`}
            className="mt-4 inline-flex rounded-button bg-ember text-obsidian px-5 py-2.5 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-ember/90 transition"
          >
            {t("signinCta")}
          </a>
        </div>
      </div>
    );
  }

  if (status === "forbidden") {
    return (
      <div className="min-h-screen bg-evergreen flex items-center justify-center px-4">
        <div className="text-center max-w-sm">
          <h1 className="font-display text-frost text-xl font-semibold">
            {t("forbiddenTitle")}
          </h1>
          <p className="font-serif text-mist mt-2 text-sm">{t("forbiddenBody")}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-evergreen">
      <header className="border-b border-frost/10 px-4 sm:px-6 lg:px-8 py-4 flex items-center justify-between">
        <span className="font-display text-frost font-semibold tracking-[var(--tracking-display)]">
          Superwizor AI · {t("panelName")}
        </span>
        <div className="flex items-center gap-4">
          <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist hidden sm:inline">
            {user?.email}
          </span>
          <button
            type="button"
            onClick={onSignOut}
            className="rounded-button border border-frost/20 px-3 py-1.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/40 transition cursor-pointer"
          >
            {t("signOut")}
          </button>
        </div>
      </header>
      {children}
    </div>
  );
}
