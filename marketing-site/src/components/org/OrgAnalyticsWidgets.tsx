// Org-scoped analytics widgets (docs/38 §7.2) — the same visual
// language as /admin/analytics (KpiCard/ChartCard + recharts + nivo),
// fed by clinical.GetOrgAnalytics which is hard-scoped to the caller's
// organization. Includes the "czas zaoszczędzony na raportowaniu" KPI:
// sessions × 20 min, current month + year.

"use client";

import { useEffect, useState, type ReactNode } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import { ResponsiveHeatMap } from "@nivo/heatmap";

import { clinicalClient } from "@/lib/connect/clients";
import {
  GetOrgAnalyticsRequestSchema,
  type GetOrgAnalyticsResponse,
} from "@superwizor/proto-ts/clinical/v1/clinical_pb";
import { KpiCard } from "@/components/admin/analytics/KpiCard";
import { ChartCard } from "@/components/admin/analytics/ChartCard";
import { chartTheme } from "@/lib/charts/theme";

const MINUTES_SAVED_PER_SESSION = 30;

export function OrgAnalyticsWidgets({ afterKpis }: { afterKpis?: ReactNode }) {
  const t = useTranslations("org.analytics");
  const locale = useLocale();
  const [data, setData] = useState<GetOrgAnalyticsResponse | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    clinicalClient
      .getOrgAnalytics(create(GetOrgAnalyticsRequestSchema, {}))
      .then((resp) => {
        if (!cancelled) setData(resp);
      })
      .catch(() => {
        if (!cancelled) setData(null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) {
    return (
      <p className="py-8 text-center font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70">
        {t("loading")}
      </p>
    );
  }
  if (!data) return null;

  // ── time saved (sessions × 20 min) ──
  const savedMonthH = (Number(data.sessionsThisMonth) * MINUTES_SAVED_PER_SESSION) / 60;
  const savedYearH = (Number(data.sessionsThisYear) * MINUTES_SAVED_PER_SESSION) / 60;

  // ── recharts trend mapping ──
  const sessionsTrend = data.sessionsTrend.map((p) => ({ label: p.label, value: p.value }));
  const durationTrend = data.sessionDurationTrend.map((p) => ({
    label: p.label,
    value: Number(p.value.toFixed(1)),
  }));
  // ── hourly heatmap (nivo) — same mapping as /admin/analytics ──
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(2023, 0, i + 1); // 2023-01-01 is a Sunday
    return new Intl.DateTimeFormat(locale, { weekday: "long" }).format(d);
  });
  const hourlyMap: Record<string, Record<string, number>> = {};
  days.forEach((d) => {
    hourlyMap[d] = {};
    for (let h = 0; h < 24; h++) hourlyMap[d][String(h)] = 0;
  });
  data.hourlyHeatmap.forEach((item) => {
    const dayName = days[item.dayOfWeek] || "—";
    hourlyMap[dayName][String(item.hour)] = Number(item.count);
  });
  const hourlyHeatmapData = days.map((day) => ({
    id: day,
    data: Array.from({ length: 24 }, (_, h) => ({
      x: String(h),
      y: hourlyMap[day][String(h)],
    })),
  }));
  const hasHourly = data.hourlyHeatmap.length > 0;

  const lineTheme = {
    tooltip: {
      container: { background: chartTheme.surfaceTeal, color: chartTheme.frost },
    },
    axis: { ticks: { text: { fill: chartTheme.mist, fontSize: 10 } } },
  };

  return (
    <div className="grid gap-6">
      {/* KPI strip — compact; the two count widgets drop their single-point
          sparkline "dot" (live feedback 2026-07-05). */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard
          compact
          title={t("kpiWau")}
          value={Number(data.kpiWau)}
          info={t("kpiWauInfo")}
        />
        <KpiCard
          compact
          title={t("kpiSessionsWeek")}
          value={Number(data.kpiSessionsThisWeek)}
          info={t("kpiSessionsWeekInfo")}
        />
        <KpiCard
          compact
          title={t("kpiAvgDuration")}
          value={data.kpiAvgSessionDuration}
          decimals={1}
          suffix=" min"
          info={t("kpiAvgDurationInfo")}
        />
        <KpiCard
          compact
          title={t("kpiTimeSaved")}
          value={savedMonthH}
          decimals={1}
          suffix=" h"
          secondaryLabel={t("kpiTimeSavedYear", {
            hours: savedYearH.toFixed(0),
            sessions: String(data.sessionsThisYear),
          })}
          info={t("kpiTimeSavedInfo")}
        />
      </div>

      {/* Slot rendered directly under the KPI strip (docs/38 live feedback:
          the per-therapist table sits here, above the trend charts). */}
      {afterKpis}

      {/* Trends */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartCard
          title={t("chartSessionsTrend")}
          description={t("chartSessionsTrendDesc")}
          isEmpty={sessionsTrend.length === 0}
          emptyLabel={t("empty")}
        >
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={sessionsTrend} margin={{ top: 10, right: 16, bottom: 0, left: -16 }}>
              <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} />
              <XAxis dataKey="label" tick={{ fill: chartTheme.mist, fontSize: 10 }} />
              <YAxis tick={{ fill: chartTheme.mist, fontSize: 10 }} allowDecimals={false} />
              <Tooltip
                contentStyle={{
                  background: chartTheme.surfaceTeal,
                  border: "none",
                  color: chartTheme.frost,
                }}
              />
              <Line
                type="monotone"
                dataKey="value"
                stroke={chartTheme.ember}
                strokeWidth={2.5}
                dot={false}
              />
            </LineChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard
          title={t("chartDurationTrend")}
          description={t("chartDurationTrendDesc")}
          isEmpty={durationTrend.length === 0}
          emptyLabel={t("empty")}
        >
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={durationTrend} margin={{ top: 10, right: 16, bottom: 0, left: -16 }}>
              <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} />
              <XAxis dataKey="label" tick={{ fill: chartTheme.mist, fontSize: 10 }} />
              <YAxis tick={{ fill: chartTheme.mist, fontSize: 10 }} />
              <Tooltip
                contentStyle={{
                  background: chartTheme.surfaceTeal,
                  border: "none",
                  color: chartTheme.frost,
                }}
              />
              <Line
                type="monotone"
                dataKey="value"
                stroke={chartTheme.aurora}
                strokeWidth={2.5}
                dot={{ r: 3 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>

      {/* Day × hour heatmap */}
      {hasHourly && (
        <ChartCard
          title={t("chartHourly")}
          description={t("chartHourlyDesc")}
        >
          <ResponsiveHeatMap
            data={hourlyHeatmapData}
            margin={{ top: 30, right: 30, bottom: 30, left: 100 }}
            colors={{ type: "sequential", scheme: "viridis" }}
            emptyColor="#555"
            enableLabels={false}
            theme={lineTheme}
          />
        </ChartCard>
      )}
    </div>
  );
}
