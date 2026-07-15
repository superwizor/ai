// src/app/[locale]/admin/analytics/page.tsx
"use client";

import React, { useEffect, useState, useCallback, useMemo } from "react";
import { useTranslations, useLocale } from "next-intl";
import { clinicalClient } from "@/lib/connect/clients";
import { useNbpRate } from "@/lib/hooks/useNbpRate";
import type { GetAdminAnalyticsResponse, AdminReportRatingRow } from "@superwizor/proto-ts/clinical/v1/clinical_pb";
import { chartTheme } from "@/lib/charts/theme";
import { KpiCard } from "@/components/admin/analytics/KpiCard";
import { ChartCard } from "@/components/admin/analytics/ChartCard";
import { TabNav, TabKey } from "@/components/admin/analytics/TabNav";
import { TimeRangeSelector, TimeRangeKey } from "@/components/admin/analytics/TimeRangeSelector";
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  ComposedChart,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";
import { ResponsivePie } from "@nivo/pie";
import { ResponsiveFunnel } from "@nivo/funnel";
import { ResponsiveHeatMap } from "@nivo/heatmap";

const getContrastColor = (cell: any) => {
  const color = cell.color;
  if (!color) return "#ffffff";
  if (color.startsWith("#")) {
    const r = parseInt(color.slice(1, 3), 16);
    const g = parseInt(color.slice(3, 5), 16);
    const b = parseInt(color.slice(5, 7), 16);
    const yiq = (r * 299 + g * 587 + b * 114) / 1000;
    return yiq >= 128 ? "#002b2c" : "#ffffff";
  }
  if (color.startsWith("rgb")) {
    const match = color.match(/\d+/g);
    if (match) {
      const r = parseInt(match[0], 10);
      const g = parseInt(match[1], 10);
      const b = parseInt(match[2], 10);
      const yiq = (r * 299 + g * 587 + b * 114) / 1000;
      return yiq >= 128 ? "#002b2c" : "#ffffff";
    }
  }
  return cell.value > 60 ? "#ffffff" : "#002b2c";
};

