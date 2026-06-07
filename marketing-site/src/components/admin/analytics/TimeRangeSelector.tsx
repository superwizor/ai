// src/components/admin/analytics/TimeRangeSelector.tsx
"use client";

import React from "react";
import { useTranslations } from "next-intl";

export type TimeRangeKey = "7d" | "30d" | "90d" | "12w" | "24w" | "52w";

interface TimeRangeSelectorProps {
  value: TimeRangeKey;
  onChange: (range: TimeRangeKey) => void;
}

const RANGE_KEYS: TimeRangeKey[] = ["7d", "30d", "90d", "12w", "24w", "52w"];

const RANGE_LABELS: Record<TimeRangeKey, string> = {
  "7d": "7 d",
  "30d": "30 d",
  "90d": "90 d",
  "12w": "12w",
  "24w": "24w",
  "52w": "52w",
};

export function TimeRangeSelector({ value, onChange }: TimeRangeSelectorProps) {
  const t = useTranslations("admin.analytics.timeRange");

  return (
    <div className="flex bg-surfaceTeal/40 border border-frost/15 rounded-button p-0.5 self-start">
      {RANGE_KEYS.map((key) => {
        const isActive = value === key;
        // Try translated label, fallback to short code
        let label: string;
        try {
          label = t(key);
        } catch {
          label = RANGE_LABELS[key];
        }
        return (
          <button
            key={key}
            onClick={() => onChange(key)}
            className={`font-mono text-xs uppercase tracking-wider px-3 py-1.5 rounded-button transition cursor-pointer ${
              isActive
                ? "bg-ember text-obsidian font-bold"
                : "text-mist hover:text-frost"
            }`}
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}
