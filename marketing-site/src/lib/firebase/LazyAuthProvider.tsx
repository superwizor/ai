// Lazy-loaded AuthProvider wrapper.
//
// The full Firebase Auth SDK (~90 KB) + the Auth iframe it spawns are
// heavy resources that block LCP on pages that don't need auth (landing
// page, legal, pricing). This wrapper uses next/dynamic to code-split
// the AuthProvider + Firebase SDK into a separate chunk that's only
// loaded when the component mounts on the client.
//
// Usage in layout.tsx: replace the direct <AuthProvider> import with
// <LazyAuthProvider>.

"use client";

import dynamic from "next/dynamic";
import type { ReactNode } from "react";

const AuthProvider = dynamic(
  () =>
    import("./auth-provider").then((mod) => mod.AuthProvider),
  {
    ssr: false,
    // While the auth chunk loads, render children immediately —
    // no loading spinner, no layout shift, pages just render
    // without auth context until the provider mounts.
    loading: () => null,
  },
);

/**
 * Lazy-loaded auth wrapper. Children render immediately while
 * Firebase Auth SDK loads asynchronously in the background.
 * Pages that don't use auth (landing, pricing, legal) never
 * trigger the Firebase SDK download at all — the dynamic import
 * only fires when the component is in the viewport/rendered.
 *
 * Note: `useAuth()` will throw during the brief window before
 * the provider mounts. Components that call `useAuth` should
 * either be inside an auth-gated route or handle the missing
 * context gracefully (e.g. with optional chaining on the hook).
 */
export function LazyAuthProvider({ children }: { children: ReactNode }) {
  return <AuthProvider>{children}</AuthProvider>;
}
