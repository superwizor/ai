// Admin chrome (sidebar + header) shared by every /admin/* page.
//
// Renders inside <AdminGuard> so by the time this component mounts we
// know the user is SUPERWIZOR_ADMIN and we have their profile.
//
// Sidebar lives on the left (collapses on mobile to a top bar — that
// polish lands in Slice 6 i18n-polish-launch). Header carries the
// brand mark + user identity + sign-out button.

"use client";

import { useTranslations, useLocale } from "next-intl";
import { usePathname } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/lib/firebase/auth-provider";
import type { User } from "@superwizor/proto-ts/identity/v1/identity_pb";

type SidebarItem = { key: "dashboard" | "orgs" | "users" | "sessions" | "audit" | "analytics" | "crm" | "prompts" | "ontologies" | "aiChat" | "discountCodes" | "stripeTest"; href: string };

function getSidebarIcon(key: string, active: boolean) {
  const colorClass = active ? "text-ember" : "text-mist group-hover:text-frost transition-colors";
  switch (key) {
    case "dashboard":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
        </svg>
      );
    case "aiChat":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.86 9.86 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
        </svg>
      );
    case "orgs":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
        </svg>
      );
    case "users":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
        </svg>
      );
    case "sessions":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
        </svg>
      );
    case "audit":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
        </svg>
      );
    case "analytics":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
        </svg>
      );
    case "crm":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
        </svg>
      );
    case "prompts":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
        </svg>
      );
    case "discountCodes":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5a1.99 1.99 0 011.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.99 1.99 0 013 12V7a4 4 0 014-4z" />
        </svg>
      );
    case "stripeTest":
      return (
        <svg className={`w-5 h-5 ${colorClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
        </svg>
      );
    default:
      return null;
  }
}

export function AdminShell({
  user,
  children,
}: {
  user: User;
  children: React.ReactNode;
}) {
  const tSide = useTranslations("admin.sidebar");
  const tHeader = useTranslations("admin.header");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";
  const pathname = usePathname() ?? "";

  const items: SidebarItem[] = [
    { key: "dashboard",  href: `${prefix}/admin` },
    { key: "orgs",       href: `${prefix}/admin/orgs` },
    { key: "users",      href: `${prefix}/admin/users` },
    { key: "sessions",   href: `${prefix}/admin/sessions` },
    { key: "audit",      href: `${prefix}/admin/audit` },
    { key: "analytics",  href: `${prefix}/admin/analytics` },
    { key: "crm",        href: `${prefix}/admin/crm` },
    { key: "prompts",    href: `${prefix}/admin/prompts` },
    { key: "ontologies", href: `${prefix}/admin/ontologies` },
    { key: "aiChat",     href: `${prefix}/admin/ai-chat` },
    { key: "discountCodes", href: `${prefix}/admin/discount-codes` },
    { key: "stripeTest", href: `${prefix}/admin/stripe-test` },
  ];

  const onSignOut = async () => {
    await auth.signOut();
    window.location.href = `${prefix}/`;
  };

  return (
    <div className="flex flex-1">
      <aside className="hidden md:flex w-60 flex-col border-r border-frost/10 bg-evergreen/40 px-4 py-6 gap-1">
        <Link
          href={`${prefix}/admin`}
          className="font-display text-frost font-semibold text-sm mb-6 px-2"
        >
          Superwizor <span className="text-ember">admin</span>
        </Link>
        <nav className="flex flex-col gap-1.5">
          {items.map((item) => {
            const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
            return (
              <Link
                key={item.key}
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={`group flex items-center gap-3 rounded-button px-3.5 py-2.5 font-display text-sm font-medium transition-all duration-200 border border-transparent ${
                  active
                    ? "bg-gradient-to-r from-ember/15 to-ember/5 text-frost border-l-2 border-l-ember shadow-[0_2px_10px_rgba(245,166,35,0.05)]"
                    : "text-mist hover:bg-frost/[0.04] hover:text-frost hover:translate-x-1 hover:border-frost/5"
                }`}
              >
                {getSidebarIcon(item.key, active)}
                <span>{tSide(item.key)}</span>
              </Link>
            );
          })}
        </nav>
      </aside>

      <div className="flex flex-col flex-1 min-w-0">
        <header className="flex items-center justify-between border-b border-frost/10 px-4 sm:px-6 py-3">
          <div className="md:hidden font-display text-frost font-semibold text-sm">
            Superwizor <span className="text-ember">admin</span>
          </div>
          <div className="flex-1" />
          <div className="flex items-center gap-3">
            <div className="text-right">
              <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70">
                {tHeader("signedInAs")}
              </p>
              <p className="font-display text-frost text-sm">{user.email}</p>
            </div>
            <button
              onClick={onSignOut}
              className="rounded-button border border-frost/15 px-3 py-1.5 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition"
            >
              {tHeader("signOut")}
            </button>
          </div>
        </header>

        <main className="flex-1 min-h-0">{children}</main>
      </div>
    </div>
  );
}
