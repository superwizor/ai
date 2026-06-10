// CRMDashboard — Marcin's relationship management hub.
//
// Features:
// - Priority inbox ("Dziś do kontaktu" — overdue + today's follow-ups)
// - Urgency-sorted subscriber table with credit/expiry alerts
// - Filter by tier, status, alert, tags, free-text search
// - Slide-out detail drawer per user (notes, tags, follow-ups, lifecycle)
// - Email composer with templates (mailto: kontakt@superwizor.ai)
// - User exclusion/blocking
// - CSV export

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

type UserDetail = {
  user_id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  professional_title: string;
  created_at: string;
  plan_tier: string;
  sub_status: string;
  tokens_remaining: number;
  tokens_limit: number;
  tokens_used: number;
  period_end: string;
  days_until_renewal: number;
  total_sessions: number;
  notes: CRMNote[];
  tags: CRMTag[];
  follow_ups: FollowUp[];
  excluded: boolean;
  lifecycle_stage: string;
  last_session_at: string;
};

type CRMNote = { id: string; body: string; created_at: string };
type CRMTag = { id: string; tag: string };
type FollowUp = {
  id: string;
  target_user_id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  due_date: string;
  note: string;
  completed: boolean;
  overdue: boolean;
  created_at: string;
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
  { value: "critical", label: "🔴 Krytyczne (≤1)" },
  { value: "warning", label: "🟡 Ostrzeżenie (≤3)" },
];

const EMAIL_TEMPLATES = [
  {
    id: "after_first",
    label: "Po pierwszej sesji",
    subject: "Jak przebiegła Twoja pierwsza sesja?",
    body: `Cześć {name},

Widzę, że Twoja pierwsza sesja w SuperWizor AI jest już za Tobą. Mam nadzieję, że raport spełnił Twoje oczekiwania.

Jeśli masz jakiekolwiek pytania lub coś nie działa tak jak powinno — napisz do mnie lub zadzwoń. Jestem tu, żeby pomóc.

Pozdrawiam,
Marcin — zespół SuperWizor AI`,
  },
  {
    id: "credits_low",
    label: "Kończą się kredyty",
    subject: "Zostały Ci {remaining} sesje w tym okresie",
    body: `Cześć {name},

Chciałem Ci dać znać, że zostało Ci {remaining} sesji do końca bieżącego okresu ({period_end}).

Jeśli potrzebujesz więcej — napisz do mnie, a pomogę dobrać odpowiedni plan.

Pozdrawiam,
Marcin — zespół SuperWizor AI`,
  },
  {
    id: "trial_end",
    label: "Koniec triala",
    subject: "Twój okres próbny dobiega końca",
    body: `Cześć {name},

Twój okres próbny SuperWizor AI kończy się {period_end}. Mam nadzieję, że udało Ci się sprawdzić możliwości aplikacji.

Chętnie porozmawiam o tym, jak SuperWizor AI może na stałe wspierać Twoją praktykę. Zadzwonię do Ciebie w najbliższych dniach — ale jeśli wolisz, napisz kiedy Ci pasuje.

Pozdrawiam,
Marcin — zespół SuperWizor AI`,
  },
  {
    id: "check_in",
    label: "Check-in",
    subject: "Jak leci z SuperWizorem?",
    body: `Cześć {name},

Piszę, żeby sprawdzić czy wszystko w porządku z aplikacją. Jeśli masz jakiekolwiek pytania, sugestie lub coś Ci przeszkadza — jestem otwarty na feedback.

Twoje zdanie jest dla nas bardzo ważne.

Pozdrawiam,
Marcin — zespół SuperWizor AI`,
  },
  {
    id: "dormant",
    label: "Brak aktywności",
    subject: "Tęsknimy za Tobą w SuperWizorze",
    body: `Cześć {name},

Zauważyłem, że nie korzystałeś/aś z SuperWizor AI od jakiegoś czasu. Wszystko w porządku?

Jeśli napotkałeś/aś jakiś problem — chętnie pomogę go rozwiązać. A jeśli po prostu masz teraz mniej sesji — rozumiem, wrócisz kiedy będziesz gotowy/a.

Pozdrawiam,
Marcin — zespół SuperWizor AI`,
  },
];

