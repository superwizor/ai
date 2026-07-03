// Org-scoped analytics widgets (docs/38 §7.2) — the same visual
// language as /admin/analytics (KpiCard/ChartCard + recharts + nivo),
// fed by clinical.GetOrgAnalytics which is hard-scoped to the caller's
// organization. Includes the "czas zaoszczędzony na raportowaniu" KPI:
// sessions × 20 min, current month + year.

"use client";

import { useEffect, useState } from "react";
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

const MINUTES_SAVED_PER_SESSION = 20;

const getContrastColor = (cell: { color?: string; value?: number | null }) => {
  const color = cell.color;
  if (color && color.startsWith("rgb")) {
    const match = color.match(/\d+/g);
    if (match) {
      const yiq =
        (parseInt(match[0], 10) * 299 +
          parseInt(match[1], 10) * 587 +
          parseInt(match[2], 10) * 114) /
        1000;
      return yiq >= 128 ? "#002b2c" : "#ffffff";
    }
  }
  return (cell.value ?? 0) > 60 ? "#ffffff" : "#002b2c";
};

export function OrgAnalyticsWidgets() {
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
  const wauSpark = data.wauTrend.map((p) => p.value);
  const sessionsSpark = data.sessionsTrend.map((p) => p.value);

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

  // ── per-therapist utilization heatmap — same graph as the admin
  //    per-org one, rows are therapists ──
  const thMap: Record<string, Record<string, number>> = {};
  const weeksSet = new Set<string>();
  const thMax: Record<string, number> = {};
  data.therapistUtilization.forEach((item) => {
    if (!thMap[item.orgName]) thMap[item.orgName] = {};
    thMap[item.orgName][item.week] = item.value;
    weeksSet.add(item.week);
    thMax[item.orgName] = Math.max(thMax[item.orgName] || 0, item.value);
  });
  const sortedWeeks = Array.from(weeksSet).sort();
  const activeTherapists = Object.keys(thMap).filter((n) => thMax[n] > 0);
  const utilizationData = activeTherapists.map((name) => ({
    id: name,
    data: sortedWeeks.map((w) => ({ x: w, y: thMap[name][w] || 0 })),
  }));

  const lineTheme = {
    tooltip: {
      container: { background: chartTheme.surfaceTeal, color: chartTheme.frost },
    },
    axis: { ticks: { text: { fill: chartTheme.mist, fontSize: 10 } } },
  };

  return (
    <div className="grid gap-6">
      {/* KPI strip */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard
          title={t("kpiWau")}
          value={Number(data.kpiWau)}
          sparklineData={wauSpark}
          info={t("kpiWauInfo")}
        />
        <KpiCard
          title={t("kpiSessionsWeek")}
          value={Number(data.kpiSessionsThisWeek)}
          sparklineData={sessionsSpark}
          info={t("kpiSessionsWeekInfo")}
        />
        <KpiCard
          title={t("kpiAvgDuration")}
          value={data.kpiAvgSessionDuration}
          decimals={1}
          suffix=" min"
          info={t("kpiAvgDurationInfo")}
        />
        <KpiCard
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

      {/* Per-therapist token utilization — same graph as admin, rows = therapists */}
      <ChartCard
        title={t("chartUtilization")}
        description={t("chartUtilizationDesc")}
        info={t("chartUtilizationInfo")}
        isEmpty={utilizationData.length === 0}
        emptyLabel={t("empty")}
      >
        <ResponsiveHeatMap
          data={utilizationData}
          margin={{ top: 30, right: 30, bottom: 30, left: 180 }}
          colors={{ type: "sequential", scheme: "magma" }}
          emptyColor="#555"
          enableLabels={true}
          label={(cell) => (cell.value === 0 || cell.value == null ? "" : `${Number(cell.value).toFixed(0)}%`)}
          labelTextColor={getContrastColor}
          theme={lineTheme}
        />
      </ChartCard>

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
