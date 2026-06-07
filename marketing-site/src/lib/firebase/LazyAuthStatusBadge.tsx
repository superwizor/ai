// Lazy-loaded AuthStatusBadge wrapper to prevent Firebase Auth SDK
// from leaking into the layout chunk.

"use client";

import dynamic from "next/dynamic";
import { usePathname } from "next/navigation";

const AuthStatusBadge = dynamic(
  () => import("./AuthStatusBadge").then((mod) => mod.AuthStatusBadge),
  {
    ssr: false,
    loading: () => null,
  }
);

export function LazyAuthStatusBadge() {
  const pathname = usePathname();

  // In production the badge returns null anyway — skip the entire
  // dynamic import (and the Firebase SDK chunk it pulls in).
  if (process.env.NODE_ENV === "production" && process.env.NEXT_PUBLIC_SHOW_AUTH_BADGE !== "1") {
    return null;
  }

  // Also skip rendering on public routes where there is no AuthProvider
  const cleanPath = pathname ? pathname.replace(/^\/(pl|en)(\/|$)/, "/") : "/";
  const isPublicRoute = 
    cleanPath === "/" ||
    cleanPath === "/pricing" ||
    cleanPath.startsWith("/legal") ||
    cleanPath === "/legal";

  if (isPublicRoute) {
    return null;
  }

  return <AuthStatusBadge />;
}
