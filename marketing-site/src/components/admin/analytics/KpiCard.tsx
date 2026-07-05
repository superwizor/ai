// src/components/admin/analytics/KpiCard.tsx
"use client";

import React, { useState } from "react";
import CountUp from "react-countup";
import { LineChart, Line, ResponsiveContainer } from "recharts";
import { chartTheme } from "@/lib/charts/theme";

interface KpiCardProps {
  title: string;
  value: number;
  suffix?: string;
  prefix?: string;
  decimals?: number;
  delta?: number;
  sparklineData?: number[];
  /** Plain-language explanation shown on ⓘ hover */
  info?: string;
  /** Secondary value line (e.g. converted currency) */
  secondaryLabel?: string;
  /** Denser padding + smaller value — for compact KPI strips (docs/38). */
  compact?: boolean;
}

export function KpiCard({
  title,
  value,
  suffix = "",
  prefix = "",
  decimals = 0,
  delta,
  sparklineData,
  info,
  secondaryLabel,
  compact = false,
}: KpiCardProps) {
  const isPositive = delta !== undefined && delta >= 0;
  const [showInfo, setShowInfo] = useState(false);

  // Map simple number array to Recharts coordinate objects
  const chartData = sparklineData?.map((val, idx) => ({ name: String(idx), value: val }));

  return (
    <div className={`rounded-card border border-frost/10 bg-surfaceTeal/30 backdrop-blur-md ${compact ? "p-4" : "p-6"} flex flex-col justify-between hover:border-ember/30 transition shadow-lg`}>
      <div>
        <div className="flex items-start gap-1.5">
          <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/60 flex-1">
            {title}
          </p>
          {info && (
            <div className="relative flex-shrink-0">
              <button
                type="button"
                aria-label="Informacja"
                onClick={() => setShowInfo((v) => !v)}
                onMouseEnter={() => setShowInfo(true)}
                onMouseLeave={() => setShowInfo(false)}
                className="w-4 h-4 rounded-full border border-frost/25 text-mist/50 hover:text-frost hover:border-ember/60 transition flex items-center justify-center text-[9px] font-bold cursor-help"
              >
                i
              </button>
              {showInfo && (
                <div className="absolute right-0 top-5 z-50 w-64 p-2.5 rounded-lg bg-obsidian/95 border border-frost/20 shadow-xl backdrop-blur-lg">
                  <p className="font-serif text-[11px] text-frost/90 leading-relaxed">
                    {info}
                  </p>
                </div>
              )}
            </div>
          )}
        </div>
        <div className="flex items-baseline gap-2 mt-2">
          <span className={`font-display ${compact ? "text-2xl" : "text-4xl"} font-bold text-frost`}>
            {prefix}
            <CountUp end={value} decimals={decimals} duration={1.5} separator=" " />
            {suffix}
          </span>
          {delta !== undefined && (
            <span
              className={`font-mono text-xs font-semibold px-2 py-0.5 rounded ${
                isPositive ? "bg-emerald-500/10 text-emerald-400" : "bg-magma/10 text-magma"
              }`}
            >
              {isPositive ? "+" : ""}
              {delta}%
            </span>
          )}
        </div>
        {secondaryLabel && (
          <p className="font-mono text-[10px] text-mist/50 mt-1">
            {secondaryLabel}
          </p>
        )}
      </div>

      {chartData && chartData.length > 0 && (
        <div className="h-10 mt-4 -mx-2">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={chartData}>
              <Line
                type="monotone"
                dataKey="value"
                stroke={chartTheme.ember}
                strokeWidth={1.5}
                dot={false}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
}
