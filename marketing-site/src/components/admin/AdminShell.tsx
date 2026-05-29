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
import { useAuth } from "@/lib/firebase/auth-provider";
import type { User } from "@superwizor/proto-ts/identity/v1/identity_pb";

type SidebarItem = { key: "dashboard" | "orgs" | "users" | "sessions" | "audit"; href: string };

export function AdminShell({
  user,
  children,
}: {
  user: User;
  children: React.ReactNode;
}) {
  const t = useTranslations("admin");
  const tSide = useTranslations("admin.sidebar");
  const tHeader = useTranslations("admin.header");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";
  const pathname = usePathname() ?? "";

  const items: SidebarItem[] = [
    { key: "dashboard", href: `${prefix}/admin` },
    { key: "orgs",      href: `${prefix}/admin/orgs` },
    { key: "users",     href: `${prefix}/admin/users` },
    { key: "sessions",  href: `${prefix}/admin/sessions` },
    { key: "audit",     href: `${prefix}/admin/audit` },
  ];

  const onSignOut = async () => {
    await auth.signOut();
    window.location.href = `${prefix}/`;
  };

  return (
    <div className="flex flex-1">
      <aside className="hidden md:flex w-60 flex-col border-r border-frost/10 bg-evergreen/40 px-4 py-6 gap-1">
        <a
          href={`${prefix}/admin`}
          className="font-display text-frost font-semibold text-sm mb-6 px-2"
        >
          Superwizor <span className="text-ember">admin</span>
        </a>
        <nav className="flex flex-col gap-1">
          {items.map((item) => {
            const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
            return (
              <a
                key={item.key}
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={`rounded-button px-3 py-2 font-display text-sm transition ${
                  active
                    ? "bg-ember/15 text-frost"
                    : "text-mist hover:bg-frost/5 hover:text-frost"
                }`}
              >
                {tSide(item.key)}
              </a>
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
