// /admin — Dashboard / landing for the admin console.
//
// Slice 4 feature 1 + 2 wire just the chrome + a placeholder home.
// Real dashboard widgets (orgs count, usage chart, recent audit
// events) land alongside features 3-8 once the underlying tables +
// queries are reachable.

"use client";

import { useTranslations, useLocale } from "next-intl";
import { useAuth } from "@/lib/firebase/auth-provider";

export default function AdminHome() {
  const t = useTranslations("admin.home");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";

  // The guard already validated SUPERWIZOR_ADMIN; auth.user is the
  // Firebase user object, which carries displayName when present.
  const firstName =
    (auth.user?.displayName?.split(" ")[0]) || auth.user?.email?.split("@")[0] || "";

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8">
      <p className="font-mono text-[10px] uppercase text-ember tracking-[var(--tracking-overline)] mb-2">
        {t("overline")}
      </p>
      <h1 className="font-display text-frost text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)]">
        {t("title", { firstName })}
      </h1>
      <p className="font-serif text-mist mt-3 max-w-xl">{t("subhead")}</p>

      <div className="mt-10 grid grid-cols-1 md:grid-cols-3 gap-4 sm:gap-6 max-w-5xl">
        <Card
          title={t("cardOrgs")}
          body={t("cardOrgsBody")}
          href={`${prefix}/admin/orgs`}
        />
        <Card
          title={t("cardUsers")}
          body={t("cardUsersBody")}
          href={`${prefix}/admin/users`}
        />
        <Card
          title={t("cardAudit")}
          body={t("cardAuditBody")}
          href={`${prefix}/admin/audit`}
        />
      </div>
    </div>
  );
}

function Card({ title, body, href }: { title: string; body: string; href: string }) {
  return (
    <a
      href={href}
      className="block rounded-card border border-frost/10 bg-frost/[0.04] p-5 hover:border-ember/40 hover:bg-frost/[0.06] transition"
    >
      <h3 className="font-display text-frost text-lg font-semibold">{title}</h3>
      <p className="font-serif text-mist text-sm mt-2 leading-relaxed">{body}</p>
    </a>
  );
}
