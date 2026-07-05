// Shared modal dialog for admin actions (block / reset tokens /
// change plan / etc.). Renders a centred glass-styled card with:
//   - title + body copy
//   - the action-specific form body (children prop)
//   - reason textarea (always required, validated ≥ 10 chars)
//   - cancel + confirm buttons
//
// Backend RPCs (AdminSetOrganizationStatus / AdminResetTokens /
// AdminChangePlan) all require reason >= 10 chars — capture once
// here so individual action handlers don't repeat the validation.

"use client";

import { useState, type ReactNode } from "react";
import { useTranslations } from "next-intl";

export type ActionResult = "success" | { error: string };

export function ActionDialog({
  open,
  title,
  body,
  children,
  confirmDisabled,
  onClose,
  onConfirm,
}: {
  open: boolean;
  title: string;
  body: string;
  children?: ReactNode;
  /** Caller can set this to true to block the confirm button while
   * other form fields are invalid (the reason field is validated
   * here, but the action-specific fields may need their own
   * validation upstream). */
  confirmDisabled?: boolean;
  onClose: () => void;
  /** Resolves to "success" on success (dialog closes); resolves to
   * {error} to surface a per-action error message inline. */
  onConfirm: (reason: string) => Promise<ActionResult>;
}) {
  const t = useTranslations("admin.actions");
  const [reason, setReason] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!open) return null;

  const reasonValid = reason.trim().length >= 10;

  const handleConfirm = async () => {
    setError(null);
    if (!reasonValid) {
      setError(t("reasonTooShort"));
      return;
    }
    setSubmitting(true);
    try {
      const result = await onConfirm(reason.trim());
      if (result === "success") {
        setReason("");
        onClose();
      } else {
        setError(result.error);
      }
    } catch {
      setError(t("errorGeneric"));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm px-4"
      onClick={(e) => {
        if (e.target === e.currentTarget && !submitting) onClose();
      }}
    >
      <div className="w-full max-w-md rounded-glass border border-glass-border/60 bg-evergreen px-6 py-6 shadow-[var(--shadow-large)]">
        <h2 className="font-display text-frost text-xl font-semibold tracking-[var(--tracking-display)]">
          {title}
        </h2>
        <p className="font-serif text-mist text-sm mt-2 leading-relaxed">
          {body}
        </p>

        {children && <div className="mt-5 grid gap-4">{children}</div>}

        <div className="mt-5">
          <label
            htmlFor="action-reason"
            className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist block mb-2"
          >
            {t("reasonLabel")}
            <span aria-hidden className="text-ember ml-1">*</span>
          </label>
          <textarea
            id="action-reason"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder={t("reasonPlaceholder")}
            rows={3}
            className="w-full rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2.5 font-serif text-sm focus:outline-none focus:border-ember placeholder:text-mist/60 transition resize-vertical"
          />
        </div>

        {error && (
          <p
            role="alert"
            className="mt-3 rounded-button border border-magma/40 bg-magma/10 px-3 py-2 font-serif text-xs text-frost"
          >
            {error}
          </p>
        )}

        <div className="mt-6 flex justify-end gap-3">
          <button
            type="button"
            onClick={onClose}
            disabled={submitting}
            className="rounded-button border border-frost/15 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition disabled:opacity-50"
          >
            {t("cancel")}
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            disabled={submitting || !!confirmDisabled || !reasonValid}
            className="rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-xs px-4 py-2 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {submitting ? t("submitting") : t("confirm")}
          </button>
        </div>
      </div>
    </div>
  );
}
