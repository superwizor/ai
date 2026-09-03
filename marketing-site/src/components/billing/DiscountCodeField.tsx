// Discount-code field for the public purchase surfaces (docs/70 §6.4).
//
// Until now the only place to type a code was the Stripe Checkout page,
// which meant the visitor committed to a plan before finding out whether
// their code was worth anything. This field moves the check forward:
// ValidateDiscountCode runs against every plan on screen, so the answer
// is "Równowaga 149 zł → 99 zł", not "we'll see at checkout".
//
// Validation is advisory, never a gate:
//   - the server re-validates when the Checkout session is created, and
//     Stripe is what actually enforces max_redemptions (D2);
//   - an anonymous visitor on /pricing has no Firebase token, so the RPC
//     answers Unauthenticated. That is NOT an error the visitor caused —
//     we keep the code, say so plainly, and hand it to checkout anyway.
//     Same for Unimplemented/Unavailable while the RPC is still rolling
//     out.

"use client";

import { useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { Code, ConnectError } from "@connectrpc/connect";

import type { DiscountCodeQuote } from "@superwizor/proto-ts/billing/v1/billing_pb";
import type { BillingCycle, PlanTier } from "@/lib/billing/plans";
import { usePlanName } from "@/lib/plans";

export type DiscountTarget = { tier: PlanTier; cycle: BillingCycle };

export type AppliedDiscount = {
  /** Normalised (upper-cased) code, ready to hand to /api/checkout. */
  code: string;
  /** Per-plan quotes, keyed by discountKey(tier, cycle). */
  quotes: Record<string, DiscountCodeQuote>;
  /** True when we could not reach the RPC — the code rides along unchecked. */
  unverified: boolean;
};

export const CODE_PATTERN = /^[A-Z0-9_]{3,32}$/;

export function discountKey(tier: string, cycle: string): string {
  return `${tier}_${cycle}`;
}

/** Is the applied code usable for this specific plan? */
export function discountAppliesTo(
  applied: AppliedDiscount | null,
  tier: string,
  cycle: string,
): boolean {
  if (!applied) return false;
  if (applied.unverified) return true;
  return applied.quotes[discountKey(tier, cycle)]?.valid === true;
}

type Phase =
  | { kind: "idle" }
  | { kind: "checking" }
  | { kind: "applied"; applied: AppliedDiscount }
  | { kind: "rejected"; message: string };

export function DiscountCodeField({
  targets,
  onChange,
  resetToken,
  tone = "light",
}: {
  /** Plans currently on screen; each gets its own quote. */
  targets: ReadonlyArray<DiscountTarget>;
  onChange: (applied: AppliedDiscount | null) => void;
  /**
   * Change this (e.g. to the selected billing cycle) whenever the quotes
   * on screen stop describing what the visitor is buying. The typed code
   * survives; the stale price preview does not. The parent is expected
   * to drop its own applied-discount state at the same moment — we can't
   * call onChange from render.
   */
  resetToken?: string | number;
  tone?: "light" | "dark";
}) {
  const t = useTranslations("billing.discount");
  const locale = useLocale();
  const planName = usePlanName();

  const [value, setValue] = useState("");
  const [phase, setPhase] = useState<Phase>({ kind: "idle" });

  // Derived-state-during-render: cheaper and flicker-free compared with
  // an effect, and React explicitly supports this shape.
  const [seenToken, setSeenToken] = useState(resetToken);
  if (resetToken !== seenToken) {
    setSeenToken(resetToken);
    if (phase.kind !== "idle") setPhase({ kind: "idle" });
  }

  const dark = tone === "dark";

  const reset = () => {
    setValue("");
    setPhase({ kind: "idle" });
    onChange(null);
  };

  const check = async () => {
    const code = value.trim().toUpperCase();
    if (!CODE_PATTERN.test(code)) {
      setPhase({ kind: "rejected", message: t("invalidFormat") });
      onChange(null);
      return;
    }

    setPhase({ kind: "checking" });
    try {
      // Klienta Connect i wygenerowane proto billingu ładujemy DOPIERO
      // przy kliknięciu "Sprawdź". /pricing jest stroną marketingową
      // dopieszczoną pod LCP (usunięto z niej nawet preconnecty), a
      // statyczny import wciągał tam cały transport RPC dla funkcji,
      // z której korzysta ułamek odwiedzających — i to nigdy przed
      // pierwszą interakcją.
      const [{ billingClient }, { ValidateDiscountCodeRequestSchema }, { create }] =
        await Promise.all([
          import("@/lib/connect/clients"),
          import("@superwizor/proto-ts/billing/v1/billing_pb"),
          import("@bufbuild/protobuf"),
        ]);

      const results = await Promise.all(
        targets.map(async (target) => {
          const quote = await billingClient.validateDiscountCode(
            create(ValidateDiscountCodeRequestSchema, {
              code,
              planTier: target.tier,
              planCycle: target.cycle,
              channel: "WEB",
            }),
          );
          return [discountKey(target.tier, target.cycle), quote] as const;
        }),
      );

      const quotes: Record<string, DiscountCodeQuote> = {};
      for (const [key, quote] of results) quotes[key] = quote;

      const anyValid = results.some(([, q]) => q.valid);
      if (!anyValid) {
        // Every plan bounced. Prefer a reason that isn't plan-specific:
        // "code expired" tells the visitor more than "not for this plan"
        // when both are true for different cards.
        // "OK" never accompanies valid:false in the contract, but a
        // rejection explained as "the code is valid" would be nonsense,
        // so it is filtered out rather than trusted.
        const reasons = results
          .map(([, q]) => q.reason)
          .filter((r) => r && r !== "OK");
        const primary =
          reasons.find((r) => r !== "PLAN_NOT_ELIGIBLE") ?? reasons[0] ?? "";
        setPhase({ kind: "rejected", message: reasonMessage(t, primary) });
        onChange(null);
        return;
      }

      const applied: AppliedDiscount = { code, quotes, unverified: false };
      setPhase({ kind: "applied", applied });
      onChange(applied);
    } catch (e) {
      if (isUnreachable(e)) {
        // Not the visitor's problem — carry the code to checkout, where
        // the server validates for real, and say what we did.
        const applied: AppliedDiscount = { code, quotes: {}, unverified: true };
        setPhase({ kind: "applied", applied });
        onChange(applied);
        return;
      }
      setPhase({ kind: "rejected", message: reasonMessage(t, "") });
      onChange(null);
    }
  };

  const applied = phase.kind === "applied" ? phase.applied : null;
  const validQuotes = applied
    ? targets
        .map((target) => applied.quotes[discountKey(target.tier, target.cycle)])
        .filter((q): q is DiscountCodeQuote => !!q && q.valid)
    : [];
  const headline = validQuotes[0];

  const labelClass = dark
    ? "font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist"
    : "font-mono text-[10px] uppercase tracking-wider text-[#4E5A55] font-semibold";
  const inputClass = dark
    ? "flex-1 min-w-0 rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2.5 font-mono text-sm tracking-widest uppercase focus:outline-none focus:border-ember transition placeholder:text-mist/50 placeholder:tracking-normal"
    : "flex-1 min-w-0 rounded-[5px] bg-white border border-[#E2DED5] text-[#1B2522] px-3.5 py-2.5 font-mono text-sm tracking-widest uppercase focus:outline-none focus:border-[#004D54] transition placeholder:text-[#4E5A55]/50 placeholder:tracking-normal";
  const buttonClass = dark
    ? "shrink-0 rounded-button bg-ember text-obsidian px-4 py-2.5 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:brightness-110 transition disabled:opacity-50 disabled:cursor-not-allowed"
    : "shrink-0 rounded-[5px] bg-[#004D54] text-white px-5 py-2.5 font-sans font-bold text-xs uppercase tracking-wider hover:bg-[#003A40] transition disabled:opacity-50 disabled:cursor-not-allowed";

  return (
    <div className="mx-auto w-full max-w-md">
      <label htmlFor="discount-code" className={`${labelClass} block mb-2`}>
        {t("label")}
      </label>
      <div className="flex items-stretch gap-2">
        <input
          id="discount-code"
          type="text"
          autoComplete="off"
          spellCheck={false}
          value={value}
          placeholder={t("placeholder")}
          onChange={(e) => {
            setValue(e.target.value.toUpperCase().replace(/\s+/g, ""));
            if (phase.kind !== "idle") {
              setPhase({ kind: "idle" });
              onChange(null);
            }
          }}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              void check();
            }
          }}
          className={inputClass}
        />
        <button
          type="button"
          onClick={() => void check()}
          disabled={phase.kind === "checking" || value.trim().length === 0}
          className={buttonClass}
        >
          {phase.kind === "checking" ? t("checking") : t("checkCta")}
        </button>
      </div>

      {phase.kind === "rejected" && (
        <p
          role="alert"
          className={`mt-2 font-sans text-[12px] ${dark ? "text-magma" : "text-[#B23A17]"}`}
        >
          {phase.message}
        </p>
      )}

      {applied && (
        <div
          role="status"
          className={`mt-3 rounded-[10px] border px-4 py-3 ${
            dark
              ? "border-ember/30 bg-ember/10"
              : "border-[#B2DFD8] bg-[#E6F2F0]"
          }`}
        >
          {applied.unverified ? (
            <p
              className={`font-sans text-[12px] leading-relaxed ${
                dark ? "text-frost" : "text-[#004D54]"
              }`}
            >
              {t("unverified")}
            </p>
          ) : (
            <>
              <p
                className={`font-sans text-[13px] font-bold ${
                  dark ? "text-frost" : "text-[#004D54]"
                }`}
              >
                {t("appliedTitle", { code: applied.code })}
              </p>
              {headline?.name && (
                <p
                  className={`font-sans text-[12px] mt-0.5 ${
                    dark ? "text-mist" : "text-[#4E5A55]"
                  }`}
                >
                  {t("campaign", { name: headline.name })}
                </p>
              )}
              <ul className="mt-2 space-y-1">
                {targets.map((target) => {
                  const quote =
                    applied.quotes[discountKey(target.tier, target.cycle)];
                  if (!quote?.valid) return null;
                  return (
                    <li
                      key={discountKey(target.tier, target.cycle)}
                      className={`font-sans text-[13px] ${
                        dark ? "text-frost" : "text-[#1B2522]"
                      }`}
                    >
                      {t("planLine", {
                        plan: planName(target.tier),
                        before: fmtMoney(locale, quote.priceBefore, quote.currencyCode),
                        after: fmtMoney(locale, quote.priceAfter, quote.currencyCode),
                      })}
                    </li>
                  );
                })}
              </ul>
              {headline && (
                <p
                  className={`font-sans text-[11px] mt-2 ${
                    dark ? "text-mist" : "text-[#4E5A55]"
                  }`}
                >
                  {durationNote(t, headline)}
                  {headline.redemptionsLeft > 0 && (
                    <> {t("redemptionsLeft", { count: headline.redemptionsLeft })}</>
                  )}
                </p>
              )}
            </>
          )}
          <button
            type="button"
            onClick={reset}
            className={`mt-2 font-mono text-[10px] uppercase tracking-wider underline ${
              dark ? "text-mist hover:text-frost" : "text-[#4E5A55] hover:text-[#1B2522]"
            }`}
          >
            {t("clearCta")}
          </button>
        </div>
      )}
    </div>
  );
}

