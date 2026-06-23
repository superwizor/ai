// Lazy-loaded AuthProvider wrapper.
//
// The full Firebase Auth SDK (~90 KB) + the Auth iframe it spawns are
// heavy resources that block LCP on pages that don't need auth (landing
// page, legal, pricing). This wrapper uses next/dynamic to code-split
// the AuthProvider + Firebase SDK into a separate chunk that's only
// loaded when the component mounts on the client.
//
// To avoid loading the Firebase Auth SDK on public pages (which mounts
// them immediately upon client hydration due to root layout nesting),
// this component conditionally bypasses AuthProvider on public pages
// (landing page, pricing, and legal).

"use client";

import dynamic from "next/dynamic";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";

const AuthProvider = dynamic(
  () =>
    import("./auth-provider").then((mod) => mod.AuthProvider),
  {
    ssr: false,
    loading: () => null,
  },
);

export function LazyAuthProvider({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  
  // Normalize path by removing locale prefix (e.g. /pl/pricing -> /pricing)
  const cleanPath = pathname ? pathname.replace(/^\/(pl|en)(\/|$)/, "/") : "/";
  
  const isPublicRoute = 
    cleanPath === "/" ||
    cleanPath === "/pricing" ||
    cleanPath === "/o-nas" ||
    cleanPath === "/kontakt" ||
    cleanPath === "/pacjent" ||
    cleanPath === "/beta" ||
    cleanPath.startsWith("/legal") ||
    cleanPath === "/legal";

  if (isPublicRoute) {
    return <>{children}</>;
  }

  return <AuthProvider>{children}</AuthProvider>;
}
