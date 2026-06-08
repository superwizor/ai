// Admin CRM Dashboard — Marcin's operational tool for managing users.
//
// Features:
// - Filter by plan tier (Beta/Trial/Paid/Churned)
// - Credit alert flags (≤1 critical, ≤3 warning, ≤5 low)
// - Expiry alerts (≤3d imminent, ≤7d soon)
// - Urgency-sorted (most critical first)
// - Quick actions: call, email, view subscription
// - Inline email composer
// - CSV export
//
// Data source: billing-svc GET /admin/crm/subscribers via /api/admin/crm proxy.

"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { TableSkeleton } from "./TableSkeleton";

// ─── Types ───────────────────────────────────────────────────

type CRMSubscriber = {
  user_id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  professional_title: string;
  created_at: string;
  subscription_id: string;
  plan_tier: string;
  plan_display_name: string;
  sub_status: string;
  provider: string;
  period_start: string;
  period_end: string;
  days_until_renewal: number;
  tokens_limit: number;
  tokens_used: number;
  tokens_remaining: number;
  usage_pct: number;
  total_sessions: number;
  credit_alert: string;
  expiry_alert: string;
  urgency_score: number;
  org_id: string;
  org_name: string;
};

type FilterState = {
  tier: string;
  status: string;
  alert: string;
  search: string;
};

// ─── Constants ───────────────────────────────────────────────

const TIER_OPTIONS = [
  { value: "", label: "Wszystkie plany" },
  { value: "BETA", label: "🧪 Beta" },
  { value: "TRIAL", label: "🆓 Trial" },
  { value: "SOLO", label: "🌿 Równowaga" },
  { value: "PRO", label: "🌸 Rozkwit" },
  { value: "CLINIC", label: "🏥 Klinika" },
];

const STATUS_OPTIONS = [
  { value: "", label: "Wszystkie statusy" },
  { value: "ACTIVE", label: "✅ Aktywny" },
  { value: "TRIALING", label: "⏳ Trial" },
  { value: "CANCELED", label: "❌ Anulowany" },
  { value: "PAST_DUE", label: "⚠️ Zaległy" },
];

const ALERT_OPTIONS = [
  { value: "", label: "Wszystkie alerty" },
  { value: "critical", label: "🔴 Krytyczne (≤1 kredyt)" },
  { value: "warning", label: "🟡 Ostrzeżenie (≤3 kredyty)" },
];

// ─── Component ───────────────────────────────────────────────

