// Canonical plan display names — single source of truth is the pricing
// page copy (messages/<locale>.json → pricing.tiers.<tier>.name):
//
//   TRIAL → Poznanie / Discovery
//   SOLO  → Równowaga / Balance
//   PRO   → Rozkwit / Growth
//   CLINIC → Ewolucja / Evolution
//
// Every panel surface (dashboard quota strip, /org, /admin seats)
// renders tiers through this hook so the names stay in lockstep with
// the cennik. Unknown tiers fall back to the raw code.

"use client";

import { useTranslations } from "next-intl";

const KNOWN_TIERS = ["trial", "solo", "pro", "clinic"] as const;

export function usePlanName(): (tier: string | undefined | null) => string {
  const t = useTranslations("pricing.tiers");
  return (tier) => {
    if (!tier) return "";
    const key = tier.toLowerCase();
    if ((KNOWN_TIERS as readonly string[]).includes(key)) {
      return t(`${key}.name`);
    }
    return tier;
  };
}
