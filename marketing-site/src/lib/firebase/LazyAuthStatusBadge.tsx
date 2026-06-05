// Lazy-loaded AuthStatusBadge wrapper to prevent Firebase Auth SDK
// from leaking into the layout chunk.

"use client";

import dynamic from "next/dynamic";

const AuthStatusBadge = dynamic(
  () => import("./AuthStatusBadge").then((mod) => mod.AuthStatusBadge),
  {
    ssr: false,
    loading: () => null,
  }
);

export function LazyAuthStatusBadge() {
  // In production the badge returns null anyway — skip the entire
  // dynamic import (and the Firebase SDK chunk it pulls in).
  if (process.env.NODE_ENV === "production" && process.env.NEXT_PUBLIC_SHOW_AUTH_BADGE !== "1") {
    return null;
  }
  return <AuthStatusBadge />;
}