export default function AnalyticsPage() {
  const t = useTranslations("admin.analytics");
  const locale = useLocale();
  const { rate: plnRate, effectiveDate: plnDate, loading: plnLoading } = useNbpRate();
  const [currency, setCurrency] = useState<"USD" | "PLN">("USD");

  // USD → PLN formatter
  const toPlnLabel = (usd: number, dec = 2) => {
    const pln = (usd * plnRate).toFixed(dec);
    const rateStr = plnRate.toFixed(2);
    const dateStr = plnDate ? ` z ${plnDate}` : "";
    return `≈ ${pln} PLN · kurs NBP ${rateStr}${dateStr}`;
  };

  // PLN → USD formatter (used when currency is PLN)
  const toUsdLabel = (usd: number, dec = 2) => {
    return `≈ ${usd.toFixed(dec)} USD`;
  };
  const [activeTab, setActiveTab] = useState<TabKey>("overview");
  const [timeRange, setTimeRange] = useState<TimeRangeKey>("12w");
  const [showRegistrationsDetail, setShowRegistrationsDetail] = useState(false);
  const [marketingFilter, setMarketingFilter] = useState<"all" | "yes" | "no">("all");
  const [data, setData] = useState<GetAdminAnalyticsResponse | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const filteredRegistrations = useMemo(() => {
    if (!data?.registrationsDetail) return [];
    return data.registrationsDetail.filter((user: any) => {
      if (marketingFilter === "yes") {
        return user.hasMarketingConsent === true;
      }
      if (marketingFilter === "no") {
        return user.hasMarketingConsent === false;
      }
      return true;
    });
  }, [data?.registrationsDetail, marketingFilter]);

  const handleExportCSV = () => {
    if (!filteredRegistrations || filteredRegistrations.length === 0) return;

    const headers = [
      t("registrationsDetail.colName"),
      t("registrationsDetail.colEmail"),
      t("registrationsDetail.colCreatedAt"),
      t("registrationsDetail.colLogins"),
      t("registrationsDetail.colSessions"),
      t("registrationsDetail.colMarketing")
    ];

    const rows = filteredRegistrations.map((user: any) => [
      `"${user.firstName} ${user.lastName}"`,
      `"${user.email}"`,
      `"${user.createdAt ? new Date(Number(user.createdAt.seconds) * 1000).toLocaleString(locale, { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }) : ""}"`,
      user.loginCount,
      user.sessionCount,
      user.hasMarketingConsent ? t("registrationsDetail.yes") : t("registrationsDetail.no")
    ]);

    const csvContent = "\uFEFF" + [headers.join(","), ...rows.map(e => e.join(","))].join("\n");
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `rejestracje_mailing_${timeRange}_${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Feedback tab state
  const [feedbackRatings, setFeedbackRatings] = useState<AdminReportRatingRow[]>([]);
  const [feedbackTotal, setFeedbackTotal] = useState(0);
  const [feedbackPage, setFeedbackPage] = useState(0);
  const [feedbackPageSize] = useState(25);
  const [feedbackRatingFilter, setFeedbackRatingFilter] = useState("");
  const [feedbackStatusFilter, setFeedbackStatusFilter] = useState("");
  const [feedbackSearch, setFeedbackSearch] = useState("");
  const [feedbackLoading, setFeedbackLoading] = useState(false);

  const fetchAnalytics = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const resp = await clinicalClient.getAdminAnalytics({ timeRange });
      setData(resp);
    } catch (err: any) {
      console.error("Failed to load admin analytics:", err);
      setError(t("errorFetch"));
    } finally {
      setLoading(false);
    }
  }, [timeRange, t]);

  useEffect(() => {
    void fetchAnalytics();
  }, [fetchAnalytics]);

  // Feedback tab data fetching
  const fetchFeedback = useCallback(async () => {
    setFeedbackLoading(true);
    try {
      const resp = await clinicalClient.adminListReportRatings({
        pageSize: feedbackPageSize,
        page: feedbackPage,
        ratingFilter: feedbackRatingFilter,
        statusFilter: feedbackStatusFilter,
        search: feedbackSearch,
      });
      setFeedbackRatings(resp.ratings as AdminReportRatingRow[]);
      setFeedbackTotal(Number(resp.totalCount));
    } catch (err: any) {
      console.error("Failed to load feedback:", err);
    } finally {
      setFeedbackLoading(false);
    }
  }, [feedbackPage, feedbackPageSize, feedbackRatingFilter, feedbackStatusFilter, feedbackSearch]);

  useEffect(() => {
    if (activeTab === "feedback") {
      void fetchFeedback();
    }
  }, [activeTab, fetchFeedback]);

  const handleToggleStatus = async (ratingId: string, currentStatus: string) => {
    const newStatus = currentStatus === "done" ? "pending" : "done";
    try {
      await clinicalClient.adminSetRatingReviewStatus({ ratingId, status: newStatus });
      setFeedbackRatings((prev) =>
        prev.map((r) => (r.id === ratingId ? { ...r, adminReviewStatus: newStatus } as AdminReportRatingRow : r))
      );
    } catch (err: any) {
      console.error("Failed to toggle status:", err);
    }
  };

  if (loading) {
    return (
      <div className="px-4 sm:px-6 lg:px-8 py-8 flex flex-col gap-6 animate-pulse">
        <div className="h-10 bg-frost/5 w-64 rounded-button" />
        <div className="h-6 bg-frost/5 w-96 rounded-button" />
        <div className="h-12 bg-frost/5 w-full rounded-button mt-4" />
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div className="h-32 bg-frost/5 rounded-card" />
          <div className="h-32 bg-frost/5 rounded-card" />
          <div className="h-32 bg-frost/5 rounded-card" />
          <div className="h-32 bg-frost/5 rounded-card" />
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="h-80 bg-frost/5 rounded-card" />
          <div className="h-80 bg-frost/5 rounded-card" />
        </div>
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="px-4 sm:px-6 lg:px-8 py-8 flex flex-col items-center justify-center min-h-[400px]">
        <div className="text-magma text-lg font-semibold mb-2">{t("errorTitle")}</div>
        <div className="text-mist mb-6">{error || t("errorDefault")}</div>
        <button
          onClick={() => void fetchAnalytics()}
          className="rounded-button bg-ember text-obsidian px-5 py-2.5 font-mono text-xs uppercase hover:brightness-110 transition shadow-lg"
        >
          {t("retry")}
        </button>
      </div>
    );
  }

  // Helper: check if array has meaningful data
  const hasData = (arr: any[] | undefined) => arr && arr.length > 0;
  const hasNonZeroData = (arr: any[] | undefined, key: string) =>
    arr && arr.length > 0 && arr.some((item: any) => Number(item[key]) > 0);

  // Helper selectors / formatters
  const wauSparkline = data.wauTrend.map((t) => t.value);
  const sessionsSparkline = data.sessionsTrend.map((t) => t.value);

  // Mappings for Nivo & Recharts
  const planPieData = data.planDistribution.map((p) => ({
    id: p.planName,
    label: p.planName,
    value: Number(p.count),
  }));

  const modalityPieData = data.modalityDistribution.map((m) => ({
    id: m.modalityName,
    label: m.modalityName,
    value: Number(m.count),
  }));

  const funnelData = data.funnelSteps.map((f) => ({
    id: f.stepName,
    value: Number(f.count),
    label: `${f.stepName} (${f.count})`,
  }));

  // Map session duration trend and convert to minutes
  const sessionDurationTrendData = data.sessionDurationTrend.map((item) => ({
    label: item.label,
    value: Number((item.value / 60).toFixed(1)),
  }));

  // Convert token usage trend and other charts' data to ensure proper number formatting for Recharts (handling int64/string/Long conversions)
  const tokenUsageTrendData = data.tokenUsageTrend.map((item) => ({
    label: item.label,
    inputTokens: Number(item.inputTokens),
    outputTokens: Number(item.outputTokens),
  }));

  const issueCategoriesData = data.issueCategories.map((item) => ({
    category: item.category,
    count: Number(item.count),
  }));

  const activationTimeHistogramData = data.activationTimeHistogram.map((item) => ({
    bucketLabel: item.bucketLabel,
    count: Number(item.count),
  }));

  // Cost trend mapping based on current currency
  const costTrendData = data.costTrend.map((item) => {
    const mult = currency === "PLN" ? plnRate : 1;
    return {
      ...item,
      sttCost: item.sttCost * mult,
      llmCost: item.llmCost * mult,
      totalCost: item.totalCost * mult,
    };
  });

  // Fixed costs calculations
  const platformFixedCosts = data.platformFixedCosts || [];
  const fixedCostsMult = currency === "PLN" ? plnRate : 1;
  const totalFixedCosts = platformFixedCosts.reduce((acc, c) => acc + c.amountUsd, 0) * fixedCostsMult;
  const gcpFixedCosts = platformFixedCosts.filter(c => c.provider === "GCP").reduce((acc, c) => acc + c.amountUsd, 0) * fixedCostsMult;
  const firebaseFixedCosts = platformFixedCosts.filter(c => c.provider === "Firebase").reduce((acc, c) => acc + c.amountUsd, 0) * fixedCostsMult;

  const fixedCostsPieData = platformFixedCosts
    .map(c => ({
      id: c.name,
      label: c.name,
      value: Number((c.amountUsd * fixedCostsMult).toFixed(2)),
    }))
    .filter(c => c.value > 0);

  // Token Utilization Heatmap Nivo Mapping
  const orgsMap: Record<string, Record<string, number>> = {};
  const weeksSet = new Set<string>();
  const orgMaxVal: Record<string, number> = {};

  data.tokenUtilizationHeatmap.forEach((item) => {
    if (!orgsMap[item.orgName]) orgsMap[item.orgName] = {};
    orgsMap[item.orgName][item.week] = item.value;
    weeksSet.add(item.week);
    orgMaxVal[item.orgName] = Math.max(orgMaxVal[item.orgName] || 0, item.value);
  });

  const sortedWeeks = Array.from(weeksSet).sort();

  // Filter out organizations with 0% utilization across all weeks to avoid visual clutter and overlapping text
  const activeOrgs = Object.keys(orgsMap).filter((org) => orgMaxVal[org] > 0);

  const tokenHeatmapData = activeOrgs.map((org) => ({
    id: org,
    data: sortedWeeks.map((w) => ({
      x: w,
      y: orgsMap[org][w] || 0,
    })),
  }));

  // Cohort Retention Heatmap Nivo Mapping
  const cohortsMap: Record<string, Record<string, number>> = {};
  const cWeeksSet = new Set<string>();
  data.cohortRetention.forEach((item) => {
    if (!cohortsMap[item.cohort]) cohortsMap[item.cohort] = {};
    cohortsMap[item.cohort][item.week] = item.pct * 100;
    cWeeksSet.add(item.week);
  });
  const sortedCWeeks = Array.from(cWeeksSet).sort();
  const cohortHeatmapData = Object.keys(cohortsMap).map((cohort) => ({
    id: cohort,
    data: sortedCWeeks.map((w) => ({
      x: w,
      y: cohortsMap[cohort][w] || 0,
    })),
  }));

  // Hourly Heatmap Mapping
  // Generate locale-aware day names (Sunday=0 … Saturday=6)
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(2023, 0, i + 1); // 2023-01-01 is a Sunday
    return new Intl.DateTimeFormat(locale, { weekday: "long" }).format(d);
  });
  const hourlyMap: Record<string, Record<string, number>> = {};
  days.forEach((d) => {
    hourlyMap[d] = {};
    for (let h = 0; h < 24; h++) {
      hourlyMap[d][String(h)] = 0;
    }
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

  // Shared tooltip style
  const tooltipStyle = {
    backgroundColor: chartTheme.surfaceTeal,
    borderColor: chartTheme.glassBorder,
    color: chartTheme.frost,
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8 flex flex-col gap-6">
      <header className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-display text-frost text-3xl font-semibold tracking-[var(--tracking-display)]">
            {t("title")}
          </h1>
          <p className="font-serif text-sm text-mist mt-2">
            {t("subtitle")}
          </p>
        </div>
        <div className="flex items-center gap-4 self-end sm:self-auto">
          <TimeRangeSelector value={timeRange} onChange={setTimeRange} />
        </div>
      </header>

      <TabNav activeTab={activeTab} onChange={setActiveTab} />

      {/* ── Overview Tab ── */}
      {activeTab === "overview" && (
        <div className="flex flex-col gap-6">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <KpiCard title={t("kpi.wau")} info={t("kpi.wauInfo")} value={Number(data.kpiWau)} sparklineData={wauSparkline} />
            <KpiCard title={t("kpi.sessionsThisWeek")} info={t("kpi.sessionsThisWeekInfo")} value={Number(data.kpiSessionsThisWeek)} sparklineData={sessionsSparkline} />
            <KpiCard title={t("kpi.activationRate")} info={t("kpi.activationRateInfo")} value={data.kpiActivationRate} suffix="%" />
            <KpiCard title={t("kpi.satisfactionRate")} info={t("kpi.satisfactionRateInfo")} value={data.kpiSatisfactionRate} suffix="%" />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <ChartCard title={t("chart.sessionsTrend")} description={t("chart.sessionsTrendDesc")} info={t("chart.sessionsTrendInfo")} isEmpty={!hasData(data.sessionsTrend)}>
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data.sessionsTrend} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorSessions" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor={chartTheme.ember} stopOpacity={0.4}/>
                      <stop offset="95%" stopColor={chartTheme.ember} stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="label" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Area type="monotone" dataKey="value" stroke={chartTheme.ember} fillOpacity={1} fill="url(#colorSessions)" strokeWidth={2} />
                </AreaChart>
              </ResponsiveContainer>
            </ChartCard>

            <ChartCard
              title={t("chart.registrationsTrend")}
              description={t("chart.registrationsTrendDesc")}
              info={t("chart.registrationsTrendInfo")}
              isEmpty={!hasData(data.registrationsTrend)}
              action={
                <button
                  type="button"
                  onClick={() => setShowRegistrationsDetail(!showRegistrationsDetail)}
                  className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-ember hover:text-ember/85 transition bg-frost/5 hover:bg-frost/10 px-2 py-1 rounded cursor-pointer"
                >
                  {showRegistrationsDetail ? t("chart.hideDetails") : t("chart.showDetails")}
                </button>
              }
            >
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={data.registrationsTrend} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="label" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Bar dataKey="value" fill={chartTheme.aurora} radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </ChartCard>

            {planPieData.length > 0 && (
              <ChartCard title={t("chart.planDistribution")} description={t("chart.planDistributionDesc")} info={t("chart.planDistributionInfo")}>
                <ResponsivePie
                  data={planPieData}
                  margin={{ top: 40, right: 80, bottom: 40, left: 80 }}
                  innerRadius={0.6}
                  padAngle={1}
                  cornerRadius={3}
                  activeOuterRadiusOffset={8}
                  colors={[chartTheme.ember, chartTheme.aurora, chartTheme.mist, chartTheme.magma]}
                  borderWidth={1}
                  borderColor={{ from: "color", modifiers: [["darker", 0.2]] }}
                  enableArcLinkLabels={true}
                  arcLinkLabelsTextColor={chartTheme.frost}
                  arcLinkLabelsThickness={2}
                  arcLinkLabelsColor={{ from: "color" }}
                  arcLabelsSkipAngle={10}
                  arcLabelsTextColor={chartTheme.nocturne}
                  theme={{
                    tooltip: { container: { background: chartTheme.surfaceTeal, color: chartTheme.frost } },
                    labels: { text: { fontSize: 10 } }
                  }}
                />
              </ChartCard>
            )}

            {modalityPieData.length > 0 && (
              <ChartCard title={t("chart.modalityDistribution")} description={t("chart.modalityDistributionDesc")} info={t("chart.modalityDistributionInfo")}>
                <ResponsivePie
                  data={modalityPieData}
                  margin={{ top: 40, right: 80, bottom: 40, left: 80 }}
                  innerRadius={0.6}
                  padAngle={1}
                  cornerRadius={3}
                  activeOuterRadiusOffset={8}
                  colors={[chartTheme.aurora, chartTheme.ember, chartTheme.magma, chartTheme.mist]}
                  borderWidth={1}
                  borderColor={{ from: "color", modifiers: [["darker", 0.2]] }}
                  enableArcLinkLabels={true}
                  arcLinkLabelsTextColor={chartTheme.frost}
                  arcLinkLabelsThickness={2}
                  arcLinkLabelsColor={{ from: "color" }}
                  arcLabelsSkipAngle={10}
                  arcLabelsTextColor={chartTheme.nocturne}
                  theme={{
                    tooltip: { container: { background: chartTheme.surfaceTeal, color: chartTheme.frost } },
                    labels: { text: { fontSize: 10 } }
                  }}
                />
              </ChartCard>
            )}
          </div>

          {showRegistrationsDetail && (
            <div className="rounded-card border border-frost/10 bg-surfaceTeal/10 p-6 backdrop-blur-md animate-in fade-in-0 duration-200">
              <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
                <h3 className="font-display text-frost text-base font-semibold tracking-wide">
                  {t("registrationsDetail.title")}
                </h3>
                <div className="flex items-center gap-3">
                  <select
                    value={marketingFilter}
                    onChange={(e) => setMarketingFilter(e.target.value as any)}
                    className="bg-frost/5 border border-frost/10 text-frost text-xs font-mono rounded-button px-3 py-1.5 focus:outline-none focus:border-ember/40 cursor-pointer"
                  >
                    <option value="all">{t("registrationsDetail.filterMarketingAll")}</option>
                    <option value="yes">{t("registrationsDetail.filterMarketingYes")}</option>
                    <option value="no">{t("registrationsDetail.filterMarketingNo")}</option>
                  </select>

                  <button
                    type="button"
                    onClick={handleExportCSV}
                    disabled={filteredRegistrations.length === 0}
                    className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] bg-ember hover:bg-ember/85 disabled:opacity-30 disabled:hover:bg-ember text-nocturne font-bold px-3 py-1.5 rounded transition cursor-pointer"
                  >
                    {t("registrationsDetail.exportCsv")}
                  </button>

                  <button
                    type="button"
                    onClick={() => setShowRegistrationsDetail(false)}
                    className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost transition cursor-pointer ml-2"
                  >
                    {t("registrationsDetail.close")}
                  </button>
                </div>
              </div>
              <div className="overflow-x-auto rounded-card border border-frost/5 bg-obsidian/30">
                <table className="w-full text-sm">
                  <thead className="bg-frost/5">
                    <tr>
                      <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                        {t("registrationsDetail.colName")}
                      </th>
                      <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                        {t("registrationsDetail.colEmail")}
                      </th>
                      <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                        {t("registrationsDetail.colCreatedAt")}
                      </th>
                      <th className="text-right px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                        {t("registrationsDetail.colLogins")}
                      </th>
                      <th className="text-right px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                        {t("registrationsDetail.colSessions")}
                      </th>
                      <th className="text-center px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                        {t("registrationsDetail.colMarketing")}
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredRegistrations.map((user: any) => (
                      <tr key={user.userId} className="border-t border-frost/5 hover:bg-frost/[0.02]">
                        <td className="px-4 py-3 font-display text-frost">
                          {user.firstName} {user.lastName}
                        </td>
                        <td className="px-4 py-3 font-mono text-xs text-mist break-all">
                          {user.email}
                        </td>
                        <td className="px-4 py-3 font-serif text-mist">
                          {user.createdAt ? new Date(Number(user.createdAt.seconds) * 1000).toLocaleString(locale, { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "—"}
                        </td>
                        <td className="px-4 py-3 text-right font-mono text-frost">
                          {Number(user.loginCount)}
                        </td>
                        <td className="px-4 py-3 text-right font-mono text-frost">
                          {Number(user.sessionCount)}
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold uppercase tracking-wider ${
                            user.hasMarketingConsent
                              ? "bg-aurora/10 text-aurora border border-aurora/20"
                              : "bg-frost/5 text-mist border border-frost/10"
                          }`}>
                            {user.hasMarketingConsent ? `👍 ${t("registrationsDetail.yes")}` : `❌ ${t("registrationsDetail.no")}`}
                          </span>
                        </td>
                      </tr>
                    ))}
                    {filteredRegistrations.length === 0 && (
                      <tr>
                        <td colSpan={6} className="px-4 py-8 text-center text-mist/60 font-serif">
                          {t("registrationsDetail.empty")}
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── Costs & Economics Tab ── */}
      {activeTab === "costs" && (
        <div className="flex flex-col gap-6">
          <div className="flex flex-wrap items-center justify-between gap-4">
            {/* Exchange rate badge */}
            {!plnLoading ? (
              <div className="flex items-center gap-2 px-3 py-1.5 bg-frost/5 border border-frost/10 rounded-button">
                <span className="font-mono text-[10px] text-mist/60 uppercase">
                  1 USD = {plnRate.toFixed(4)} PLN
                </span>
                {plnDate && (
                  <span className="font-mono text-[10px] text-mist/40">
                    · NBP {plnDate}
                  </span>
                )}
              </div>
            ) : <div />}

            {/* Currency Toggle */}
            <div className="flex bg-frost/5 p-1 rounded-button border border-frost/10">
              <button
                onClick={() => setCurrency("USD")}
                className={`px-3 py-1 text-xs font-mono rounded-button transition-all ${
                  currency === "USD"
                    ? "bg-frost text-obsidian font-semibold"
                    : "text-mist hover:text-frost"
                }`}
              >
                USD
              </button>
              <button
                onClick={() => setCurrency("PLN")}
                className={`px-3 py-1 text-xs font-mono rounded-button transition-all ${
                  currency === "PLN"
                    ? "bg-frost text-obsidian font-semibold"
                    : "text-mist hover:text-frost"
                }`}
              >
                PLN
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <KpiCard
              title={t("kpi.avgCostPerSession")}
              info={currency === "PLN" ? t("kpi.avgCostPerSessionInfoPln") : t("kpi.avgCostPerSessionInfo")}
              value={currency === "PLN" ? data.kpiAvgCostPerSession * plnRate : data.kpiAvgCostPerSession}
              prefix={currency === "PLN" ? "PLN " : "USD "}
              decimals={4}
              secondaryLabel={currency === "PLN" ? toUsdLabel(data.kpiAvgCostPerSession, 4) : toPlnLabel(data.kpiAvgCostPerSession, 4)}
            />
            <KpiCard
              title={t("kpi.monthlySttCost")}
              info={currency === "PLN" ? t("kpi.monthlySttCostInfoPln") : t("kpi.monthlySttCostInfo")}
              value={currency === "PLN" ? data.kpiMonthlySttCost * plnRate : data.kpiMonthlySttCost}
              prefix={currency === "PLN" ? "PLN " : "USD "}
              decimals={2}
              secondaryLabel={currency === "PLN" ? toUsdLabel(data.kpiMonthlySttCost) : toPlnLabel(data.kpiMonthlySttCost)}
            />
            <KpiCard
              title={t("kpi.monthlyLlmCost")}
              info={currency === "PLN" ? t("kpi.monthlyLlmCostInfoPln") : t("kpi.monthlyLlmCostInfo")}
              value={currency === "PLN" ? data.kpiMonthlyLlmCost * plnRate : data.kpiMonthlyLlmCost}
              prefix={currency === "PLN" ? "PLN " : "USD "}
              decimals={2}
              secondaryLabel={currency === "PLN" ? toUsdLabel(data.kpiMonthlyLlmCost) : toPlnLabel(data.kpiMonthlyLlmCost)}
            />
            <KpiCard title={t("kpi.avgTokenUtil")} info={t("kpi.avgTokenUtilInfo")} value={data.kpiAvgTokenUtilization} suffix="%" decimals={1} />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <ChartCard title={t("chart.costTrend")} description={t("chart.costTrendDesc").replace("USD", currency)} info={currency === "PLN" ? t("chart.costTrendInfoPln") : t("chart.costTrendInfo")} isEmpty={!hasData(costTrendData)}>
              <ResponsiveContainer width="100%" height="100%">
                <ComposedChart data={costTrendData} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="label" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <Tooltip
                    contentStyle={tooltipStyle}
                    formatter={(value: any, name: any) => [
                      `${Number(value).toFixed(currency === "PLN" ? 2 : 4)} ${currency}`,
                      String(name || "")
                    ]}
                  />
                  <Legend wrapperStyle={{ fontSize: 10, color: chartTheme.mist }} />
                  <Bar dataKey="sttCost" name="STT" stackId="a" fill={chartTheme.aurora} />
                  <Bar dataKey="llmCost" name="LLM" stackId="a" fill={chartTheme.ember} />
                  <Line type="monotone" dataKey="totalCost" name="Σ" stroke={chartTheme.magma} strokeWidth={2} dot={false} />
                </ComposedChart>
              </ResponsiveContainer>
            </ChartCard>

            <ChartCard title={t("chart.tokenUsage")} description={t("chart.tokenUsageDesc")} info={t("chart.tokenUsageInfo")} isEmpty={!hasNonZeroData(tokenUsageTrendData, "inputTokens")}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={tokenUsageTrendData} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="label" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Legend wrapperStyle={{ fontSize: 10, color: chartTheme.mist }} />
                  <Bar dataKey="inputTokens" name="Input" fill={chartTheme.mist} radius={[4, 4, 0, 0]} />
                  <Bar dataKey="outputTokens" name="Output" fill={chartTheme.ember} radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </ChartCard>

            <div className="col-span-1 lg:col-span-2">
              <ChartCard
                title={t("chart.tokenUtilHeatmap")}
                description={t("chart.tokenUtilHeatmapDesc")}
                info={t("chart.tokenUtilHeatmapInfo")}
                isEmpty={tokenHeatmapData.length === 0}
                emptyLabel="Brak aktywnego użycia limitów subskrypcji"
              >
                <ResponsiveHeatMap
                  data={tokenHeatmapData}
                  margin={{ top: 30, right: 30, bottom: 30, left: 180 }}
                  colors={{
                    type: "sequential",
                    scheme: "magma",
                  }}
                  emptyColor="#555"
                  enableLabels={true}
                  label={(cell: any) => cell.value === 0 ? "" : `${Number(cell.value).toFixed(0)}%`}
                  labelTextColor={getContrastColor}
                  theme={{
                    tooltip: { container: { background: chartTheme.surfaceTeal, color: chartTheme.frost } },
                    axis: {
                      ticks: { text: { fill: chartTheme.mist, fontSize: 10 } },
                      legend: { text: { fill: chartTheme.mist } }
                    }
                  }}
                />
              </ChartCard>
            </div>
          </div>

          {/* ── Platform Fixed Costs Section ── */}
          <div className="border-t border-frost/10 pt-8 mt-6">
            <div className="mb-6">
              <h2 className="font-display text-frost text-xl font-semibold tracking-wide">
                {t("fixedCostsTable.title")}
              </h2>
              <p className="font-serif text-xs text-mist mt-1">
                {t("chart.fixedCostsBreakdownDesc")}
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
              <KpiCard
                title={t("kpi.totalFixedCosts")}
                info={t("kpi.totalFixedCostsInfo")}
                value={totalFixedCosts}
                prefix={currency === "PLN" ? "PLN " : "USD "}
                decimals={2}
                secondaryLabel={currency === "PLN" ? toUsdLabel(totalFixedCosts / plnRate) : toPlnLabel(totalFixedCosts)}
              />
              <KpiCard
                title={t("kpi.gcpFixedCosts")}
                info={t("kpi.gcpFixedCostsInfo")}
                value={gcpFixedCosts}
                prefix={currency === "PLN" ? "PLN " : "USD "}
                decimals={2}
                secondaryLabel={currency === "PLN" ? toUsdLabel(gcpFixedCosts / plnRate) : toPlnLabel(gcpFixedCosts)}
              />
              <KpiCard
                title={t("kpi.firebaseFixedCosts")}
                info={t("kpi.firebaseFixedCostsInfo")}
                value={firebaseFixedCosts}
                prefix={currency === "PLN" ? "PLN " : "USD "}
                decimals={2}
                secondaryLabel={currency === "PLN" ? toUsdLabel(firebaseFixedCosts / plnRate) : toPlnLabel(firebaseFixedCosts)}
              />
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <div className="col-span-1">
                <ChartCard 
                  title={t("chart.fixedCostsBreakdown")} 
                  description={t("chart.fixedCostsBreakdownDesc")} 
                  info={t("chart.fixedCostsBreakdownInfo")}
                  isEmpty={fixedCostsPieData.length === 0}
                >
                  <ResponsivePie
                    data={fixedCostsPieData}
                    margin={{ top: 30, right: 30, bottom: 30, left: 30 }}
                    innerRadius={0.6}
                    padAngle={1}
                    cornerRadius={3}
                    activeOuterRadiusOffset={8}
                    colors={[chartTheme.ember, chartTheme.aurora, chartTheme.mist, chartTheme.magma]}
                    borderWidth={1}
                    borderColor={{ from: "color", modifiers: [["darker", 0.2]] }}
                    enableArcLinkLabels={false}
                    arcLabelsSkipAngle={10}
                    arcLabelsTextColor={chartTheme.nocturne}
                    theme={{
                      tooltip: { container: { background: chartTheme.surfaceTeal, color: chartTheme.frost } },
                      labels: { text: { fontSize: 8 } }
                    }}
                  />
                </ChartCard>
              </div>

              <div className="col-span-1 lg:col-span-2">
                <ChartCard
                  title={t("fixedCostsTable.title")}
                  description={t("chart.fixedCostsBreakdownDesc")}
                  info={t("chart.fixedCostsBreakdownInfo")}
                  isEmpty={platformFixedCosts.length === 0}
                >
                  <div className="overflow-x-auto w-full">
                    <table className="w-full text-left border-collapse text-xs">
                      <thead>
                        <tr className="border-b border-frost/10 text-mist/60 font-semibold font-mono uppercase tracking-wider">
                          <th className="py-2.5 px-3">{t("fixedCostsTable.name")}</th>
                          <th className="py-2.5 px-3">{t("fixedCostsTable.provider")}</th>
                          <th className="py-2.5 px-3">{t("fixedCostsTable.billingPeriod")}</th>
                          <th className="py-2.5 px-3 text-right">{t("fixedCostsTable.amount")}</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-frost/5 text-frost">
                        {platformFixedCosts.map((cost) => (
                          <tr key={cost.id} className="hover:bg-frost/5 transition-colors">
                            <td className="py-2.5 px-3 font-medium">{cost.name}</td>
                            <td className="py-2.5 px-3">
                              <span className={`px-2 py-0.5 rounded text-[9px] font-semibold uppercase tracking-wider ${
                                cost.provider === "GCP" 
                                  ? "bg-ember/10 text-ember border border-ember/20" 
                                  : "bg-aurora/10 text-aurora border border-aurora/20"
                              }`}>
                                {cost.provider}
                              </span>
                            </td>
                            <td className="py-2.5 px-3 text-mist/60 font-serif italic">
                              {t(`fixedCostsTable.${cost.billingPeriod}`) || cost.billingPeriod}
                            </td>
                            <td className="py-2.5 px-3 text-right font-mono font-medium">
                              {currency === "PLN" 
                                ? `${(cost.amountUsd * plnRate).toFixed(2)} PLN`
                                : `${cost.amountUsd.toFixed(2)} USD`
                              }
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </ChartCard>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── AI Quality Tab ── */}
      {activeTab === "quality" && (
        <div className="flex flex-col gap-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <KpiCard title={t("kpi.avgLatency")} info={t("kpi.avgLatencyInfo")} value={data.kpiAvgPipelineLatency / 60} suffix=" min" decimals={1} />
            <KpiCard title={t("kpi.failureRate7d")} info={t("kpi.failureRate7dInfo")} value={data.kpiFailureRate7d * 100} suffix="%" decimals={2} />
            <KpiCard title={t("kpi.relabelRate")} info={t("kpi.relabelRateInfo")} value={data.kpiRelabelRate * 100} suffix="%" decimals={1} />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <ChartCard title={t("chart.satisfactionTrend")} description={t("chart.satisfactionTrendDesc")} info={t("chart.satisfactionTrendInfo")} isEmpty={!hasData(data.satisfactionTrend)}>
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data.satisfactionTrend} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorSatisfaction" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor={chartTheme.ember} stopOpacity={0.4}/>
                      <stop offset="95%" stopColor={chartTheme.ember} stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="label" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} domain={[0, 100]} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Area type="monotone" dataKey="satisfactionPct" name="%" stroke={chartTheme.ember} fillOpacity={1} fill="url(#colorSatisfaction)" strokeWidth={2} />
                </AreaChart>
              </ResponsiveContainer>
            </ChartCard>

            <ChartCard title={t("chart.latencyTrend")} description={t("chart.latencyTrendDesc")} info={t("chart.latencyTrendInfo")} isEmpty={!hasData(data.latencyTrend)}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={data.latencyTrend} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="label" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Legend wrapperStyle={{ fontSize: 10, color: chartTheme.mist }} />
                  <Line type="monotone" dataKey="p50" name="P50 (mediana)" stroke={chartTheme.aurora} strokeWidth={2} dot={false} />
                  <Line type="monotone" dataKey="p95" name="P95" stroke={chartTheme.magma} strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </ChartCard>

            <ChartCard title={t("chart.issueCategories")} description={t("chart.issueCategoriesDesc")} info={t("chart.issueCategoriesInfo")} isEmpty={!hasData(issueCategoriesData)}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={issueCategoriesData} layout="vertical" margin={{ left: 20, right: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis type="number" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis dataKey="category" type="category" stroke={chartTheme.mist} fontSize={10} tickLine={false} width={80} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Bar dataKey="count" fill={chartTheme.magma} radius={[0, 4, 4, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </ChartCard>

            <ChartCard title={t("chart.failureRateTrend")} description={t("chart.failureRateTrendDesc")} info={t("chart.failureRateTrendInfo")} isEmpty={!hasData(data.failureRateTrend)}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={data.failureRateTrend} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="label" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Line type="monotone" dataKey="failureRate" name="%" stroke={chartTheme.magma} strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </ChartCard>
          </div>
        </div>
      )}

      {/* ── Funnel & Retention Tab ── */}
      {activeTab === "funnel" && (
        <div className="flex flex-col gap-6">
          <div className="grid grid-cols-1 md:grid-cols-1 gap-6">
            <KpiCard title={t("kpi.retention30d")} info={t("kpi.retention30dInfo")} value={data.kpi30dRetention} suffix="%" decimals={1} />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {funnelData.length > 0 && (
              <ChartCard title={t("chart.funnel")} description={t("chart.funnelDesc")} info={t("chart.funnelInfo")}>
                <ResponsiveFunnel
                  data={funnelData}
                  margin={{ top: 20, right: 20, bottom: 20, left: 20 }}
                  valueFormat=">-.0f"
                  colors={{ scheme: "spectral" }}
                  borderWidth={20}
                  labelColor={chartTheme.frost}
                  theme={{
                    tooltip: { container: { background: chartTheme.surfaceTeal, color: chartTheme.frost } },
                    labels: { text: { fontSize: 10 } }
                  }}
                />
              </ChartCard>
            )}

            <ChartCard title={t("chart.activationTime")} description={t("chart.activationTimeDesc")} info={t("chart.activationTimeInfo")} isEmpty={!hasNonZeroData(activationTimeHistogramData, "count")}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={activationTimeHistogramData} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="bucketLabel" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Bar dataKey="count" fill={chartTheme.aurora} radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </ChartCard>

            {cohortHeatmapData.length > 0 && (
              <div className="col-span-1 lg:col-span-2">
                <ChartCard title={t("chart.cohortRetention")} description={t("chart.cohortRetentionDesc")} info={t("chart.cohortRetentionInfo")}>
                  <ResponsiveHeatMap
                    data={cohortHeatmapData}
                    margin={{ top: 30, right: 30, bottom: 30, left: 100 }}
                    colors={{
                      type: "sequential",
                      scheme: "blues",
                    }}
                    emptyColor="#555"
                    enableLabels={true}
                    label={(cell: any) => cell.value === 0 ? "" : `${Number(cell.value).toFixed(0)}%`}
                    labelTextColor={getContrastColor}
                    theme={{
                      tooltip: { container: { background: chartTheme.surfaceTeal, color: chartTheme.frost } },
                      axis: {
                        ticks: { text: { fill: chartTheme.mist, fontSize: 10 } }
                      }
                    }}
                  />
                </ChartCard>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── Operations Tab ── */}
      {activeTab === "ops" && (
        <div className="flex flex-col gap-6">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <KpiCard
              title={t("kpi.avgSessionDuration")}
              info={t("kpi.avgSessionDurationInfo")}
              value={data.kpiAvgSessionDuration / 60}
              suffix=" min"
              decimals={1}
            />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <ChartCard title={t("chart.sessionDurationTrend")} description={t("chart.sessionDurationTrendDesc")} info={t("chart.sessionDurationTrendInfo")} isEmpty={!hasNonZeroData(sessionDurationTrendData, "value")}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={sessionDurationTrendData} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="label" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <Tooltip
                    contentStyle={tooltipStyle}
                    formatter={(value: any) => [`${value} min`, ""]}
                  />
                  <Line type="monotone" dataKey="value" name="Średnia" stroke={chartTheme.aurora} strokeWidth={2} dot={true} />
                </LineChart>
              </ResponsiveContainer>
            </ChartCard>

            <ChartCard title={t("chart.uploadFailures")} description={t("chart.uploadFailuresDesc")} info={t("chart.uploadFailuresInfo")} isEmpty={!hasData(data.uploadFailuresTrend)}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={data.uploadFailuresTrend} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="label" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Line type="monotone" dataKey="failureRate" name="%" stroke={chartTheme.magma} strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </ChartCard>

            {hourlyHeatmapData.length > 0 && (
              <div className="col-span-1 lg:col-span-2">
                <ChartCard title={t("chart.hourlyHeatmap")} description={t("chart.hourlyHeatmapDesc")} info={t("chart.hourlyHeatmapInfo")}>
                  <ResponsiveHeatMap
                    data={hourlyHeatmapData}
                    margin={{ top: 30, right: 30, bottom: 30, left: 100 }}
                    colors={{
                      type: "sequential",
                      scheme: "viridis",
                    }}
                    emptyColor="#555"
                    enableLabels={false}
                    theme={{
                      tooltip: { container: { background: chartTheme.surfaceTeal, color: chartTheme.frost } },
                      axis: {
                        ticks: { text: { fill: chartTheme.mist, fontSize: 10 } }
                      }
                    }}
                  />
                </ChartCard>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── Report Feedback Tab ── */}
      {activeTab === "feedback" && (
        <div className="flex flex-col gap-6">
          {/* Feedback header */}
          <div>
            <h2 className="font-display text-frost text-xl font-semibold tracking-wide">
              {t("feedback.title")}
            </h2>
            <p className="font-serif text-xs text-mist mt-1">
              {t("feedback.subtitle")}
            </p>
          </div>

          {/* KPI Cards */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <KpiCard title={t("feedback.kpiTotal")} info={t("feedback.kpiTotalInfo")} value={Number(data.kpiRatingsTotal)} />
            <KpiCard title={t("feedback.kpiPositive")} info={t("feedback.kpiPositiveInfo")} value={Number(data.kpiRatingsPositive)} />
            <KpiCard title={t("feedback.kpiNegative")} info={t("feedback.kpiNegativeInfo")} value={Number(data.kpiRatingsNegative)} />
            <KpiCard title={t("feedback.kpiWithNotes")} info={t("feedback.kpiWithNotesInfo")} value={Number(data.kpiRatingsWithNotes)} />
          </div>

          {/* Charts — reuse existing satisfaction trend + issue categories */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <ChartCard title={t("chart.satisfactionTrend")} description={t("chart.satisfactionTrendDesc")} info={t("chart.satisfactionTrendInfo")} isEmpty={!hasData(data.satisfactionTrend)}>
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data.satisfactionTrend} margin={{ left: -20, right: 10, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorSatisfactionFb" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor={chartTheme.ember} stopOpacity={0.4}/>
                      <stop offset="95%" stopColor={chartTheme.ember} stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis dataKey="label" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis stroke={chartTheme.mist} fontSize={10} tickLine={false} domain={[0, 100]} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Area type="monotone" dataKey="satisfactionPct" name="%" stroke={chartTheme.ember} fillOpacity={1} fill="url(#colorSatisfactionFb)" strokeWidth={2} />
                </AreaChart>
              </ResponsiveContainer>
            </ChartCard>

            <ChartCard title={t("chart.issueCategories")} description={t("chart.issueCategoriesDesc")} info={t("chart.issueCategoriesInfo")} isEmpty={!hasData(issueCategoriesData)}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={issueCategoriesData} layout="vertical" margin={{ left: 20, right: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={chartTheme.glassBorder} opacity={0.2} />
                  <XAxis type="number" stroke={chartTheme.mist} fontSize={10} tickLine={false} />
                  <YAxis dataKey="category" type="category" stroke={chartTheme.mist} fontSize={10} tickLine={false} width={80} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Bar dataKey="count" fill={chartTheme.magma} radius={[0, 4, 4, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </ChartCard>
          </div>

          {/* Filters */}
          <div className="flex flex-wrap items-center gap-3 p-4 rounded-card bg-frost/[0.02] border border-frost/10">
            <select
              value={feedbackRatingFilter}
              onChange={(e) => { setFeedbackRatingFilter(e.target.value); setFeedbackPage(0); }}
              className="bg-frost/5 border border-frost/10 text-frost text-xs font-mono rounded-button px-3 py-2 focus:outline-none focus:border-ember/40"
            >
              <option value="">{t("feedback.filterAll")}</option>
              <option value="positive">{t("feedback.filterPositive")}</option>
              <option value="negative">{t("feedback.filterNegative")}</option>
            </select>

            <select
              value={feedbackStatusFilter}
              onChange={(e) => { setFeedbackStatusFilter(e.target.value); setFeedbackPage(0); }}
              className="bg-frost/5 border border-frost/10 text-frost text-xs font-mono rounded-button px-3 py-2 focus:outline-none focus:border-ember/40"
            >
              <option value="">{t("feedback.filterAll")}</option>
              <option value="pending">{t("feedback.filterPending")}</option>
              <option value="done">{t("feedback.filterDone")}</option>
            </select>

            <input
              type="text"
              value={feedbackSearch}
              onChange={(e) => { setFeedbackSearch(e.target.value); setFeedbackPage(0); }}
              placeholder={t("feedback.searchPlaceholder")}
              className="bg-frost/5 border border-frost/10 text-frost text-xs font-mono rounded-button px-3 py-2 w-64 focus:outline-none focus:border-ember/40 placeholder:text-mist/40"
            />
          </div>

          {/* Ratings Table */}
          {feedbackLoading ? (
            <div className="animate-pulse space-y-3">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="h-14 bg-frost/5 rounded-card" />
              ))}
            </div>
          ) : feedbackRatings.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-center">
              <div className="text-mist text-lg font-semibold mb-2">{t("feedback.noData")}</div>
              <div className="text-mist/60 text-sm">{t("feedback.noDataHint")}</div>
            </div>
          ) : (
            <div className="overflow-x-auto rounded-card border border-frost/10">
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="border-b border-frost/10 text-mist/60 font-semibold font-mono uppercase tracking-wider">
                    <th className="py-3 px-4">{t("feedback.tableTherapist")}</th>
                    <th className="py-3 px-4">{t("feedback.tableRating")}</th>
                    <th className="py-3 px-4">{t("feedback.tableIssues")}</th>
                    <th className="py-3 px-4 min-w-[200px]">{t("feedback.tableNotes")}</th>
                    <th className="py-3 px-4">{t("feedback.tableDate")}</th>
                    <th className="py-3 px-4">{t("feedback.tableStatus")}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-frost/5 text-frost">
                  {feedbackRatings.map((r) => (
                    <tr key={r.id} className="hover:bg-frost/[0.03] transition-colors">
                      <td className="py-3 px-4">
                        <div className="font-medium">{r.therapistName}</div>
                        <div className="text-mist/50 text-[10px]">{r.therapistEmail}</div>
                      </td>
                      <td className="py-3 px-4">
                        <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold uppercase tracking-wider ${
                          r.rating === "positive"
                            ? "bg-aurora/10 text-aurora border border-aurora/20"
                            : "bg-magma/10 text-magma border border-magma/20"
                        }`}>
                          {r.rating === "positive" ? "👍" : "👎"} {t(`feedback.${r.rating}`)}
                        </span>
                      </td>
                      <td className="py-3 px-4">
                        <div className="flex flex-wrap gap-1">
                          {r.issues && r.issues.length > 0 ? r.issues.map((iss) => (
                            <span key={iss} className="px-1.5 py-0.5 rounded bg-frost/5 border border-frost/10 text-mist text-[9px] font-mono">
                              {iss.replace(/_/g, " ")}
                            </span>
                          )) : <span className="text-mist/30">—</span>}
                        </div>
                      </td>
                      <td className="py-3 px-4">
                        <div className="max-w-[300px] break-words text-mist/80 font-serif text-[11px] leading-relaxed">
                          {r.notes || t("feedback.noNotes")}
                        </div>
                      </td>
                      <td className="py-3 px-4 text-mist/60 font-mono text-[10px] whitespace-nowrap">
                        {r.createdAt ? new Date(Number(r.createdAt.seconds) * 1000).toLocaleDateString(locale, { day: "2-digit", month: "2-digit", year: "numeric" }) : "—"}
                      </td>
                      <td className="py-3 px-4">
                        <button
                          onClick={() => handleToggleStatus(r.id, r.adminReviewStatus)}
                          className={`px-2.5 py-1 rounded-button text-[10px] font-mono font-semibold uppercase tracking-wider transition-all cursor-pointer ${
                            r.adminReviewStatus === "done"
                              ? "bg-aurora/10 text-aurora border border-aurora/20 hover:bg-aurora/20"
                              : "bg-frost/5 text-mist border border-frost/10 hover:bg-ember/10 hover:text-ember hover:border-ember/20"
                          }`}
                          title={r.adminReviewStatus === "done" ? t("feedback.markPending") : t("feedback.markDone")}
                        >
                          {r.adminReviewStatus === "done" ? t("feedback.statusDone") : t("feedback.statusPending")}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Pagination */}
          {feedbackTotal > feedbackPageSize && (
            <div className="flex items-center justify-between px-1">
              <button
                onClick={() => setFeedbackPage((p) => Math.max(0, p - 1))}
                disabled={feedbackPage === 0}
                className="px-3 py-1.5 text-xs font-mono rounded-button bg-frost/5 border border-frost/10 text-mist hover:text-frost disabled:opacity-30 disabled:cursor-not-allowed transition"
              >
                {t("feedback.prev")}
              </button>
              <span className="text-mist/60 font-mono text-[10px]">
                {t("feedback.pageOf", { page: feedbackPage + 1, total: Math.ceil(feedbackTotal / feedbackPageSize) })}
              </span>
              <button
                onClick={() => setFeedbackPage((p) => p + 1)}
                disabled={(feedbackPage + 1) * feedbackPageSize >= feedbackTotal}
                className="px-3 py-1.5 text-xs font-mono rounded-button bg-frost/5 border border-frost/10 text-mist hover:text-frost disabled:opacity-30 disabled:cursor-not-allowed transition"
              >
                {t("feedback.next")}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
