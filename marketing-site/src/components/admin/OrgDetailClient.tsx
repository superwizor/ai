// Thin client wrapper that pulls the org id from the URL pathname
// and hands it to OrgDetail. Exists because the static-export build
// emits one `[id]/index.html` template and Firebase Hosting rewrites
// every /admin/orgs/<real-id> path to it — useParams() would return
// the literal string "[id]" since the template lives at that exact
// path. usePathname() gives us the URL the user actually requested,
// from which we extract the segment after /admin/orgs/.

"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";

import { OrgDetail } from "./OrgDetail";

export function OrgDetailClient() {
  const pathname = usePathname();
  const [orgId, setOrgId] = useState<string | null>(null);

  useEffect(() => {
    // Pathname shapes:
    //   /admin/orgs/<id>/        ← PL (default locale)
    //   /en/admin/orgs/<id>/     ← EN
    //   /admin/orgs/[id]/        ← the literal placeholder during SSR
    //                             dev; ignored at runtime
    if (!pathname) return;
    const match = pathname.match(/\/admin\/orgs\/([^/]+)\/?$/);
    if (!match || match[1] === "[id]") {
      setOrgId(null);
      return;
    }
    // URL-decode in case the id contains percent-encoded chars
    // (UUIDs are hex+hyphen so unaffected, but defensive).
    try {
      setOrgId(decodeURIComponent(match[1]));
    } catch {
      setOrgId(match[1]);
    }
  }, [pathname]);

  if (!orgId) {
    return (
      <p className="px-4 sm:px-6 lg:px-8 py-12 font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70 text-center">
        Loading…
      </p>
    );
  }

  return <OrgDetail orgId={orgId} />;
}