const LIFECYCLE_LABELS: Record<string, { label: string; color: string; emoji: string }> = {
  new: { label: "Nowy", color: "text-frost bg-frost/10", emoji: "🆕" },
  onboarding: { label: "Onboarding", color: "text-ember bg-ember/10", emoji: "📋" },
  first_session: { label: "Pierwsza sesja", color: "text-aurora bg-aurora/10", emoji: "🎯" },
  active: { label: "Aktywny", color: "text-aurora bg-aurora/10", emoji: "✅" },
  power_user: { label: "Power User", color: "text-magma bg-magma/10", emoji: "⚡" },
  at_risk: { label: "Zagrożony", color: "text-ember bg-ember/10", emoji: "⚠️" },
  churned: { label: "Odszedł", color: "text-mist bg-mist/10", emoji: "❌" },
};

const SENDER_EMAIL = "kontakt@superwizor.ai";

// ─── Component ───────────────────────────────────────────────

export function CRMDashboard() {
  const t = useTranslations("admin.crm");
  const [subscribers, setSubscribers] = useState<CRMSubscriber[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filters, setFilters] = useState<FilterState>({
    tier: "", status: "", alert: "", search: "",
  });

  // Detail drawer
  const [selectedUser, setSelectedUser] = useState<UserDetail | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerLoading, setDrawerLoading] = useState(false);

  // Notes
  const [newNote, setNewNote] = useState("");
  const [noteSaving, setNoteSaving] = useState(false);

  // Tags
  const [newTag, setNewTag] = useState("");

  // Follow-ups
  const [followUps, setFollowUps] = useState<FollowUp[]>([]);
  const [todayCount, setTodayCount] = useState(0);
  const [overdueCount, setOverdueCount] = useState(0);

  // Email composer
  const [emailTarget, setEmailTarget] = useState<{ name: string; email: string; remaining?: number; period_end?: string } | null>(null);
  const [emailSubject, setEmailSubject] = useState("");
  const [emailBody, setEmailBody] = useState("");

  // Follow-up modal
  const [followUpTarget, setFollowUpTarget] = useState<string | null>(null);
  const [followUpDate, setFollowUpDate] = useState("");
  const [followUpNote, setFollowUpNote] = useState("");

  // ─── Data Fetching ─────────────────────────────────────────

  const fetchSubscribers = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams();
      if (filters.tier) params.set("tier", filters.tier);
      if (filters.status) params.set("status", filters.status);
      if (filters.alert) params.set("alert", filters.alert);
      const qs = params.toString();
      const resp = await fetch(`/api/admin/crm/subscribers${qs ? `?${qs}` : ""}`);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const data = await resp.json();
      setSubscribers(data.subscribers || []);
    } catch (err: any) {
      setError(err.message || "Błąd ładowania danych CRM");
    } finally {
      setLoading(false);
    }
  }, [filters.tier, filters.status, filters.alert]);

  const fetchFollowUps = useCallback(async () => {
    try {
      const resp = await fetch("/api/admin/crm/follow-ups");
      if (!resp.ok) return;
      const data = await resp.json();
      setFollowUps(data.follow_ups || []);
      setTodayCount(data.today_count || 0);
      setOverdueCount(data.overdue_count || 0);
    } catch { /* silent */ }
  }, []);

  useEffect(() => { void fetchSubscribers(); }, [fetchSubscribers]);
  useEffect(() => { void fetchFollowUps(); }, [fetchFollowUps]);

  const openUserDetail = async (userId: string) => {
    setDrawerLoading(true);
    setDrawerOpen(true);
    try {
      const resp = await fetch(`/api/admin/crm/user/${userId}/detail`);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const data = await resp.json();
      setSelectedUser(data);
    } catch (err) {
      console.error("Failed to load user detail:", err);
    } finally {
      setDrawerLoading(false);
    }
  };

  const closeDrawer = () => {
    setDrawerOpen(false);
    setTimeout(() => setSelectedUser(null), 300);
  };

  // ─── Actions ───────────────────────────────────────────────

  const addNote = async () => {
    if (!selectedUser || !newNote.trim()) return;
    setNoteSaving(true);
    try {
      await fetch("/api/admin/crm/notes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ target_user_id: selectedUser.user_id, body: newNote }),
      });
      setNewNote("");
      // Refresh detail
      await openUserDetail(selectedUser.user_id);
    } finally {
      setNoteSaving(false);
    }
  };

  const addTag = async () => {
    if (!selectedUser || !newTag.trim()) return;
    await fetch("/api/admin/crm/tags", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ target_user_id: selectedUser.user_id, tag: newTag.trim() }),
    });
    setNewTag("");
    await openUserDetail(selectedUser.user_id);
  };

  const removeTag = async (tagId: string) => {
    await fetch(`/api/admin/crm/tags/${tagId}`, { method: "DELETE" });
    if (selectedUser) await openUserDetail(selectedUser.user_id);
  };

  const excludeUser = async (userId: string) => {
    await fetch("/api/admin/crm/exclude", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ user_id: userId, reason: "excluded from CRM" }),
    });
    closeDrawer();
    void fetchSubscribers();
  };

  const createFollowUp = async () => {
    if (!followUpTarget || !followUpDate) return;
    await fetch("/api/admin/crm/follow-ups", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ target_user_id: followUpTarget, due_date: followUpDate, note: followUpNote }),
    });
    setFollowUpTarget(null);
    setFollowUpDate("");
    setFollowUpNote("");
    void fetchFollowUps();
    if (selectedUser) await openUserDetail(selectedUser.user_id);
  };

  const completeFollowUp = async (id: string) => {
    await fetch(`/api/admin/crm/follow-ups/${id}/complete`, { method: "PATCH" });
    void fetchFollowUps();
    if (selectedUser) await openUserDetail(selectedUser.user_id);
  };

  const openEmail = (sub: CRMSubscriber | UserDetail, templateId?: string) => {
    const name = sub.first_name;
    const template = templateId ? EMAIL_TEMPLATES.find((t) => t.id === templateId) : null;
    const subj = template
      ? template.subject
          .replace("{name}", name)
          .replace("{remaining}", String((sub as any).tokens_remaining ?? ""))
          .replace("{period_end}", (sub as any).period_end ?? "")
      : `SuperWizor AI — wiadomość od zespołu`;
    const body = template
      ? template.body
          .replace(/{name}/g, name)
          .replace(/{remaining}/g, String((sub as any).tokens_remaining ?? ""))
          .replace(/{period_end}/g, (sub as any).period_end ?? "")
      : `Cześć ${name},\n\n`;
    setEmailTarget({ name, email: sub.email, remaining: (sub as any).tokens_remaining, period_end: (sub as any).period_end });
    setEmailSubject(subj);
    setEmailBody(body);
  };

  const sendEmail = () => {
    if (!emailTarget) return;
    const subject = encodeURIComponent(emailSubject);
    const body = encodeURIComponent(emailBody);
    window.open(
      `mailto:${emailTarget.email}?from=${SENDER_EMAIL}&subject=${subject}&body=${body}`,
      "_blank",
    );
    setEmailTarget(null);
    setEmailSubject("");
    setEmailBody("");
  };

  // ─── Filters ───────────────────────────────────────────────

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

  const stats = {
    total: filtered.length,
    critical: filtered.filter((s) => s.credit_alert === "critical").length,
    warning: filtered.filter((s) => s.credit_alert === "warning" || s.credit_alert === "low").length,
    expiring: filtered.filter((s) => s.expiry_alert !== "").length,
    churned: filtered.filter((s) => s.sub_status === "CANCELED").length,
  };

  // CSV export
  const exportCSV = () => {
    const headers = ["Imię","Nazwisko","Email","Telefon","Plan","Status","Sesje","Kredyty użyte","Kredyty pozostałe","Limit","Koniec okresu","Dni do odnowienia","Alert","Pilność","Dołączył"];
    const rows = filtered.map((s) => [s.first_name, s.last_name, s.email, s.phone, s.plan_display_name, s.sub_status, s.total_sessions, s.tokens_used, s.tokens_remaining, s.tokens_limit, s.period_end, s.days_until_renewal, s.credit_alert || s.expiry_alert || "-", s.urgency_score, s.created_at]);
    const csv = [headers.join(","), ...rows.map((r) => r.join(","))].join("\n");
    const blob = new Blob([csv], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `superwizor-crm-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // ─── Quick date helpers ────────────────────────────────────

  const quickDate = (daysFromNow: number): string => {
    const d = new Date();
    d.setDate(d.getDate() + daysFromNow);
    return d.toISOString().slice(0, 10);
  };
  const nextMonday = (): string => {
    const d = new Date();
    const day = d.getDay();
    const diff = day === 0 ? 1 : 8 - day;
    d.setDate(d.getDate() + diff);
    return d.toISOString().slice(0, 10);
  };

  // ─── Render ────────────────────────────────────────────────

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8 max-w-[1400px] mx-auto">
      {/* Header */}
      <header className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 mb-6">
        <div>
          <p className="font-mono text-xs uppercase text-ember tracking-[0.2em] mb-1.5">{t("overline")}</p>
          <h1 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-[var(--tracking-display)]">{t("title")}</h1>
          <p className="font-serif text-mist mt-1 text-sm">{t("subhead")}</p>
        </div>
        <button onClick={exportCSV} className="rounded-button border border-ember/30 bg-ember/5 text-ember px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-ember/10 transition self-start sm:self-auto">
          📥 Eksport CSV
        </button>
      </header>

      {/* ── Priority Inbox ────────────────────────────────── */}
      {(todayCount > 0 || overdueCount > 0) && (
        <div className="mb-6 rounded-card border border-ember/30 bg-gradient-to-r from-ember/5 to-magma/5 p-4">
          <div className="flex items-center gap-3 mb-3">
            <span className="text-xl">📋</span>
            <h2 className="font-display text-frost font-semibold text-sm">
              Dziś do kontaktu: {todayCount + overdueCount} {todayCount + overdueCount === 1 ? "osoba" : overdueCount + todayCount < 5 ? "osoby" : "osób"}
              {overdueCount > 0 && <span className="text-magma ml-2">({overdueCount} zaległe!)</span>}
            </h2>
          </div>
          <div className="space-y-2">
            {followUps.filter((f) => f.overdue || f.due_date === new Date().toISOString().slice(0, 10)).slice(0, 5).map((f) => (
              <div key={f.id} className={`flex items-center justify-between rounded-lg px-3 py-2 ${f.overdue ? "bg-magma/10 border border-magma/20" : "bg-ember/10 border border-ember/20"}`}>
                <div className="flex items-center gap-3">
                  <span className="font-display text-frost text-sm font-medium">{f.first_name} {f.last_name}</span>
                  {f.note && <span className="font-serif text-mist/60 text-xs italic">— {f.note}</span>}
                  {f.overdue && <span className="text-magma font-mono text-[9px] uppercase">zaległe</span>}
                </div>
                <div className="flex gap-2">
                  {f.phone && (
                    <a href={`tel:${f.phone}`} className="p-1 rounded bg-frost/5 text-aurora hover:bg-frost/10 transition" title="Zadzwoń">
                      <PhoneIcon />
                    </a>
                  )}
                  <button onClick={() => completeFollowUp(f.id)} className="p-1 rounded bg-aurora/10 text-aurora hover:bg-aurora/20 transition text-xs font-mono" title="Oznacz jako zrobione">
                    ✓
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── KPI Chips ─────────────────────────────────────── */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-6">
        <KPIChip label="Łącznie" value={stats.total} color="frost" />
        <KPIChip label="🔴 Krytyczne" value={stats.critical} color="magma" />
        <KPIChip label="🟡 Ostrzeżenie" value={stats.warning} color="ember" />
        <KPIChip label="⏰ Wygasa" value={stats.expiring} color="aurora" />
        <KPIChip label="❌ Churned" value={stats.churned} color="mist" />
      </div>

      {/* ── Filters ───────────────────────────────────────── */}
      <div className="flex flex-wrap gap-2 mb-6">
        <FilterSelect value={filters.tier} onChange={(v) => setFilters((f) => ({ ...f, tier: v }))} options={TIER_OPTIONS} />
        <FilterSelect value={filters.status} onChange={(v) => setFilters((f) => ({ ...f, status: v }))} options={STATUS_OPTIONS} />
        <FilterSelect value={filters.alert} onChange={(v) => setFilters((f) => ({ ...f, alert: v }))} options={ALERT_OPTIONS} />
        <input
          type="search"
          value={filters.search}
          onChange={(e) => setFilters((f) => ({ ...f, search: e.target.value }))}
          placeholder="Szukaj (imię, email, organizacja)..."
          className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember focus:bg-frost/[0.07] placeholder:text-mist/40 transition flex-1 min-w-[200px]"
        />
      </div>

      {/* ── Table ─────────────────────────────────────────── */}
      {loading && <TableSkeleton columns={7} />}
      {error && (
        <div className="rounded-card border border-magma/40 bg-magma/10 px-4 py-6 text-center">
          <p className="font-serif text-frost text-sm">{error}</p>
          <button onClick={() => void fetchSubscribers()} className="mt-3 inline-flex items-center rounded-button border border-frost/20 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-frost hover:bg-frost/5">Ponów</button>
        </div>
      )}
      {!loading && !error && filtered.length === 0 && (
        <p className="font-serif text-mist text-center py-12">Brak użytkowników dla wybranych filtrów</p>
      )}
      {!loading && !error && filtered.length > 0 && (
        <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
          <table className="w-full text-sm">
            <thead className="bg-frost/5">
              <tr>
                {["Użytkownik", "Plan", "Kredyty", "Sesje", "Odnowienie", "Alerty", "Akcje"].map((h) => (
                  <th key={h} className={`${h === "Akcje" ? "text-right" : h === "Kredyty" || h === "Sesje" || h === "Odnowienie" || h === "Alerty" ? "text-center" : "text-left"} px-3 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist`}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((s) => (
                <tr
                  key={s.subscription_id}
                  onClick={() => openUserDetail(s.user_id)}
                  className="border-t border-frost/5 hover:bg-frost/[0.03] transition-colors cursor-pointer"
                >
                  <td className="px-3 py-3">
                    <div className="flex flex-col gap-0.5">
                      <span className="font-display text-frost text-sm font-medium">{s.first_name} {s.last_name}</span>
                      <span className="font-mono text-[11px] text-mist/60">{s.email}</span>
                    </div>
                  </td>
                  <td className="px-3 py-3">
                    <span className={`inline-flex px-2 py-0.5 rounded text-[10px] font-semibold uppercase tracking-wider ${getTierBadge(s.plan_tier)}`}>{s.plan_display_name}</span>
                  </td>
                  <td className="px-3 py-3 text-center">
                    <span className={`font-mono text-sm font-bold ${s.credit_alert === "critical" ? "text-magma" : s.credit_alert === "warning" ? "text-ember" : "text-frost"}`}>
                      {s.tokens_remaining}/{s.tokens_limit}
                    </span>
                    <div className="w-16 h-1.5 bg-frost/10 rounded-full overflow-hidden mx-auto mt-1">
                      <div className={`h-full rounded-full ${s.usage_pct >= 90 ? "bg-magma" : s.usage_pct >= 70 ? "bg-ember" : "bg-aurora"}`} style={{ width: `${Math.min(s.usage_pct, 100)}%` }} />
                    </div>
                  </td>
                  <td className="px-3 py-3 text-center font-mono text-sm text-frost">{s.total_sessions}</td>
                  <td className="px-3 py-3 text-center">
                    <span className={`font-mono text-xs ${s.days_until_renewal <= 3 ? "text-magma font-bold" : s.days_until_renewal <= 7 ? "text-ember" : "text-mist"}`}>
                      {s.days_until_renewal > 0 ? `${s.days_until_renewal}d` : "wygasł"}
                    </span>
                  </td>
                  <td className="px-3 py-3 text-center">
                    {s.credit_alert === "critical" && <AlertPill color="magma" text="🔴 ≤1" />}
                    {s.credit_alert === "warning" && <AlertPill color="ember" text="🟡 ≤3" />}
                    {s.expiry_alert === "imminent" && <AlertPill color="magma" text="⏰ ≤3d" />}
                    {!s.credit_alert && !s.expiry_alert && <span className="text-mist/30 text-[10px]">—</span>}
                  </td>
                  <td className="px-3 py-3 text-right" onClick={(e) => e.stopPropagation()}>
                    <div className="inline-flex gap-1.5">
                      {s.phone && <ActionBtn href={`tel:${s.phone}`} title="Zadzwoń" color="aurora"><PhoneIcon /></ActionBtn>}
                      <ActionBtn onClick={() => openEmail(s)} title="Email" color="ember"><MailIcon /></ActionBtn>
                      <ActionBtn onClick={() => { setFollowUpTarget(s.user_id); setFollowUpDate(quickDate(3)); }} title="Przypomnij" color="frost">🔔</ActionBtn>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* ── Detail Drawer ─────────────────────────────────── */}
      {drawerOpen && (
        <div className="fixed inset-0 z-50 flex justify-end">
          <div className="absolute inset-0 bg-nocturne/60 backdrop-blur-sm" onClick={closeDrawer} />
          <div className={`relative w-full max-w-lg bg-obsidian border-l border-frost/15 overflow-y-auto shadow-2xl transition-transform duration-300 ${drawerOpen ? "translate-x-0" : "translate-x-full"}`}>
            {drawerLoading ? (
              <div className="flex items-center justify-center h-64">
                <div className="w-8 h-8 border-2 border-ember border-t-transparent rounded-full animate-spin" />
              </div>
            ) : selectedUser && (
              <div className="p-6 space-y-6">
                {/* Close */}
                <button onClick={closeDrawer} className="absolute top-4 right-4 text-mist hover:text-frost transition">✕</button>

                {/* Contact Card */}
                <div className="border-b border-frost/10 pb-6">
                  <div className="flex items-start justify-between">
                    <div>
                      <h2 className="font-display text-frost text-xl font-bold">{selectedUser.first_name} {selectedUser.last_name}</h2>
                      {selectedUser.professional_title && <p className="font-serif text-mist/60 text-sm italic">{selectedUser.professional_title}</p>}
                    </div>
                    {LIFECYCLE_LABELS[selectedUser.lifecycle_stage] && (
                      <span className={`px-2.5 py-1 rounded-lg text-[10px] font-bold uppercase ${LIFECYCLE_LABELS[selectedUser.lifecycle_stage].color}`}>
                        {LIFECYCLE_LABELS[selectedUser.lifecycle_stage].emoji} {LIFECYCLE_LABELS[selectedUser.lifecycle_stage].label}
                      </span>
                    )}
                  </div>
                  <div className="mt-3 space-y-1.5">
                    <p className="font-mono text-xs text-mist/80">📧 {selectedUser.email}</p>
                    {selectedUser.phone && <p className="font-mono text-xs text-mist/80">📱 <a href={`tel:${selectedUser.phone}`} className="text-aurora hover:underline">{selectedUser.phone}</a></p>}
                    <p className="font-mono text-xs text-mist/50">Dołączył: {selectedUser.created_at}</p>
                    {selectedUser.last_session_at && <p className="font-mono text-xs text-mist/50">Ostatnia sesja: {selectedUser.last_session_at}</p>}
                  </div>
                  {/* Quick stats */}
                  <div className="grid grid-cols-3 gap-2 mt-4">
                    <MiniStat label="Sesje" value={selectedUser.total_sessions} />
                    <MiniStat label="Kredyty" value={`${selectedUser.tokens_remaining}/${selectedUser.tokens_limit}`} />
                    <MiniStat label="Dni do końca" value={selectedUser.days_until_renewal} />
                  </div>
                </div>

                {/* Tags */}
                <div>
                  <h3 className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist/60 mb-2">Tagi</h3>
                  <div className="flex flex-wrap gap-1.5 mb-2">
                    {selectedUser.tags.map((tag) => (
                      <span key={tag.id} className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-frost/10 border border-frost/15 text-frost text-[11px] font-mono">
                        {tag.tag}
                        <button onClick={() => removeTag(tag.id)} className="text-mist/40 hover:text-magma transition ml-0.5">×</button>
                      </span>
                    ))}
                  </div>
                  <div className="flex gap-1.5">
                    <input
                      value={newTag}
                      onChange={(e) => setNewTag(e.target.value)}
                      onKeyDown={(e) => e.key === "Enter" && addTag()}
                      placeholder="nowy tag..."
                      className="flex-1 rounded bg-frost/5 border border-frost/15 px-2 py-1 text-frost text-xs font-mono focus:outline-none focus:border-ember"
                    />
                    <button onClick={addTag} className="px-2 py-1 rounded bg-ember/10 text-ember text-xs font-mono hover:bg-ember/20 transition">+</button>
                  </div>
                </div>

                {/* Follow-ups */}
                <div>
                  <h3 className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist/60 mb-2">Follow-upy</h3>
                  {selectedUser.follow_ups.length > 0 ? (
                    <div className="space-y-1.5 mb-2">
                      {selectedUser.follow_ups.map((f) => (
                        <div key={f.id} className={`flex items-center justify-between rounded px-2 py-1.5 text-xs ${f.completed ? "bg-frost/5 text-mist/40 line-through" : f.overdue ? "bg-magma/10 text-magma" : "bg-ember/5 text-frost"}`}>
                          <span className="font-mono">{f.due_date} {f.note && `— ${f.note}`}</span>
                          {!f.completed && (
                            <button onClick={() => completeFollowUp(f.id)} className="text-aurora hover:text-frost transition">✓</button>
                          )}
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-mist/30 text-xs font-serif mb-2">Brak zaplanowanych follow-upów</p>
                  )}
                  <button onClick={() => { setFollowUpTarget(selectedUser.user_id); setFollowUpDate(quickDate(3)); }} className="w-full rounded bg-frost/5 border border-frost/15 px-3 py-1.5 text-frost text-xs font-mono hover:bg-frost/10 transition">
                    + Zaplanuj follow-up
                  </button>
                </div>

                {/* Email Templates */}
                <div>
                  <h3 className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist/60 mb-2">Szybki email</h3>
                  <div className="grid grid-cols-2 gap-1.5">
                    {EMAIL_TEMPLATES.map((tmpl) => (
                      <button
                        key={tmpl.id}
                        onClick={() => openEmail(selectedUser, tmpl.id)}
                        className="text-left rounded bg-frost/5 border border-frost/10 px-2.5 py-2 text-xs font-display text-frost hover:bg-frost/10 hover:border-ember/20 transition"
                      >
                        {tmpl.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Notes Journal */}
                <div>
                  <h3 className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist/60 mb-2">📓 Notatki ({selectedUser.notes.length})</h3>
                  <div className="flex gap-1.5 mb-3">
                    <textarea
                      value={newNote}
                      onChange={(e) => setNewNote(e.target.value)}
                      placeholder="Dodaj notatkę..."
                      rows={2}
                      className="flex-1 rounded bg-frost/5 border border-frost/15 px-2.5 py-1.5 text-frost text-xs font-serif resize-none focus:outline-none focus:border-ember transition"
                    />
                    <button onClick={addNote} disabled={!newNote.trim() || noteSaving} className="px-3 rounded bg-ember/10 text-ember text-xs font-mono hover:bg-ember/20 transition disabled:opacity-40 self-end">
                      {noteSaving ? "..." : "📝"}
                    </button>
                  </div>
                  <div className="space-y-2 max-h-64 overflow-y-auto">
                    {selectedUser.notes.map((note) => (
                      <div key={note.id} className="rounded bg-frost/[0.03] border border-frost/8 px-3 py-2">
                        <p className="font-serif text-frost text-xs leading-relaxed whitespace-pre-wrap">{note.body}</p>
                        <p className="font-mono text-[9px] text-mist/30 mt-1">{new Date(note.created_at).toLocaleDateString("pl-PL", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}</p>
                      </div>
                    ))}
                    {selectedUser.notes.length === 0 && <p className="text-mist/30 text-xs font-serif">Brak notatek</p>}
                  </div>
                </div>

                {/* Exclusion */}
                <div className="border-t border-frost/10 pt-4">
                  <button
                    onClick={() => excludeUser(selectedUser.user_id)}
                    className="w-full rounded bg-magma/5 border border-magma/20 px-3 py-2 text-magma text-xs font-mono uppercase tracking-wider hover:bg-magma/10 transition"
                  >
                    🚫 Wyklucz z CRM
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── Email Composer Modal ──────────────────────────── */}
      {emailTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-nocturne/70 backdrop-blur-sm">
          <div className="bg-obsidian border border-frost/15 rounded-card p-6 w-full max-w-lg mx-4 shadow-2xl">
            <h3 className="font-display text-frost text-lg font-semibold mb-1">✉️ Email do {emailTarget.name}</h3>
            <p className="font-mono text-xs text-mist/60 mb-1">{emailTarget.email}</p>
            <p className="font-mono text-[10px] text-mist/40 mb-4">od: {SENDER_EMAIL}</p>
            <input
              value={emailSubject}
              onChange={(e) => setEmailSubject(e.target.value)}
              placeholder="Temat..."
              className="w-full rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember mb-3"
            />
            <textarea
              value={emailBody}
              onChange={(e) => setEmailBody(e.target.value)}
              rows={10}
              className="w-full rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-serif text-sm focus:outline-none focus:border-ember transition resize-y mb-4"
            />
            <div className="flex justify-end gap-3">
              <button onClick={() => { setEmailTarget(null); setEmailSubject(""); setEmailBody(""); }} className="rounded-button border border-frost/15 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost transition">Anuluj</button>
              <button onClick={sendEmail} disabled={!emailBody.trim()} className="rounded-button bg-ember text-obsidian px-5 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:brightness-110 transition disabled:opacity-50">
                Otwórz w kliencie email
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Follow-up Modal ───────────────────────────────── */}
      {followUpTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-nocturne/70 backdrop-blur-sm">
          <div className="bg-obsidian border border-frost/15 rounded-card p-6 w-full max-w-sm mx-4 shadow-2xl">
            <h3 className="font-display text-frost text-lg font-semibold mb-4">🔔 Zaplanuj follow-up</h3>
            <div className="flex flex-wrap gap-2 mb-4">
              <QuickDateBtn label="Jutro" onClick={() => setFollowUpDate(quickDate(1))} active={followUpDate === quickDate(1)} />
              <QuickDateBtn label="Za 3 dni" onClick={() => setFollowUpDate(quickDate(3))} active={followUpDate === quickDate(3)} />
              <QuickDateBtn label="Poniedziałek" onClick={() => setFollowUpDate(nextMonday())} active={followUpDate === nextMonday()} />
              <QuickDateBtn label="Za tydzień" onClick={() => setFollowUpDate(quickDate(7))} active={followUpDate === quickDate(7)} />
            </div>
            <input
              type="date"
              value={followUpDate}
              onChange={(e) => setFollowUpDate(e.target.value)}
              className="w-full rounded-button bg-frost/5 border border-frost/15 text-frost px-3 py-2 font-mono text-sm focus:outline-none focus:border-ember mb-3"
            />
            <input
              value={followUpNote}
              onChange={(e) => setFollowUpNote(e.target.value)}
              placeholder="Notatka (opcjonalna)..."
              className="w-full rounded-button bg-frost/5 border border-frost/15 text-frost px-3 py-2 font-display text-sm focus:outline-none focus:border-ember mb-4"
            />
            <div className="flex justify-end gap-3">
              <button onClick={() => { setFollowUpTarget(null); setFollowUpDate(""); setFollowUpNote(""); }} className="rounded-button border border-frost/15 px-4 py-2 font-mono text-xs uppercase text-mist hover:text-frost transition">Anuluj</button>
              <button onClick={createFollowUp} disabled={!followUpDate} className="rounded-button bg-ember text-obsidian px-5 py-2 font-mono text-xs uppercase hover:brightness-110 transition disabled:opacity-50">Zapisz</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Sub-components ──────────────────────────────────────────

function KPIChip({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="rounded-card border border-frost/10 bg-frost/[0.03] px-3 py-3 text-center">
      <div className={`font-display text-${color} text-2xl font-bold`}>{value}</div>
      <div className="font-mono text-[9px] text-mist/60 uppercase tracking-[0.1em] mt-1">{label}</div>
    </div>
  );
}

function FilterSelect({ value, onChange, options }: { value: string; onChange: (v: string) => void; options: { value: string; label: string }[] }) {
  return (
    <select value={value} onChange={(e) => onChange(e.target.value)} className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3 py-2 font-display text-sm focus:outline-none focus:border-ember transition cursor-pointer">
      {options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
    </select>
  );
}

function AlertPill({ color, text }: { color: string; text: string }) {
  return <span className={`px-1.5 py-0.5 rounded bg-${color}/15 text-${color} text-[9px] font-bold uppercase`}>{text}</span>;
}

function ActionBtn({ children, onClick, href, title, color }: { children: React.ReactNode; onClick?: () => void; href?: string; title: string; color: string }) {
  const cls = `p-1.5 rounded-lg bg-frost/5 border border-frost/10 text-${color} hover:bg-frost/10 hover:border-${color}/30 transition`;
  if (href) return <a href={href} title={title} className={cls}>{children}</a>;
  return <button onClick={onClick} title={title} className={cls}>{children}</button>;
}

function MiniStat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded bg-frost/5 px-2 py-1.5 text-center">
      <div className="font-mono text-frost text-sm font-bold">{value}</div>
      <div className="font-mono text-[8px] text-mist/50 uppercase">{label}</div>
    </div>
  );
}

function QuickDateBtn({ label, onClick, active }: { label: string; onClick: () => void; active: boolean }) {
  return (
    <button onClick={onClick} className={`px-3 py-1.5 rounded-lg text-xs font-mono transition ${active ? "bg-ember text-obsidian" : "bg-frost/5 border border-frost/15 text-frost hover:bg-frost/10"}`}>
      {label}
    </button>
  );
}

function getTierBadge(tier: string): string {
  switch (tier) {
    case "BETA": return "bg-aurora/10 text-aurora border border-aurora/20";
    case "TRIAL": return "bg-mist/10 text-mist border border-mist/20";
    case "SOLO": return "bg-ember/10 text-ember border border-ember/20";
    case "PRO": return "bg-magma/10 text-magma border border-magma/20";
    case "CLINIC": return "bg-frost/10 text-frost border border-frost/20";
    default: return "bg-frost/5 text-mist border border-frost/10";
  }
}

function PhoneIcon() {
  return <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" /></svg>;
}

function MailIcon() {
  return <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>;
}
