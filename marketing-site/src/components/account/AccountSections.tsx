// Therapist account management surface — Apple Settings-style layout
//
// Five category sections, each as a frosted-glass card:
//   1. TWOJE KONTO (Profile — editable profile fields + modality)
//   2. ORGANIZACJA (Org — legal name, NIP, address, etc.)
//   3. SUBSKRYPCJA (Billing — read-only + active upgrade CTA)
//   4. INFORMACJE PRAWNE (Legal links)
//   5. ZARZĄDZANIE KONTEM (Logout + delete account)
//
// Plus a header card with email + kartoteki CTA + sign-out.
// Typography: Montserrat (font-sans) for all labels, fields, headings.
// Roboto Mono (font-mono) only for tiny meta details (email badge, version).

"use client";

import { useEffect, useState, useCallback } from "react";
import { useTranslations } from "next-intl";
import { useLocale } from "next-intl";
import Link from "next/link";
import { useSearchParams, useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { ConnectError, Code } from "@connectrpc/connect";
import { playSuccessSound } from "../register/SuccessContent";

import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient, billingClient } from "@/lib/connect/clients";
import { openAppWithSso } from "@/lib/auth/open-app-sso";
import {
  GetSubscriptionRequestSchema,
  ListInvoicesRequestSchema,
} from "@superwizor/proto-ts/billing/v1/billing_pb";
import {
  UpdateProfileRequestSchema,
  UpdateMyOrganizationRequestSchema,
  AddressSchema,
  OrganizationType,
  type User,
  type Organization,
  GetReportPreferencesRequestSchema,
  UpdateReportPreferencesRequestSchema,
  ReportPreferencesSchema,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import type {
  Subscription,
  Invoice,
  BillingSurface,
} from "@superwizor/proto-ts/billing/v1/billing_pb";

import { getModalityCatalog, type ModalityRow } from "@/lib/clinical/modalities";
import { PhoneInput } from "@/components/forms/Field";

const APP_URL = "https://superwizor-app.web.app/";

export function AccountSections() {
  const t = useTranslations("account");
  const locale = useLocale();
  const { user: fbUser, signOut } = useAuth();
  const [showDeleteFlow, setShowDeleteFlow] = useState(false);
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false);

  const searchParams = useSearchParams();
  const upgraded = searchParams.get("upgraded");

  const [profile, setProfile] = useState<User | null>(null);
  const [profileError, setProfileError] = useState<string | null>(null);

  const [pollStatus, setPollStatus] = useState<"idle" | "polling" | "success" | "timeout">("idle");
  const [upgradedSub, setUpgradedSub] = useState<Subscription | null>(null);
  const [tokenCount, setTokenCount] = useState(0);
  const [particles, setParticles] = useState<any[]>([]);

  const triggerConfetti = useCallback(() => {
    const generated: any[] = [];
    const colors = [
      "#F5A623", // Gold
      "#4FC097", // Emerald
      "#38B2AC", // Teal
      "#F6AD55", // Orange
      "#EC4899", // Pink
      "#3B82F6", // Blue
      "#A855F7", // Purple
      "#10B981", // Green
    ];
    const shapes: ("circle" | "square" | "triangle")[] = ["circle", "square", "triangle"];

    for (let i = 0; i < 90; i++) {
      const angle = (Math.random() * 120 + 210) * (Math.PI / 180);
      const distance = 160 + Math.random() * 280;
      const x = Math.cos(angle) * distance;
      const y = Math.sin(angle) * distance;

      generated.push({
        id: i,
        x,
        y,
        color: colors[Math.floor(Math.random() * colors.length)],
        size: 6 + Math.random() * 8,
        delay: Math.random() * 0.15,
        duration: 1.6 + Math.random() * 0.8,
        rotate: Math.random() * 360,
        shape: shapes[Math.floor(Math.random() * shapes.length)],
      });
    }
    setParticles(generated);
  }, []);

  useEffect(() => {
    if (upgraded !== "1" || !profile?.organizationId) return;

    setPollStatus("polling");
    let attempts = 0;
    let timerId: NodeJS.Timeout;

    const poll = async () => {
      try {
        const s = await billingClient.getSubscription(
          create(GetSubscriptionRequestSchema, { organizationId: profile.organizationId }),
        );
        if (s && s.planTier && s.planTier !== "TRIAL" && s.planTier !== "BETA") {
          setUpgradedSub(s);
          setPollStatus("success");
          return;
        }

        attempts++;
        if (attempts >= 8) {
          setUpgradedSub(s || null);
          setPollStatus("timeout");
        } else {
          timerId = setTimeout(poll, 1500);
        }
      } catch (e) {
        console.error("Error polling subscription status:", e);
        attempts++;
        if (attempts >= 8) {
          setPollStatus("timeout");
        } else {
          timerId = setTimeout(poll, 1500);
        }
      }
    };

    poll();
    return () => {
      if (timerId) clearTimeout(timerId);
    };
  }, [profile, upgraded]);

  const targetTokens = upgradedSub?.tokensPerPeriod || 30;
  useEffect(() => {
    if (pollStatus !== "success" && pollStatus !== "timeout") return;

    try {
      playSuccessSound();
    } catch (e) {
      console.warn("Chime blocked by browser autoplay policy:", e);
    }

    triggerConfetti();

    let start = 0;
    const duration = 2000;
    const intervalTime = 30;
    const stepCount = duration / intervalTime;
    const increment = targetTokens / stepCount;

    const counter = setInterval(() => {
      start += increment;
      if (start >= targetTokens) {
        setTokenCount(targetTokens);
        clearInterval(counter);
      } else {
        setTokenCount(Math.floor(start));
      }
    }, intervalTime);

    return () => clearInterval(counter);
  }, [pollStatus, targetTokens, triggerConfetti]);

  const [openSections, setOpenSections] = useState({
    profile: true,
    organization: true,
    preferences: true,
    billing: true,
    legal: true,
    mgmt: true,
  });

  const [activeAnchor, setActiveAnchor] = useState<string>("profile");

  const toggleSection = (key: keyof typeof openSections) => {
    setOpenSections((prev) => ({ ...prev, [key]: !prev[key] }));
  };

  const handleNavClick = (key: keyof typeof openSections) => {
    setOpenSections((prev) => ({ ...prev, [key]: true }));
    setTimeout(() => {
      const element = document.getElementById(key);
      if (element) {
        element.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    }, 50);
  };

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setActiveAnchor(entry.target.id);
          }
        });
      },
      {
        rootMargin: "-20% 0px -60% 0px",
        threshold: 0,
      }
    );

    const ids = ["profile", "organization", "preferences", "billing", "legal", "mgmt"];
    ids.forEach((id) => {
      const el = document.getElementById(id);
      if (el) observer.observe(el);
    });

    return () => {
      ids.forEach((id) => {
        const el = document.getElementById(id);
        if (el) observer.unobserve(el);
      });
    };
  }, [openSections]);

  useEffect(() => {
    if (!fbUser) return;
    let cancelled = false;
    (async () => {
      try {
        const me = await identityClient.getMyProfile(create(EmptySchema, {}));
        if (!cancelled) setProfile(me);
      } catch (e) {
        console.error("[account] load profile failed", e);
        if (!cancelled) setProfileError(t("errLoad"));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [fbUser, t]);

  if (!fbUser) return null;

  const prefix = locale === "en" ? "/en" : "";

  if (upgraded === "1") {
    return (
      <div className="w-full relative">
        <AnimatePresence mode="wait">
          {pollStatus === "polling" || pollStatus === "idle" ? (
            <motion.div
              key="polling"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="rounded-2xl border border-white/[0.08] bg-white/[0.04] backdrop-blur-md p-10 flex flex-col items-center justify-center text-center min-h-[400px]"
            >
              <div className="relative w-16 h-16 mb-6">
                <div className="absolute inset-0 rounded-full border-4 border-white/5" />
                <div className="absolute inset-0 rounded-full border-4 border-t-[#F5A623] animate-spin" />
              </div>
              <h2 className="font-serif text-[#F2F0EA] text-xl font-bold mb-2">
                {locale === "pl" ? "Aktywacja subskrypcji..." : "Activating subscription..."}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] max-w-sm">
                {locale === "pl"
                  ? "Weryfikujemy płatność w Stripe. To potrwa tylko chwilę."
                  : "We are verifying your payment with Stripe. This will only take a moment."}
              </p>
            </motion.div>
          ) : (
            <motion.div
              key="success"
              initial={{ opacity: 0, scale: 0.96 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ type: "spring", stiffness: 100, damping: 20 }}
              className="relative rounded-3xl bg-gradient-to-b from-[#0F2E32]/90 to-[#0A2326]/95 border border-[#1A3A3E] p-8 sm:p-12 shadow-[0_20px_50px_rgba(0,0,0,0.4)] backdrop-blur-xl text-center overflow-visible"
            >
              {tokenCount === targetTokens && (
                <motion.div
                  initial={{ scale: 0.8, opacity: 0, y: -5 }}
                  animate={{ scale: 1, opacity: 1, y: 0 }}
                  transition={{ type: "spring", stiffness: 120, damping: 14 }}
                  className="absolute top-4 right-4 sm:top-6 sm:right-6 flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#4FC097]/10 border border-[#4FC097]/25 text-[#4FC097] text-[10px] sm:text-xs font-bold uppercase tracking-widest shadow-[0_0_15px_rgba(79,192,151,0.08)] backdrop-blur-md z-10"
                >
                  <span className="relative flex h-1.5 w-1.5 sm:h-2 sm:w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#4FC097] opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-1.5 w-1.5 sm:h-2 sm:w-2 bg-[#4FC097]"></span>
                  </span>
                  <span>{locale === "pl" ? "Subskrypcja aktywna" : "Subscription active"}</span>
                </motion.div>
              )}

              <div className="absolute inset-0 overflow-visible pointer-events-none z-50">
                {particles.map((p) => (
                  <motion.div
                    key={p.id}
                    className="absolute"
                    initial={{ x: 0, y: 0, scale: 0, rotate: 0, opacity: 1 }}
                    animate={{
                      x: p.x,
                      y: [0, p.y * 0.4, p.y, p.y + 200],
                      scale: [0, 1, 1, 0.7, 0],
                      rotate: [0, p.rotate, p.rotate * 2.5, p.rotate * 4],
                      opacity: [1, 1, 1, 0.9, 0],
                    }}
                    transition={{
                      duration: p.duration,
                      ease: [0.1, 0.8, 0.25, 1],
                      delay: p.delay,
                    }}
                    style={{
                      width: p.shape === "triangle" ? 0 : p.size,
                      height: p.shape === "triangle" ? 0 : p.size,
                      backgroundColor: p.shape !== "triangle" ? p.color : undefined,
                      borderRadius: p.shape === "circle" ? "50%" : p.shape === "square" ? "4px" : undefined,
                      borderLeft: p.shape === "triangle" ? `${p.size / 2}px solid transparent` : undefined,
                      borderRight: p.shape === "triangle" ? `${p.size / 2}px solid transparent` : undefined,
                      borderBottom: p.shape === "triangle" ? `${p.size}px solid ${p.color}` : undefined,
                      left: "50%",
                      top: "20%",
                    }}
                  />
                ))}
              </div>

              <button
                onClick={triggerConfetti}
                className="group relative w-20 h-20 rounded-full bg-gradient-to-br from-[#2F6B62]/20 to-[#4FC097]/10 flex items-center justify-center mx-auto mb-8 border border-[#2F6B62]/40 hover:border-[#4FC097] hover:shadow-[0_0_25px_rgba(79,192,151,0.25)] transition-all duration-300 active:scale-95"
              >
                <svg
                  className="w-10 h-10 text-[#4FC097] group-hover:scale-110 transition-transform duration-300"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={3}
                >
                  <motion.path
                    initial={{ pathLength: 0 }}
                    animate={{ pathLength: 1 }}
                    transition={{ duration: 0.6, ease: "easeOut", delay: 0.3 }}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M5 13l4 4L19 7"
                  />
                </svg>
                <span className="absolute -top-1 -right-1 text-base animate-bounce opacity-80">✨</span>
                <span className="absolute -bottom-2 -left-1 text-xs opacity-60">✨</span>
              </button>

              <h1 className="font-serif text-[#F2F0EA] text-3xl font-bold tracking-tight mb-4 leading-tight">
                {locale === "pl" ? "Subskrypcja aktywowana!" : "Subscription activated!"}
              </h1>
              <p className="font-sans text-[#8FA5A0] text-sm sm:text-base leading-relaxed max-w-md mx-auto mb-8">
                {locale === "pl"
                  ? "Twoje konto zostało pomyślnie zaktualizowane. Płatność została potwierdzona."
                  : "Your account has been successfully upgraded. Your payment is verified."}
              </p>

              <div className="relative max-w-xs mx-auto p-6 rounded-2xl bg-white/[0.03] border border-white/[0.06] mb-8 flex flex-col items-center overflow-hidden">
                <span className="font-sans text-[11px] font-medium uppercase tracking-wider text-[#8FA5A0] mt-2">
                  {locale === "pl" ? "Limit sesji w tym miesiącu" : "Sessions limit this month"}
                </span>
                <span className="font-sans text-5xl font-extrabold text-[#F5A623] mt-3 tabular-nums">
                  {tokenCount}
                </span>
              </div>

              <div className="flex flex-col sm:flex-row items-center justify-center gap-4 max-w-md mx-auto">
                <Link
                  href={`${prefix}/dashboard`}
                  className="w-full sm:w-auto min-w-[180px] rounded-2xl bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#1B2522] font-sans font-bold text-xs uppercase tracking-wider px-6 py-4 hover:shadow-[0_8px_30px_rgba(245,166,35,0.4)] hover:scale-[1.02] active:scale-[0.98] transition-all duration-300 text-center"
                >
                  {locale === "pl" ? "Przejdź do panelu" : "Go to Dashboard"}
                </Link>
                <a
                  href={APP_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={(e) => {
                    e.preventDefault();
                    void openAppWithSso(fbUser.email ?? undefined);
                  }}
                  className="w-full sm:w-auto min-w-[180px] rounded-2xl bg-white/5 hover:bg-white/10 border border-white/15 text-white font-sans font-bold text-xs uppercase tracking-wider px-6 py-4 hover:border-white/30 hover:scale-[1.02] active:scale-[0.98] transition-all duration-300 text-center"
                >
                  {locale === "pl" ? "Przejdź do aplikacji" : "Go to App"}
                </a>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    );
  }

  if (showDeleteFlow) {
    return (
      <DeleteAccountView
        locale={locale}
        onCancel={() => setShowDeleteFlow(false)}
        fbUser={fbUser}
        signOut={signOut}
      />
    );
  }

  return (
    <div className="grid gap-8 lg:grid-cols-12 items-start w-full">
      {/* Left Column: settings stack */}
      <div className="lg:col-span-8 grid gap-5">
        {/* ── Header card: email + kartoteki + sign out ─────────── */}
        <header className="rounded-2xl border border-white/[0.08] bg-white/[0.04] backdrop-blur-md p-5 flex flex-col md:flex-row md:items-center md:justify-between gap-4 overflow-hidden">
          <div className="min-w-0">
            <p className="font-mono text-[11px] uppercase tracking-[0.15em] text-[#8FA5A0] truncate max-w-full" title={fbUser.email ?? ""}>
              {fbUser.email}
            </p>
            <p className="font-sans text-[13px] text-[#8FA5A0]/70 mt-1">
              {t("emailReadOnly")}
            </p>
          </div>
          <div className="flex items-center gap-4 shrink-0">
            <OpenKartotekiButton email={fbUser.email ?? ""} />
            <button
              type="button"
              onClick={() => setShowLogoutConfirm(true)}
              className="font-sans text-[13px] font-bold uppercase tracking-wider text-[#8FA5A0] hover:text-[#ff4444] transition-colors py-2"
            >
              {t("signOut")}
            </button>
          </div>
        </header>

        {profileError && (
          <p role="alert" className="rounded-xl border border-[#ff4444]/40 bg-[#ff4444]/10 px-4 py-3 font-sans text-sm text-[#F2F0EA]">
            {profileError}
          </p>
        )}

        {/* ── 1. TWOJE KONTO ──────────────────────────────────── */}
        <ProfileSection
          profile={profile}
          onUpdate={setProfile}
          locale={locale}
          isOpen={openSections.profile}
          onToggle={() => toggleSection("profile")}
        />

        {/* ── 2. ORGANIZACJA ──────────────────────────────────── */}
        <OrgSection
          profile={profile}
          isOpen={openSections.organization}
          onToggle={() => toggleSection("organization")}
        />

        {/* ── 2.5. PREFERENCJE RAPORTÓW ────────────────────────── */}
        <ReportPreferencesSection
          userId={profile?.id ?? null}
          locale={locale}
          isOpen={openSections.preferences}
          onToggle={() => toggleSection("preferences")}
        />

        {/* ── 3. SUBSKRYPCJA ──────────────────────────────────── */}
        <BillingSection
          organizationId={profile?.organizationId ?? null}
          locale={locale}
          isOpen={openSections.billing}
          onToggle={() => toggleSection("billing")}
        />

        {/* ── 4. INFORMACJE PRAWNE ────────────────────────────── */}
        <SettingsCard
          id="legal"
          title={t("sectionLegal")}
          isOpen={openSections.legal}
          onToggle={() => toggleSection("legal")}
        >
          <div className="divide-y divide-white/[0.06] pb-2">
            <LinkRow href={`${prefix}/legal/terms`} label={t("legalTerms")} />
            <LinkRow href={`${prefix}/legal/privacy`} label={t("legalPrivacy")} />
            <LinkRow href={`${prefix}/legal/dpa`} label={t("legalDpa")} />
          </div>
        </SettingsCard>

        {/* ── 5. ZARZĄDZANIE KONTEM ────────────────────────────── */}
        <SettingsCard
          id="mgmt"
          title={t("sectionAccountMgmt")}
          isOpen={openSections.mgmt}
          onToggle={() => toggleSection("mgmt")}
        >
          <div className="divide-y divide-white/[0.06] pb-2">
            <button
              type="button"
              onClick={() => setShowLogoutConfirm(true)}
              className="w-full flex items-center justify-between px-4 py-3.5 hover:bg-white/[0.03] transition-colors"
            >
              <span className="font-sans text-[15px] text-[#F2F0EA]">{t("signOut")}</span>
              <ChevronRight />
            </button>
            <button
              type="button"
              onClick={() => setShowDeleteFlow(true)}
              className="w-full flex items-center justify-between px-4 py-3.5 hover:bg-white/[0.03] transition-colors text-left"
            >
              <div>
                <span className="font-sans text-[15px] text-[#ff4444]">{t("deleteAccount")}</span>
              </div>
              <ChevronRight color="#ff4444" />
            </button>
          </div>
        </SettingsCard>
 
        {/* ── Footer version ──────────────────────────────────── */}
        <p className="text-center font-mono text-[11px] text-[#8FA5A0]/40 pb-4">
          {t("version")}
        </p>
      </div>
 
      {/* Right Column: Sticky Navigation Sidebar (Desktop only) */}
      <aside className="hidden lg:block lg:col-span-4 sticky top-28 space-y-4 [transform:translateZ(0)]">
        <nav className="rounded-2xl border border-white/[0.08] bg-white/[0.04] backdrop-blur-md p-5">
          <h3 className="font-sans text-[11px] font-bold uppercase tracking-[0.15em] text-[#8FA5A0] mb-4">
            {locale === "pl" ? "Nawigacja" : "Navigation"}
          </h3>
          <ul className="space-y-1">
            <SidebarNavLink
              label={t("sectionProfile")}
              active={activeAnchor === "profile"}
              onClick={() => handleNavClick("profile")}
            />
            <SidebarNavLink
              label={t("sectionOrg")}
              active={activeAnchor === "organization"}
              onClick={() => handleNavClick("organization")}
            />
            <SidebarNavLink
              label={t("sectionReportPrefs")}
              active={activeAnchor === "preferences"}
              onClick={() => handleNavClick("preferences")}
            />
            <SidebarNavLink
              label={t("sectionBilling")}
              active={activeAnchor === "billing"}
              onClick={() => handleNavClick("billing")}
            />
            <SidebarNavLink
              label={t("sectionLegal")}
              active={activeAnchor === "legal"}
              onClick={() => handleNavClick("legal")}
            />
            <SidebarNavLink
              label={t("sectionAccountMgmt")}
              active={activeAnchor === "mgmt"}
              onClick={() => handleNavClick("mgmt")}
            />
          </ul>
        </nav>
      </aside>

      {/* Logout Confirmation Modal Overlay */}
      <AnimatePresence>
        {showLogoutConfirm && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4"
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="w-full max-w-sm rounded-2xl border border-white/[0.1] bg-[#0A2326] p-6 shadow-2xl relative text-center"
            >
              <div className="w-16 h-16 rounded-full bg-[#F5A623]/15 flex items-center justify-center text-[#F5A623] mx-auto mb-5 shadow-[0_0_20px_rgba(245,166,35,0.2)]">
                <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                </svg>
              </div>

              <h3 className="font-sans text-xl font-bold text-[#F2F0EA] mb-2">
                {locale === "pl" ? "Czy na pewno?" : "Are you sure?"}
              </h3>
              <p className="font-sans text-sm text-[#8FA5A0] mb-6 leading-relaxed">
                {locale === "pl"
                  ? "Czy na pewno chcesz się wylogować ze swojego konta?"
                  : "Are you sure you want to log out of your account?"}
              </p>

              <div className="flex flex-col gap-2">
                <button
                  type="button"
                  onClick={async () => {
                    setShowLogoutConfirm(false);
                    await signOut();
                  }}
                  className="w-full py-3 px-6 rounded-xl font-sans font-bold text-xs uppercase tracking-wider text-[#1B2522] bg-[#F5A623] hover:brightness-110 active:scale-[0.99] transition shadow-[0_4px_15px_rgba(245,166,35,0.2)] flex items-center justify-center min-h-[44px]"
                >
                  {locale === "pl" ? "Tak, wyloguj" : "Yes, log out"}
                </button>
                <button
                  type="button"
                  onClick={() => setShowLogoutConfirm(false)}
                  className="w-full py-3 px-6 rounded-xl font-sans font-semibold text-xs uppercase tracking-wider text-[#8FA5A0] hover:text-[#F2F0EA] active:scale-[0.99] transition"
                >
                  {locale === "pl" ? "Wróć" : "Back"}
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────
// Otwórz kartoteki — cross-origin SSO into the Flutter web app
// ────────────────────────────────────────────────────────────────────
function OpenKartotekiButton({ email }: { email: string }) {
  const t = useTranslations("account");
  const [busy, setBusy] = useState(false);

  const onClick = async () => {
    if (busy) return;
    setBusy(true);
    try {
      await openAppWithSso(email);
    } finally {
      setBusy(false);
    }
  };

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={busy}
      className="inline-flex items-center justify-center rounded-xl bg-[#2F6B62]/10 text-[#4FC097] border border-[#2F6B62]/30 font-sans font-bold text-[13px] uppercase tracking-wider px-5 py-2.5 hover:bg-[#2F6B62]/20 hover:border-[#4FC097] transition disabled:opacity-60 disabled:cursor-progress"
      title={t("kartotekiHint")}
    >
      {busy ? t("kartotekiOpening") : t("kartotekiCta")} →
    </button>
  );
}

// ────────────────────────────────────────────────────────────────────
// Profile Section
// ────────────────────────────────────────────────────────────────────
function ProfileSection({
  profile,
  onUpdate,
  locale,
  isOpen,
  onToggle,
}: {
  profile: User | null;
  onUpdate: (u: User) => void;
  locale: string;
  isOpen: boolean;
  onToggle: () => void;
}) {
  const t = useTranslations("account");
  const [draft, setDraft] = useState({
    firstName: "",
    lastName: "",
    phoneNumber: "",
    professionalTitle: "",
    credentialsNumber: "",
    biography: "",
    selectedModalityId: "",
  });
  const [submitting, setSubmitting] = useState(false);
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [modalities, setModalities] = useState<ReadonlyArray<ModalityRow>>([]);

  // Fetch modality catalog for label resolution (UUID → display name)
  useEffect(() => {
    let cancelled = false;
    getModalityCatalog().then((catalog) => {
      if (!cancelled) setModalities(catalog);
    });
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    if (!profile) return;
    setDraft({
      firstName: profile.firstName ?? "",
      lastName: profile.lastName ?? "",
      phoneNumber: profile.phoneNumber ?? "",
      professionalTitle: profile.professionalTitle ?? "",
      credentialsNumber: profile.credentialsNumber ?? "",
      biography: profile.biography ?? "",
      selectedModalityId: profile.defaultModalityId ?? "",
    });
  }, [profile]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    setFieldErrors({});

    // Client-side validation
    const errs: Record<string, string> = {};
    const isPl = locale === "pl";
    if (!draft.firstName.trim()) {
      errs.firstName = isPl ? "Imię jest wymagane" : "First name is required";
    }
    if (!draft.lastName.trim()) {
      errs.lastName = isPl ? "Nazwisko jest wymagane" : "Last name is required";
    }

    if (Object.keys(errs).length > 0) {
      setFieldErrors(errs);
      setError(isPl ? "Proszę poprawić błędy w formularzu" : "Please correct the errors in the form");
      setSubmitting(false);
      return;
    }

    try {
      const req = create(UpdateProfileRequestSchema, {
        userId: "",
        firstName: draft.firstName,
        lastName: draft.lastName,
        phoneNumber: draft.phoneNumber,
        professionalTitle: draft.professionalTitle,
        credentialsNumber: draft.credentialsNumber,
        biography: draft.biography,
        defaultModalityId: draft.selectedModalityId || undefined,
      });
      const updated = await identityClient.updateProfile(req);
      onUpdate(updated);
      setSavedAt(Date.now());
    } catch (e) {
      console.error("[account] update profile failed", e);
      setError(t("errGeneric"));
    } finally {
      setSubmitting(false);
    }
  }



  if (!profile) {
    return (
      <SettingsCard title={t("sectionProfile")}>
        <p className="px-6 pt-6 pb-6 font-sans text-sm text-[#8FA5A0]">{t("orgLoading")}</p>
      </SettingsCard>
    );
  }

  return (
    <SettingsCard
      id="profile"
      title={t("sectionProfile")}
      isOpen={isOpen}
      onToggle={onToggle}
    >
      <form onSubmit={onSubmit} className="px-6 pt-7 pb-7 grid gap-6" noValidate>
        <div className="grid gap-5 sm:grid-cols-2">
          <SettingsField label={t("firstName")} error={fieldErrors.firstName}>
            <input
              type="text"
              value={draft.firstName}
              onChange={(e) => setDraft((d) => ({ ...d, firstName: e.target.value }))}
              className={getInputClass(!!fieldErrors.firstName)}
            />
          </SettingsField>
          <SettingsField label={t("lastName")} error={fieldErrors.lastName}>
            <input
              type="text"
              value={draft.lastName}
              onChange={(e) => setDraft((d) => ({ ...d, lastName: e.target.value }))}
              className={getInputClass(!!fieldErrors.lastName)}
            />
          </SettingsField>
        </div>
        <SettingsField label={t("phoneNumber")}>
          <PhoneInput
            id="phoneNumber"
            value={draft.phoneNumber}
            onChange={(val) => setDraft((d) => ({ ...d, phoneNumber: val }))}
            placeholder={t("phoneNumber")}
          />
        </SettingsField>
        <div className="grid gap-5 sm:grid-cols-2">
          <SettingsField label={t("professionalTitle")}>
            <input
              type="text"
              value={draft.professionalTitle}
              onChange={(e) => setDraft((d) => ({ ...d, professionalTitle: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
          <SettingsField label={t("credentialsNumber")}>
            <input
              type="text"
              value={draft.credentialsNumber}
              onChange={(e) => setDraft((d) => ({ ...d, credentialsNumber: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
        </div>

        {/* Modality (editable dropdown) */}
        <SettingsField label={t("modality")}>
          <select
            value={draft.selectedModalityId}
            onChange={(e) => setDraft((d) => ({ ...d, selectedModalityId: e.target.value }))}
            className={inputClass}
          >
            <option value="">
              {locale === "pl" ? "— Wybierz nurt terapii —" : "— Choose therapy modality —"}
            </option>
            {modalities.filter((m) => m.isSupported).map((m) => (
              <option key={m.id} value={m.id}>
                {m.labels[locale as "pl" | "en"] ?? m.displayName}
              </option>
            ))}
          </select>
        </SettingsField>

        {error && (
          <p role="alert" className="rounded-xl border border-[#ff4444]/40 bg-[#ff4444]/10 px-3 py-2 font-sans text-xs text-[#F2F0EA]">
            {error}
          </p>
        )}
        {savedAt && !error && !submitting && (
          <p role="status" className="rounded-xl border border-green-500/40 bg-green-500/10 px-3 py-2 font-sans text-xs text-[#F2F0EA]">
            {t("profileSaved")}
          </p>
        )}

        <div>
          <button type="submit" disabled={submitting} className={submitBtnClass}>
            {submitting ? t("profileSubmitting") : t("profileSubmit")}
          </button>
        </div>
      </form>
    </SettingsCard>
  );
}

// ────────────────────────────────────────────────────────────────────
// Organisation
// ────────────────────────────────────────────────────────────────────
function OrgSection({
  profile,
  isOpen,
  onToggle,
}: {
  profile: User | null;
  isOpen: boolean;
  onToggle: () => void;
}) {
  const t = useTranslations("account");
  const [phase, setPhase] = useState<"loading" | "ready" | "notAllowed" | "noOrg" | "error">("loading");
  const [org, setOrg] = useState<Organization | null>(null);
  const [draft, setDraft] = useState({
    legalName: "",
    taxId: "",
    vatIdEu: "",
    countryCode: "PL",
    region: "",
    city: "",
    postalCode: "",
    streetLine: "",
    buildingNumber: "",
    unitNumber: "",
    directions: "",
  });
  const [submitting, setSubmitting] = useState(false);
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const locale = useLocale();

  useEffect(() => {
    if (!profile) return;
    if (!profile.organizationId) {
      setPhase("noOrg");
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const o = await identityClient.getMyOrganization(create(EmptySchema, {}));
        if (cancelled) return;
        setOrg(o);
        setDraft({
          legalName: o.legalName ?? "",
          taxId: o.taxId ?? "",
          vatIdEu: o.vatIdEu ?? "",
          countryCode: o.headquartersAddress?.countryCode ?? "PL",
          region: o.headquartersAddress?.region ?? "",
          city: o.headquartersAddress?.city ?? "",
          postalCode: o.headquartersAddress?.postalCode ?? "",
          streetLine: o.headquartersAddress?.streetLine ?? "",
          buildingNumber: o.headquartersAddress?.buildingNumber ?? "",
          unitNumber: o.headquartersAddress?.unitNumber ?? "",
          directions: o.headquartersAddress?.directions ?? "",
        });
        setPhase("ready");
      } catch (e) {
        if (cancelled) return;
        if (e instanceof ConnectError && e.code === Code.PermissionDenied) {
          setPhase("notAllowed");
        } else {
          console.error("[account] load org failed", e);
          setPhase("error");
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [profile]);

  const [loadingNip, setLoadingNip] = useState(false);

  async function handleNipLookup() {
    const cleanTaxId = draft.taxId.replace(/[\s\-]/g, "");
    if (!cleanTaxId || cleanTaxId.length !== 10) {
      setFieldErrors(prev => ({
        ...prev,
        taxId: locale === "pl" ? "Wpisz poprawny 10-cyfrowy NIP" : "Enter a valid 10-digit NIP",
      }));
      return;
    }
    setLoadingNip(true);
    setFieldErrors(prev => {
      const copy = { ...prev };
      delete copy.taxId;
      return copy;
    });
    setError(null);

    try {
      const res = await fetch(`/api/nip-lookup?nip=${cleanTaxId}`);
      if (!res.ok) {
        const body = await res.json();
        throw new Error(body.error || "Błąd wyszukiwania");
      }
      const data = await res.json();
      setDraft(prev => ({
        ...prev,
        legalName: data.legalName || prev.legalName,
        vatIdEu: data.vatIdEu || prev.vatIdEu,
        streetLine: data.streetLine || prev.streetLine,
        buildingNumber: data.buildingNumber || prev.buildingNumber,
        unitNumber: data.unitNumber || prev.unitNumber,
        postalCode: data.postalCode || prev.postalCode,
        city: data.city || prev.city,
      }));
      setFieldErrors({}); // Clear all validation errors on success
    } catch (e: any) {
      console.error("[account] NIP lookup failed", e);
      setError(
        locale === "pl"
          ? `Wyszukiwanie NIP nie powiodło się: ${e.message}`
          : `NIP lookup failed: ${e.message}`
      );
    } finally {
      setLoadingNip(false);
    }
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    setFieldErrors({});

    // Client-side validation
    const errs: Record<string, string> = {};
    const isPl = locale === "pl";

    // 1. Legal Name is required
    if (!draft.legalName.trim()) {
      errs.legalName = isPl ? "Nazwa prawna jest wymagana" : "Legal name is required";
    }

    // 2. Tax ID (NIP) validation
    const cleanTaxId = draft.taxId.replace(/[\s\-]/g, "");
    if (draft.taxId && !/^\d{10}$/.test(cleanTaxId)) {
      errs.taxId = isPl ? "NIP musi składać się z 10 cyfr" : "Tax ID must be exactly 10 digits";
    }

    // 3. Address validation
    const hasAddressInput = !!(
      draft.streetLine.trim() ||
      draft.buildingNumber.trim() ||
      draft.postalCode.trim() ||
      draft.city.trim() ||
      draft.region.trim() ||
      draft.unitNumber.trim() ||
      draft.directions.trim()
    );
    const hasExistingAddress = !!(org?.headquartersAddress?.id);

    if (hasAddressInput || hasExistingAddress) {
      if (!draft.streetLine.trim()) {
        errs.streetLine = isPl ? "Ulica jest wymagana" : "Street is required";
      }
      if (!draft.buildingNumber.trim()) {
        errs.buildingNumber = isPl ? "Numer budynku jest wymagany" : "Building number is required";
      }
      if (!draft.postalCode.trim()) {
        errs.postalCode = isPl ? "Kod pocztowy jest wymagany" : "Postal code is required";
      } else if (draft.countryCode === "PL" && !/^\d{2}-\d{3}$/.test(draft.postalCode.trim())) {
        errs.postalCode = isPl ? "Niepoprawny format (np. 00-001)" : "Invalid format (e.g. 00-001)";
      }
      if (!draft.city.trim()) {
        errs.city = isPl ? "Miejscowość jest wymagana" : "City is required";
      }
    }

    if (Object.keys(errs).length > 0) {
      setFieldErrors(errs);
      setError(isPl ? "Proszę poprawić błędy w formularzu" : "Please correct the errors in the form");
      setSubmitting(false);
      return;
    }

    try {
      // Build address schema only if address input is present OR we are updating an existing address row
      const address = (hasAddressInput || hasExistingAddress) ? create(AddressSchema, {
        id: org?.headquartersAddress?.id || undefined,
        countryCode: draft.countryCode || "PL",
        region: draft.region,
        city: draft.city,
        postalCode: draft.postalCode,
        streetLine: draft.streetLine,
        buildingNumber: draft.buildingNumber,
        unitNumber: draft.unitNumber,
        directions: draft.directions,
      }) : undefined;

      const req = create(UpdateMyOrganizationRequestSchema, {
        legalName: draft.legalName,
        taxId: cleanTaxId || undefined,
        vatIdEu: draft.vatIdEu || undefined,
        headquartersAddress: address,
      });

      const updated = await identityClient.updateMyOrganization(req);
      setOrg(updated);
      setSavedAt(Date.now());
    } catch (e) {
      console.error("[account] update org failed", e);
      setError(t("errGeneric"));
    } finally {
      setSubmitting(false);
    }
  }

  if (phase === "loading") {
    return (
      <SettingsCard title={t("sectionOrg")}>
        <p className="px-6 pt-6 pb-6 font-sans text-sm text-[#8FA5A0]">{t("orgLoading")}</p>
      </SettingsCard>
    );
  }
  if (phase === "noOrg") {
    return (
      <SettingsCard title={t("sectionOrg")}>
        <p className="px-6 pt-6 pb-6 font-sans text-sm text-[#8FA5A0]">{t("orgNone")}</p>
      </SettingsCard>
    );
  }
  if (phase === "notAllowed") {
    return (
      <SettingsCard title={t("sectionOrg")}>
        <p className="px-6 pt-6 pb-6 font-sans text-sm text-[#8FA5A0]">{t("orgNotAllowed")}</p>
      </SettingsCard>
    );
  }
  if (phase === "error") {
    return (
      <SettingsCard title={t("sectionOrg")}>
        <p className="px-6 pt-6 pb-6 font-sans text-sm text-[#8FA5A0]">{t("errLoad")}</p>
      </SettingsCard>
    );
  }

  return (
    <SettingsCard
      id="organization"
      title={t("sectionOrg")}
      isOpen={isOpen}
      onToggle={onToggle}
    >
      <form onSubmit={onSubmit} className="px-6 pt-7 pb-7 grid gap-6" noValidate>
        <SettingsField label={t("legalName")} error={fieldErrors.legalName}>
          <input
            type="text"
            value={draft.legalName}
            onChange={(e) => setDraft((d) => ({ ...d, legalName: e.target.value }))}
            placeholder={t("legalNamePlaceholder")}
            className={getInputClass(!!fieldErrors.legalName)}
          />
        </SettingsField>
        <div className="grid gap-5 sm:grid-cols-2">
          <SettingsField label={t("taxId")} error={fieldErrors.taxId}>
            <input
              type="text"
              value={draft.taxId}
              onChange={(e) => setDraft((d) => ({ ...d, taxId: e.target.value }))}
              placeholder={t("taxIdPlaceholder")}
              className={getInputClass(!!fieldErrors.taxId)}
            />
          </SettingsField>
          <SettingsField label={t("vatIdEu")} error={fieldErrors.vatIdEu}>
            <input
              type="text"
              value={draft.vatIdEu}
              onChange={(e) => setDraft((d) => ({ ...d, vatIdEu: e.target.value }))}
              placeholder={t("vatIdEuPlaceholder")}
              className={getInputClass(!!fieldErrors.vatIdEu)}
            />
          </SettingsField>
        </div>
        <div className="flex items-center gap-4">
          <button
            type="button"
            onClick={handleNipLookup}
            disabled={loadingNip}
            className="shrink-0 rounded-xl bg-white/[0.04] text-[#F5A623] border border-white/[0.08] hover:border-[#F5A623]/40 hover:bg-[#F5A623]/10 font-sans font-bold text-[11px] uppercase tracking-wider px-5 py-2.5 transition disabled:opacity-50 flex items-center justify-center gap-2 min-h-[38px]"
          >
            {loadingNip ? (
              <span className="inline-block w-4 h-4 rounded-full border-2 border-[#F5A623]/30 border-t-[#F5A623] animate-spin" />
            ) : (
              locale === "pl" ? "Uzupełnij z bazy GUS" : "Autofill from registry"
            )}
          </button>
          <p className="font-sans text-[11px] text-[#8FA5A0]/60 leading-snug">
            {locale === "pl"
              ? "Pobierze nazwę firmy, adres i numer VAT UE na podstawie NIP."
              : "Retrieves company name, address, and VAT EU based on NIP."}
          </p>
        </div>
        <div className="grid gap-5 sm:grid-cols-3">
          <SettingsField label={t("streetLine")} error={fieldErrors.streetLine}>
            <input
              type="text"
              value={draft.streetLine}
              onChange={(e) => setDraft((d) => ({ ...d, streetLine: e.target.value }))}
              className={getInputClass(!!fieldErrors.streetLine)}
            />
          </SettingsField>
          <SettingsField label={t("buildingNumber")} error={fieldErrors.buildingNumber}>
            <input
              type="text"
              value={draft.buildingNumber}
              onChange={(e) => setDraft((d) => ({ ...d, buildingNumber: e.target.value }))}
              className={getInputClass(!!fieldErrors.buildingNumber)}
            />
          </SettingsField>
          <SettingsField label={t("unitNumber")} error={fieldErrors.unitNumber}>
            <input
              type="text"
              value={draft.unitNumber}
              onChange={(e) => setDraft((d) => ({ ...d, unitNumber: e.target.value }))}
              className={getInputClass(!!fieldErrors.unitNumber)}
            />
          </SettingsField>
        </div>
        <div className="grid gap-5 sm:grid-cols-3">
          <SettingsField label={t("postalCode")} error={fieldErrors.postalCode}>
            <input
              type="text"
              value={draft.postalCode}
              onChange={(e) => setDraft((d) => ({ ...d, postalCode: e.target.value }))}
              placeholder={t("postalCodePlaceholder")}
              className={getInputClass(!!fieldErrors.postalCode)}
            />
          </SettingsField>
          <SettingsField label={t("city")} error={fieldErrors.city}>
            <input
              type="text"
              value={draft.city}
              onChange={(e) => setDraft((d) => ({ ...d, city: e.target.value }))}
              className={getInputClass(!!fieldErrors.city)}
            />
          </SettingsField>
          <SettingsField label={t("region")} error={fieldErrors.region}>
            <input
              type="text"
              value={draft.region}
              onChange={(e) => setDraft((d) => ({ ...d, region: e.target.value }))}
              className={getInputClass(!!fieldErrors.region)}
            />
          </SettingsField>
        </div>

        {error && (
          <p role="alert" className="rounded-xl border border-[#ff4444]/40 bg-[#ff4444]/10 px-3 py-2 font-sans text-xs text-[#F2F0EA]">
            {error}
          </p>
        )}
        {savedAt && !error && !submitting && (
          <p role="status" className="rounded-xl border border-green-500/40 bg-green-500/10 px-3 py-2 font-sans text-xs text-[#F2F0EA]">
            {t("orgSaved")}
          </p>
        )}

        <div className="flex items-center gap-3">
          <button type="submit" disabled={submitting} className={submitBtnClass}>
            {submitting ? t("orgSubmitting") : t("orgSubmit")}
          </button>
          {org && (
            <span className="font-mono text-[10px] uppercase tracking-[0.15em] text-[#8FA5A0]/70">
              {t("orgType")}: {orgTypeName(org.type)}
            </span>
          )}
        </div>
      </form>
    </SettingsCard>
  );
}

function orgTypeName(t: OrganizationType): string {
  switch (t) {
    case OrganizationType.SOLO: return "SOLO";
    case OrganizationType.CLINIC: return "CLINIC";
    case OrganizationType.ENTERPRISE: return "ENTERPRISE";
    default: return "—";
  }
}

// ────────────────────────────────────────────────────────────────────
// Report Preferences
// ────────────────────────────────────────────────────────────────────

const LENGTH_OPTIONS = [
  { value: "brief", pl: "Krótki", en: "Brief" },
  { value: "standard", pl: "Standardowy", en: "Standard" },
  { value: "detailed", pl: "Szczegółowy", en: "Detailed" },
];
const TONE_OPTIONS = [
  { value: "clinical_formal", pl: "Kliniczny, formalny", en: "Clinical, formal" },
  { value: "empathic_warm", pl: "Empatyczny, ciepły", en: "Empathic, warm" },
  { value: "pragmatic_direct", pl: "Pragmatyczny, bezpośredni", en: "Pragmatic, direct" },
  { value: "academic_rigorous", pl: "Akademicki, rygorystyczny", en: "Academic, rigorous" },
];
const QUOTE_OPTIONS = [
  { value: "few", pl: "Mało (1–2)", en: "Few (1–2)" },
  { value: "selective", pl: "Selektywnie (3–5)", en: "Selective (3–5)" },
  { value: "many", pl: "Dużo (6+)", en: "Many (6+)" },
];
const DIAG_OPTIONS = [
  { value: "descriptive", pl: "Opisowy", en: "Descriptive" },
  { value: "clinical_labels", pl: "Etykiety kliniczne", en: "Clinical labels" },
  { value: "dsm_icd", pl: "DSM / ICD", en: "DSM / ICD" },
];
const HEDGE_OPTIONS = [
  { value: "tentative", pl: "Ostrożne", en: "Tentative" },
  { value: "balanced", pl: "Zbalansowane", en: "Balanced" },
  { value: "assertive", pl: "Asertywne", en: "Assertive" },
];
const STRENGTHS_OPTIONS = [
  { value: "problem_focused", pl: "Zorientowany na problem", en: "Problem-focused" },
  { value: "balanced", pl: "Zbalansowany", en: "Balanced" },
  { value: "strengths_first", pl: "Mocne strony najpierw", en: "Strengths-first" },
];

function ReportPreferencesSection({
  userId,
  locale,
  isOpen,
  onToggle,
}: {
  userId: string | null;
  locale: string;
  isOpen: boolean;
  onToggle: () => void;
}) {
  const t = useTranslations("account");
  const lang = locale as "pl" | "en";

  const [prefs, setPrefs] = useState({
    length: "standard",
    tone: "clinical_formal",
    quoteDensity: "selective",
    diagnosticLanguage: "descriptive",
    hypothesisHedging: "balanced",
    strengthsFraming: "balanced",
    sectionEmphasis: [] as string[],
    freeText: "",
  });
  const [loaded, setLoaded] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!userId) return;
    let cancelled = false;
    (async () => {
      try {
        const resp = await identityClient.getReportPreferences(
          create(GetReportPreferencesRequestSchema, { therapistId: userId }),
        );
        if (!cancelled && resp) {
          setPrefs({
            length: resp.length || "standard",
            tone: resp.tone || "clinical_formal",
            quoteDensity: resp.quoteDensity || "selective",
            diagnosticLanguage: resp.diagnosticLanguage || "descriptive",
            hypothesisHedging: resp.hypothesisHedging || "balanced",
            strengthsFraming: resp.strengthsFraming || "balanced",
            sectionEmphasis: [...resp.sectionEmphasis],
            freeText: resp.freeText || "",
          });
        }
      } catch {
        // No preferences set yet — use defaults
      } finally {
        if (!cancelled) setLoaded(true);
      }
    })();
    return () => { cancelled = true; };
  }, [userId]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!userId) return;
    setSubmitting(true);
    setError(null);
    try {
      const req = create(UpdateReportPreferencesRequestSchema, {
        therapistId: userId,
        preferences: create(ReportPreferencesSchema, {
          version: 1,
          length: prefs.length,
          tone: prefs.tone,
          quoteDensity: prefs.quoteDensity,
          diagnosticLanguage: prefs.diagnosticLanguage,
          hypothesisHedging: prefs.hypothesisHedging,
          strengthsFraming: prefs.strengthsFraming,
          sectionEmphasis: prefs.sectionEmphasis,
          freeText: prefs.freeText,
        }),
        idempotencyKey: crypto.randomUUID(),
      });
      await identityClient.updateReportPreferences(req);
      setSavedAt(Date.now());
    } catch {
      setError(t("errGeneric"));
    } finally {
      setSubmitting(false);
    }
  }


  if (!userId) return null;

  return (
    <SettingsCard
      id="preferences"
      title={t("sectionReportPrefs")}
      isOpen={isOpen}
      onToggle={onToggle}
    >
      {!loaded ? (
        <p className="px-6 pt-6 pb-6 font-sans text-sm text-[#8FA5A0]">{t("orgLoading")}</p>
      ) : (
        <form onSubmit={onSubmit} className="px-6 pt-7 pb-7 grid gap-6" noValidate>
          <div className="grid gap-5 sm:grid-cols-2">
            <SettingsField label={t("reportLength")}>
              <select
                value={prefs.length}
                onChange={(e) => setPrefs((p) => ({ ...p, length: e.target.value }))}
                className={inputClass}
              >
                {LENGTH_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{o[lang]}</option>
                ))}
              </select>
            </SettingsField>
            <SettingsField label={t("reportTone")}>
              <select
                value={prefs.tone}
                onChange={(e) => setPrefs((p) => ({ ...p, tone: e.target.value }))}
                className={inputClass}
              >
                {TONE_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{o[lang]}</option>
                ))}
              </select>
            </SettingsField>
          </div>
          <div className="grid gap-5 sm:grid-cols-2">
            <SettingsField label={t("reportQuoteDensity")}>
              <select
                value={prefs.quoteDensity}
                onChange={(e) => setPrefs((p) => ({ ...p, quoteDensity: e.target.value }))}
                className={inputClass}
              >
                {QUOTE_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{o[lang]}</option>
                ))}
              </select>
            </SettingsField>
            <SettingsField label={t("reportDiagnosticLanguage")}>
              <select
                value={prefs.diagnosticLanguage}
                onChange={(e) => setPrefs((p) => ({ ...p, diagnosticLanguage: e.target.value }))}
                className={inputClass}
              >
                {DIAG_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{o[lang]}</option>
                ))}
              </select>
            </SettingsField>
          </div>
          <div className="grid gap-5 sm:grid-cols-2">
            <SettingsField label={t("reportHypothesisHedging")}>
              <select
                value={prefs.hypothesisHedging}
                onChange={(e) => setPrefs((p) => ({ ...p, hypothesisHedging: e.target.value }))}
                className={inputClass}
              >
                {HEDGE_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{o[lang]}</option>
                ))}
              </select>
            </SettingsField>
            <SettingsField label={t("reportStrengthsFraming")}>
              <select
                value={prefs.strengthsFraming}
                onChange={(e) => setPrefs((p) => ({ ...p, strengthsFraming: e.target.value }))}
                className={inputClass}
              >
                {STRENGTHS_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{o[lang]}</option>
                ))}
              </select>
            </SettingsField>
          </div>


          {/* Free text */}
          <SettingsField label={t("reportFreeText")}>
            <textarea
              rows={2}
              maxLength={500}
              value={prefs.freeText}
              onChange={(e) => setPrefs((p) => ({ ...p, freeText: e.target.value }))}
              className={`${inputClass} resize-y`}
              placeholder={locale === "pl"
                ? "Dodatkowe instrukcje dla AI (max 500 znaków)..."
                : "Additional instructions for AI (max 500 chars)..."}
            />
          </SettingsField>

          {error && (
            <p role="alert" className="rounded-xl border border-[#ff4444]/40 bg-[#ff4444]/10 px-3 py-2 font-sans text-xs text-[#F2F0EA]">
              {error}
            </p>
          )}
          {savedAt && !error && !submitting && (
            <p role="status" className="rounded-xl border border-green-500/40 bg-green-500/10 px-3 py-2 font-sans text-xs text-[#F2F0EA]">
              {t("reportPrefsSaved")}
            </p>
          )}

          <div>
            <button type="submit" disabled={submitting} className={submitBtnClass}>
              {submitting ? t("profileSubmitting") : t("reportPrefsSave")}
            </button>
          </div>
        </form>
      )}
    </SettingsCard>
  );
}

// ────────────────────────────────────────────────────────────────────
// Subscription
// ────────────────────────────────────────────────────────────────────
function BillingSection({
  organizationId,
  locale,
  isOpen,
  onToggle,
}: {
  organizationId: string | null;
  locale: string;
  isOpen: boolean;
  onToggle: () => void;
}) {
  const t = useTranslations("account");
  const { user: fbUser } = useAuth();
  const [sub, setSub] = useState<Subscription | null>(null);
  const [phase, setPhase] = useState<"loading" | "ready" | "none" | "error">("loading");
  const prefix = locale === "en" ? "/en" : "";

  const [showInvoices, setShowInvoices] = useState(false);
  const [invoices, setInvoices] = useState<Invoice[] | null>(null);
  const [loadingInvoices, setLoadingInvoices] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [portalLoading, setPortalLoading] = useState(false);
  const [portalError, setPortalError] = useState<string | null>(null);

  // docs/70 S5 — who sold this subscription decides what this card may
  // offer. GetBillingSurface is the authoritative answer and carries the
  // store deep link; it is additive and may not be deployed yet, so any
  // failure degrades to today's Stripe-only view rather than blanking
  // the card. The org type is only a fallback signal for "your
  // organization manages this plan" when the surface is unavailable.
  const [surface, setSurface] = useState<BillingSurface | null>(null);
  const [orgType, setOrgType] = useState<OrganizationType | null>(null);

  const handleManageBilling = async () => {
    if (!fbUser?.email) return;
    setPortalLoading(true);
    setPortalError(null);
    try {
      const resp = await fetch("/api/billing-portal", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: fbUser.email, returnUrl: "/account" }),
      });
      const data = await resp.json();
      if (!resp.ok) {
        throw new Error(data.error || "Failed to create portal session");
      }
      if (data.url) {
        window.location.href = data.url;
      }
    } catch (err: any) {
      console.error("[BillingSection] portal error:", err);
      setPortalError(
        locale === "pl"
          ? "Nie udało się otworzyć portalu płatności. Upewnij się, że dokonałeś już pierwszej płatności."
          : "Failed to open billing portal. Make sure you have completed your first payment."
      );
    } finally {
      setPortalLoading(false);
    }
  };

  const fetchInvoices = useCallback(async () => {
    if (!organizationId) return;
    setLoadingInvoices(true);
    setLoadError(null);
    try {
      const resp = await billingClient.listInvoices(
        create(ListInvoicesRequestSchema, { organizationId }),
      );
      setInvoices(resp.invoices);
    } catch (e) {
      console.error("[account] list invoices failed", e);
      setLoadError(t("errGeneric"));
    } finally {
      setLoadingInvoices(false);
    }
  }, [organizationId, t]);

  const handleToggleInvoices = () => {
    const nextShow = !showInvoices;
    setShowInvoices(nextShow);
    if (nextShow && invoices === null) {
      fetchInvoices();
    }
  };

  useEffect(() => {
    if (!organizationId) return;
    let cancelled = false;
    (async () => {
      try {
        const s = await billingClient.getBillingSurface(create(EmptySchema, {}));
        if (!cancelled) setSurface(s);
      } catch {
        // RPC not deployed yet / not permitted — fall back to
        // Subscription.billing_provider alone.
      }
      try {
        const o = await identityClient.getMyOrganization(create(EmptySchema, {}));
        if (!cancelled) setOrgType(o?.type ?? null);
      } catch {
        // Without it we simply never claim "managed by your organization".
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [organizationId]);

  useEffect(() => {
    if (!organizationId) return;
    let cancelled = false;
    (async () => {
      try {
        const s = await billingClient.getSubscription(
          create(GetSubscriptionRequestSchema, { organizationId }),
        );
        if (cancelled) return;
        if (!s || !s.planTier) {
          setPhase("none");
        } else {
          setSub(s);
          setPhase("ready");
        }
      } catch (e) {
        if (e instanceof ConnectError &&
            (e.code === Code.NotFound || e.code === Code.FailedPrecondition)) {
          if (!cancelled) setPhase("none");
          return;
        }
        console.error("[account] load subscription failed", e);
        if (!cancelled) setPhase("error");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [organizationId]);

  if (phase === "loading") {
    return (
      <SettingsCard title={t("sectionBilling")} isOpen={isOpen} onToggle={onToggle}>
        <div className="px-6 pt-7 pb-7 animate-pulse">
          {/* Row 1: plan + status skeletons */}
          <div className="grid grid-cols-2 gap-4 mb-4 pb-4 border-b border-white/[0.06]">
            <div>
              <div className="h-3 w-16 rounded bg-white/[0.06] mb-2" />
              <div className="h-5 w-28 rounded bg-white/[0.08]" />
            </div>
            <div>
              <div className="h-3 w-12 rounded bg-white/[0.06] mb-2" />
              <div className="h-5 w-20 rounded bg-white/[0.08]" />
            </div>
          </div>
          {/* Row 2: token bar skeleton */}
          <div className="mb-4">
            <div className="flex justify-between mb-2">
              <div className="h-3 w-24 rounded bg-white/[0.06]" />
              <div className="h-3 w-16 rounded bg-white/[0.06]" />
            </div>
            <div className="h-2.5 w-full rounded-full bg-white/[0.06]" />
          </div>
          {/* Row 3: CTA skeleton */}
          <div className="h-10 w-full rounded-xl bg-white/[0.06]" />
        </div>
      </SettingsCard>
    );
  }
  if (phase === "none") {
    // No subscription of our own — but the org may still be on someone
    // else's seat, in which case offering a checkout is a dead end.
    const noneOrgManaged =
      surface?.blockReason === "ORG_MANAGED" || isManagedOrgType(orgType);
    return (
      <SettingsCard title={t("sectionBilling")}>
        <div className="px-6 pt-7 pb-7">
          {noneOrgManaged ? (
            <>
              <p className="font-sans text-sm text-[#F2F0EA] mb-1">
                {t("billingOrgManagedTitle")}
              </p>
              <p className="font-sans text-[13px] text-[#8FA5A0]/80">
                {t("billingOrgManagedBody")}
              </p>
            </>
          ) : (
            <>
              <p className="font-sans text-sm text-[#8FA5A0] mb-1">{t("billingNone")}</p>
              <p className="font-sans text-[13px] text-[#8FA5A0]/60 mb-4">{t("billingNoneBody")}</p>
              <UpgradeLink href={`${prefix}/upgrade?from=account`} label={t("billingNoneCta")} />
            </>
          )}
        </div>
      </SettingsCard>
    );
  }
  if (phase === "error") {
    return (
      <SettingsCard title={t("sectionBilling")}>
        <p className="px-6 pt-6 pb-6 font-sans text-sm text-[#8FA5A0]">{t("errLoad")}</p>
      </SettingsCard>
    );
  }
  if (!sub) {
    return (
      <SettingsCard title={t("sectionBilling")}>
        <p className="px-6 pt-6 pb-6 font-sans text-sm text-[#8FA5A0]">{t("billingNone")}</p>
      </SettingsCard>
    );
  }

  const total = sub.tokensPerPeriod;
  const used = sub.tokensUsedThisPeriod + sub.tokensReservedThisPeriod;
  const left = Math.max(0, total - used);
  const pct = total > 0 ? Math.min(100, Math.round((used / total) * 100)) : 0;
  const planName = planLabel(t, sub.planTier);
  const periodEnd = sub.currentPeriodEnd
    ? new Date(Number(sub.currentPeriodEnd.seconds) * 1000).toLocaleDateString()
    : "—";
  let statusName = statusLabel(t, sub.status);
  if (sub.cancelAtPeriodEnd && sub.status === "ACTIVE") {
    statusName = locale === "pl"
      ? `Aktywna (anulowana, wygasa ${periodEnd})`
      : `Active (canceled, expires ${periodEnd})`;
  }

  // ── Provider awareness (docs/70 §5.1 + S5) ────────────────────────
  const provider = (sub.billingProvider || "").toUpperCase();
  const isApple = provider === "APPLE_IAP";
  const isGoogle = provider === "GOOGLE_IAP";
  const isStore = isApple || isGoogle;
  // Only trust manage_url for store subscriptions: for Stripe it points
  // at the portal we already open through /api/billing-portal.
  const storeManageUrl = isStore ? surface?.manageUrl || "" : "";
  // MANUAL covers both the trial everyone starts on AND B2B seats. Only
  // the latter is "your organization manages this" — saying it to a
  // trial user would be plain wrong.
  const isFreeTier = sub.planTier === "TRIAL" || sub.planTier === "BETA";
  const orgManaged =
    surface?.blockReason === "ORG_MANAGED" ||
    (provider === "MANUAL" && !isFreeTier && isManagedOrgType(orgType));
  // Store and org-managed plans have no Stripe portal to open.
  const managementHidden = isStore || orgManaged;
  // Buying is additionally off the table while another provider holds an
  // active subscription (docs/70 §5.1, E22).
  const purchaseBlocked =
    managementHidden ||
    (surface?.canPurchase === false &&
      (surface.blockReason === "OTHER_PROVIDER_ACTIVE" ||
        surface.blockReason === "ORG_MANAGED"));
  const providerName = providerLabel(t, provider, orgManaged);
  const graceUntil = sub.graceUntil
    ? new Date(Number(sub.graceUntil.seconds) * 1000).toLocaleDateString(locale)
    : null;

  return (
    <SettingsCard
      id="billing"
      title={t("sectionBilling")}
      isOpen={isOpen}
      onToggle={onToggle}
    >
      <div className="px-6 pt-7 pb-7">
        {/* Plan & Status metadata */}
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-4 pb-4 border-b border-white/[0.06]">
          <div>
            <span className="font-sans text-[11px] font-medium uppercase tracking-wider text-[#8FA5A0]">{t("billingPlanName")}</span>
            <div className="flex items-center gap-2 mt-0.5">
              <p className="font-sans text-[15px] font-semibold text-[#F2F0EA]">{planName}</p>
              {sub.planCycle === "ANNUAL" && (
                <span className="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-[#F5A623]/10 text-[#F5A623] border border-[#F5A623]/25 shadow-[0_0_10px_rgba(245,166,35,0.08)]">
                  {locale === "pl" ? "Roczna" : "Annual"}
                </span>
              )}
            </div>
          </div>
          <div>
            <span className="font-sans text-[11px] font-medium uppercase tracking-wider text-[#8FA5A0]">{t("billingStatus")}</span>
            <p className="font-sans text-[15px] font-semibold text-[#F2F0EA] mt-0.5">{statusName}</p>
          </div>
          {providerName && (
            <div>
              <span className="font-sans text-[11px] font-medium uppercase tracking-wider text-[#8FA5A0]">{t("billingProviderLabel")}</span>
              <p className="font-sans text-[15px] font-semibold text-[#F2F0EA] mt-0.5">{providerName}</p>
            </div>
          )}
        </div>

        {/* Store billing grace period (docs/70 E13): access continues,
            but only until the store gives up on the card. */}
        {graceUntil && (
          <div className="mb-5 p-4 rounded-xl border border-[#F5A623]/30 bg-[#F5A623]/10 text-[#F5A623] flex items-start gap-3 text-left">
            <svg className="w-5 h-5 shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <div className="text-xs font-sans leading-relaxed">
              <p className="font-bold text-[#F2F0EA] mb-0.5">{t("billingGraceTitle")}</p>
              <p>{t("billingGraceBody", { date: graceUntil })}</p>
            </div>
          </div>
        )}

        {sub.cancelAtPeriodEnd && sub.status === "ACTIVE" && (
          <div className="mb-5 p-4 rounded-xl border border-red-500/20 bg-red-500/10 text-[#fca5a5] flex items-start gap-3 text-left">
            <svg className="w-5 h-5 shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <div className="text-xs font-sans leading-relaxed">
              <p className="font-bold text-white mb-0.5">
                {locale === "pl" ? "Subskrypcja w trakcie anulowania" : "Subscription cancellation pending"}
              </p>
              <p>
                {locale === "pl"
                  ? `Twoja subskrypcja została anulowana i wygaśnie z dniem ${periodEnd}. Po tym terminie nie będziesz mógł/mogła zlecać nowych transkrypcji — dotychczasowe dane sesji pozostaną bezpieczne i dostępne. Aby kontynuować, wykup nowy plan.`
                  : `Your subscription has been canceled and will expire on ${periodEnd}. After this date, you won't be able to request new transcriptions — your existing session data remains safe and accessible. To continue, purchase a new plan.`}
              </p>
            </div>
          </div>
        )}

        {/* Quota Highlights Grid */}
        <div className="grid gap-4 sm:grid-cols-3 mb-5">
          <div className="p-4 rounded-xl bg-white/[0.03] border border-white/[0.06] flex flex-col justify-between">
            <span className="font-sans text-[11px] font-medium uppercase tracking-wider text-[#8FA5A0]">{t("billingTokensLeft")}</span>
            <span className="font-sans text-3xl font-extrabold text-[#F5A623] mt-2">{left}</span>
          </div>
          <div className="p-4 rounded-xl bg-white/[0.03] border border-white/[0.06] flex flex-col justify-between">
            <span className="font-sans text-[11px] font-medium uppercase tracking-wider text-[#8FA5A0]">{t("billingTokensTotal")}</span>
            <span className="font-sans text-2xl font-bold text-[#F2F0EA] mt-2">{total}</span>
          </div>
          <div className="p-4 rounded-xl bg-white/[0.03] border border-white/[0.06] flex flex-col justify-between">
            <span className="font-sans text-[11px] font-medium uppercase tracking-wider text-[#8FA5A0]">{t("billingPeriodEnd")}</span>
            <span className="font-sans text-lg font-semibold text-[#F2F0EA] mt-2">{periodEnd}</span>
          </div>
        </div>

        {/* Usage bar */}
        {total > 0 && (
          <div className="mb-5">
            <div className="h-2.5 w-full rounded-full bg-white/[0.06] overflow-hidden">
              <div
                className="h-full rounded-full bg-gradient-to-r from-[#F5A623] to-[#E09500] transition-all"
                style={{ width: `${pct}%` }}
              />
            </div>
            <p className="mt-2 font-sans text-[11px] text-[#8FA5A0]/70">
              {t("billingUsedBar", { used, total })}
            </p>
          </div>
        )}

        {/* Store-bought subscription: no Stripe portal exists for it —
            Apple/Google are the merchant of record (docs/70 S5, E23). */}
        {isStore && (
          <div className="p-4 rounded-xl bg-white/[0.03] border border-white/[0.08]">
            <p className="font-sans text-[13px] font-bold text-[#F2F0EA]">
              {isApple ? t("billingStoreAppleTitle") : t("billingStoreGoogleTitle")}
            </p>
            <p className="font-sans text-[12px] text-[#8FA5A0] mt-1 leading-relaxed">
              {isApple ? t("billingStoreAppleBody") : t("billingStoreGoogleBody")}
            </p>
            {storeManageUrl && (
              <a
                href={storeManageUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="mt-3 inline-flex items-center gap-2 rounded-xl bg-white/[0.06] hover:bg-white/[0.12] text-[#F2F0EA] border border-white/[0.1] font-sans font-bold text-[12px] uppercase tracking-wider px-4 py-2.5 transition"
              >
                {isApple
                  ? t("billingStoreManageAppleCta")
                  : t("billingStoreManageGoogleCta")}
                <svg className="w-3.5 h-3.5 text-[#F5A623]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                </svg>
              </a>
            )}
          </div>
        )}

        {/* B2B seat: the paywall is hidden entirely (docs/70 §5.1). */}
        {orgManaged && !isStore && (
          <div className="p-4 rounded-xl bg-white/[0.03] border border-white/[0.08]">
            <p className="font-sans text-[13px] font-bold text-[#F2F0EA]">
              {t("billingOrgManagedTitle")}
            </p>
            <p className="font-sans text-[12px] text-[#8FA5A0] mt-1 leading-relaxed">
              {t("billingOrgManagedBody")}
            </p>
          </div>
        )}

        {managementHidden ? null : sub.planTier !== "TRIAL" ? (
          <div className="space-y-3">
            {sub.cancelAtPeriodEnd && (
              <button
                type="button"
                disabled={portalLoading}
                onClick={handleManageBilling}
                className="group w-full flex items-center justify-between px-5 py-4 rounded-xl bg-gradient-to-r from-[#F5A623] to-[#E09500] hover:brightness-110 border border-transparent shadow-[0_4px_15px_rgba(245,166,35,0.15)] hover:shadow-[0_4px_25px_rgba(245,166,35,0.25)] transition-all duration-300 active:scale-99 text-left text-[#1B2522]"
              >
                <div>
                  <span className="font-sans text-[13px] font-bold uppercase tracking-wider">
                    {portalLoading
                      ? (locale === "pl" ? "Otwieranie portalu Stripe..." : "Opening Stripe Portal...")
                      : (locale === "pl" ? "Cofnij anulowanie i przedłuż subskrypcję" : "Reactivate & Renew Subscription")
                    }
                  </span>
                  <p className="font-sans text-[11px] text-[#1B2522]/70 mt-0.5">
                    {locale === "pl"
                      ? "Kliknij, aby przejść do Stripe i przywrócić subskrypcję jednym kliknięciem"
                      : "Click to go to Stripe and restore your subscription with one click"
                    }
                  </p>
                </div>
                <div className="flex items-center gap-1.5 text-[#1B2522]">
                  <svg className="w-5 h-5 transition-transform duration-300 group-hover:translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              </button>
            )}

            {sub.planTier === "SOLO" && !sub.cancelAtPeriodEnd && !purchaseBlocked && (
              <Link
                href={`${prefix}/upgrade?from=account`}
                className="group w-full flex items-center justify-between px-5 py-4 rounded-xl bg-gradient-to-r from-[#F5A623] to-[#E09500] hover:brightness-110 border border-transparent shadow-[0_4px_15px_rgba(245,166,35,0.15)] hover:shadow-[0_4px_25px_rgba(245,166,35,0.25)] transition-all duration-300 active:scale-99 text-left text-[#1B2522]"
              >
                <div>
                  <span className="font-sans text-[13px] font-bold uppercase tracking-wider">
                    {locale === "pl" ? "Ulepsz subskrypcję (Rozkwit)" : "Upgrade subscription (Growth)"}
                  </span>
                  <p className="font-sans text-[11px] text-[#1B2522]/70 mt-0.5">
                    {locale === "pl"
                      ? "Zwiększ limit do 90 sesji miesięcznie i zyskaj priorytetową kolejkę"
                      : "Increase limit to 90 sessions per month and get priority queue"}
                  </p>
                </div>
                <div className="flex items-center gap-1.5 text-[#1B2522]">
                  <svg className="w-5 h-5 transition-transform duration-300 group-hover:translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              </Link>
            )}

            <button
              type="button"
              disabled={portalLoading}
              onClick={handleManageBilling}
              className="group w-full flex items-center justify-between px-5 py-4 rounded-xl bg-gradient-to-r from-white/[0.04] to-white/[0.02] hover:from-white/[0.08] hover:to-white/[0.04] border border-white/[0.08] hover:border-[#F5A623]/30 transition-all duration-300 active:scale-99 text-left"
            >
              <div>
                <span className="font-sans text-[13px] font-bold uppercase tracking-wider text-[#F2F0EA]">
                  {portalLoading 
                    ? (locale === "pl" ? "Otwieranie portalu Stripe..." : "Opening Stripe Portal...") 
                    : (locale === "pl" ? "Zarządzaj płatnościami w Stripe" : "Manage Billing in Stripe")
                  }
                </span>
                <p className="font-sans text-[11px] text-[#8FA5A0]/70 mt-0.5">
                  {locale === "pl" 
                    ? "Zaktualizuj dane karty płatniczej, dane firmy lub pobierz faktury" 
                    : "Update payment card, company details, or download invoices"
                  }
                </p>
              </div>
              <div className="flex items-center gap-1.5 text-[#F5A623]">
                <svg className="w-5 h-5 transition-transform duration-300 group-hover:translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                </svg>
              </div>
            </button>
            {portalError && (
              <p className="font-sans text-[12px] text-[#ff4444] mt-1.5">{portalError}</p>
            )}
          </div>
        ) : purchaseBlocked ? null : (
          <UpgradeLink href={`${prefix}/upgrade?from=account`} label={t("billingUpgrade")} />
        )}

        {/* Store receipts live in the store — billing-svc `invoices` is
            Stripe-only by design (docs/70 §7.1, E23). */}
        {isStore && (
          <div className="mt-6 pt-6 border-t border-white/[0.06] w-full">
            <p className="font-sans text-[13px] text-[#8FA5A0] leading-relaxed">
              {isApple
                ? t("billingStoreInvoicesApple")
                : t("billingStoreInvoicesGoogle")}
            </p>
          </div>
        )}

        {/* Toggle Button for Invoices */}
        {!isStore && (
        <div className="mt-6 pt-6 border-t border-white/[0.06] flex flex-col items-start w-full">
          <button
            type="button"
            onClick={handleToggleInvoices}
            className="group inline-flex items-center gap-2.5 rounded-xl bg-white/[0.04] hover:bg-white/[0.08] text-[#F2F0EA] border border-white/[0.08] hover:border-white/[0.15] font-sans font-bold text-[13px] uppercase tracking-wider px-5 py-3 transition-all duration-300 active:scale-98"
          >
            <svg
              className={`w-4 h-4 text-[#8FA5A0] group-hover:text-[#F2F0EA] transition-transform duration-300 ${
                showInvoices ? "rotate-180" : ""
              }`}
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth="2.5"
            >
              <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
            </svg>
            <span>
              {showInvoices ? t("billingInvoicesHideBtn") : t("billingInvoicesShowBtn")}
            </span>
          </button>

          <AnimatePresence>
            {showInvoices && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: "auto" }}
                exit={{ opacity: 0, height: 0 }}
                transition={{ duration: 0.3 }}
                className="w-full overflow-hidden"
              >
                <div className="pt-6 w-full">
                  <h3 className="font-sans text-[11px] font-bold uppercase tracking-[0.15em] text-[#8FA5A0] mb-3">
                    {t("billingInvoicesTitle")}
                  </h3>

                  {loadingInvoices && (
                    <div className="py-6 flex items-center justify-center gap-3">
                      <div className="w-5 h-5 rounded-full border-2 border-white/5 border-t-[#F5A623] animate-spin" />
                      <span className="font-sans text-sm text-[#8FA5A0]">{t("billingInvoicesLoading")}</span>
                    </div>
                  )}

                  {loadError && (
                    <div className="w-full p-4 rounded-xl border border-[#ff4444]/40 bg-[#ff4444]/10 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                      <span className="font-sans text-sm text-[#F2F0EA]">{loadError}</span>
                      <button
                        type="button"
                        onClick={fetchInvoices}
                        className="font-sans font-bold text-xs uppercase tracking-wider text-[#F5A623] hover:underline"
                      >
                        {locale === "pl" ? "Spróbuj ponownie" : "Try again"}
                      </button>
                    </div>
                  )}

                  {!loadingInvoices && !loadError && (!invoices || invoices.length === 0) && (
                    <p className="font-sans text-sm text-[#8FA5A0]/70 py-2">
                      {t("billingInvoicesNoInvoices")}
                    </p>
                  )}

                  {!loadingInvoices && !loadError && invoices && invoices.length > 0 && (
                    <div className="overflow-x-auto rounded-xl border border-white/[0.06] bg-white/[0.01] w-full">
                      <table className="w-full text-left border-collapse">
                        <thead>
                          <tr className="border-b border-white/[0.08] bg-white/[0.02]">
                            <th className="px-4 py-3 font-sans text-[11px] font-bold uppercase tracking-wider text-[#8FA5A0]">
                              {t("billingInvoicesDate")}
                            </th>
                            <th className="px-4 py-3 font-sans text-[11px] font-bold uppercase tracking-wider text-[#8FA5A0]">
                              {t("billingInvoicesAmount")}
                            </th>
                            <th className="px-4 py-3 font-sans text-[11px] font-bold uppercase tracking-wider text-[#8FA5A0] text-right">
                              {locale === "pl" ? "Akcje" : "Actions"}
                            </th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-white/[0.04]">
                          {invoices.map((inv) => {
                            const dateStr = inv.createdAt
                              ? new Date(Number(inv.createdAt.seconds) * 1000).toLocaleDateString(locale)
                              : "—";
                            const formattedAmount = `${(inv.amountPaid).toFixed(2)} ${inv.currency.toUpperCase()}`;

                            return (
                              <tr key={inv.id} className="hover:bg-white/[0.02] transition-colors">
                                <td className="px-4 py-3.5 font-sans text-sm font-medium text-[#F2F0EA]">
                                  {dateStr}
                                </td>
                                <td className="px-4 py-3.5 font-sans text-sm font-semibold text-[#F2F0EA]">
                                  {formattedAmount}
                                </td>
                                <td className="px-4 py-3.5 text-right space-x-2 whitespace-nowrap">
                                  {inv.invoicePdf && (
                                    <a
                                      href={inv.invoicePdf}
                                      target="_blank"
                                      rel="noopener noreferrer"
                                      className="inline-flex items-center gap-1.5 rounded-lg bg-[#2F6B62]/10 hover:bg-[#2F6B62]/20 text-[#4FC097] border border-[#2F6B62]/30 hover:border-[#4FC097] font-sans font-bold text-[11px] uppercase tracking-wider px-3 py-1.5 transition-all"
                                    >
                                      <svg
                                        className="w-3.5 h-3.5"
                                        fill="none"
                                        viewBox="0 0 24 24"
                                        stroke="currentColor"
                                        strokeWidth="2.5"
                                      >
                                        <path
                                          strokeLinecap="round"
                                          strokeLinejoin="round"
                                          d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
                                        />
                                      </svg>
                                      <span>{t("billingInvoicesDownload")}</span>
                                    </a>
                                  )}
                                  {inv.hostedInvoiceUrl && (
                                    <a
                                      href={inv.hostedInvoiceUrl}
                                      target="_blank"
                                      rel="noopener noreferrer"
                                      className="inline-flex items-center gap-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-[#F2F0EA] border border-white/10 hover:border-white/20 font-sans font-bold text-[11px] uppercase tracking-wider px-3 py-1.5 transition-all"
                                    >
                                      <svg
                                        className="w-3.5 h-3.5 text-[#8FA5A0]"
                                        fill="none"
                                        viewBox="0 0 24 24"
                                        stroke="currentColor"
                                        strokeWidth="2.5"
                                      >
                                        <path
                                          strokeLinecap="round"
                                          strokeLinejoin="round"
                                          d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                                        />
                                      </svg>
                                      <span>{t("billingInvoicesView")}</span>
                                    </a>
                                  )}
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
        )}
      </div>
    </SettingsCard>
  );
}

// Active upgrade link → navigates to /upgrade page
function UpgradeLink({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="inline-flex items-center justify-center rounded-xl bg-[#F5A623] text-[#1B2522] font-sans font-bold text-[13px] uppercase tracking-wider px-6 py-3 shadow-[0_0_20px_rgba(245,166,35,0.2)] hover:brightness-110 hover:shadow-[0_0_30px_rgba(245,166,35,0.3)] transition-all"
    >
      {label}
    </Link>
  );
}

// Connect-Web JSON gives us either the numeric enum or its string name;
// tolerate both, exactly like OrgsList does.
function isManagedOrgType(type: OrganizationType | null): boolean {
  if (type === null || type === undefined) return false;
  const v = type as unknown;
  return (
    v === OrganizationType.CLINIC ||
    v === "ORGANIZATION_TYPE_CLINIC" ||
    v === OrganizationType.ENTERPRISE ||
    v === "ORGANIZATION_TYPE_ENTERPRISE"
  );
}

// Naming the seller is only useful when it tells the user where to go.
// MANUAL on a trial means "nobody sold you anything yet" — stay quiet.
function providerLabel(
  t: ReturnType<typeof useTranslations>,
  provider: string,
  orgManaged: boolean,
): string | null {
  switch (provider) {
    case "STRIPE":
      return t("billingProviderStripe");
    case "APPLE_IAP":
      return t("billingProviderApple");
    case "GOOGLE_IAP":
      return t("billingProviderGoogle");
    case "MANUAL":
      return orgManaged ? t("billingProviderManual") : null;
    default:
      return null;
  }
}

// planLabel + statusLabel map raw enum strings to localised copy
function planLabel(t: ReturnType<typeof useTranslations>, raw: string): string {
  if (!raw) return "—";
  const k = `plan${raw.toUpperCase()}`;
  try {
    const val = t(k);
    if (val && val !== k) return val;
  } catch {}
  return raw;
}
function statusLabel(t: ReturnType<typeof useTranslations>, raw: string): string {
  if (!raw) return "—";
  const k = `status${raw.toUpperCase()}`;
  try {
    const val = t(k);
    if (val && val !== k) return val;
  } catch {}
  return raw;
}

// ────────────────────────────────────────────────────────────────────
// Shared UI components — Apple Settings style
// ────────────────────────────────────────────────────────────────────

const getInputClass = (hasError?: boolean) =>
  `rounded-xl bg-white/[0.04] border ${
    hasError ? "border-[#ff4444]" : "border-white/[0.08]"
  } px-3.5 py-2.5 font-sans text-[15px] text-[#F2F0EA] focus:outline-none focus:border-${
    hasError ? "[#ff4444]" : "[#F5A623]/50"
  } focus:ring-1 focus:ring-${
    hasError ? "[#ff4444]/20" : "[#F5A623]/20"
  } w-full transition placeholder:text-[#8FA5A0]/40`;

const inputClass = getInputClass(false);

const submitBtnClass =
  "inline-flex items-center justify-center rounded-xl bg-[#2F6B62]/10 text-[#4FC097] border border-[#2F6B62]/30 font-sans font-bold text-[13px] uppercase tracking-wider px-6 py-3 hover:bg-[#2F6B62]/20 hover:border-[#4FC097] transition disabled:opacity-50 disabled:cursor-not-allowed";

function SettingsCard({
  id,
  title,
  isOpen,
  onToggle,
  children,
}: {
  id?: string;
  title: string;
  isOpen?: boolean;
  onToggle?: () => void;
  children: React.ReactNode;
}) {
  const isCollapsible = isOpen !== undefined && onToggle !== undefined;
  const icon = getSectionIcon(id);

  return (
    <section
      id={id}
      className="rounded-2xl border border-white/[0.08] bg-white/[0.04] backdrop-blur-md overflow-hidden transition-all duration-300 scroll-mt-24"
    >
      {isCollapsible ? (
        <button
          type="button"
          onClick={onToggle}
          className="w-full flex items-center justify-between px-6 py-5 text-left hover:bg-white/[0.02] transition-colors focus:outline-none"
        >
          <div className="flex items-center gap-3">
            {icon}
            <h2 className="font-sans text-[11px] font-bold uppercase tracking-[0.15em] text-[#8FA5A0]">
              {title}
            </h2>
          </div>
          <svg
            className={`w-4 h-4 text-[#8FA5A0] transition-transform duration-300 ${
              isOpen ? "rotate-180" : ""
            }`}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth="2.5"
          >
            <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
          </svg>
        </button>
      ) : (
        <div className="px-6 pt-5 pb-3 flex items-center gap-3">
          {icon}
          <h2 className="font-sans text-[11px] font-bold uppercase tracking-[0.15em] text-[#8FA5A0]">
            {title}
          </h2>
        </div>
      )}

      {isCollapsible ? (
        <div
          className={`transition-all duration-300 overflow-hidden ${
            isOpen ? "max-h-[1500px] opacity-100" : "max-h-0 opacity-0 pointer-events-none"
          }`}
        >
          <div className="border-t border-white/[0.08]">
            {children}
          </div>
        </div>
      ) : (
        <div>{children}</div>
      )}
    </section>
  );
}

function SidebarNavLink({
  label,
  active,
  onClick,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <li>
      <button
        type="button"
        onClick={onClick}
        className={`w-full text-left px-3 py-2 rounded-lg font-sans text-[13px] font-medium transition-all duration-200 ${
          active
            ? "bg-white/[0.06] text-[#F5A623] pl-4 shadow-sm"
            : "text-[#8FA5A0]/80 hover:text-[#F2F0EA] hover:bg-white/[0.02]"
        }`}
      >
        {label}
      </button>
    </li>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <h2 className="px-4 pt-4 pb-2 font-sans text-[11px] font-bold uppercase tracking-[0.15em] text-[#8FA5A0]">
      {children}
    </h2>
  );
}

function SettingsField({
  label,
  children,
  error,
}: {
  label: string;
  children: React.ReactNode;
  error?: string;
}) {
  return (
    <div className="grid gap-2.5">
      <div className="flex justify-between items-baseline">
        <span className="font-sans text-[12px] font-medium uppercase tracking-wider text-[#8FA5A0]">
          {label}
        </span>
        {error && (
          <span className="font-sans text-[11px] font-semibold text-[#ff4444] tracking-wide animate-pulse">
            {error}
          </span>
        )}
      </div>
      {children}
    </div>
  );
}

function StatRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="font-sans text-[11px] font-medium uppercase tracking-wider text-[#8FA5A0]">{label}</dt>
      <dd className="font-sans text-lg font-semibold text-[#F2F0EA] mt-0.5">{value}</dd>
    </div>
  );
}

function LinkRow({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="flex items-center justify-between px-4 py-3.5 hover:bg-white/[0.03] transition-colors"
    >
      <span className="font-sans text-[15px] text-[#F2F0EA]">{label}</span>
      <ChevronRight />
    </Link>
  );
}

function ChevronRight({ color = "#8FA5A0" }: { color?: string }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="opacity-40 flex-shrink-0">
      <polyline points="9 18 15 12 9 6" />
    </svg>
  );
}

// Apple settings-style icons helper
function getSectionIcon(id?: string) {
  if (!id) return null;
  switch (id) {
    case "profile":
      return (
        <div className="w-7 h-7 rounded-lg bg-[#38B2AC]/15 flex items-center justify-center text-[#38B2AC] shrink-0">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
            <path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
        </div>
      );
    case "organization":
      return (
        <div className="w-7 h-7 rounded-lg bg-[#A855F7]/15 flex items-center justify-center text-[#A855F7] shrink-0">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
            <path strokeLinecap="round" strokeLinejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
          </svg>
        </div>
      );
    case "preferences":
      return (
        <div className="w-7 h-7 rounded-lg bg-[#3B82F6]/15 flex items-center justify-center text-[#3B82F6] shrink-0">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
          </svg>
        </div>
      );
    case "billing":
      return (
        <div className="w-7 h-7 rounded-lg bg-[#F5A623]/15 flex items-center justify-center text-[#F5A623] shrink-0">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
            <path strokeLinecap="round" strokeLinejoin="round" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
          </svg>
        </div>
      );
    case "legal":
      return (
        <div className="w-7 h-7 rounded-lg bg-[#8FA5A0]/20 flex items-center justify-center text-[#8FA5A0] shrink-0">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
            <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
          </svg>
        </div>
      );
    case "mgmt":
      return (
        <div className="w-7 h-7 rounded-lg bg-[#FF4444]/15 flex items-center justify-center text-[#FF4444] shrink-0">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
          </svg>
        </div>
      );
    default:
      return null;
  }
}

// Aligned 3-step account deletion component
function DeleteAccountView({
  locale,
  onCancel,
  fbUser,
  signOut,
}: {
  locale: string;
  onCancel: () => void;
  fbUser: any;
  signOut: () => Promise<void>;
}) {
  const t = useTranslations("account");
  const router = useRouter();
  const [understands, setUnderstands] = useState(false);
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [confirmText, setConfirmText] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const expectedWord = t("deleteAccountConfirmWord"); // "usuwam" or "delete"
  const isMatch = confirmText.trim().toLowerCase() === expectedWord.toLowerCase();

  async function handleDelete() {
    if (!isMatch || deleting) return;
    setDeleting(true);
    setError(null);
    try {
      await fbUser.delete();
      // Successfully deleted. Redirect is handled automatically by the auth state observer,
      // but we force redirect just in case.
      const prefix = locale === "en" ? "/en" : "/pl";
      router.push(`${prefix}/login`);
    } catch (err: any) {
      console.error("Error deleting user account:", err);
      setDeleting(false);
      if (err?.code === "auth/requires-recent-login" || err?.message?.includes("requires-recent-login")) {
        setShowConfirmModal(false);
        const prefix = locale === "en" ? "/en" : "/pl";
        await signOut();
        window.location.href = `${prefix}/login?err=reauth`;
      } else {
        setError(t("errGeneric"));
      }
    }
  }

  return (
    <div className="max-w-2xl mx-auto rounded-2xl border border-white/[0.08] bg-white/[0.04] backdrop-blur-md p-6 sm:p-10 shadow-2xl relative">
      {/* Back button */}
      <button
        type="button"
        onClick={onCancel}
        className="inline-flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-[#8FA5A0] hover:text-[#F2F0EA] transition mb-8 font-sans"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="rotate-180">
          <polyline points="9 18 15 12 9 6" />
        </svg>
        {locale === "pl" ? "Wróć do ustawień" : "Back to settings"}
      </button>

      <h1 className="font-sans text-2xl sm:text-3xl font-extrabold text-[#F2F0EA] tracking-tight mb-8">
        {t("deleteAccountTitle")}
      </h1>

      <div className="space-y-6 mb-10">
        <div className="flex gap-4 items-start">
          <div className="w-6 h-6 rounded-full bg-[#FF4444]/15 flex items-center justify-center text-[#FF4444] shrink-0 mt-0.5">
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="3">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </div>
          <p className="font-sans text-[15px] text-[#8FA5A0] leading-relaxed">
            {t("deleteAccountConsequence1")}
          </p>
        </div>

        <div className="flex gap-4 items-start">
          <div className="w-6 h-6 rounded-full bg-[#FF4444]/15 flex items-center justify-center text-[#FF4444] shrink-0 mt-0.5">
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="3">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </div>
          <p className="font-sans text-[15px] text-[#8FA5A0] leading-relaxed">
            {t("deleteAccountConsequence2")}
          </p>
        </div>

        <div className="flex gap-4 items-start">
          <div className="w-6 h-6 rounded-full bg-[#FF4444]/15 flex items-center justify-center text-[#FF4444] shrink-0 mt-0.5">
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="3">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </div>
          <p className="font-sans text-[15px] text-[#8FA5A0] leading-relaxed">
            {t("deleteAccountConsequence3")}
          </p>
        </div>
      </div>

      <div className="border-t border-white/[0.08] pt-6 flex flex-col gap-6">
        {/* Toggle row */}
        <label className="flex items-center justify-between gap-4 cursor-pointer">
          <span className="font-sans text-sm font-semibold text-[#FF4444] leading-relaxed select-none">
            {t("deleteAccountToggleText")}
          </span>
          <input
            type="checkbox"
            checked={understands}
            onChange={(e) => setUnderstands(e.target.checked)}
            className="w-5 h-5 rounded border-white/20 bg-white/5 text-[#FF4444] focus:ring-[#FF4444]/50 accent-[#FF4444]"
          />
        </label>

        {/* Delete button */}
        <button
          type="button"
          disabled={!understands}
          onClick={() => {
            setConfirmText("");
            setError(null);
            setShowConfirmModal(true);
          }}
          className="w-full py-4 px-6 rounded-xl font-sans font-bold text-sm uppercase tracking-wider text-white bg-[#FF4444] hover:bg-[#E03333] active:scale-[0.99] transition disabled:opacity-35 disabled:cursor-not-allowed text-center shadow-[0_4px_15px_rgba(255,68,68,0.2)] disabled:shadow-none"
        >
          {t("deleteAccountButton")}
        </button>
      </div>

      {/* Confirm Modal Overlay */}
      {showConfirmModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
          <div className="w-full max-w-md rounded-2xl border border-white/[0.1] bg-[#0A2326] p-6 shadow-2xl relative text-center">
            <div className="w-16 h-16 rounded-full bg-[#FF4444]/15 flex items-center justify-center text-[#FF4444] mx-auto mb-5 shadow-[0_0_20px_rgba(255,68,68,0.2)]">
              <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>

            <h3 className="font-sans text-xl font-bold text-[#F2F0EA] mb-2">
              {t("deleteAccountSheetTitle")}
            </h3>
            <p className="font-sans text-sm text-[#8FA5A0] mb-4">
              {t("deleteAccountSheetSubtitle")} <strong className="font-mono text-[#FF4444] tracking-widest uppercase ml-1">{expectedWord}</strong>
            </p>

            <input
              type="text"
              autoFocus
              value={confirmText}
              onChange={(e) => setConfirmText(e.target.value)}
              placeholder={t("deleteAccountSheetHint")}
              className="w-full rounded-xl bg-white/[0.04] border border-white/[0.08] px-4 py-3 font-mono text-center text-lg text-[#F2F0EA] focus:outline-none focus:border-[#FF4444]/50 focus:ring-1 focus:ring-[#FF4444]/20 transition mb-5 placeholder:text-[#8FA5A0]/30"
            />

            {error && (
              <p role="alert" className="rounded-xl border border-[#ff4444]/40 bg-[#ff4444]/10 px-3 py-2 font-sans text-xs text-[#F2F0EA] mb-4 text-left">
                {error}
              </p>
            )}

            <div className="flex flex-col gap-2">
              <button
                type="button"
                disabled={!isMatch || deleting}
                onClick={handleDelete}
                className="w-full py-3 px-6 rounded-xl font-sans font-bold text-xs uppercase tracking-wider text-white bg-[#FF4444] hover:bg-[#E03333] transition disabled:opacity-35 disabled:cursor-not-allowed flex items-center justify-center min-h-[44px]"
              >
                {deleting ? (
                  <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : (
                  t("deleteAccountSheetButton")
                )}
              </button>
              <button
                type="button"
                disabled={deleting}
                onClick={() => setShowConfirmModal(false)}
                className="w-full py-3 px-6 rounded-xl font-sans font-semibold text-xs uppercase tracking-wider text-[#8FA5A0] hover:text-[#F2F0EA] transition"
              >
                {t("deleteAccountSheetCancel")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
