// CRMDashboard — Marcin's relationship management hub.
//
// Features:
// - Priority inbox ("Dziś do kontaktu" — overdue + today's follow-ups)
// - Urgency-sorted subscriber table with credit/expiry alerts
// - Filter by tier, status, alert, tags, free-text search (server-side)
// - Slide-out detail drawer per user (notes, tags, follow-ups, lifecycle)
// - Email composer with templates (mailto: kontakt@superwizor.ai)
// - User exclusion/blocking
// - CSV export
// - Phone normalization & validation

"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { serviceEndpoints, getAuthToken } from "@/lib/connect/clients";
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
  last_session_at: string;
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
  email_logs: EmailLog[];
  excluded: boolean;
  lifecycle_stage: string;
  last_session_at: string;
};

type CRMNote = { id: string; body: string; created_at: string };
type CRMTag = { id: string; tag: string; color: string };
type EmailLog = { id: string; template_id: string; subject: string; recipient_email: string; sent_at: string };
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

type GlobalStats = {
  total: number;
  critical: number;
  warning: number;
  expiring: number;
  churned: number;
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
  { value: "critical", label: "🔴 Krytyczne (1 lub mniej)" },
  { value: "warning", label: "🟡 Ostrzeżenie (3 lub mniej)" },
  { value: "expiring", label: "🟣 Wygasa (3 dni lub mniej)" },
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
  new: { label: "Nowy", color: "text-[var(--crm-accent-blue)] bg-[var(--crm-info-bg)]", emoji: "🆕" },
  onboarding: { label: "Onboarding", color: "text-[var(--crm-ember-text)] bg-[var(--crm-ember-subtle)]", emoji: "📋" },
  first_session: { label: "Pierwsza sesja", color: "text-[var(--crm-accent-purple)] bg-[var(--crm-purple-bg)]", emoji: "🎯" },
  active: { label: "Aktywny", color: "text-[var(--crm-accent-green)] bg-[var(--crm-success-bg)]", emoji: "✅" },
  power_user: { label: "Power User", color: "text-[var(--crm-ember-text)] bg-[var(--crm-ember-subtle)]", emoji: "⚡" },
  at_risk: { label: "Zagrożony", color: "text-[var(--crm-accent-red)] bg-[var(--crm-danger-subtle)]", emoji: "⚠️" },
  churned: { label: "Odszedł", color: "text-[var(--crm-muted)] bg-[var(--crm-neutral-bg)]", emoji: "❌" },
};

// Tag color presets
const TAG_COLORS = [
  { name: "gray",   hex: "#6b7280" },
  { name: "red",    hex: "#ef4444" },
  { name: "orange", hex: "#f97316" },
  { name: "yellow", hex: "#eab308" },
  { name: "green",  hex: "#22c55e" },
  { name: "blue",   hex: "#3b82f6" },
  { name: "purple", hex: "#a855f7" },
  { name: "pink",   hex: "#ec4899" },
];

const SENDER_EMAIL = "kontakt@superwizor.ai";

// ─── Helpers ─────────────────────────────────────────────────

// P3.10: Phone normalization
function normalizePhone(phone: string): string {
  if (!phone) return "";
  // Remove all whitespace
  let cleaned = phone.replace(/\s+/g, "");
  // Remove dashes and parentheses
  cleaned = cleaned.replace(/[-()]/g, "");
  // Add + prefix if missing and starts with country code
  if (/^\d{9,}$/.test(cleaned)) {
    // Assume Polish number if 9 digits
    if (cleaned.length === 9) cleaned = "+48" + cleaned;
    // If 11+ digits, assume starts with country code (e.g. 48...)
    else if (!cleaned.startsWith("+")) cleaned = "+" + cleaned;
  }
  return cleaned;
}

function isValidPhone(phone: string): boolean {
  if (!phone) return false;
  const cleaned = normalizePhone(phone);
  // E.164 max is 15 digits (including country code without +)
  const digits = cleaned.replace(/\D/g, "");
  return digits.length >= 7 && digits.length <= 15;
}

function formatPhoneDisplay(phone: string): string {
  const normalized = normalizePhone(phone);
  if (!isValidPhone(phone)) return phone + " ⚠️";
  return normalized;
}

// Solid color tint — mixes foreground hex with background hex at given ratio (0-1). No transparency.
function solidTint(fgHex: string, bgHex: string, ratio: number): string {
  const p = (h: string, o: number) => parseInt(h.slice(o, o + 2), 16);
  const mix = (a: number, b: number) => Math.round(b + (a - b) * ratio);
  const r = mix(p(fgHex, 1), p(bgHex, 1)), g = mix(p(fgHex, 3), p(bgHex, 3)), b = mix(p(fgHex, 5), p(bgHex, 5));
  return `#${r.toString(16).padStart(2,"0")}${g.toString(16).padStart(2,"0")}${b.toString(16).padStart(2,"0")}`;
}

// Avatar initials
function getInitials(firstName: string, lastName: string): string {
  return ((firstName?.[0] || "") + (lastName?.[0] || "")).toUpperCase() || "?";
}

function getAvatarColor(name: string): string {
  const colors = [
    "bg-[var(--crm-warning-bg)] text-[var(--crm-accent-orange)]",
    "bg-[var(--crm-purple-bg)] text-[var(--crm-accent-purple)]",
    "bg-[var(--crm-info-bg)] text-[var(--crm-accent-blue)]",
    "bg-[var(--crm-success-bg)] text-[var(--crm-accent-green)]",
    "bg-[var(--crm-pink-bg)] text-[var(--crm-accent-pink)]",
  ];
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
  return colors[Math.abs(hash) % colors.length];
}

function getTagColor(color: string): string {
  const found = TAG_COLORS.find((c) => c.name === color || c.hex === color);
  return found?.hex || "#6b7280";
}

// ─── Component ───────────────────────────────────────────────


// crmFetch — direct call to billing-svc's admin CRM endpoints with the
// Firebase bearer token. Replaces the Next.js api proxy: the site is
// statically exported (output: "export"), so API routes have no runtime
// in production, and the proxy forwarded requests UNAUTHENTICATED —
// billing-svc now requires SUPERWIZOR_ADMIN on these routes
// (2026-06-10 exposure fix). CORS on billing-svc already allows the
// panel origins.
async function crmFetch(path: string, init?: RequestInit): Promise<Response> {
  const token = await getAuthToken();
  const headers = new Headers(init?.headers);
  if (token) headers.set("Authorization", `Bearer ${token}`);
  if (init?.body && !headers.has("Content-Type")) headers.set("Content-Type", "application/json");
  return fetch(`${serviceEndpoints.billing}${path}`, { ...init, headers });
}

