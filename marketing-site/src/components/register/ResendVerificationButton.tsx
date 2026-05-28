// Tiny client island for "Resend verification email".
//
// Lives in feature 1's verify-email page. Feature 5
// (email-verification-gate) will extend this with the
// poll-for-verification + auto-redirect logic.

"use client";

import { useState } from "react";
import { sendEmailVerification } from "firebase/auth";
import { useTranslations } from "next-intl";
import { useAuth } from "@/lib/firebase/auth-provider";

export function ResendVerificationButton() {
  const t = useTranslations("register.verifyEmail");
  const { user } = useAuth();
  const [status, setStatus] = useState<"idle" | "sending" | "sent">("idle");

  const onClick = async () => {
    if (!user) return;
    setStatus("sending");
    try {
      await sendEmailVerification(user);
      setStatus("sent");
    } catch {
      setStatus("idle");
    }
  };

  return (
    <button
      onClick={onClick}
      disabled={!user || status === "sending"}
      className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-50 disabled:cursor-not-allowed"
    >
      {status === "sending"
        ? t("resending")
        : status === "sent"
        ? t("resent")
        : t("resend")}
    </button>
  );
}
