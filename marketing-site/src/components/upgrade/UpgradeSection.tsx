// UpgradeSection — the core UI for /upgrade.
//
// Plan: "bez opcji free, krótki pitch + 2 plany (Równowaga + Rozkwit)"
// Design: short motivational pitch + two large cards + promo codes.
// No trial card — they already had their trial.
//
// Auth-aware: if user is logged in, CTA calls /api/checkout directly
// with their organizationId. If not logged in, falls back to registration.

"use client";

import { useState, useCallback } from "react";
import { useTranslations } from "next-intl";
import { useSearchParams } from "next/navigation";
import { getAuth } from "firebase/auth";
import type { BillingCycle, PlanRow } from "@/lib/billing/plans";
import { findPlan, formatPrice } from "@/lib/billing/plans";
import {
  DiscountCodeField,
  discountAppliesTo,
  type AppliedDiscount,
} from "@/components/billing/DiscountCodeField";
import { identityClient, billingClient } from "@/lib/connect/clients";
import { GetSubscriptionRequestSchema } from "@superwizor/proto-ts/billing/v1/billing_pb";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { useEffect } from "react";

export function UpgradeSection({
  catalog,
  locale,
}: {
  catalog: ReadonlyArray<PlanRow>;
  locale: string;
}) {
  const [cycle, setCycle] = useState<BillingCycle>("MONTHLY");
  const [currentPlanTier, setCurrentPlanTier] = useState<string | undefined>(undefined);
  const prefix = locale === "en" ? "/en" : "";
  const isAnnual = cycle === "ANNUAL";

  // Validated code overrides the plan's own coupon when it covers that
  // plan; otherwise the existing auto-coupon behaviour stands.
  const [discount, setDiscount] = useState<AppliedDiscount | null>(null);
  const selectCycle = (next: BillingCycle) => {
    setCycle(next);
    setDiscount(null);
  };

  useEffect(() => {
    const fetchCurrentPlan = async () => {
      try {
        const auth = getAuth();
        const user = auth.currentUser;
        if (!user) return;

        const token = await user.getIdToken();
        const ctx = await identityClient.validateToken({ firebaseIdToken: token });
        if (ctx.organizationId) {
          const s = await billingClient.getSubscription(
            create(GetSubscriptionRequestSchema, { organizationId: ctx.organizationId }),
          );
          if (s && s.planTier) {
            setCurrentPlanTier(s.planTier.toUpperCase());
          }
        }
      } catch (err) {
        console.warn("[UpgradeSection] Failed to fetch current subscription tier for UI:", err);
      }
    };
    fetchCurrentPlan();
  }, []);

  const solo = findPlan(catalog, "SOLO", cycle);
  const pro = findPlan(catalog, "PRO", cycle);

  return (
    <section className="relative overflow-hidden bg-gradient-to-b from-[#F8F6F1] to-[#ECE8DF] pt-28 pb-20 sm:pt-36 sm:pb-28">
      {/* Decorative background elements */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[900px] h-[900px] bg-[radial-gradient(ellipse_at_center,_rgba(0,77,84,0.04)_0%,_transparent_70%)] pointer-events-none" />

      <div className="relative mx-auto max-w-3xl px-5">
        {/* --- Pitch --- */}
        <div className="text-center mb-14">
          <span className="inline-flex items-center gap-2 px-3.5 py-1.5 mb-5 rounded-full bg-[#004D54]/10 text-[#004D54] text-[11px] font-mono uppercase tracking-wider font-bold">
            <span className="w-1.5 h-1.5 rounded-full bg-[#004D54] animate-pulse" />
            {locale === "en"
              ? "Continue your practice"
              : "Kontynuuj swoją praktykę"}
          </span>

          <h1 className="font-serif text-3xl sm:text-4xl font-bold text-[#1B2522] leading-tight mb-4">
            {locale === "en"
              ? "Choose the plan that\nfits your practice."
              : "Wybierz plan dopasowany\ndo Twojej praktyki."}
          </h1>

          <p className="font-sans text-base sm:text-lg text-[#4E5A55] leading-relaxed max-w-xl mx-auto">
            {locale === "en"
              ? "Choose the plan that fits your practice. All your sessions, reports, and client files stay exactly where you left them."
              : "Wybierz plan dopasowany do Twojej praktyki. Wszystkie Twoje sesje, raporty i kartoteki czekają na Ciebie dokładnie tam, gdzie je zostawiłeś."}
          </p>
        </div>

        {/* --- Cycle Toggle --- */}
        <div className="flex flex-col items-center mb-10">
          <div
            role="tablist"
            aria-label="billing cycle"
            className="relative inline-flex items-center rounded-full bg-[#F2F0EA] border border-[#E2DED5] p-1"
          >
            <div
              className={`absolute top-1 bottom-1 w-[calc(50%-4px)] rounded-full bg-[#004D54] shadow-lg transition-all duration-300 ease-out ${
                isAnnual ? "left-[calc(50%+2px)]" : "left-1"
              }`}
            />
            <button
              role="tab"
              aria-selected={!isAnnual}
              onClick={() => selectCycle("MONTHLY")}
              className={`relative z-10 w-[130px] sm:w-[150px] py-2.5 rounded-full font-sans font-bold text-xs sm:text-sm uppercase tracking-wider transition-colors duration-300 cursor-pointer text-center ${
                !isAnnual
                  ? "text-white"
                  : "text-[#4E5A55] hover:text-[#1B2522]"
              }`}
            >
              {locale === "en" ? "Monthly" : "Miesięcznie"}
            </button>
            <button
              role="tab"
              aria-selected={isAnnual}
              onClick={() => selectCycle("ANNUAL")}
              className={`relative z-10 w-[130px] sm:w-[150px] py-2.5 rounded-full font-sans font-bold text-xs sm:text-sm uppercase tracking-wider transition-colors duration-300 cursor-pointer text-center ${
                isAnnual
                  ? "text-white"
                  : "text-[#4E5A55] hover:text-[#1B2522]"
              }`}
            >
              {locale === "en" ? "Annually" : "Rocznie"}
            </button>
          </div>
          {isAnnual && (
            <span className="mt-2 inline-flex items-center gap-1.5 text-[#004D54] font-sans text-[11px] uppercase tracking-wider font-bold">
              <span className="w-1.5 h-1.5 rounded-full bg-[#004D54] animate-pulse" />
              {locale === "en"
                ? "Annual billing — 17% off"
                : "Rozliczenie roczne — 17% taniej"}
            </span>
          )}
        </div>

        {/* --- Discount code (docs/70 §6.4) --- */}
        <div className="mb-10">
          <DiscountCodeField
            targets={[
              { tier: "SOLO", cycle },
              { tier: "PRO", cycle },
            ]}
            resetToken={cycle}
            onChange={setDiscount}
          />
        </div>

        {/* --- Two Plan Cards --- */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
          {solo && (
            <UpgradeCard
              tier="solo"
              tierName={locale === "en" ? "Balance" : "Równowaga"}
              row={solo}
              cycle={cycle}
              locale={locale}
              prefix={prefix}
              isHero={false}
              currentPlanTier={currentPlanTier}
              discount={discount}
            />
          )}
          {pro && (
            <UpgradeCard
              tier="pro"
              tierName={locale === "en" ? "Growth" : "Rozkwit"}
              row={pro}
              cycle={cycle}
              locale={locale}
              prefix={prefix}
              isHero={true}
              currentPlanTier={currentPlanTier}
              discount={discount}
            />
          )}
        </div>

        {/* --- Footnote --- */}
        <div className="mt-8 text-center">
          <p className="font-mono text-[10px] uppercase tracking-wider text-[#4E5A55]">
            {locale === "en"
              ? "Prices incl. 23% VAT · Secure payment via Stripe · Cancel anytime"
              : "Ceny zawierają VAT · Bezpieczna płatność przez Stripe · Anuluj w dowolnym momencie"}
          </p>
        </div>
      </div>
    </section>
  );
}

/* ─── Plan Card ──────────────────────────────────────────────── */

function UpgradeCard({
  tier,
  tierName,
  row,
  cycle,
  locale,
  prefix,
  isHero,
  currentPlanTier,
  discount,
}: {
  tier: string;
  tierName: string;
  row: PlanRow;
  cycle: BillingCycle;
  locale: string;
  prefix: string;
  isHero: boolean;
  currentPlanTier?: string;
  discount: AppliedDiscount | null;
}) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const tCheckout = useTranslations("billing.checkout");
  const searchParams = useSearchParams();
  // When user arrives from /account → ?from=account, we pass returnUrl
  // to the checkout API so Stripe redirects back to /account after payment.
  const fromAccount = searchParams.get("from") === "account";
  const returnUrl = fromAccount ? `${prefix}/account` : undefined;

  const monthlyPrice =
    cycle === "ANNUAL" ? Math.round(row.priceGross / 12) : row.priceGross;
  const introMonthlyPrice = row.priceIntroGross
    ? cycle === "ANNUAL"
      ? Math.round(row.priceIntroGross / 12)
      : row.priceIntroGross
    : null;
  const sessionsLabel =
    locale === "en"
      ? `${row.tokensPerPeriod} sessions/${cycle === "ANNUAL" ? "year" : "month"}`
      : `${row.tokensPerPeriod} sesji/${cycle === "ANNUAL" ? "rok" : "mies."}`;

  const features =
    tier === "solo"
      ? locale === "en"
        ? [
            "30 AI-analyzed sessions/month",
            "Full reports + HiTOP",
            "Unlimited client files",
            "Encrypted local recording",
          ]
        : [
            "30 sesji z analizą AI/mies.",
            "Pełne raporty + HiTOP",
            "Nieograniczone kartoteki",
            "Szyfrowane nagrywanie lokalne",
          ]
      : locale === "en"
        ? [
            "90 AI-analyzed sessions/month",
            "Everything in Balance, plus:",
            "Priority processing queue",
            "Extended report customization",
          ]
        : [
            "90 sesji z analizą AI/mies.",
            "Wszystko z Równowagi, plus:",
            "Priorytetowa kolejka przetwarzania",
            "Rozszerzona personalizacja raportów",
          ];

  // Build the correct planSlug reflecting the selected cycle
  const cycleSuffix = cycle === "ANNUAL" ? "annual" : "monthly";
  const planSlug = `${tier}_${cycleSuffix}`;
  // A code only rides along when it actually covers THIS plan+cycle —
  // otherwise checkout would reject a discount the visitor never asked
  // to apply here.
  const codeForThisPlan = discountAppliesTo(discount, tier.toUpperCase(), cycle)
    ? discount!.code
    : undefined;
  const registerHref = `${prefix}/register/therapist?plan=${planSlug}${
    codeForThisPlan ? `&code=${encodeURIComponent(codeForThisPlan)}` : ""
  }`;

  // Checkout handler: if logged in → /api/checkout direct; else → registration
  const handleCheckout = useCallback(async () => {
    if (!row.stripePriceId) {
      // No Stripe price configured (e.g. CLINIC tier) — go to contact
      window.location.href = `${prefix}/kontakt`;
      return;
    }

    setError(null);
    setLoading(true);

    try {
      const auth = getAuth();
      const user = auth.currentUser;

      if (!user) {
        // Not logged in — redirect to registration with plan pre-selected
        window.location.href = registerHref;
        return;
      }

      // Logged in: resolve organizationId via identity-svc
      const token = await user.getIdToken();
      const ctx = await identityClient.validateToken(
        { firebaseIdToken: token },
      );
      const organizationId = ctx.organizationId;

      if (!organizationId) {
        // User exists but no org (edge case) — fallback to registration
        console.warn("[UpgradeCard] No organizationId, falling back to register");
        window.location.href = registerHref;
        return;
      }

      // Fetch user profile details to prefill name and phone number
      let phoneNumber: string | undefined;
      let name: string | undefined;
      try {
        const profile = await identityClient.getMyProfile(create(EmptySchema, {}));
        if (profile) {
          phoneNumber = profile.phoneNumber || undefined;
          name = `${profile.firstName || ""} ${profile.lastName || ""}`.trim() || undefined;
        }
      } catch (err) {
        console.warn("[UpgradeCard] Failed to fetch profile details for prefilling:", err);
      }

      // Fetch organization details for B2B billing prefill
      let address: any = undefined;
      let taxId: string | undefined;
      let vatIdEu: string | undefined;
      try {
        const org = await identityClient.getMyOrganization(create(EmptySchema, {}));
        if (org) {
          if (org.legalName) {
            name = org.legalName;
          }
          taxId = org.taxId || undefined;
          vatIdEu = org.vatIdEu || undefined;

          if (org.headquartersAddress) {
            const street = org.headquartersAddress.streetLine || "";
            const bldg = org.headquartersAddress.buildingNumber || "";
            const unit = org.headquartersAddress.unitNumber || "";

            let line1 = `${street} ${bldg}`.trim();
            if (unit) {
              line1 = `${line1}/${unit}`;
            }

            address = {
              line1: line1 || undefined,
              line2: org.headquartersAddress.directions || undefined,
              city: org.headquartersAddress.city || undefined,
              postal_code: org.headquartersAddress.postalCode || undefined,
              state: org.headquartersAddress.region || undefined,
              country: org.headquartersAddress.countryCode || undefined,
            };
          }
        }
      } catch (err) {
        console.warn("[UpgradeCard] Failed to fetch organization details for prefilling:", err);
      }

      // Call /api/checkout with the user's org and email
      const resp = await fetch("/api/checkout", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
        },
        body: JSON.stringify({
          priceId: row.stripePriceId,
          organizationId,
          email: user.email ?? undefined,
          phoneNumber,
          name,
          taxId,
          vatIdEu,
          address,
          promoCode: codeForThisPlan ?? row.couponCode ?? undefined,
          ...(returnUrl ? { returnUrl } : {}),
        }),
      });

      // 409 = the org already has a store subscription, so Stripe must
      // not sell it a second one (docs/70 §5.1, E22). This is a normal
      // state to be in, not a failure to report as "Error: ...".
      if (resp.status === 409) {
        const body = await resp.json().catch(() => ({} as Record<string, string>));
        if (body?.error === "OTHER_PROVIDER_ACTIVE") {
          const until = body.blocked_until ? new Date(body.blocked_until) : null;
          const date =
            until && !Number.isNaN(until.getTime())
              ? until.toLocaleDateString(locale === "en" ? "en-GB" : "pl-PL")
              : null;
          setError(
            date && body.provider === "APPLE_IAP"
              ? tCheckout("otherProviderApple", { date })
              : date && body.provider === "GOOGLE_IAP"
                ? tCheckout("otherProviderGoogle", { date })
                : tCheckout("otherProvider"),
          );
          return;
        }
      }

      if (!resp.ok) {
        const body = await resp.json().catch(() => ({}));
        throw new Error(body.error || `Checkout failed (${resp.status})`);
      }

      const { url } = await resp.json();
      if (url) {
        window.location.href = url;
      } else {
        throw new Error("No checkout URL returned");
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Unexpected error";
      console.error("[UpgradeCard] checkout error:", err);
      setError(
        locale === "en"
          ? `Error: ${msg}`
          : `Błąd: ${msg}`,
      );
    } finally {
      setLoading(false);
    }
  }, [row.stripePriceId, row.couponCode, prefix, registerHref, locale, codeForThisPlan, returnUrl, tCheckout]);

  return (
    <div
      className={`relative rounded-2xl p-6 sm:p-8 flex flex-col transition-all duration-300 ${
        isHero
          ? "bg-[#004D54] text-white shadow-xl shadow-[#004D54]/20 ring-2 ring-[#2F6B62]"
          : "bg-white text-[#1B2522] shadow-lg border border-[#E2DED5]"
      }`}
    >
      {/* Popular badge */}
      {isHero && (
        <span className="absolute -top-3 left-1/2 -translate-x-1/2 inline-flex items-center gap-1 px-3 py-1 rounded-full bg-[#F5A623] text-[#1B2522] text-[10px] font-mono uppercase tracking-wider font-bold shadow-md">
          {locale === "en" ? "Most popular" : "Najpopularniejszy"}
        </span>
      )}

      {/* Tier name */}
      <h3
        className={`font-serif text-lg font-bold mb-1 ${
          isHero ? "text-[#F5A623]" : "text-[#004D54]"
        }`}
      >
        {tierName}
      </h3>

      {/* Sessions badge */}
      <span
        className={`inline-flex self-start items-center px-2 py-0.5 rounded-full text-[10px] font-mono uppercase tracking-wider font-bold mb-4 ${
          isHero
            ? "bg-white/10 text-white/80"
            : "bg-[#004D54]/5 text-[#004D54]"
        }`}
      >
        {sessionsLabel}
      </span>

      {/* Price */}
      <div className="mb-5">
        {introMonthlyPrice && (
          <div className="flex items-baseline gap-2 mb-1">
            <span
              className={`text-sm line-through ${
                isHero ? "text-white/40" : "text-[#4E5A55]/40"
              }`}
            >
              {formatPrice(locale, monthlyPrice)} zł
            </span>
            {row.couponCode && (
              <span
                className={`text-[10px] font-mono uppercase tracking-wider ${
                  isHero ? "text-[#F5A623]" : "text-[#2F6B62]"
                }`}
              >
                {row.couponCode}
              </span>
            )}
          </div>
        )}
        <div className="flex items-baseline gap-1">
          <span className="text-4xl sm:text-5xl font-bold font-sans tabular-nums">
            {formatPrice(locale, introMonthlyPrice ?? monthlyPrice)}
          </span>
          <span
            className={`text-base font-sans ${
              isHero ? "text-white/60" : "text-[#4E5A55]"
            }`}
          >
            zł
            <span className="text-xs">
              /{locale === "en" ? "mo" : "mies."}
            </span>
          </span>
        </div>
        {cycle === "ANNUAL" && (
          <p
            className={`text-[11px] mt-1 ${
              isHero ? "text-white/50" : "text-[#4E5A55]/50"
            }`}
          >
            {locale === "en"
              ? `Billed ${formatPrice(locale, row.priceIntroGross ?? row.priceGross)} zł/year`
              : `Rozliczenie ${formatPrice(locale, row.priceIntroGross ?? row.priceGross)} zł/rok`}
          </p>
        )}
      </div>

      {/* Features */}
      <ul className="space-y-2.5 mb-6 flex-1">
        {features.map((f) => (
          <li key={f} className="flex items-start gap-2 text-sm font-sans">
            <span
              className={`mt-0.5 text-xs ${
                isHero ? "text-[#F5A623]" : "text-[#2F6B62]"
              }`}
            >
              ✓
            </span>
            <span className={isHero ? "text-white/90" : "text-[#4E5A55]"}>
              {f}
            </span>
          </li>
        ))}
      </ul>

      {/* Error message */}
      {error && (
        <p className={`text-xs font-sans mb-3 ${
          isHero ? "text-red-300" : "text-red-600"
        }`}>
          {error}
        </p>
      )}

      {/* CTA */}
      <button
        onClick={handleCheckout}
        disabled={loading || currentPlanTier === tier.toUpperCase()}
        className={`block w-full text-center py-3.5 rounded-full font-sans font-bold text-sm uppercase tracking-wider transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed ${
          currentPlanTier === tier.toUpperCase()
            ? isHero
              ? "bg-white/10 text-white/40 cursor-not-allowed border border-white/10"
              : "bg-neutral-100 text-[#8FA5A0] cursor-not-allowed border border-[#E2DED5]"
            : isHero
              ? "bg-gradient-to-r from-[#FCAE2F] to-[#F97316] text-[#1B2522] hover:brightness-110 shadow-lg shadow-[#FCAE2F]/20"
              : "bg-[#004D54] text-white hover:bg-[#003A40] shadow-md"
        }`}
      >
        {loading
          ? (locale === "en" ? "Redirecting…" : "Przekierowuję…")
          : currentPlanTier === tier.toUpperCase()
            ? (locale === "en" ? "Your current plan" : "Twój aktualny plan")
            : currentPlanTier === "SOLO" && tier.toUpperCase() === "PRO"
              ? (locale === "en" ? "Upgrade plan" : "Przejdź na wyższy plan")
              : (locale === "en" ? "Choose this plan" : "Wybierz ten plan")
        }
      </button>

      {/* Invoice prefill helper text */}
      <p className={`text-[11px] font-sans text-center mt-3.5 leading-snug ${
        isHero ? "text-white/60" : "text-[#4E5A55]/70"
      }`}>
        {locale === "pl" ? (
          "Dane firmy i NIP z Twojego profilu zostaną automatycznie przeniesione na fakturę VAT."
        ) : (
          "Company details & NIP from your profile will be automatically added to the VAT invoice."
        )}
      </p>
    </div>
  );
}

