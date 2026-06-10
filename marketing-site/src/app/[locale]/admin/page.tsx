"use client";

import { useTranslations, useLocale } from "next-intl";
import { useAuth } from "@/lib/firebase/auth-provider";

export default function AdminHome() {
  const t = useTranslations("admin.home");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";

  const firstName =
    (auth.user?.displayName?.split(" ")[0]) || auth.user?.email?.split("@")[0] || "";

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-10 max-w-6xl mx-auto">
      {/* Welcome Banner */}
      <div className="relative overflow-hidden rounded-2xl border border-frost/10 bg-gradient-to-br from-evergreen/10 via-surface-teal/5 to-transparent p-6 sm:p-10 mb-8 shadow-xl">
        <div className="absolute top-0 right-0 -mt-16 -mr-16 w-80 h-80 rounded-full bg-ember/5 blur-3xl pointer-events-none" />
        <div className="absolute bottom-0 left-0 -mb-16 -ml-16 w-80 h-80 rounded-full bg-aurora/5 blur-3xl pointer-events-none" />

        <p className="font-mono text-xs uppercase text-ember tracking-[0.2em] mb-2.5">
          {t("overline")}
        </p>
        <h1 className="font-display text-frost text-3xl sm:text-5xl font-semibold tracking-tight leading-none">
          {t("title", { firstName })}
        </h1>
        <p className="font-sans text-mist/85 mt-4 max-w-xl text-sm sm:text-base leading-relaxed">
          {t("subhead")}
        </p>
      </div>

      {/* Grid of Section Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card
          title={t("cardOrgs")}
          body={t("cardOrgsBody")}
          href={`${prefix}/admin/orgs`}
          icon={<BuildingIcon />}
          hoverGlow="hover:border-ember/30 hover:shadow-[0_0_30px_rgba(252,174,47,0.08)]"
          ctaText={t("cardOrgsCta")}
        />
        <Card
          title={t("cardAnalytics")}
          body={t("cardAnalyticsBody")}
          href={`${prefix}/admin/analytics`}
          icon={<ChartIcon />}
          hoverGlow="hover:border-ember/30 hover:shadow-[0_0_30px_rgba(252,174,47,0.08)]"
          ctaText={t("cardAnalyticsCta")}
        />
        <Card
          title={t("cardUsers")}
          body={t("cardUsersBody")}
          href={`${prefix}/admin/users`}
          icon={<UsersIcon />}
          hoverGlow="hover:border-aurora/30 hover:shadow-[0_0_30px_rgba(103,89,255,0.08)]"
          ctaText={t("cardUsersCta")}
        />
        <Card
          title={t("cardCrm")}
          body={t("cardCrmBody")}
          href={`${prefix}/admin/crm`}
          icon={<HeartIcon />}
          hoverGlow="hover:border-magma/30 hover:shadow-[0_0_30px_rgba(255,59,48,0.08)]"
          ctaText={t("cardCrmCta")}
        />
        <Card
          title={t("cardAudit")}
          body={t("cardAuditBody")}
          href={`${prefix}/admin/audit`}
          icon={<ShieldIcon />}
          hoverGlow="hover:border-mist/30 hover:shadow-[0_0_30px_rgba(178,202,204,0.08)]"
          ctaText={t("cardAuditCta")}
        />
      </div>
    </div>
  );
}

function Card({
  title,
  body,
  href,
  icon,
  hoverGlow,
  ctaText,
}: {
  title: string;
  body: string;
  href: string;
  icon: React.ReactNode;
  hoverGlow: string;
  ctaText: string;
}) {
  return (
    <a
      href={href}
      className={`group flex flex-col justify-between rounded-2xl border border-frost/10 bg-frost/[0.02] p-6 backdrop-blur-sm transition-all duration-300 hover:scale-[1.01] hover:bg-frost/[0.04] ${hoverGlow}`}
    >
      <div className="flex items-start gap-4 mb-4">
        <div className="flex-shrink-0 p-3 rounded-xl bg-frost/[0.04] border border-frost/10 group-hover:border-frost/20 transition-all duration-300">
          {icon}
        </div>
        <div className="flex-1 min-w-0">
          <h3 className="font-display text-frost text-lg font-semibold tracking-tight group-hover:text-frost transition-colors">
            {title}
          </h3>
          <p className="font-sans text-mist/75 text-sm mt-2 leading-relaxed">
            {body}
          </p>
        </div>
      </div>
      <div className="inline-flex items-center gap-1.5 self-start rounded-xl bg-frost/5 border border-frost/10 px-3.5 py-2 font-mono text-[10px] uppercase tracking-wider text-mist group-hover:bg-ember/15 group-hover:text-ember group-hover:border-ember/30 transition-all duration-300">
        <span>{ctaText}</span>
        <svg className="w-3.5 h-3.5 group-hover:translate-x-0.5 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
        </svg>
      </div>
    </a>
  );
}

// Inline SVGs for beautiful clean icons
function HeartIcon() {
  return (
    <svg className="w-6 h-6 text-magma" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
    </svg>
  );
}

function BuildingIcon() {
  return (
    <svg className="w-6 h-6 text-ember" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
    </svg>
  );
}

// Users icon: represents therapists, patient files, admins
function UsersIcon() {
  return (
    <svg className="w-6 h-6 text-aurora" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
    </svg>
  );
}

// Chart icon: represents usage, billing trends, AI Quality
function ChartIcon() {
  return (
    <svg className="w-6 h-6 text-ember" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
    </svg>
  );
}

// Shield icon: represents security audits and operational trail
function ShieldIcon() {
  return (
    <svg className="w-6 h-6 text-mist" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
    </svg>
  );
}