/* ── helpers ─────────────────────────────────────────────────────── */

const KNOWN_REASONS = [
  "OK",
  "NOT_FOUND",
  "EXPIRED",
  "NOT_STARTED",
  "EXHAUSTED",
  "ALREADY_USED",
  "PLAN_NOT_ELIGIBLE",
  "CHANNEL_NOT_ELIGIBLE",
  "NEW_CUSTOMERS_ONLY",
  "INACTIVE",
] as const;

function reasonMessage(
  t: ReturnType<typeof useTranslations>,
  reason: string,
): string {
  const key = (KNOWN_REASONS as readonly string[]).includes(reason)
    ? reason
    : "UNKNOWN";
  return t(`reason.${key}`);
}

function durationNote(
  t: ReturnType<typeof useTranslations>,
  quote: DiscountCodeQuote,
): string {
  if (quote.duration === "ONCE") return t("durationOnce");
  if (quote.duration === "REPEATING") {
    return t("durationRepeating", { count: quote.durationPeriods });
  }
  return t("durationForever");
}

// "Unreachable" = the visitor did nothing wrong. Anonymous browsing on
// /pricing (Unauthenticated) is the common case; the other two cover the
// window where the RPC isn't deployed yet.
function isUnreachable(e: unknown): boolean {
  if (!(e instanceof ConnectError)) return false;
  return (
    e.code === Code.Unauthenticated ||
    e.code === Code.Unimplemented ||
    e.code === Code.Unavailable
  );
}

function fmtMoney(locale: string, raw: string, currency: string): string {
  const n = Number(raw);
  const tag = locale === "en" ? "en-GB" : "pl-PL";
  if (!Number.isFinite(n)) return raw || "—";
  try {
    return new Intl.NumberFormat(tag, {
      style: "currency",
      currency: currency || "PLN",
      maximumFractionDigits: 2,
    }).format(n);
  } catch {
    return `${n} ${currency || "PLN"}`;
  }
}
