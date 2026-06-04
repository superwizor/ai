// Tiny bottom-right corner indicator showing the current Firebase auth
// state. Useful for smoke / evaluator evidence — at a glance you can
// tell whether the SDK initialised, whether the emulator is wired, and
// whether the bearer-token interceptor would attach a token if a Connect
// call fired right now.
//
// Hidden in production by default. Set NEXT_PUBLIC_SHOW_AUTH_BADGE=1 to
// keep it visible (e.g. on a staging preview deploy).

"use client";

import { useAuth } from "./auth-provider";
import { shouldUseAuthEmulator } from "./config";

export function AuthStatusBadge() {
  const { status, user } = useAuth();
  const emu = shouldUseAuthEmulator();

  if (process.env.NODE_ENV === "production" && process.env.NEXT_PUBLIC_SHOW_AUTH_BADGE !== "1") {
    return null;
  }

  const label =
    status === "loading"
      ? "auth: loading…"
      : status === "signed-in"
      ? `auth: ${user?.email ?? user?.uid ?? "signed-in"}`
      : "auth: anonymous";

  return (
    <div
      data-testid="auth-status-badge"
      className="fixed bottom-3 right-3 z-50 select-none rounded-button bg-black/40 backdrop-blur px-3 py-1 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist border border-glass-border/60"
    >
      <span className={status === "signed-in" ? "text-ember" : "text-mist/80"}>
        {label}
      </span>
      {emu && <span className="ml-2 text-aurora">· emu</span>}
    </div>
  );
}