export function CRMDashboard() {
  const t = useTranslations("admin.crm");
  const [subscribers, setSubscribers] = useState<CRMSubscriber[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filters, setFilters] = useState<FilterState>({
    tier: "",
    status: "",
    alert: "",
    search: "",
  });
  const [emailTarget, setEmailTarget] = useState<CRMSubscriber | null>(null);
  const [emailBody, setEmailBody] = useState("");
  const [emailSending, setEmailSending] = useState(false);

  const fetchSubscribers = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const params = new URLSearchParams();
      if (filters.tier) params.set("tier", filters.tier);
      if (filters.status) params.set("status", filters.status);
      if (filters.alert) params.set("alert", filters.alert);

      const qs = params.toString();
      const resp = await fetch(`/api/admin/crm${qs ? `?${qs}` : ""}`);

      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}`);
      }

      const data = await resp.json();
      setSubscribers(data.subscribers || []);
    } catch (err: any) {
      setError(err.message || "Błąd ładowania danych CRM");
    } finally {
      setLoading(false);
    }
  }, [filters.tier, filters.status, filters.alert]);

  useEffect(() => {
    void fetchSubscribers();
  }, [fetchSubscribers]);

  // Local search filter (name/email)
  const filtered = subscribers.filter((s) => {
    if (!filters.search) return true;
    const q = filters.search.toLowerCase();
    return (
      s.first_name.toLowerCase().includes(q) ||
      s.last_name.toLowerCase().includes(q) ||
      s.email.toLowerCase().includes(q) ||
      s.org_name.toLowerCase().includes(q)
    );
  });

  // Stats
  const stats = {
    total: filtered.length,
    critical: filtered.filter((s) => s.credit_alert === "critical").length,
    warning: filtered.filter(
      (s) => s.credit_alert === "warning" || s.credit_alert === "low",
    ).length,
    expiring: filtered.filter((s) => s.expiry_alert !== "").length,
    churned: filtered.filter((s) => s.sub_status === "CANCELED").length,
  };

  // CSV export
  const exportCSV = () => {
    const headers = [
      "Imię",
      "Nazwisko",
      "Email",
      "Telefon",
      "Plan",
      "Status",
      "Sesje (łącznie)",
      "Kredyty użyte",
      "Kredyty pozostałe",
      "Limit",
      "Koniec okresu",
      "Dni do odnowienia",
      "Alert kredyty",
      "Alert wygaśnięcie",
      "Pilność",
      "Dołączył",
    ];
    const rows = filtered.map((s) => [
      s.first_name,
      s.last_name,
      s.email,
      s.phone,
      s.plan_display_name,
      s.sub_status,
      s.total_sessions,
      s.tokens_used,
      s.tokens_remaining,
      s.tokens_limit,
      s.period_end,
      s.days_until_renewal,
      s.credit_alert,
      s.expiry_alert,
      s.urgency_score,
      s.created_at,
    ]);
    const csv =
      [headers.join(","), ...rows.map((r) => r.join(","))].join("\n");
    const blob = new Blob([csv], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `superwizor-crm-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // Email send (via mailto: for now — Resend integration TODO)
  const sendEmail = () => {
    if (!emailTarget) return;
    const subject = encodeURIComponent("SuperWizor AI — wiadomość od zespołu");
    const body = encodeURIComponent(emailBody);
    window.open(
      `mailto:${emailTarget.email}?subject=${subject}&body=${body}`,
      "_blank",
    );
    setEmailTarget(null);
    setEmailBody("");
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8 max-w-[1400px] mx-auto">
      {/* Header */}
      <header className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 mb-6">
        <div>
          <p className="font-mono text-xs uppercase text-ember tracking-[0.2em] mb-1.5">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-[var(--tracking-display)]">
            {t("title")}
          </h1>
          <p className="font-serif text-mist mt-1 text-sm">{t("subhead")}</p>
        </div>
        <button
          onClick={exportCSV}
          className="rounded-button border border-ember/30 bg-ember/5 text-ember px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-ember/10 transition self-start sm:self-auto"
        >
          📥 Eksport CSV
        </button>
      </header>

      {/* KPI Bars */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-6">
        <KPIChip label="Łącznie" value={stats.total} color="frost" />
        <KPIChip
          label="🔴 Krytyczne"
          value={stats.critical}
          color="magma"
        />
        <KPIChip label="🟡 Ostrzeżenie" value={stats.warning} color="ember" />
        <KPIChip
          label="⏰ Wygasa"
          value={stats.expiring}
          color="aurora"
        />
        <KPIChip label="❌ Churned" value={stats.churned} color="mist" />
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-2 mb-6">
        <FilterSelect
          value={filters.tier}
          onChange={(v) => setFilters((f) => ({ ...f, tier: v }))}
          options={TIER_OPTIONS}
        />
        <FilterSelect
          value={filters.status}
          onChange={(v) => setFilters((f) => ({ ...f, status: v }))}
          options={STATUS_OPTIONS}
        />
        <FilterSelect
          value={filters.alert}
          onChange={(v) => setFilters((f) => ({ ...f, alert: v }))}
          options={ALERT_OPTIONS}
        />
        <input
          type="search"
          value={filters.search}
          onChange={(e) =>
            setFilters((f) => ({ ...f, search: e.target.value }))
          }
          placeholder="Szukaj (imię, email, organizacja)..."
          className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember focus:bg-frost/[0.07] placeholder:text-mist/40 transition flex-1 min-w-[200px]"
        />
      </div>

      {/* Table */}
      {loading && <TableSkeleton columns={8} />}

      {error && (
        <div className="rounded-card border border-magma/40 bg-magma/10 px-4 py-6 text-center">
          <p className="font-serif text-frost text-sm">{error}</p>
          <button
            onClick={() => void fetchSubscribers()}
            className="mt-3 inline-flex items-center rounded-button border border-frost/20 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-frost hover:bg-frost/5"
          >
            Ponów
          </button>
        </div>
      )}

      {!loading && !error && filtered.length === 0 && (
        <p className="font-serif text-mist text-center py-12">
          Brak użytkowników dla wybranych filtrów
        </p>
      )}

      {!loading && !error && filtered.length > 0 && (
        <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
          <table className="w-full text-sm">
            <thead className="bg-frost/5">
              <tr>
                <th className="text-left px-3 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                  Użytkownik
                </th>
                <th className="text-left px-3 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                  Plan
                </th>
                <th className="text-center px-3 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                  Kredyty
                </th>
                <th className="text-center px-3 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                  Sesje
                </th>
                <th className="text-center px-3 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                  Odnowienie
                </th>
                <th className="text-center px-3 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                  Alerty
                </th>
                <th className="text-right px-3 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                  Akcje
                </th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((s) => (
                <CRMRow
                  key={s.subscription_id}
                  sub={s}
                  onEmail={() => {
                    setEmailTarget(s);
                    setEmailBody(
                      `Cześć ${s.first_name},\n\nPiszę do Ciebie w sprawie Twojego konta w SuperWizor AI.\n\n`,
                    );
                  }}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Email Composer Modal */}
      {emailTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-nocturne/70 backdrop-blur-sm">
          <div className="bg-obsidian border border-frost/15 rounded-card p-6 w-full max-w-lg mx-4 shadow-2xl">
            <h3 className="font-display text-frost text-lg font-semibold mb-1">
              ✉️ Napisz do {emailTarget.first_name} {emailTarget.last_name}
            </h3>
            <p className="font-mono text-xs text-mist/60 mb-4">
              {emailTarget.email}
            </p>
            <textarea
              value={emailBody}
              onChange={(e) => setEmailBody(e.target.value)}
              rows={8}
              className="w-full rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-serif text-sm focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition resize-y mb-4"
              placeholder="Treść wiadomości..."
            />
            <div className="flex justify-end gap-3">
              <button
                onClick={() => {
                  setEmailTarget(null);
                  setEmailBody("");
                }}
                className="rounded-button border border-frost/15 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost transition"
              >
                Anuluj
              </button>
              <button
                onClick={sendEmail}
                disabled={emailSending || !emailBody.trim()}
                className="rounded-button bg-ember text-obsidian px-5 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:brightness-110 transition disabled:opacity-50"
              >
                {emailSending ? "Wysyłanie..." : "Otwórz w mailu"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Sub-components ──────────────────────────────────────────

function CRMRow({
  sub,
  onEmail,
}: {
  sub: CRMSubscriber;
  onEmail: () => void;
}) {
  const tierBadge = getTierBadge(sub.plan_tier);
  const statusBadge = getStatusBadge(sub.sub_status);

  return (
    <tr className="border-t border-frost/5 hover:bg-frost/[0.03] transition-colors">
      {/* User */}
      <td className="px-3 py-3">
        <div className="flex flex-col gap-0.5">
          <span className="font-display text-frost text-sm font-medium">
            {sub.first_name} {sub.last_name}
          </span>
          <span className="font-mono text-[11px] text-mist/60">
            {sub.email}
          </span>
          {sub.professional_title && (
            <span className="font-serif text-[11px] text-mist/40 italic">
              {sub.professional_title}
            </span>
          )}
        </div>
      </td>

      {/* Plan */}
      <td className="px-3 py-3">
        <div className="flex flex-col gap-1">
          <span className={`inline-flex items-center px-2 py-0.5 rounded text-[10px] font-semibold uppercase tracking-wider w-fit ${tierBadge}`}>
            {sub.plan_display_name}
          </span>
          <span className={`inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium w-fit ${statusBadge}`}>
            {sub.sub_status}
          </span>
        </div>
      </td>

      {/* Credits */}
      <td className="px-3 py-3 text-center">
        <div className="flex flex-col items-center gap-1">
          <span
            className={`font-mono text-sm font-bold ${
              sub.credit_alert === "critical"
                ? "text-magma"
                : sub.credit_alert === "warning"
                  ? "text-ember"
                  : "text-frost"
            }`}
          >
            {sub.tokens_remaining}/{sub.tokens_limit}
          </span>
          {/* Usage bar */}
          <div className="w-16 h-1.5 bg-frost/10 rounded-full overflow-hidden">
            <div
              className={`h-full rounded-full transition-all ${
                sub.usage_pct >= 90
                  ? "bg-magma"
                  : sub.usage_pct >= 70
                    ? "bg-ember"
                    : "bg-aurora"
              }`}
              style={{ width: `${Math.min(sub.usage_pct, 100)}%` }}
            />
          </div>
          <span className="font-mono text-[9px] text-mist/50">
            {sub.usage_pct.toFixed(0)}%
          </span>
        </div>
      </td>

      {/* Sessions */}
      <td className="px-3 py-3 text-center">
        <span className="font-mono text-sm text-frost">
          {sub.total_sessions}
        </span>
      </td>

      {/* Renewal */}
      <td className="px-3 py-3 text-center">
        <div className="flex flex-col items-center gap-0.5">
          <span
            className={`font-mono text-xs ${
              sub.days_until_renewal <= 3
                ? "text-magma font-bold"
                : sub.days_until_renewal <= 7
                  ? "text-ember"
                  : "text-mist"
            }`}
          >
            {sub.days_until_renewal > 0
              ? `${sub.days_until_renewal}d`
              : "wygasł"}
          </span>
          <span className="font-mono text-[9px] text-mist/40">
            {sub.period_end}
          </span>
        </div>
      </td>

      {/* Alerts */}
      <td className="px-3 py-3 text-center">
        <div className="flex flex-col items-center gap-1">
          {sub.credit_alert === "critical" && (
            <span className="px-1.5 py-0.5 rounded bg-magma/15 text-magma text-[9px] font-bold uppercase">
              🔴 ≤1 kredyt
            </span>
          )}
          {sub.credit_alert === "warning" && (
            <span className="px-1.5 py-0.5 rounded bg-ember/15 text-ember text-[9px] font-bold uppercase">
              🟡 ≤3 kredyty
            </span>
          )}
          {sub.credit_alert === "low" && (
            <span className="px-1.5 py-0.5 rounded bg-mist/15 text-mist text-[9px] font-bold uppercase">
              🟠 ≤5 kredytów
            </span>
          )}
          {sub.expiry_alert === "imminent" && (
            <span className="px-1.5 py-0.5 rounded bg-magma/15 text-magma text-[9px] font-bold uppercase">
              ⏰ ≤3 dni
            </span>
          )}
          {sub.expiry_alert === "soon" && (
            <span className="px-1.5 py-0.5 rounded bg-ember/15 text-ember text-[9px] font-bold uppercase">
              ⏰ ≤7 dni
            </span>
          )}
          {!sub.credit_alert && !sub.expiry_alert && (
            <span className="text-mist/30 text-[10px]">—</span>
          )}
        </div>
      </td>

      {/* Actions */}
      <td className="px-3 py-3 text-right">
        <div className="inline-flex gap-1.5">
          {sub.phone && (
            <a
              href={`tel:${sub.phone}`}
              title={`Zadzwoń: ${sub.phone}`}
              className="p-1.5 rounded-lg bg-frost/5 border border-frost/10 text-aurora hover:bg-frost/10 hover:border-aurora/30 transition"
            >
              <PhoneIcon />
            </a>
          )}
          <button
            onClick={onEmail}
            title="Napisz email"
            className="p-1.5 rounded-lg bg-frost/5 border border-frost/10 text-ember hover:bg-frost/10 hover:border-ember/30 transition"
          >
            <MailIcon />
          </button>
        </div>
      </td>
    </tr>
  );
}

function KPIChip({
  label,
  value,
  color,
}: {
  label: string;
  value: number;
  color: string;
}) {
  return (
    <div className="rounded-card border border-frost/10 bg-frost/[0.03] px-3 py-3 text-center">
      <div className={`font-display text-${color} text-2xl font-bold`}>
        {value}
      </div>
      <div className="font-mono text-[9px] text-mist/60 uppercase tracking-[0.1em] mt-1">
        {label}
      </div>
    </div>
  );
}

function FilterSelect({
  value,
  onChange,
  options,
}: {
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <select
      value={value}
      onChange={(e) => onChange(e.target.value)}
      className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3 py-2 font-display text-sm focus:outline-none focus:border-ember transition cursor-pointer"
    >
      {options.map((o) => (
        <option key={o.value} value={o.value}>
          {o.label}
        </option>
      ))}
    </select>
  );
}

function getTierBadge(tier: string): string {
  switch (tier) {
    case "BETA":
      return "bg-aurora/10 text-aurora border border-aurora/20";
    case "TRIAL":
      return "bg-mist/10 text-mist border border-mist/20";
    case "SOLO":
      return "bg-ember/10 text-ember border border-ember/20";
    case "PRO":
      return "bg-magma/10 text-magma border border-magma/20";
    case "CLINIC":
      return "bg-frost/10 text-frost border border-frost/20";
    default:
      return "bg-frost/5 text-mist border border-frost/10";
  }
}

function getStatusBadge(status: string): string {
  switch (status) {
    case "ACTIVE":
      return "bg-aurora/10 text-aurora";
    case "TRIALING":
      return "bg-ember/10 text-ember";
    case "CANCELED":
      return "bg-magma/10 text-magma";
    case "PAST_DUE":
      return "bg-magma/15 text-magma";
    default:
      return "bg-frost/5 text-mist";
  }
}

function PhoneIcon() {
  return (
    <svg
      className="w-4 h-4"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"
      />
    </svg>
  );
}

function MailIcon() {
  return (
    <svg
      className="w-4 h-4"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={1.5}
        d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
      />
    </svg>
  );
}