export function CRMDashboard() {
  const t = useTranslations("admin.crm");

  // ─── Theme ─────────────────────────────────────────────────
  const [isDark, setIsDark] = useState(() => {
    if (typeof window === "undefined") return true;
    return localStorage.getItem("crm-theme") !== "light";
  });
  const toggleTheme = () => {
    setIsDark((d) => {
      const next = !d;
      localStorage.setItem("crm-theme", next ? "dark" : "light");
      return next;
    });
  };
  const themeVars = isDark ? {
    "--crm-bg": "#010409",
    "--crm-card": "#161b22",
    "--crm-surface": "#0d1117",
    "--crm-elevated": "#21262d",
    "--crm-border": "#30363d",
    "--crm-border-subtle": "#21262d",
    "--crm-text": "#c9d1d9",
    "--crm-heading": "#ffffff",
    "--crm-muted": "#8b949e",
    "--crm-faint": "#484f58",
    "--crm-focus": "#58a6ff",
    "--crm-row-alt": "#0d1117",
    "--crm-row-base": "#010409",
    // Solid accent states (no transparency)
    "--crm-ember-subtle": "#2B2210",
    "--crm-ember-bg": "#3D3117",
    "--crm-ember-bg-hover": "#4A3B1C",
    "--crm-ember-border": "#7A5F2E",
    "--crm-ember-faint": "#1E1C15",
    "--crm-danger-subtle": "#2D161A",
    "--crm-danger-bg": "#381C21",
    "--crm-danger-border": "#7D3333",
    "--crm-success-bg": "#162E1F",
    "--crm-success-border": "#256B3F",
    "--crm-purple-bg": "#241C38",
    "--crm-purple-border": "#4C3278",
    "--crm-info-bg": "#1A2740",
    "--crm-warning-bg": "#2D2013",
    "--crm-pink-bg": "#2D1525",
    "--crm-neutral-bg": "#252830",
    "--crm-overlay": "#000000",
    "--crm-toast-bar": "#7A5F2E",
    "--crm-credit-empty": "#2A2D33",
    "--crm-ember-text": "#FCAE2F",
    "--crm-accent-blue": "#58a6ff",
    "--crm-accent-purple": "#a855f7",
    "--crm-accent-green": "#22c55e",
    "--crm-accent-red": "#ef4444",
    "--crm-accent-orange": "#f97316",
    "--crm-accent-pink": "#ec4899",
  } as React.CSSProperties : {
    "--crm-bg": "#FAFAFA",
    "--crm-card": "#ffffff",
    "--crm-surface": "#f5f7f8",
    "--crm-elevated": "#ebeef0",
    "--crm-border": "#d0d7de",
    "--crm-border-subtle": "#e8ecef",
    "--crm-text": "#1F2937",
    "--crm-heading": "#1F1F1F",
    "--crm-muted": "#57606a",
    "--crm-faint": "#6b7280",
    "--crm-focus": "#004D54",
    "--crm-row-alt": "#f5f7f8",
    "--crm-row-base": "#ffffff",
    // Solid accent states — BOLD, high contrast for light mode
    "--crm-ember-subtle": "#FDE68A",
    "--crm-ember-bg": "#FBBF24",
    "--crm-ember-bg-hover": "#F59E0B",
    "--crm-ember-border": "#D97706",
    "--crm-ember-faint": "#FEF9C3",
    "--crm-danger-subtle": "#FEE2E2",
    "--crm-danger-bg": "#FECACA",
    "--crm-danger-border": "#DC2626",
    "--crm-success-bg": "#D1FAE5",
    "--crm-success-border": "#16A34A",
    "--crm-purple-bg": "#E9D5FF",
    "--crm-purple-border": "#7C3AED",
    "--crm-info-bg": "#DBEAFE",
    "--crm-warning-bg": "#FED7AA",
    "--crm-pink-bg": "#FBCFE8",
    "--crm-neutral-bg": "#E5E7EB",
    "--crm-overlay": "#1F1F1F",
    "--crm-toast-bar": "#D97706",
    "--crm-credit-empty": "#D0D7DE",
    "--crm-ember-text": "#92400E",
    "--crm-accent-blue": "#1D4ED8",
    "--crm-accent-purple": "#6D28D9",
    "--crm-accent-green": "#15803D",
    "--crm-accent-red": "#DC2626",
    "--crm-accent-orange": "#C2410C",
    "--crm-accent-pink": "#BE185D",
  } as React.CSSProperties;

  const [subscribers, setSubscribers] = useState<CRMSubscriber[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filters, setFilters] = useState<FilterState>(() => {
    if (typeof window === "undefined") return { tier: "", status: "", alert: "", search: "" };
    const p = new URLSearchParams(window.location.search);
    return { tier: p.get("tier") || "", status: p.get("status") || "", alert: p.get("alert") || "", search: p.get("search") || "" };
  });

  // Debounced search
  const [searchInput, setSearchInput] = useState(filters.search);
  const searchTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Pagination
  const [page, setPage] = useState(() => {
    if (typeof window === "undefined") return 1;
    return parseInt(new URLSearchParams(window.location.search).get("page") || "1");
  });
  const [perPage, setPerPage] = useState(25);
  const [totalFiltered, setTotalFiltered] = useState(0);
  const [totalAll, setTotalAll] = useState(0);

  // Global stats (KPI chips — always full database)
  const [globalStats, setGlobalStats] = useState<GlobalStats>({ total: 0, critical: 0, warning: 0, expiring: 0, churned: 0 });

  // Sorting
  const [sortColumn, setSortColumn] = useState<string>("urgency");
  const [sortDirection, setSortDirection] = useState<"asc" | "desc">("desc");

  // Bulk selection
  const [selected, setSelected] = useState<Set<string>>(new Set());

  // Confirmation modal
  const [confirmAction, setConfirmAction] = useState<{ message: string; onConfirm: () => void } | null>(null);

  // Toast notification
  const [toast, setToast] = useState<string | null>(null);

  // Detail drawer
  const [selectedUser, setSelectedUser] = useState<UserDetail | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerLoading, setDrawerLoading] = useState(false);
  const [drawerError, setDrawerError] = useState<string | null>(null);

  // Notes
  const [newNote, setNewNote] = useState("");
  const [noteSaving, setNoteSaving] = useState(false);

  // Tags
  const [newTag, setNewTag] = useState("");
  const [newTagColor, setNewTagColor] = useState("gray");

  // Follow-ups
  const [followUps, setFollowUps] = useState<FollowUp[]>([]);
  const [todayCount, setTodayCount] = useState(0);
  const [overdueCount, setOverdueCount] = useState(0);

  // Email composer
  const [emailTarget, setEmailTarget] = useState<{ name: string; email: string; userId: string; remaining?: number; period_end?: string } | null>(null);
  const [emailSubject, setEmailSubject] = useState("");
  const [emailBody, setEmailBody] = useState("");
  const [emailTemplateId, setEmailTemplateId] = useState("");

  // Follow-up modal
  const [followUpTarget, setFollowUpTarget] = useState<string | null>(null);
  const [followUpDate, setFollowUpDate] = useState("");
  const [followUpNote, setFollowUpNote] = useState("");

  // ─── URL sync ──────────────────────────────────────────────

  useEffect(() => {
    if (typeof window === "undefined") return;
    const p = new URLSearchParams();
    if (filters.tier) p.set("tier", filters.tier);
    if (filters.status) p.set("status", filters.status);
    if (filters.alert) p.set("alert", filters.alert);
    if (filters.search) p.set("search", filters.search);
    if (page > 1) p.set("page", String(page));
    const qs = p.toString();
    const url = `${window.location.pathname}${qs ? `?${qs}` : ""}`;
    window.history.replaceState(null, "", url);
  }, [filters, page]);

  // Debounce search input → filters.search
  useEffect(() => {
    if (searchTimerRef.current) clearTimeout(searchTimerRef.current);
    searchTimerRef.current = setTimeout(() => {
      setFilters((f) => ({ ...f, search: searchInput }));
      setPage(1); // P2.5: reset page on search
    }, 300);
    return () => { if (searchTimerRef.current) clearTimeout(searchTimerRef.current); };
  }, [searchInput]);

  // ─── Data Fetching ─────────────────────────────────────────

  const fetchSubscribers = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams();
      if (filters.tier) params.set("tier", filters.tier);
      if (filters.status) params.set("status", filters.status);
      if (filters.alert) params.set("alert", filters.alert);
      if (filters.search) params.set("search", filters.search); // P2.4: send search to backend
      params.set("page", String(page));
      params.set("per_page", String(perPage));
      const qs = params.toString();
      const resp = await crmFetch(`/admin/crm/subscribers${qs ? `?${qs}` : ""}`);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const data = await resp.json();
      setSubscribers(data.subscribers || []);
      setTotalFiltered(data.total || 0);
      setTotalAll(data.total_all || 0);
      setGlobalStats(data.global_stats || { total: 0, critical: 0, warning: 0, expiring: 0, churned: 0 });
    } catch (err: any) {
      setError(err.message || "Błąd ładowania danych CRM");
    } finally {
      setLoading(false);
    }
  }, [filters.tier, filters.status, filters.alert, filters.search, page, perPage]);

  const fetchFollowUps = useCallback(async () => {
    try {
      const resp = await crmFetch("/admin/crm/follow-ups");
      if (!resp.ok) return;
      const data = await resp.json();
      setFollowUps(data.follow_ups || []);
      setTodayCount(data.today_count || 0);
      setOverdueCount(data.overdue_count || 0);
    } catch { /* silent */ }
  }, []);

  useEffect(() => { void fetchSubscribers(); }, [fetchSubscribers]);
  useEffect(() => { void fetchFollowUps(); }, [fetchFollowUps]);

  // P2.5: Reset page when filters change (except search which resets via debounce)
  const updateFilter = useCallback((key: keyof FilterState, value: string) => {
    setFilters((f) => ({ ...f, [key]: value }));
    setPage(1);
  }, []);

  const openUserDetail = async (userId: string) => {
    setDrawerLoading(true);
    setDrawerOpen(true);
    setDrawerError(null);
    try {
      const resp = await crmFetch(`/admin/crm/user/${userId}/detail`);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const data = await resp.json();
      setSelectedUser(data);
    } catch (err: any) {
      console.error("Failed to load user detail:", err);
      setDrawerError(err.message || "Nie udało się załadować szczegółów");
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
      const resp = await crmFetch("/admin/crm/notes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ target_user_id: selectedUser.user_id, body: newNote }),
      });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      setNewNote("");
      await openUserDetail(selectedUser.user_id);
      showToast("📝 Notatka zapisana");
    } catch (err: any) {
      showToast(`❌ Błąd: ${err.message}`);
    } finally {
      setNoteSaving(false);
    }
  };

  const addTag = async () => {
    if (!selectedUser || !newTag.trim()) return;
    const tagText = newTag.trim();
    const tagColor = newTagColor;
    try {
      const resp = await crmFetch("/admin/crm/tags", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ target_user_id: selectedUser.user_id, tag: tagText, color: tagColor }),
      });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const data = await resp.json();
      // Optimistic: add tag to local state immediately
      setSelectedUser((prev) => prev ? {
        ...prev,
        tags: [...prev.tags, { id: data.id || crypto.randomUUID(), tag: tagText.toLowerCase(), color: tagColor }],
      } : prev);
      setNewTag("");
      setNewTagColor("gray");
      showToast(`🏷️ Tag "${tagText}" dodany`);
    } catch (err: any) {
      showToast(`❌ Nie udało się dodać tagu: ${err.message}`);
    }
  };

  const removeTag = async (tagId: string) => {
    // Optimistic: remove from local state immediately
    const prevTags = selectedUser?.tags || [];
    setSelectedUser((prev) => prev ? { ...prev, tags: prev.tags.filter((t) => t.id !== tagId) } : prev);
    try {
      const resp = await crmFetch(`/admin/crm/tags/${tagId}`, { method: "DELETE" });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      showToast("🏷️ Tag usunięty");
    } catch (err: any) {
      // Rollback on error
      setSelectedUser((prev) => prev ? { ...prev, tags: prevTags } : prev);
      showToast(`❌ Nie udało się usunąć tagu: ${err.message}`);
    }
  };

  const excludeUser = async (userId: string) => {
    try {
      const resp = await crmFetch("/admin/crm/exclude", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user_id: userId, reason: "excluded from CRM" }),
      });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      closeDrawer();
      void fetchSubscribers();
      showToast("🚫 Użytkownik wykluczony z CRM");
    } catch (err: any) {
      showToast(`❌ Błąd: ${err.message}`);
    }
  };

  const createFollowUp = async () => {
    if (!followUpTarget || !followUpDate) return;
    try {
      const resp = await crmFetch("/admin/crm/follow-ups", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ target_user_id: followUpTarget, due_date: followUpDate, note: followUpNote }),
      });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      setFollowUpTarget(null);
      setFollowUpDate("");
      setFollowUpNote("");
      void fetchFollowUps();
      if (selectedUser) await openUserDetail(selectedUser.user_id);
      showToast("🔔 Follow-up zaplanowany");
    } catch (err: any) {
      showToast(`❌ Błąd: ${err.message}`);
    }
  };

  const completeFollowUp = async (id: string) => {
    try {
      const resp = await crmFetch(`/admin/crm/follow-ups/${id}/complete`, { method: "PATCH" });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      void fetchFollowUps();
      if (selectedUser) await openUserDetail(selectedUser.user_id);
      showToast("✅ Follow-up zakończony");
    } catch (err: any) {
      showToast(`❌ Nie udało się zakończyć follow-upa: ${err.message}`);
    }
  };

  const deleteFollowUp = async (id: string) => {
    try {
      const resp = await crmFetch(`/admin/crm/follow-ups/${id}`, { method: "DELETE" });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      void fetchFollowUps();
      if (selectedUser) await openUserDetail(selectedUser.user_id);
      showToast("🗑️ Follow-up usunięty");
    } catch (err: any) {
      showToast(`❌ Nie udało się usunąć: ${err.message}`);
    }
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
    setEmailTarget({ name, email: sub.email, userId: sub.user_id, remaining: (sub as any).tokens_remaining, period_end: (sub as any).period_end });
    setEmailSubject(subj);
    setEmailBody(body);
    setEmailTemplateId(templateId || "custom");
  };

  const sendEmail = () => {
    if (!emailTarget) return;
    setConfirmAction({
      message: `Czy na pewno chcesz otworzyć emaila do ${emailTarget.name} (${emailTarget.email})?`,
      onConfirm: async () => {
        const subject = encodeURIComponent(emailSubject);
        const body = encodeURIComponent(emailBody);
        window.open(
          `mailto:${emailTarget.email}?from=${SENDER_EMAIL}&subject=${subject}&body=${body}`,
          "_blank",
        );
        // Log the email
        try {
          await crmFetch("/admin/crm/email-log", {
            method: "POST",
            body: JSON.stringify({
              target_user_id: emailTarget.userId,
              template_id: emailTemplateId,
              subject: emailSubject,
              recipient_email: emailTarget.email,
            }),
          });
        } catch { /* silent — email was already opened */ }
        setEmailTarget(null);
        setEmailSubject("");
        setEmailBody("");
        setEmailTemplateId("");
        showToast("📧 Email otwarty i zapisany w historii");
        if (selectedUser) await openUserDetail(selectedUser.user_id);
        setConfirmAction(null);
      },
    });
  };

  // ─── Sorting ───────────────────────────────────────────────

  const sorted = useMemo(() => {
    return [...subscribers].sort((a, b) => {
      const dir = sortDirection === "asc" ? 1 : -1;
      switch (sortColumn) {
        case "credits": return (a.tokens_remaining - b.tokens_remaining) * dir;
        case "sessions": return (a.total_sessions - b.total_sessions) * dir;
        case "renewal": return (a.days_until_renewal - b.days_until_renewal) * dir;
        case "activity": {
          const aDate = a.last_session_at || "1970-01-01";
          const bDate = b.last_session_at || "1970-01-01";
          return aDate.localeCompare(bDate) * dir;
        }
        default: return (a.urgency_score - b.urgency_score) * -dir;
      }
    });
  }, [subscribers, sortColumn, sortDirection]);

  const toggleSort = (column: string) => {
    if (sortColumn === column) {
      setSortDirection(sortDirection === "asc" ? "desc" : "asc");
    } else {
      setSortColumn(column);
      setSortDirection(column === "urgency" ? "desc" : "asc");
    }
  };

  const sortIndicator = (column: string) => {
    if (sortColumn !== column) return "";
    return sortDirection === "asc" ? " ▲" : " ▼";
  };

  // ─── Bulk actions ──────────────────────────────────────────

  const toggleSelect = (userId: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(userId)) next.delete(userId);
      else next.add(userId);
      return next;
    });
  };

  const toggleSelectAll = () => {
    if (selected.size === sorted.length) {
      setSelected(new Set());
    } else {
      setSelected(new Set(sorted.map((s) => s.user_id)));
    }
  };

  const bulkRemind = async () => {
    if (selected.size === 0) return;
    setConfirmAction({
      message: `Zaplanować follow-up dla ${selected.size} ${selected.size === 1 ? "osoby" : selected.size < 5 ? "osób" : "osób"}?`,
      onConfirm: async () => {
        try {
          await crmFetch("/admin/crm/bulk/remind", {
            method: "POST",
            body: JSON.stringify({
              user_ids: Array.from(selected),
              due_date: quickDate(3),
              note: "Bulk follow-up z CRM",
            }),
          });
          showToast(`🔔 Zaplanowano ${selected.size} follow-upów`);
          setSelected(new Set());
          void fetchFollowUps();
        } catch { showToast("❌ Błąd przy tworzeniu follow-upów"); }
        setConfirmAction(null);
      },
    });
  };

  const bulkDelete = async () => {
    if (selected.size === 0) return;
    setConfirmAction({
      message: `CZY NA PEWNO CHCESZ USUNĄĆ ${selected.size} zaznaczonych użytkowników z widoku CRM? Konta użytkowników i ich dane w bazie pozostaną nienaruszone, ale znikną oni z paneli CRM.`,
      onConfirm: async () => {
        try {
          const resp = await crmFetch("/admin/crm/subscribers/bulk-delete", {
            method: "POST",
            body: JSON.stringify({
              user_ids: Array.from(selected),
            }),
          });
          if (!resp.ok) throw new Error("Bulk delete failed");
          showToast(`🗑️ Pomyślnie usunięto ${selected.size} użytkowników`);
          setSelected(new Set());
          void fetchSubscribers();
        } catch {
          showToast("❌ Błąd podczas usuwania użytkowników");
        }
        setConfirmAction(null);
      },
    });
  };

  const bulkEmail = () => {
    if (selected.size === 0) return;
    const selectedSubs = sorted.filter((s) => selected.has(s.user_id));
    const batch = selectedSubs.slice(0, 10);
    batch.forEach((s) => {
      window.open(`mailto:${s.email}?from=${SENDER_EMAIL}&subject=${encodeURIComponent("SuperWizor AI — wiadomość od zespołu")}`, "_blank");
    });
    if (selectedSubs.length > 10) {
      showToast(`📧 Otwarto 10 z ${selectedSubs.length} emaili (limit przeglądarki)`);
    } else {
      showToast(`📧 Otwarto ${batch.length} ${batch.length === 1 ? "email" : "emaili"}`);
    }
  };

  // ─── Toast helper ─────────────────────────────────────────

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 3500);
  };

  // Pagination — P2.4 fix: use totalFiltered from backend (already filtered by search)
  const totalPages = Math.max(1, Math.ceil(totalFiltered / perPage));

  // Helper: format relative date
  const formatRelativeDate = (dateStr: string) => {
    const d = new Date(dateStr);
    const now = new Date();
    const days = Math.floor((now.getTime() - d.getTime()) / (1000 * 60 * 60 * 24));
    if (days === 0) return "dziś";
    if (days === 1) return "wczoraj";
    if (days < 7) return `${days} dni temu`;
    if (days < 30) return `${Math.floor(days / 7)} tyg. temu`;
    if (days < 365) return `${Math.floor(days / 30)} mies. temu`;
    return `${Math.floor(days / 365)} lat temu`;
  };

  const getActivityColor = (dateStr: string) => {
    const days = Math.floor((new Date().getTime() - new Date(dateStr).getTime()) / (1000 * 60 * 60 * 24));
    if (days < 7) return "text-aurora";
    if (days < 14) return "text-frost";
    if (days < 30) return "text-[var(--crm-ember-text)]";
    return "text-magma";
  };

  // P3.9 fix: credit bar shows % REMAINING (not % used)
  const getCreditBarInfo = (remaining: number, limit: number) => {
    if (limit === 0) return { pct: 0, color: "bg-[var(--crm-credit-empty)]" };
    const pct = (remaining / limit) * 100;
    if (pct <= 10) return { pct, color: "bg-magma" };
    if (pct <= 30) return { pct, color: "bg-ember" };
    return { pct, color: "bg-aurora" };
  };

  // CSV export
  const exportCSV = () => {
    const headers = ["Imię","Nazwisko","Email","Telefon","Plan","Status","Sesje","Kredyty użyte","Kredyty pozostałe","Limit","Koniec okresu","Dni do odnowienia","Alert","Pilność","Dołączył"];
    const rows = sorted.map((s) => [s.first_name, s.last_name, s.email, s.phone, s.plan_display_name, s.sub_status, s.total_sessions, s.tokens_used, s.tokens_remaining, s.tokens_limit, s.period_end, s.days_until_renewal, s.credit_alert || s.expiry_alert || "-", s.urgency_score, s.created_at]);
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

  // Active filters count
  const activeFilterCount = [filters.tier, filters.status, filters.alert, filters.search].filter(Boolean).length;

  // Priority inbox items — P3.8: show overdue (due_date < today) + today's (due_date == today)
  const today = new Date().toISOString().slice(0, 10);
  const priorityItems = followUps.filter((f) => !f.completed && (f.overdue || f.due_date === today)).slice(0, 8);

  // ─── Render ────────────────────────────────────────────────

  return (
    <div className="min-h-screen bg-[var(--crm-bg)] transition-colors duration-300" style={themeVars}>
    <div className="px-4 sm:px-6 lg:px-8 py-8 max-w-[1400px] mx-auto">
      {/* Header */}
      <header className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 mb-8">
        <div className="flex items-center gap-4">
          <img src="/images/capybara-crm.png" alt="Kapibara CRM" className="w-12 h-12 sm:w-14 sm:h-14 rounded-2xl object-cover" />
          <div>
            <h1 className="text-[var(--crm-heading)] text-2xl sm:text-3xl font-bold tracking-tight">Panel CRM</h1>
            <p className="text-[var(--crm-muted)] mt-0.5 text-sm">{t("subhead")}</p>
          </div>
        </div>
        <div className="flex gap-2 self-start sm:self-auto">
          <button onClick={toggleTheme} className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] text-[var(--crm-text)] w-10 h-10 flex items-center justify-center text-base hover:bg-[var(--crm-border)] transition" title={isDark ? "Tryb jasny" : "Tryb ciemny"}>
            {isDark ? "☀️" : "🌙"}
          </button>
          <button onClick={() => { void fetchSubscribers(); void fetchFollowUps(); }} className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] text-[var(--crm-text)] px-4 py-2.5 text-xs font-semibold hover:bg-[var(--crm-border)] hover:border-[var(--crm-muted)] transition" title="Odśwież dane">
            ↻ Odśwież
          </button>
          <button onClick={exportCSV} className="rounded-lg bg-[var(--crm-ember-subtle)] border border-[var(--crm-ember-border)] text-[var(--crm-ember-text)] px-4 py-2.5 text-xs font-semibold hover:bg-[var(--crm-ember-bg-hover)] transition">
            📥 Eksport CSV
          </button>
        </div>
      </header>

      {/* ── Priority Inbox ────────────────────────────────── */}
      {priorityItems.length > 0 && (
        <div className="mb-8 rounded-xl bg-[var(--crm-card)] border border-[var(--crm-border)] p-5 sm:p-6">
          <div className="flex items-center justify-between mb-5">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-[var(--crm-ember-bg)] flex items-center justify-center">
                <span className="text-xl">📋</span>
              </div>
              <div>
                <h2 className="text-[var(--crm-heading)] font-bold text-lg">
                  Dziś do kontaktu
                </h2>
                <div className="flex items-center gap-2 mt-0.5">
                  {overdueCount > 0 && <span className="text-[var(--crm-accent-red)] text-xs font-semibold bg-[var(--crm-danger-bg)] px-2 py-0.5 rounded-full">{overdueCount} zaległe</span>}
                  {todayCount > 0 && <span className="text-[var(--crm-ember-text)] text-xs font-semibold bg-[var(--crm-ember-bg)] px-2 py-0.5 rounded-full">{todayCount} na dziś</span>}
                </div>
              </div>
            </div>
          </div>
          <div className="grid gap-2.5">
            {priorityItems.map((f) => (
              <div key={f.id} className={`flex items-center justify-between rounded-lg px-4 py-3.5 transition-all duration-200 hover:brightness-110 ${f.overdue ? "bg-[var(--crm-danger-subtle)] border border-[var(--crm-danger-border)]" : "bg-[var(--crm-ember-subtle)] border border-[var(--crm-ember-border)]"}`}>
                <div className="flex items-center gap-3 min-w-0 flex-1">
                  <button
                    onClick={() => openUserDetail(f.target_user_id)}
                    className={`w-9 h-9 rounded-lg flex items-center justify-center text-xs font-bold flex-shrink-0 transition-transform hover:scale-110 ${getAvatarColor(f.first_name + f.last_name)}`}
                  >
                    {getInitials(f.first_name, f.last_name)}
                  </button>
                  <div className="min-w-0">
                    <button
                      onClick={() => openUserDetail(f.target_user_id)}
                      className="text-[var(--crm-heading)] text-sm font-semibold hover:text-[var(--crm-ember-text)] transition-colors cursor-pointer text-left"
                    >
                      {f.first_name} {f.last_name}
                    </button>
                    <div className="flex items-center gap-2 mt-0.5">
                      {f.note && <span className="text-[var(--crm-muted)] text-xs truncate max-w-[300px]">{f.note}</span>}
                      {f.overdue && <span className="text-[var(--crm-accent-red)] text-[10px] font-bold uppercase bg-[var(--crm-danger-bg)] px-2 py-0.5 rounded-full">zaległe</span>}
                    </div>
                  </div>
                </div>
                <div className="flex gap-2 flex-shrink-0 ml-3">
                  {f.phone && isValidPhone(f.phone) && (
                    <a href={`tel:${normalizePhone(f.phone)}`} className="w-8 h-8 rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] text-[var(--crm-accent-blue)] hover:bg-[var(--crm-border)] transition flex items-center justify-center" title="Zadzwoń">
                      <PhoneIcon />
                    </a>
                  )}
                  <button onClick={() => completeFollowUp(f.id)} className="w-8 h-8 rounded-lg bg-[var(--crm-success-bg)] border border-[var(--crm-success-border)] text-[var(--crm-accent-green)] hover:bg-[var(--crm-success-border)] transition flex items-center justify-center text-sm font-bold" title="Oznacz jako zrobione">
                    ✓
                  </button>
                  <button onClick={() => deleteFollowUp(f.id)} className="w-8 h-8 rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] text-[var(--crm-muted)] hover:text-[var(--crm-accent-red)] hover:bg-[var(--crm-danger-subtle)] hover:border-[var(--crm-danger-border)] transition flex items-center justify-center text-sm" title="Usuń follow-up">
                    ×
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── KPI Chips ────────────────────────────────────── */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-8">
        <KPIChip label="Łącznie" value={globalStats.total} color="#c9d1d9" onClick={() => {
          setFilters((f) => ({ ...f, alert: "", status: "", tier: "" }));
          setPage(1);
        }} />
        <KPIChip label="Krytyczne" value={globalStats.critical} color="#ef4444" onClick={() => {
          setFilters((f) => ({ ...f, alert: "critical", status: "", tier: "" }));
          setPage(1);
        }} />
        <KPIChip label="Ostrzeżenie" value={globalStats.warning} color="#f97316" onClick={() => {
          setFilters((f) => ({ ...f, alert: "warning", status: "", tier: "" }));
          setPage(1);
        }} />
        <KPIChip label="Wygasa" value={globalStats.expiring} color="#a855f7" onClick={() => {
          setFilters((f) => ({ ...f, alert: "expiring", status: "", tier: "" }));
          setPage(1);
        }} />
        <KPIChip label="Churned" value={globalStats.churned} color="#6b7280" onClick={() => {
          setFilters((f) => ({ ...f, alert: "", status: "CANCELED", tier: "" }));
          setPage(1);
        }} />
      </div>

      {/* ── Filters ───────────────────────────────────────── */}
      <div className="flex flex-wrap items-center gap-2 mb-6">
        <FilterSelect value={filters.tier} onChange={(v) => updateFilter("tier", v)} options={TIER_OPTIONS} />
        <FilterSelect value={filters.status} onChange={(v) => updateFilter("status", v)} options={STATUS_OPTIONS} />
        <FilterSelect value={filters.alert} onChange={(v) => updateFilter("alert", v)} options={ALERT_OPTIONS} />
        <div className="relative flex-1 min-w-[220px]">
          <input
            type="search"
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Szukaj (imię, email, telefon, organizacja)..."
            className="w-full rounded-lg bg-[var(--crm-surface)] border border-[var(--crm-border)] text-[var(--crm-text)] pl-9 pr-4 py-2.5 text-sm focus:outline-none focus:border-[var(--crm-focus)] placeholder:text-[var(--crm-faint)] transition"
          />
          <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--crm-faint)]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
        </div>
        {activeFilterCount > 0 && (
          <button
            onClick={() => { setFilters({ tier: "", status: "", alert: "", search: "" }); setSearchInput(""); setPage(1); }}
            className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] text-[var(--crm-muted)] px-3 py-2.5 text-xs font-semibold hover:text-[var(--crm-text)] hover:bg-[var(--crm-border)] transition"
          >
            ✕ Wyczyść ({activeFilterCount})
          </button>
        )}
      </div>

      {/* ── Table ─────────────────────────────────────────── */}
      {loading && <TableSkeleton columns={7} />}
      {error && (
        <div className="rounded-xl border border-[var(--crm-danger-border)] bg-[var(--crm-danger-subtle)] px-6 py-8 text-center">
          <p className="text-[var(--crm-text)] text-sm font-medium">{error}</p>
          <button onClick={() => void fetchSubscribers()} className="mt-4 inline-flex items-center rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] px-5 py-2.5 text-xs font-semibold text-[var(--crm-text)] hover:bg-[var(--crm-border)] transition">Ponów</button>
        </div>
      )}
      {!loading && !error && sorted.length === 0 && (
        <div className="rounded-xl border border-[var(--crm-border)] bg-[var(--crm-card)] px-6 py-16 text-center">
          <div className="text-5xl mb-4">🔍</div>
          <p className="text-[var(--crm-heading)] text-base font-semibold mb-1">Brak wyników</p>
          <p className="text-[var(--crm-muted)] text-sm">Spróbuj zmienić filtry lub wyszukiwanie</p>
        </div>
      )}
      {!loading && !error && sorted.length > 0 && (
        <>
          <div className="flex items-center justify-between mb-3">
            <p className="text-[var(--crm-muted)] text-xs">
              Pokazano <span className="text-[var(--crm-text)] font-semibold">{(page - 1) * perPage + 1}–{Math.min(page * perPage, totalFiltered)}</span> z {totalFiltered}
              {totalFiltered !== totalAll && <span className="text-[var(--crm-faint)]"> (z {totalAll} wszystkich)</span>}
            </p>
            <div className="flex items-center gap-2">
              <span className="text-[var(--crm-faint)] text-xs">Pokaż:</span>
              <select
                value={perPage}
                onChange={(e) => { setPerPage(Number(e.target.value)); setPage(1); }}
                className="rounded-lg bg-[var(--crm-surface)] border border-[var(--crm-border)] text-[var(--crm-text)] px-2 py-1 text-xs focus:outline-none focus:border-[var(--crm-focus)] cursor-pointer"
              >
                <option value={25}>25</option>
                <option value={50}>50</option>
                <option value={100}>100</option>
              </select>
            </div>
          </div>
          <div className="overflow-x-auto rounded-xl border border-[var(--crm-border)] bg-[var(--crm-surface)]">
            <table className="w-full text-[13px]">
              <thead className="bg-[var(--crm-card)] border-b border-[var(--crm-border)] sticky top-0 z-10">
                <tr>
                  <th className="px-4 py-3.5 text-left w-10">
                    <input
                      type="checkbox"
                      checked={selected.size === sorted.length && sorted.length > 0}
                      onChange={toggleSelectAll}
                      className="rounded border-[var(--crm-border)] bg-[var(--crm-surface)] accent-ember cursor-pointer w-4 h-4"
                      title="Zaznacz / odznacz wszystkich"
                    />
                  </th>
                  <th className="px-4 py-3.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)]">Użytkownik</th>
                  <th className="px-4 py-3.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)]">Plan</th>
                  <th className="px-4 py-3.5 text-center text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)] cursor-pointer hover:text-[var(--crm-text)] transition select-none" onClick={() => toggleSort("credits")}>Kredyty{sortIndicator("credits")}</th>
                  <th className="px-4 py-3.5 text-center text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)] cursor-pointer hover:text-[var(--crm-text)] transition select-none" onClick={() => toggleSort("sessions")}>Sesje{sortIndicator("sessions")}</th>
                  <th className="px-4 py-3.5 text-center text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)] cursor-pointer hover:text-[var(--crm-text)] transition select-none" onClick={() => toggleSort("activity")}>Aktywność{sortIndicator("activity")}</th>
                  <th className="px-4 py-3.5 text-center text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)] cursor-pointer hover:text-[var(--crm-text)] transition select-none" onClick={() => toggleSort("renewal")}>Odnowienie{sortIndicator("renewal")}</th>
                  <th className="px-4 py-3.5 text-center text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)]">Alerty</th>
                  <th className="px-4 py-3.5 text-right text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)]">Akcje</th>
                </tr>
              </thead>
              <tbody>
                {sorted.map((s, idx) => {
                  const creditBar = getCreditBarInfo(s.tokens_remaining, s.tokens_limit);
                  return (
                    <tr
                      key={s.subscription_id}
                      onClick={() => openUserDetail(s.user_id)}
                      className={`border-t border-[var(--crm-border-subtle)] hover:bg-[var(--crm-card)] transition-colors cursor-pointer ${selected.has(s.user_id) ? "bg-[var(--crm-ember-faint)]" : idx % 2 === 1 ? "bg-[var(--crm-surface)]" : "bg-[var(--crm-bg)]"}`}
                    >
                      <td className="px-4 py-3.5" onClick={(e) => e.stopPropagation()}>
                        <input
                          type="checkbox"
                          checked={selected.has(s.user_id)}
                          onChange={() => toggleSelect(s.user_id)}
                          className="rounded border-[var(--crm-border)] bg-[var(--crm-surface)] accent-ember cursor-pointer w-4 h-4"
                        />
                      </td>
                      <td className="px-4 py-3.5">
                        <div className="flex items-center gap-3">
                          <div className={`w-9 h-9 rounded-lg flex items-center justify-center text-xs font-bold flex-shrink-0 ${getAvatarColor(s.first_name + s.last_name)}`}>
                            {getInitials(s.first_name, s.last_name)}
                          </div>
                          <div className="flex flex-col gap-0.5 min-w-0">
                            <span className="text-[var(--crm-text)] font-semibold truncate">{s.first_name} {s.last_name}</span>
                            <span className="text-[var(--crm-muted)] text-xs truncate">{s.email}</span>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3.5">
                        <span className={`inline-flex px-2.5 py-1 rounded-md text-[10px] font-bold uppercase tracking-wider ${getTierBadge(s.plan_tier, isDark)}`}>{s.plan_display_name}</span>
                      </td>
                      <td className="px-4 py-3.5 text-center">
                        <span className={`font-mono text-sm font-bold ${s.credit_alert === "critical" ? "text-[var(--crm-accent-red)]" : s.credit_alert === "warning" ? "text-[var(--crm-ember-text)]" : "text-[var(--crm-text)]"}`}>
                          {s.tokens_remaining}/{s.tokens_limit}
                        </span>
                        <div className="w-16 h-1.5 bg-[var(--crm-elevated)] rounded-full overflow-hidden mx-auto mt-1.5">
                          <div className={`h-full rounded-full transition-all duration-500 ${creditBar.color}`} style={{ width: `${Math.min(creditBar.pct, 100)}%` }} />
                        </div>
                      </td>
                      <td className="px-4 py-3.5 text-center font-mono text-[var(--crm-text)]">{s.total_sessions}</td>
                      <td className="px-4 py-3.5 text-center">
                        {s.last_session_at ? (
                          <span className={`text-xs font-medium ${getActivityColor(s.last_session_at)}`} title={s.last_session_at}>
                            {formatRelativeDate(s.last_session_at)}
                          </span>
                        ) : (
                          <span className="text-[var(--crm-faint)] text-xs">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3.5 text-center">
                        {!s.period_end || s.days_until_renewal > 365 ? (
                          <span className="text-[var(--crm-faint)] font-mono text-xs">—</span>
                        ) : (
                          <span className={`font-mono text-xs font-semibold ${s.days_until_renewal <= 3 ? "text-[var(--crm-accent-red)]" : s.days_until_renewal <= 7 ? "text-[var(--crm-ember-text)]" : "text-[var(--crm-muted)]"}`}>
                            {s.days_until_renewal > 0 ? `${s.days_until_renewal}d` : "wygasł"}
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3.5 text-center">
                        {s.credit_alert === "critical" && <AlertPill color="#ef4444" label="1 kredyt" bgVar="--crm-danger-subtle" />}
                        {s.credit_alert === "warning" && <AlertPill color="#f97316" label="3 kredyty" bgVar="--crm-warning-bg" />}
                        {s.expiry_alert === "imminent" && <AlertPill color="#ef4444" label="3 dni" bgVar="--crm-danger-subtle" />}
                        {!s.credit_alert && !s.expiry_alert && <span className="text-[var(--crm-faint)] text-xs">—</span>}
                      </td>
                      <td className="px-4 py-3.5 text-right" onClick={(e) => e.stopPropagation()}>
                        <div className="inline-flex gap-1.5">
                          {s.phone && isValidPhone(s.phone) && <ActionBtn href={`tel:${normalizePhone(s.phone)}`} title="Zadzwoń" color="#58a6ff"><PhoneIcon /></ActionBtn>}
                          <ActionBtn onClick={() => openEmail(s)} title="Email" color="#f97316"><MailIcon /></ActionBtn>
                          <ActionBtn onClick={() => { setFollowUpTarget(s.user_id); setFollowUpDate(quickDate(3)); }} title="Follow-up" color="#c9d1d9">🔔</ActionBtn>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* ── Pagination ─────────────────────────────────── */}
          <div className="flex items-center justify-between mt-5">
            <p className="text-[var(--crm-muted)] text-xs">Strona {page} z {totalPages}</p>
            <div className="flex items-center gap-1.5">
              <button onClick={() => setPage(Math.max(1, page - 1))} disabled={page <= 1} className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] px-3.5 py-2 text-xs font-semibold text-[var(--crm-text)] hover:bg-[var(--crm-border)] transition disabled:opacity-30 disabled:cursor-not-allowed">← Poprzednia</button>
              {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => {
                let pageNum: number;
                if (totalPages <= 5) pageNum = i + 1;
                else if (page <= 3) pageNum = i + 1;
                else if (page >= totalPages - 2) pageNum = totalPages - 4 + i;
                else pageNum = page - 2 + i;
                return (
                  <button key={pageNum} onClick={() => setPage(pageNum)} className={`w-9 h-9 rounded-lg text-xs font-semibold transition ${page === pageNum ? "bg-ember text-obsidian" : "text-[var(--crm-muted)] hover:bg-[var(--crm-elevated)] hover:text-[var(--crm-text)]"}`}>
                    {pageNum}
                  </button>
                );
              })}
              <button onClick={() => setPage(Math.min(totalPages, page + 1))} disabled={page >= totalPages} className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] px-3.5 py-2 text-xs font-semibold text-[var(--crm-text)] hover:bg-[var(--crm-border)] transition disabled:opacity-30 disabled:cursor-not-allowed">Następna →</button>
            </div>
          </div>
        </>
      )}

      {/* ── Detail Drawer ─────────────────────────────────── */}
      {drawerOpen && (
        <div className="fixed inset-0 z-50 flex justify-end">
          <div className="absolute inset-0" style={{ backgroundColor: isDark ? "rgba(0,0,0,0.5)" : "rgba(0,0,0,0.2)" }} onClick={closeDrawer} />
          <div className={`relative w-full max-w-lg bg-[var(--crm-surface)] border-l border-[var(--crm-border)] overflow-y-auto transition-transform duration-300 ${drawerOpen ? "translate-x-0" : "translate-x-full"}`} style={{ boxShadow: isDark ? "-8px 0 30px rgba(0,0,0,0.7)" : "-8px 0 30px rgba(0,0,0,0.15)" }}>
            {drawerLoading ? (
              <div className="flex items-center justify-center h-64">
                <div className="w-8 h-8 border-2 border-ember border-t-transparent rounded-full animate-spin" />
              </div>
            ) : drawerError ? (
              <div className="flex flex-col items-center justify-center h-64 gap-3">
                <p className="text-[var(--crm-accent-red)] text-sm font-medium">{drawerError}</p>
                <button onClick={closeDrawer} className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] px-4 py-2 text-xs font-semibold text-[var(--crm-text)] hover:bg-[var(--crm-border)]">Zamknij</button>
              </div>
            ) : selectedUser && (
              <div className="p-6 space-y-6">
                <button onClick={closeDrawer} className="absolute top-4 right-4 text-[var(--crm-muted)] hover:text-[var(--crm-heading)] transition w-8 h-8 rounded-lg hover:bg-[var(--crm-elevated)] flex items-center justify-center">✕</button>

                {/* Contact Card */}
                <div className="border-b border-[var(--crm-border-subtle)] pb-6">
                  <div className="flex items-start gap-4">
                    <div className={`w-14 h-14 rounded-2xl flex items-center justify-center text-lg font-bold flex-shrink-0 ${getAvatarColor(selectedUser.first_name + selectedUser.last_name)}`}>
                      {getInitials(selectedUser.first_name, selectedUser.last_name)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <h2 className="text-[var(--crm-heading)] text-xl font-bold">{selectedUser.first_name} {selectedUser.last_name}</h2>
                          {selectedUser.professional_title && <p className="text-[var(--crm-muted)] text-sm mt-0.5">{selectedUser.professional_title}</p>}
                        </div>
                        {LIFECYCLE_LABELS[selectedUser.lifecycle_stage] && (
                          <span className={`px-2.5 py-1 rounded-lg text-[10px] font-bold uppercase flex-shrink-0 ${LIFECYCLE_LABELS[selectedUser.lifecycle_stage].color}`}>
                            {LIFECYCLE_LABELS[selectedUser.lifecycle_stage].emoji} {LIFECYCLE_LABELS[selectedUser.lifecycle_stage].label}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                  <div className="mt-4 space-y-2">
                    <p className="text-sm text-[var(--crm-muted)]">📧 <a href={`mailto:${selectedUser.email}`} className="text-[var(--crm-text)] hover:text-[var(--crm-ember-text)] transition">{selectedUser.email}</a></p>
                    {selectedUser.phone && (
                      <p className="text-sm text-[var(--crm-muted)]">
                        📱 <a href={isValidPhone(selectedUser.phone) ? `tel:${normalizePhone(selectedUser.phone)}` : undefined} className={`${isValidPhone(selectedUser.phone) ? "text-[var(--crm-text)] hover:text-[var(--crm-ember-text)] transition" : "text-[var(--crm-muted)]"}`}>
                          {formatPhoneDisplay(selectedUser.phone)}
                        </a>
                      </p>
                    )}
                    <p className="text-xs text-[var(--crm-faint)]">Dołączył: {selectedUser.created_at}</p>
                    {selectedUser.last_session_at && <p className="text-xs text-[var(--crm-faint)]">Ostatnia sesja: {selectedUser.last_session_at}</p>}
                  </div>
                  <div className="grid grid-cols-3 gap-2 mt-4">
                    <MiniStat label="Sesje" value={selectedUser.total_sessions} />
                    <MiniStat label="Kredyty" value={`${selectedUser.tokens_remaining}/${selectedUser.tokens_limit}`} />
                    <MiniStat label="Dni do końca" value={selectedUser.days_until_renewal > 365 ? "—" : selectedUser.days_until_renewal} />
                  </div>
                </div>

                {/* Tags */}
                <div>
                  <h3 className="text-xs font-semibold uppercase tracking-wider text-[var(--crm-muted)] mb-3">Tagi</h3>
                  <div className="flex flex-wrap gap-1.5 mb-3">
                    {selectedUser.tags.map((tag) => {
                      const hex = getTagColor(tag.color);
                      const surfaceBg = isDark ? "#0d1117" : "#ffffff";
                      return (
                        <span key={tag.id} className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border text-xs font-medium" style={{ borderColor: solidTint(hex, surfaceBg, 0.3), backgroundColor: solidTint(hex, surfaceBg, 0.12), color: hex }}>
                          <span className="w-2 h-2 rounded-full flex-shrink-0" style={{ backgroundColor: hex }} />
                          {tag.tag}
                          <button onClick={() => removeTag(tag.id)} className="hover:brightness-150 transition ml-0.5 opacity-70 hover:opacity-100">×</button>
                        </span>
                      );
                    })}
                    {selectedUser.tags.length === 0 && <p className="text-[var(--crm-faint)] text-xs">Brak tagów</p>}
                  </div>
                  <div className="flex gap-2 items-end">
                    <div className="flex-1">
                      <input
                        value={newTag}
                        onChange={(e) => setNewTag(e.target.value)}
                        onKeyDown={(e) => e.key === "Enter" && addTag()}
                        placeholder="nowy tag..."
                        className="w-full rounded-lg bg-[var(--crm-surface)] border border-[var(--crm-border)] px-3 py-2 text-[var(--crm-text)] text-xs focus:outline-none focus:border-[var(--crm-focus)] transition"
                      />
                      <div className="flex gap-1 mt-1.5">
                        {TAG_COLORS.map((c) => (
                          <button key={c.name} onClick={() => setNewTagColor(c.name)} className={`w-4 h-4 rounded-full transition-all ${newTagColor === c.name ? "ring-2 ring-offset-1 ring-offset-[var(--crm-surface)] ring-[var(--crm-muted)]" : "opacity-50 hover:opacity-100"}`} style={{ backgroundColor: c.hex }} title={c.name} />
                        ))}
                      </div>
                    </div>
                    <button onClick={addTag} disabled={!newTag.trim()} className="px-3 py-2 rounded-lg bg-[var(--crm-ember-bg)] border border-[var(--crm-ember-border)] text-[var(--crm-ember-text)] text-xs font-semibold hover:bg-[var(--crm-ember-bg-hover)] transition disabled:opacity-30">+</button>
                  </div>
                </div>

                {/* Follow-ups */}
                <div>
                  <h3 className="text-xs font-semibold uppercase tracking-wider text-[var(--crm-muted)] mb-3">Follow-upy</h3>
                  {selectedUser.follow_ups.length > 0 ? (
                    <div className="space-y-2 mb-3">
                      {selectedUser.follow_ups.map((f) => (
                        <div key={f.id} className={`flex items-center justify-between rounded-lg px-3 py-2.5 text-xs ${f.completed ? "bg-[var(--crm-elevated)]/50 text-[var(--crm-faint)] line-through" : f.overdue ? "bg-[var(--crm-danger-subtle)] border border-[var(--crm-danger-border)] text-[var(--crm-text)]" : "bg-[var(--crm-card)] border border-[var(--crm-border)] text-[var(--crm-text)]"}`}>
                          <span className="font-mono">{f.due_date} {f.note && `— ${f.note}`}</span>
                          <div className="flex gap-1.5">
                            {!f.completed && (
                              <>
                                <button onClick={() => completeFollowUp(f.id)} className="text-[var(--crm-accent-green)] hover:text-[var(--crm-heading)] transition font-bold" title="Zakończ">✓</button>
                                <button onClick={() => deleteFollowUp(f.id)} className="text-[var(--crm-muted)] hover:text-[var(--crm-accent-red)] transition" title="Usuń">×</button>
                              </>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-[var(--crm-faint)] text-xs mb-3">Brak zaplanowanych follow-upów</p>
                  )}
                  <button onClick={() => { setFollowUpTarget(selectedUser.user_id); setFollowUpDate(quickDate(3)); }} className="w-full rounded-lg bg-[var(--crm-card)] border border-[var(--crm-border)] px-3 py-2.5 text-[var(--crm-text)] text-xs font-semibold hover:bg-[var(--crm-elevated)] transition">
                    + Zaplanuj follow-up
                  </button>
                </div>

                {/* Email Templates */}
                <div>
                  <h3 className="text-xs font-semibold uppercase tracking-wider text-[var(--crm-muted)] mb-3">Szybki email</h3>
                  <div className="grid grid-cols-2 gap-2">
                    {EMAIL_TEMPLATES.map((tmpl) => (
                      <button key={tmpl.id} onClick={() => openEmail(selectedUser, tmpl.id)} className="text-left rounded-lg bg-[var(--crm-card)] border border-[var(--crm-border)] px-3 py-2.5 text-xs font-medium text-[var(--crm-text)] hover:bg-[var(--crm-elevated)] hover:border-[var(--crm-muted)] transition">
                        {tmpl.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Email History */}
                {selectedUser.email_logs && selectedUser.email_logs.length > 0 && (
                  <div>
                    <h3 className="text-xs font-semibold uppercase tracking-wider text-[var(--crm-muted)] mb-3">📬 Historia kontaktu ({selectedUser.email_logs.length})</h3>
                    <div className="space-y-1.5 max-h-40 overflow-y-auto">
                      {selectedUser.email_logs.map((log) => (
                        <div key={log.id} className="flex items-center justify-between rounded-lg px-3 py-2.5 bg-[var(--crm-card)] border border-[var(--crm-border)] text-xs">
                          <div className="flex items-center gap-2">
                            <span className="text-[var(--crm-ember-text)]">📧</span>
                            <span className="text-[var(--crm-text)] font-medium">{log.subject}</span>
                          </div>
                          <span className="text-[var(--crm-faint)] text-[10px]">{new Date(log.sent_at).toLocaleDateString("pl-PL", { day: "numeric", month: "short" })}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Notes */}
                <div>
                  <h3 className="text-xs font-semibold uppercase tracking-wider text-[var(--crm-muted)] mb-3">📓 Notatki ({selectedUser.notes.length})</h3>
                  <div className="flex gap-2 mb-3">
                    <textarea
                      value={newNote}
                      onChange={(e) => setNewNote(e.target.value)}
                      placeholder="Dodaj notatkę..."
                      rows={2}
                      className="flex-1 rounded-lg bg-[var(--crm-surface)] border border-[var(--crm-border)] px-3 py-2.5 text-[var(--crm-text)] text-xs resize-none focus:outline-none focus:border-[var(--crm-focus)] transition"
                    />
                    <button onClick={addNote} disabled={!newNote.trim() || noteSaving} className="px-4 rounded-lg bg-[var(--crm-ember-bg)] border border-[var(--crm-ember-border)] text-[var(--crm-ember-text)] text-xs font-semibold hover:bg-[var(--crm-ember-bg-hover)] transition disabled:opacity-40 self-end">
                      {noteSaving ? "..." : "📝"}
                    </button>
                  </div>
                  <div className="space-y-2 max-h-64 overflow-y-auto">
                    {selectedUser.notes.map((note) => (
                      <div key={note.id} className="rounded-lg bg-[var(--crm-card)] border border-[var(--crm-border)] px-3.5 py-3">
                        <p className="text-[var(--crm-text)] text-xs leading-relaxed whitespace-pre-wrap">{note.body}</p>
                        <p className="text-[var(--crm-faint)] text-[10px] mt-1.5">{new Date(note.created_at).toLocaleDateString("pl-PL", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}</p>
                      </div>
                    ))}
                    {selectedUser.notes.length === 0 && <p className="text-[var(--crm-faint)] text-xs">Brak notatek</p>}
                  </div>
                </div>

                {/* Exclusion */}
                <div className="border-t border-[var(--crm-border-subtle)] pt-4">
                  <button
                    onClick={() => {
                      setConfirmAction({
                        message: `Czy na pewno chcesz wykluczyć ${selectedUser.first_name} ${selectedUser.last_name} z CRM?`,
                        onConfirm: () => { excludeUser(selectedUser.user_id); setConfirmAction(null); },
                      });
                    }}
                    className="w-full rounded-lg bg-[var(--crm-danger-subtle)] border border-[var(--crm-danger-border)] px-3 py-2.5 text-[var(--crm-accent-red)] text-xs font-semibold uppercase tracking-wider hover:bg-[var(--crm-danger-bg)] transition"
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
        <div className="fixed inset-0 z-50 flex items-center justify-center" style={{ backgroundColor: isDark ? "rgba(0,0,0,0.6)" : "rgba(0,0,0,0.25)" }}>
          <div className="bg-[var(--crm-card)] border border-[var(--crm-border)] rounded-xl p-6 w-full max-w-lg mx-4 shadow-2xl">
            <h3 className="text-[var(--crm-heading)] text-lg font-bold mb-1">✉️ Email do {emailTarget.name}</h3>
            <p className="text-[var(--crm-muted)] text-xs mb-0.5">{emailTarget.email}</p>
            <p className="text-[var(--crm-faint)] text-[10px] mb-4">od: {SENDER_EMAIL}</p>
            <input value={emailSubject} onChange={(e) => setEmailSubject(e.target.value)} placeholder="Temat..." className="w-full rounded-lg bg-[var(--crm-surface)] border border-[var(--crm-border)] text-[var(--crm-text)] px-4 py-2.5 text-sm focus:outline-none focus:border-[var(--crm-focus)] mb-3" />
            <textarea value={emailBody} onChange={(e) => setEmailBody(e.target.value)} rows={10} className="w-full rounded-lg bg-[var(--crm-surface)] border border-[var(--crm-border)] text-[var(--crm-text)] px-4 py-3 text-sm focus:outline-none focus:border-[var(--crm-focus)] transition resize-y mb-4" />
            <div className="flex justify-end gap-3">
              <button onClick={() => { setEmailTarget(null); setEmailSubject(""); setEmailBody(""); }} className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] px-4 py-2.5 text-xs font-semibold text-[var(--crm-muted)] hover:text-[var(--crm-text)] transition">Anuluj</button>
              <button onClick={sendEmail} disabled={!emailBody.trim()} className="rounded-lg bg-ember text-obsidian px-5 py-2.5 text-xs font-bold uppercase hover:brightness-110 transition disabled:opacity-50">Otwórz w kliencie email</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Follow-up Modal ───────────────────────────────── */}
      {followUpTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center" style={{ backgroundColor: isDark ? "rgba(0,0,0,0.6)" : "rgba(0,0,0,0.25)" }}>
          <div className="bg-[var(--crm-card)] border border-[var(--crm-border)] rounded-xl p-6 w-full max-w-sm mx-4 shadow-2xl">
            <h3 className="text-[var(--crm-heading)] text-lg font-bold mb-4">🔔 Zaplanuj follow-up</h3>
            <div className="flex flex-wrap gap-2 mb-4">
              <QuickDateBtn label="Jutro" onClick={() => setFollowUpDate(quickDate(1))} active={followUpDate === quickDate(1)} />
              <QuickDateBtn label="Za 3 dni" onClick={() => setFollowUpDate(quickDate(3))} active={followUpDate === quickDate(3)} />
              <QuickDateBtn label="Poniedziałek" onClick={() => setFollowUpDate(nextMonday())} active={followUpDate === nextMonday()} />
              <QuickDateBtn label="Za tydzień" onClick={() => setFollowUpDate(quickDate(7))} active={followUpDate === quickDate(7)} />
            </div>
            <input type="date" value={followUpDate} onChange={(e) => setFollowUpDate(e.target.value)} className="w-full rounded-lg bg-[var(--crm-surface)] border border-[var(--crm-border)] text-[var(--crm-text)] px-3 py-2.5 text-sm focus:outline-none focus:border-[var(--crm-focus)] mb-3" />
            <input value={followUpNote} onChange={(e) => setFollowUpNote(e.target.value)} placeholder="Notatka (opcjonalna)..." className="w-full rounded-lg bg-[var(--crm-surface)] border border-[var(--crm-border)] text-[var(--crm-text)] px-3 py-2.5 text-sm focus:outline-none focus:border-[var(--crm-focus)] mb-4" />
            <div className="flex justify-end gap-3">
              <button onClick={() => { setFollowUpTarget(null); setFollowUpDate(""); setFollowUpNote(""); }} className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] px-4 py-2.5 text-xs font-semibold text-[var(--crm-muted)] hover:text-[var(--crm-text)] transition">Anuluj</button>
              <button onClick={createFollowUp} disabled={!followUpDate} className="rounded-lg bg-ember text-obsidian px-5 py-2.5 text-xs font-bold uppercase hover:brightness-110 transition disabled:opacity-50">Zapisz</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Bulk Actions Bar ─────────────────────────────── */}
      {selected.size > 0 && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-40 bg-[var(--crm-card)] border border-[var(--crm-ember-border)] rounded-xl px-6 py-3.5 shadow-2xl flex items-center gap-4 animate-[slideUp_0.2s_ease-out]">
          <span className="text-xs text-[var(--crm-text)] font-medium">Zaznaczono: <span className="text-[var(--crm-ember-text)] font-bold">{selected.size}</span></span>
          <button onClick={bulkEmail} className="rounded-lg bg-[var(--crm-ember-bg)] border border-[var(--crm-ember-border)] text-[var(--crm-ember-text)] px-3.5 py-2 text-xs font-semibold hover:bg-[var(--crm-ember-bg-hover)] transition">📧 Email</button>
          <button onClick={bulkRemind} className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] text-[var(--crm-text)] px-3.5 py-2 text-xs font-semibold hover:bg-[var(--crm-border)] transition">🔔 Przypomnij</button>
          <button onClick={bulkDelete} className="rounded-lg bg-[var(--crm-danger-subtle)] border border-[var(--crm-danger-border)] text-[var(--crm-accent-red)] px-3.5 py-2 text-xs font-semibold hover:bg-[var(--crm-danger-bg)] transition">🗑️ Usuń</button>
          <button onClick={() => setSelected(new Set())} className="text-[var(--crm-muted)] hover:text-[var(--crm-heading)] transition text-xs font-semibold">✕ Odznacz</button>
        </div>
      )}

      {/* ── Confirmation Modal ───────────────────────────── */}
      {confirmAction && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center" style={{ backgroundColor: isDark ? "rgba(0,0,0,0.6)" : "rgba(0,0,0,0.25)" }}>
          <div className="bg-[var(--crm-card)] border border-[var(--crm-border)] rounded-xl p-6 w-full max-w-sm mx-4 shadow-2xl">
            <p className="text-[var(--crm-text)] text-sm mb-6">{confirmAction.message}</p>
            <div className="flex justify-end gap-3">
              <button onClick={() => setConfirmAction(null)} className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] px-4 py-2.5 text-xs font-semibold text-[var(--crm-muted)] hover:text-[var(--crm-text)] transition">Anuluj</button>
              <button onClick={confirmAction.onConfirm} className="rounded-lg bg-ember text-obsidian px-5 py-2.5 text-xs font-bold uppercase hover:brightness-110 transition">Tak, potwierdź</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Toast ───────────────────────────────────────── */}
      {toast && (
        <div className="fixed top-6 right-6 z-[70] bg-[var(--crm-card)] border border-[var(--crm-border)] rounded-xl px-5 py-3.5 shadow-2xl animate-[slideIn_0.3s_ease-out]">
          <p className="text-[var(--crm-text)] text-sm font-medium">{toast}</p>
          <div className="h-0.5 bg-[var(--crm-toast-bar)] rounded-full mt-2.5 animate-[shrink_3.5s_linear_forwards]" />
        </div>
      )}

      <style>{`
        @keyframes slideUp { from { opacity: 0; transform: translate(-50%, 20px); } to { opacity: 1; transform: translate(-50%, 0); } }
        @keyframes slideIn { from { opacity: 0; transform: translateX(20px); } to { opacity: 1; transform: translateX(0); } }
        @keyframes shrink { from { width: 100%; } to { width: 0%; } }
      `}</style>
    </div>
    </div>
  );
}

// ─── Sub-components ──────────────────────────────────────────

function KPIChip({ label, value, color, onClick }: { label: string; value: number; color: string; onClick?: () => void }) {
  return (
    <div onClick={onClick} className={`rounded-xl bg-[var(--crm-card)] border border-[var(--crm-border)] px-4 py-4 text-center hover:bg-[var(--crm-elevated)] transition-colors ${onClick ? "cursor-pointer" : ""}`}>
      <div className="text-3xl font-bold" style={{ color }}>{value}</div>
      <div className="text-[11px] font-semibold text-[var(--crm-muted)] uppercase tracking-wider mt-1.5">{label}</div>
    </div>
  );
}

function FilterSelect({ value, onChange, options }: { value: string; onChange: (v: string) => void; options: { value: string; label: string }[] }) {
  return (
    <select value={value} onChange={(e) => onChange(e.target.value)} className="rounded-lg bg-[var(--crm-surface)] border border-[var(--crm-border)] text-[var(--crm-text)] px-3.5 py-2.5 text-sm focus:outline-none focus:border-[var(--crm-focus)] transition cursor-pointer">
      {options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
    </select>
  );
}

function AlertPill({ color, label, bgVar }: { color: string; label: string; bgVar: string }) {
  return <span className="px-2.5 py-1 rounded-md text-[10px] font-bold uppercase" style={{ backgroundColor: `var(${bgVar})`, color }}>{label}</span>;
}

function ActionBtn({ children, onClick, href, title, color }: { children: React.ReactNode; onClick?: () => void; href?: string; title: string; color: string }) {
  const cls = "w-8 h-8 rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] hover:bg-[var(--crm-border)] transition flex items-center justify-center";
  if (href) return <a href={href} title={title} className={cls} style={{ color }}>{children}</a>;
  return <button onClick={onClick} title={title} className={cls} style={{ color }}>{children}</button>;
}

function MiniStat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg bg-[var(--crm-card)] border border-[var(--crm-border)] px-3 py-2.5 text-center">
      <div className="font-mono text-[var(--crm-heading)] text-base font-bold">{value}</div>
      <div className="text-[10px] font-semibold text-[var(--crm-muted)] uppercase tracking-wide mt-0.5">{label}</div>
    </div>
  );
}

function QuickDateBtn({ label, onClick, active }: { label: string; onClick: () => void; active: boolean }) {
  return (
    <button onClick={onClick} className={`px-3.5 py-2 rounded-lg text-xs font-semibold transition ${active ? "bg-ember text-obsidian" : "bg-[var(--crm-elevated)] border border-[var(--crm-border)] text-[var(--crm-text)] hover:bg-[var(--crm-border)]"}`}>
      {label}
    </button>
  );
}

function getTierBadge(tier: string, isDark: boolean): string {
  if (!isDark) {
    // Light mode: SOLID full-color backgrounds, maximum contrast text
    switch (tier) {
      case "BETA": return "bg-[#7C3AED] text-white border border-[#7C3AED]";
      case "TRIAL": return "bg-[#6B7280] text-white border border-[#6B7280]";
      case "SOLO": return "bg-ember text-[#1F1F1F] border border-ember";
      case "PRO": return "bg-[#DC2626] text-white border border-[#DC2626]";
      case "CLINIC": return "bg-[#1F2937] text-white border border-[#1F2937]";
      default: return "bg-[var(--crm-elevated)] text-[var(--crm-heading)] border border-[var(--crm-border)]";
    }
  }
  // Dark mode: subtle tinted backgrounds
  switch (tier) {
    case "BETA": return "bg-[var(--crm-purple-bg)] text-[var(--crm-accent-purple)] border border-[var(--crm-purple-border)]";
    case "TRIAL": return "bg-[var(--crm-neutral-bg)] text-[var(--crm-muted)] border border-[var(--crm-muted)]";
    case "SOLO": return "bg-[var(--crm-ember-bg)] text-[var(--crm-ember-text)] border border-[var(--crm-ember-border)]";
    case "PRO": return "bg-[var(--crm-danger-bg)] text-[var(--crm-accent-red)] border border-[var(--crm-danger-border)]";
    case "CLINIC": return "bg-[var(--crm-neutral-bg)] text-[var(--crm-text)] border border-[var(--crm-border)]";
    default: return "bg-[var(--crm-elevated)] text-[var(--crm-muted)] border border-[var(--crm-border)]";
  }
}

function PhoneIcon() {
  return <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" /></svg>;
}

function MailIcon() {
  return <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>;
}


