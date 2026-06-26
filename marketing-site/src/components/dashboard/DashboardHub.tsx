// DashboardHub — Post-login hub component.
//
// Plan: "Dashboard hub (dwa panele: apka + konto)"
// Two large cards:
//   1. "Otwórz aplikację" → launches the Flutter web app
//   2. "Zarządzaj kontem" → navigates to /account
//
// Shows welcome message + subscription status overview.
// Protected by auth — shows login redirect if not authenticated.

"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/lib/firebase/auth-provider";
import Link from "next/link";
import { motion, AnimatePresence } from "framer-motion";
import { useRouter } from "next/navigation";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { identityClient, billingClient } from "@/lib/connect/clients";
import { UserRole } from "@superwizor/proto-ts/identity/v1/identity_pb";
import { GetSubscriptionRequestSchema } from "@superwizor/proto-ts/billing/v1/billing_pb";
import type { Subscription } from "@superwizor/proto-ts/billing/v1/billing_pb";

const APP_URL = "https://superwizor-app.web.app/";
const APP_STORE_URL = "https://apps.apple.com/app/superwizor-ai/id6774975751";

export function DashboardHub({ locale }: { locale: string }) {
  const { user: fbUser, status: authStatus } = useAuth();
  const router = useRouter();
  const prefix = locale === "en" ? "/en" : "";
  const [greeting, setGreeting] = useState("");
  const [modalPlatform, setModalPlatform] = useState<"ios" | "android" | null>(null);
  const [checkingOnboarding, setCheckingOnboarding] = useState(true);
  const [showInstructions, setShowInstructions] = useState(false);
  const [showPlatformPicker, setShowPlatformPicker] = useState(false);
  const [profileFirstName, setProfileFirstName] = useState<string>("");
  const [sub, setSub] = useState<Subscription | null>(null);
  const [loadingSub, setLoadingSub] = useState<boolean>(true);

  const handleOpenModal = (platform: "ios" | "android") => {
    setShowInstructions(false);
    setModalPlatform(platform);
  };

  const handleCloseModal = () => {
    setModalPlatform(null);
    setShowInstructions(false);
  };

  const handlePickPlatform = (platform: "ios" | "android") => {
    setShowPlatformPicker(false);
    handleOpenModal(platform);
  };

  useEffect(() => {
    if (authStatus === "loading") return;
    if (authStatus === "signed-out" || !fbUser) {
      setCheckingOnboarding(false);
      setLoadingSub(false);
      return;
    }

    let active = true;
    (async () => {
      try {
        setLoadingSub(true);
        const me = await identityClient.getMyProfile(create(EmptySchema, {}));
        if (!active) return;

        const isAdmin =
          (me.role as unknown) === UserRole.SUPERWIZOR_ADMIN ||
          (me.role as unknown) === "USER_ROLE_SUPERWIZOR_ADMIN";

        if (!isAdmin && !me.defaultModalityId) {
          router.replace(`${prefix}/onboarding/`);
        } else {
          setCheckingOnboarding(false);
        }
        // Store the profile first name for greeting
        if (me.firstName) {
          setProfileFirstName(me.firstName);
        }

        if (me.organizationId) {
          try {
            const s = await billingClient.getSubscription(
              create(GetSubscriptionRequestSchema, { organizationId: me.organizationId })
            );
            if (active) {
              setSub(s);
            }
          } catch (subErr) {
            console.error("[DashboardHub] load subscription failed", subErr);
          }
        }
      } catch (err) {
        console.error("[DashboardHub] load profile failed for onboarding check", err);
        if (active) {
          setCheckingOnboarding(false);
        }
      } finally {
        if (active) {
          setLoadingSub(false);
        }
      }
    })();

    return () => {
      active = false;
    };
  }, [fbUser, authStatus, router, prefix]);

  useEffect(() => {
    const hour = new Date().getHours();
    if (locale === "en") {
      if (hour >= 5 && hour < 12) {
        setGreeting("Good morning");
      } else if (hour >= 12 && hour < 18) {
        setGreeting("Good afternoon");
      } else if (hour >= 18 && hour < 22) {
        setGreeting("Good evening");
      } else {
        setGreeting("Late night greetings");
      }
    } else {
      if (hour >= 5 && hour < 18) {
        setGreeting("Dzień dobry");
      } else if (hour >= 18 && hour < 22) {
        setGreeting("Dobry wieczór");
      } else {
        setGreeting("Witaj nocną porą");
      }
    }
  }, [locale]);

  const displayName = (() => {
    // 1. First priority: firstName from backend profile (identity-svc)
    if (profileFirstName) return profileFirstName;
    // 2. Fallback: Firebase Auth displayName (first word)
    if (fbUser?.displayName) return fbUser.displayName.split(" ")[0];
    // 3. Last resort: email prefix, cleaned up
    if (fbUser?.email) {
      const raw = fbUser.email.split("@")[0].replace(/[+.]/g, " ").trim();
      const firstName = raw.split(" ")[0];
      return firstName.charAt(0).toUpperCase() + firstName.slice(1).toLowerCase();
    }
    return "";
  })();

  const t = (pl: string, en: string) => (locale === "en" ? en : pl);

  if (authStatus === "loading" || (authStatus === "signed-in" && checkingOnboarding)) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-[#0A2326] to-[#0D1B1E] flex flex-col items-center justify-center">
        <div className="relative w-12 h-12">
          <div className="absolute inset-0 rounded-full border-4 border-white/5" />
          <div className="absolute inset-0 rounded-full border-4 border-t-[#F5A623] animate-spin" />
        </div>
      </div>
    );
  }

  return (
    <section className="relative overflow-hidden bg-gradient-to-b from-[#0A2326] to-[#0D1B1E] pt-28 pb-20 sm:pt-36 sm:pb-28 min-h-[80vh]">
      {/* Decorative ambient glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[800px] bg-[radial-gradient(ellipse_at_center,_rgba(245,166,35,0.06)_0%,_transparent_70%)] pointer-events-none" />

      <div className="relative mx-auto max-w-5xl px-5">
        {/* --- Welcome --- */}
        <div className="mb-14">
          <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-[#F5A623] mb-2">
            {greeting}
          </p>
          <h1 className="font-serif text-3xl sm:text-4xl font-bold text-[#F2F0EA] leading-tight">
            {displayName
              ? locale === "en"
                ? `Welcome back, ${displayName}`
                : `Witaj ponownie, ${displayName}`
              : locale === "en"
                ? "Welcome to Superwizor AI"
                : "Witaj w Superwizor AI"}
          </h1>
          <p className="font-sans text-base text-[#8FA5A0] mt-2">
            {locale === "en"
              ? "Choose what you'd like to do."
              : "Wybierz, co chcesz zrobić."}
          </p>
        </div>

        {/* --- Quota Status Strip (Option A) --- */}
        {fbUser && (
          <div className="mb-14">
            {loadingSub ? (
              <div className="bg-white/[0.02] border border-white/[0.04] backdrop-blur-md rounded-2xl py-3.5 px-5 sm:px-6 animate-pulse flex items-center justify-between">
                <div className="h-4 bg-white/[0.06] rounded w-28" />
                <div className="h-4 bg-white/[0.06] rounded w-48 hidden sm:block" />
                <div className="h-4 bg-white/[0.06] rounded w-16" />
              </div>
            ) : !sub ? (
              <div className="bg-white/[0.02] border border-white/[0.04] backdrop-blur-md rounded-2xl py-3.5 px-5 sm:px-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 shadow-lg">
                <div className="flex items-center gap-3">
                  <span className="font-mono text-[9px] uppercase tracking-wider text-[#8FA5A0]">
                    {locale === "en" ? "Your plan:" : "Twój plan:"}
                  </span>
                  <span className="w-1.5 h-1.5 rounded-full bg-white/10" />
                  <span className="font-sans text-xs font-semibold text-[#F2F0EA]">
                    {locale === "en" ? "Free Account" : "Darmowe konto"}
                  </span>
                </div>
                <Link
                  href={`${prefix}/upgrade`}
                  className="text-xs font-bold text-[#FCAE2F] hover:text-[#E09500] transition-colors underline underline-offset-2 hover:no-underline"
                >
                  {locale === "en" ? "Activate premium plan ➔" : "Aktywuj plan premium ➔"}
                </Link>
              </div>
            ) : (() => {
              const total = sub.tokensPerPeriod;
              const used = sub.tokensUsedThisPeriod + sub.tokensReservedThisPeriod;
              const left = Math.max(0, total - used);
              const pct = total > 0 ? Math.min(100, Math.round((used / total) * 100)) : 0;

              let planName = "";
              if (sub.planTier === "TRIAL") {
                planName = locale === "en" ? "Trial period" : "Okres próbny";
              } else if (sub.planTier === "SOLO") {
                planName = locale === "en" ? "Balance" : "Równowaga";
              } else if (sub.planTier === "PRO") {
                planName = locale === "en" ? "Flourishing" : "Rozkwit";
              } else if (sub.planTier === "CLINIC") {
                planName = locale === "en" ? "Practice / Clinic" : "Gabinet / Klinika";
              } else {
                planName = sub.planTier;
              }

              let statusText = "";
              let badgeClass = "";
              if (sub.cancelAtPeriodEnd) {
                statusText = locale === "en" ? "Cancelling" : "Rezygnacja";
                badgeClass = "bg-red-500/10 text-red-400 border border-red-500/20";
              } else if (sub.status === "TRIALING") {
                statusText = locale === "en" ? "Trial" : "Okres próbny";
                badgeClass = "bg-amber-500/10 text-amber-400 border border-amber-500/20";
              } else {
                statusText = locale === "en" ? "Active" : "Aktywny";
                badgeClass = "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20";
              }

              const resetDate = sub.currentPeriodEnd
                ? new Date(Number(sub.currentPeriodEnd.seconds) * 1000).toLocaleDateString(
                    locale === "en" ? "en-US" : "pl-PL",
                    { day: "numeric", month: "short" }
                  )
                : null;

              const isTrial = sub.planTier === "TRIAL" || sub.status === "TRIALING";
              const dateLabel = isTrial
                ? (locale === "en" ? "Trial ends" : "Koniec okresu próbnego")
                : (locale === "en" ? "Resets" : "Odnowienie");

              return (
                <div className="bg-white/[0.02] border border-white/[0.04] backdrop-blur-md rounded-2xl py-3.5 px-5 sm:px-6 flex flex-col md:flex-row md:items-center justify-between gap-4 shadow-lg">
                  <div className="flex items-center gap-3">
                    <span className="font-mono text-[9px] uppercase tracking-wider text-[#8FA5A0]">
                      {locale === "en" ? "Your plan:" : "Twój plan:"}
                    </span>
                    <span className="w-1.5 h-1.5 rounded-full bg-white/10" />
                    <span className="font-sans text-xs font-bold text-[#F2F0EA]">{planName}</span>
                  </div>

                  <div className="flex flex-1 sm:max-w-xs items-center gap-3">
                    <span className="font-sans text-[11px] text-[#8FA5A0] whitespace-nowrap">
                      {locale === "en" ? "Usage:" : "Użycie:"}
                    </span>
                    <div className="h-1.5 flex-1 rounded-full bg-white/[0.06] overflow-hidden min-w-[60px]">
                      <div
                        className="h-full rounded-full bg-gradient-to-r from-[#FCAE2F] to-[#E09500] transition-all duration-500 ease-out"
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                    <span className="font-mono text-[11px] font-bold text-[#F2F0EA] whitespace-nowrap">
                      {pct}%
                    </span>
                  </div>

                  <div className="font-sans text-xs text-[#8FA5A0] whitespace-nowrap">
                    {locale === "en"
                      ? `Remaining: ${left} of ${total} sessions${resetDate ? ` • ${dateLabel}: ${resetDate}` : ""}`
                      : `Pozostało: ${left} z ${total} sesji${resetDate ? ` • ${dateLabel}: ${resetDate}` : ""}`}
                  </div>
                </div>
              );
            })()}
          </div>
        )}


        {/* --- Three Hub Cards --- */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Card 1: Open App (Web) */}
          <a
            href={APP_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="group relative rounded-2xl p-6 sm:p-8 bg-gradient-to-br from-[#004D54]/75 to-[#003A40]/75 border border-[#2F6B62]/35 shadow-xl hover:shadow-2xl hover:shadow-[#004D54]/25 transition-all duration-300 hover:-translate-y-1 flex flex-col justify-between backdrop-blur-md"
          >
            <div>
              {/* Superwizor Logo */}
              <div className="w-14 h-14 rounded-xl overflow-hidden mb-5 shadow-md group-hover:shadow-lg transition-shadow border border-white/10">
                <img
                  src="/superwizor-logo-512.png"
                  alt="Superwizor AI"
                  width={56}
                  height={56}
                  className="w-full h-full object-cover"
                />
              </div>

              <h2 className="font-serif text-xl font-bold text-[#F2F0EA] mb-2">
                {locale === "en" ? "Go to Application" : "Przejdź do aplikacji"}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] leading-relaxed mb-6">
                {locale === "en"
                  ? "Review sessions, read AI reports, and manage client files on your computer."
                  : "Przeglądaj sesje, czytaj raporty kliniczne AI i zarządzaj kartotekami na komputerze."}
              </p>
            </div>

            <div>
              {/* App links */}
              <div className="flex flex-wrap gap-2">
                <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10">
                  🌐 Web App
                </span>
              </div>
            </div>

            {/* Arrow */}
            <div className="absolute top-6 right-6 w-8 h-8 rounded-full bg-[#FCAE2F]/10 flex items-center justify-center group-hover:bg-[#FCAE2F]/20 transition-colors border border-[#FCAE2F]/10">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#FCAE2F" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="7" y1="17" x2="17" y2="7" />
                <polyline points="7 7 17 7 17 17" />
              </svg>
            </div>
          </a>

          {/* Card 2: Download Mobile App */}
          <button
            type="button"
            onClick={() => setShowPlatformPicker(true)}
            className="group relative rounded-2xl p-6 sm:p-8 bg-gradient-to-br from-[#0B2A2D]/75 to-[#081E21]/75 border border-[#2F6B62]/25 shadow-xl hover:shadow-2xl hover:shadow-[#2F6B62]/15 transition-all duration-300 hover:-translate-y-1 flex flex-col justify-between backdrop-blur-md text-left cursor-pointer"
          >
            <div>
              {/* Icon — phone with signal */}
              <div className="w-14 h-14 rounded-xl bg-white/5 flex items-center justify-center mb-5 group-hover:bg-white/10 transition-colors border border-white/10">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#F2F0EA" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                  <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
                  <line x1="12" y1="18" x2="12" y2="18.01" />
                </svg>
              </div>

              <h2 className="font-serif text-xl font-bold text-[#F2F0EA] mb-2">
                {locale === "en" ? "Download on Phone" : "Ściągnij na telefon"}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] leading-relaxed mb-6">
                {locale === "en"
                  ? "Record sessions directly from your phone on the desk."
                  : "Nagrywaj sesje terapeutyczne bezpośrednio z telefonu leżącego na biurku."}
              </p>
            </div>

            <div>
              {/* Platform badges */}
              <div className="flex flex-wrap gap-2">
                <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10">
                  <svg className="w-3 h-3" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 4.17c.66-.81 1.11-1.93.99-3.06-.96.04-2.13.64-2.82 1.45-.6.69-1.12 1.84-.98 2.94.1.08.21.12.33.12.87 0 1.98-.54 2.48-1.45z"/></svg>
                  iOS
                </span>
                <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10">
                  <svg className="w-3 h-3" viewBox="0 0 24 24" fill="currentColor"><path d="M3 20.285V3.716c0-.525.308-.94.757-1.077L14.654 12 3.757 21.362A1.14 1.14 0 013 20.285zM15.908 13.084l2.842 2.463L5.342 2.874l10.566 10.21zM19.98 12.569c.563-.326.563-.858 0-1.184l-2.909-1.686L14.654 12l2.417 2.253 2.909-1.684zM5.342 21.126L18.75 14.56l-2.842-2.56-10.566 9.126z"/></svg>
                  Android
                </span>
              </div>
            </div>

            {/* Arrow */}
            <div className="absolute top-6 right-6 w-8 h-8 rounded-full bg-white/5 flex items-center justify-center group-hover:bg-white/10 transition-colors border border-white/5">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#8FA5A0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="9 18 15 12 9 6" />
              </svg>
            </div>
          </button>

          {/* Card 3: Manage Account */}
          <Link
            href={`${prefix}/account`}
            className="group relative rounded-2xl p-6 sm:p-8 bg-gradient-to-br from-[#0F2E32]/75 to-[#0A2326]/75 border border-[#2F6B62]/20 shadow-xl hover:shadow-2xl transition-all duration-300 hover:-translate-y-1 flex flex-col justify-between backdrop-blur-md"
          >
            <div>
              {/* Icon — gear/settings */}
              <div className="w-14 h-14 rounded-xl bg-white/5 flex items-center justify-center mb-5 group-hover:bg-white/10 transition-colors border border-white/10">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#F2F0EA" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="3" />
                  <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" />
                </svg>
              </div>

              <h2 className="font-serif text-xl font-bold text-[#F2F0EA] mb-2">
                {locale === "en" ? "Manage Account" : "Zarządzaj kontem"}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] leading-relaxed mb-6">
                {locale === "en"
                  ? "Update your profile, organization details, and subscription."
                  : "Zaktualizuj profil, dane organizacji i subskrypcję."}
              </p>
            </div>

            <div>
              {/* Quick links */}
              <div className="flex flex-wrap gap-2">
                <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10">
                  {locale === "en" ? "Profile" : "Profil"}
                </span>
                <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10">
                  {locale === "en" ? "Subscription" : "Subskrypcja"}
                </span>
                <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10">
                  {locale === "en" ? "Invoices" : "Faktury"}
                </span>
              </div>
            </div>

            {/* Arrow */}
            <div className="absolute top-6 right-6 w-8 h-8 rounded-full bg-white/5 flex items-center justify-center group-hover:bg-white/10 transition-colors border border-white/5">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#8FA5A0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="9 18 15 12 9 6" />
              </svg>
            </div>
          </Link>
        </div>

        {/* --- Not logged in state --- */}
        {!fbUser && (
          <div className="mt-10 text-center p-6 rounded-xl bg-[#0F2E32]/75 border border-[#2F6B62]/20 backdrop-blur-md">
            <p className="font-sans text-sm text-[#8FA5A0] mb-3">
              {locale === "en"
                ? "Sign in to access your dashboard."
                : "Zaloguj się, aby uzyskać dostęp do panelu."}
            </p>
            <Link
              href={`${prefix}/login`}
              className="inline-flex px-5 py-2.5 rounded-xl bg-[#F5A623] text-[#1B2522] font-sans font-bold text-sm uppercase tracking-wider hover:bg-[#E09500] transition-colors"
            >
              {locale === "en" ? "Sign in" : "Zaloguj się"}
            </Link>
          </div>
        )}

        {/* --- Premium Upgrade CTA Section --- */}
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
          className="relative mt-16 rounded-3xl overflow-hidden"
        >
          {/* Gradient mesh background */}
          <div className="absolute inset-0 bg-gradient-to-br from-[#0C3A40] via-[#0F2E32] to-[#1A2E1E]" />
          <div className="absolute top-0 right-0 w-[500px] h-[500px] bg-[radial-gradient(ellipse_at_top_right,_rgba(252,174,47,0.12)_0%,_transparent_60%)] pointer-events-none" />
          <div className="absolute bottom-0 left-0 w-[400px] h-[400px] bg-[radial-gradient(ellipse_at_bottom_left,_rgba(0,77,84,0.4)_0%,_transparent_60%)] pointer-events-none" />
          {/* Animated floating orbs */}
          <div className="absolute top-6 right-12 w-2 h-2 rounded-full bg-[#FCAE2F]/30 animate-float" />
          <div className="absolute top-16 right-32 w-1.5 h-1.5 rounded-full bg-[#FCAE2F]/20 animate-float-delayed" />
          <div className="absolute bottom-12 left-20 w-1.5 h-1.5 rounded-full bg-[#FCAE2F]/25 animate-float" />
          {/* Border overlay */}
          <div className="absolute inset-0 rounded-3xl border border-[#FCAE2F]/15 pointer-events-none" />

          <div className="relative px-6 sm:px-10 py-10 sm:py-14">
            {/* Top tagline */}
            <div className="flex items-center gap-2 mb-4">
              <div className="w-1.5 h-1.5 rounded-full bg-[#FCAE2F] animate-pulse" />
              <span className="font-mono text-[10px] uppercase tracking-[0.25em] text-[#FCAE2F]/80">
                {locale === "en" ? "Unlock full potential" : "Odblokuj pełny potencjał"}
              </span>
            </div>

            <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] leading-tight mb-3">
              {locale === "en"
                ? "Your sessions deserve more."
                : "Twoje sesje zasługują na więcej."}
            </h2>
            <p className="font-sans text-sm sm:text-base text-[#8FA5A0] max-w-xl leading-relaxed mb-8">
              {locale === "en"
                ? "Full reports after every session. Process continuity across meetings. Space in your head for what matters."
                : "Pełne raporty po każdej sesji. Ciągłość procesu między spotkaniami. Przestrzeń mentalna na to, co najważniejsze."}
            </p>

            {/* Value propositions */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-10">
              {/* Benefit 1 */}
              <div className="flex items-start gap-3 p-4 rounded-xl bg-white/[0.03] border border-white/[0.06] backdrop-blur-sm">
                <div className="flex-shrink-0 w-9 h-9 rounded-lg bg-[#FCAE2F]/10 flex items-center justify-center border border-[#FCAE2F]/15">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#FCAE2F" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z" />
                    <polyline points="14 2 14 8 20 8" />
                    <line x1="16" y1="13" x2="8" y2="13" />
                    <line x1="16" y1="17" x2="8" y2="17" />
                    <line x1="10" y1="9" x2="8" y2="9" />
                  </svg>
                </div>
                <div>
                  <span className="block font-sans text-xs font-bold text-[#F2F0EA] mb-0.5">
                    {locale === "en" ? "Unlimited Sessions" : "Bez limitów sesji"}
                  </span>
                  <span className="block font-sans text-[11px] text-[#8FA5A0] leading-relaxed">
                    {locale === "en"
                      ? "Every client gets a full report. Every time."
                      : "Każdy klient dostaje pełny raport. Za każdym razem."}
                  </span>
                </div>
              </div>

              {/* Benefit 2 */}
              <div className="flex items-start gap-3 p-4 rounded-xl bg-white/[0.03] border border-white/[0.06] backdrop-blur-sm">
                <div className="flex-shrink-0 w-9 h-9 rounded-lg bg-[#FCAE2F]/10 flex items-center justify-center border border-[#FCAE2F]/15">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#FCAE2F" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
                  </svg>
                </div>
                <div>
                  <span className="block font-sans text-xs font-bold text-[#F2F0EA] mb-0.5">
                    {locale === "en" ? "Process Continuity" : "Ciągłość procesu"}
                  </span>
                  <span className="block font-sans text-[11px] text-[#8FA5A0] leading-relaxed">
                    {locale === "en"
                      ? "See how each client's process unfolds over time."
                      : "Widzisz, jak proces z klientem rozwija się w czasie."}
                  </span>
                </div>
              </div>

              {/* Benefit 3 */}
              <div className="flex items-start gap-3 p-4 rounded-xl bg-white/[0.03] border border-white/[0.06] backdrop-blur-sm">
                <div className="flex-shrink-0 w-9 h-9 rounded-lg bg-[#FCAE2F]/10 flex items-center justify-center border border-[#FCAE2F]/15">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#FCAE2F" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                  </svg>
                </div>
                <div>
                  <span className="block font-sans text-xs font-bold text-[#F2F0EA] mb-0.5">
                    {locale === "en" ? "Priority Support" : "Priorytetowe wsparcie"}
                  </span>
                  <span className="block font-sans text-[11px] text-[#8FA5A0] leading-relaxed">
                    {locale === "en"
                      ? "Direct access to our clinical team."
                      : "Bezpośredni kontakt z naszym zespołem."}
                  </span>
                </div>
              </div>
            </div>

            {/* Large CTA Button */}
            <div className="flex flex-col sm:flex-row items-center gap-4">
              <Link
                href={`${prefix}/upgrade`}
                className="group/cta relative inline-flex items-center justify-center gap-3 px-10 py-5 rounded-2xl bg-gradient-to-r from-[#FCAE2F] to-[#E09500] text-[#1B2522] font-sans font-extrabold text-base sm:text-lg uppercase tracking-[0.12em] shadow-[0_4px_24px_rgba(252,174,47,0.35)] hover:shadow-[0_6px_32px_rgba(252,174,47,0.5)] transition-all duration-300 hover:-translate-y-0.5 w-full sm:w-auto overflow-hidden"
              >
                {/* Shimmer effect overlay */}
                <span className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover/cta:translate-x-full transition-transform duration-700 ease-in-out" />
                <svg className="relative w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
                </svg>
                <span className="relative">
                  {locale === "en" ? "Upgrade your plan" : "Rozszerz plan"}
                </span>
                <svg className="relative w-4 h-4 group-hover/cta:translate-x-1 transition-transform" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <polyline points="9 18 15 12 9 6" />
                </svg>
              </Link>
              <span className="font-sans text-xs text-[#8FA5A0]">
                {locale === "en"
                  ? "More presence. Less weight between sessions."
                  : "Więcej obecności. Mniej ciężaru między sesjami."}
              </span>
            </div>
          </div>
        </motion.div>

        {/* --- Contact links --- */}
        <div className="mt-8 flex flex-wrap justify-center gap-6">
          <Link
            href={`${prefix}/kontakt`}
            className="font-sans text-xs text-[#8FA5A0] hover:text-[#FCAE2F] transition-colors underline underline-offset-2"
          >
            {locale === "en" ? "Contact us" : "Kontakt"}
          </Link>
          <a
            href="mailto:kontakt@superwizor.ai"
            className="font-sans text-xs text-[#8FA5A0] hover:text-[#FCAE2F] transition-colors underline underline-offset-2"
          >
            kontakt@superwizor.ai
          </a>
        </div>
      </div>
      {/* --- Platform Picker Popup --- */}
      <AnimatePresence>
        {showPlatformPicker && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setShowPlatformPicker(false)}
            className="fixed inset-0 bg-black/80 backdrop-blur-md z-50 flex items-center justify-center p-4"
          >
            <motion.div
              initial={{ opacity: 0, scale: 0.9, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.9, y: 20 }}
              transition={{ type: "spring", stiffness: 300, damping: 25 }}
              onClick={(e) => e.stopPropagation()}
              className="relative bg-gradient-to-b from-[#0F2E32] to-[#0A2326] border border-[#2F6B62]/40 rounded-3xl p-6 sm:p-8 w-full max-w-sm shadow-2xl shadow-black/80 overflow-hidden text-center"
            >
              {/* Gold glow */}
              <div className="absolute -top-24 -right-24 w-48 h-48 bg-[#FCAE2F]/10 rounded-full blur-3xl pointer-events-none" />

              {/* Close */}
              <button
                onClick={() => setShowPlatformPicker(false)}
                className="absolute top-4 right-4 text-[#8FA5A0] hover:text-white transition-colors p-1 z-10"
                aria-label="Zamknij"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>

              {/* Phone icon */}
              <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mx-auto mb-4 border border-white/10">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#F2F0EA" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                  <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
                  <line x1="12" y1="18" x2="12" y2="18.01" />
                </svg>
              </div>

              <h3 className="font-serif text-xl font-bold text-[#F2F0EA] mb-2">
                {t("Jaki masz telefon?", "What phone do you have?")}
              </h3>
              <p className="font-sans text-xs text-[#8FA5A0] leading-relaxed mb-6">
                {t(
                  "Wybierz platformę, a pokażemy Ci jak pobrać aplikację.",
                  "Choose your platform and we'll show you how to download the app."
                )}
              </p>

              <div className="flex flex-col gap-3">
                {/* iOS button */}
                <button
                  type="button"
                  onClick={() => handlePickPlatform("ios")}
                  className="group/pick flex items-center gap-4 w-full px-5 py-4 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/10 hover:border-[#FCAE2F]/40 transition-all cursor-pointer text-left hover:shadow-[0_2px_12px_rgba(252,174,47,0.12)]"
                >
                  <div className="flex-shrink-0 w-11 h-11 rounded-xl bg-white/5 flex items-center justify-center border border-white/10 group-hover/pick:border-[#FCAE2F]/30 transition-colors">
                    <svg className="w-6 h-6 text-[#F2F0EA] group-hover/pick:text-[#FCAE2F] transition-colors" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 4.17c.66-.81 1.11-1.93.99-3.06-.96.04-2.13.64-2.82 1.45-.6.69-1.12 1.84-.98 2.94.1.08.21.12.33.12.87 0 1.98-.54 2.48-1.45z"/>
                    </svg>
                  </div>
                  <div className="flex-1">
                    <span className="block font-sans text-sm font-bold text-[#F2F0EA]">iPhone</span>
                    <span className="block font-sans text-[11px] text-[#8FA5A0]">App Store</span>
                  </div>
                  <svg className="w-4 h-4 text-[#8FA5A0] group-hover/pick:text-[#FCAE2F] group-hover/pick:translate-x-0.5 transition-all" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <polyline points="9 18 15 12 9 6" />
                  </svg>
                </button>

                {/* Android button */}
                <button
                  type="button"
                  onClick={() => handlePickPlatform("android")}
                  className="group/pick flex items-center gap-4 w-full px-5 py-4 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/10 hover:border-[#FCAE2F]/40 transition-all cursor-pointer text-left hover:shadow-[0_2px_12px_rgba(252,174,47,0.12)]"
                >
                  <div className="flex-shrink-0 w-11 h-11 rounded-xl bg-white/5 flex items-center justify-center border border-white/10 group-hover/pick:border-[#FCAE2F]/30 transition-colors">
                    <svg className="w-6 h-6 text-[#F2F0EA] group-hover/pick:text-[#FCAE2F] transition-colors" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M3 20.285V3.716c0-.525.308-.94.757-1.077L14.654 12 3.757 21.362A1.14 1.14 0 013 20.285zM15.908 13.084l2.842 2.463L5.342 2.874l10.566 10.21zM19.98 12.569c.563-.326.563-.858 0-1.184l-2.909-1.686L14.654 12l2.417 2.253 2.909-1.684zM5.342 21.126L18.75 14.56l-2.842-2.56-10.566 9.126z"/>
                    </svg>
                  </div>
                  <div className="flex-1">
                    <span className="block font-sans text-sm font-bold text-[#F2F0EA]">Android</span>
                    <span className="block font-sans text-[11px] text-[#8FA5A0]">Google Play</span>
                  </div>
                  <svg className="w-4 h-4 text-[#8FA5A0] group-hover/pick:text-[#FCAE2F] group-hover/pick:translate-x-0.5 transition-all" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <polyline points="9 18 15 12 9 6" />
                  </svg>
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* --- Premium Pop-up Modals for App Downloads --- */}
      <AnimatePresence>
        {modalPlatform && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={handleCloseModal}
            className="fixed inset-0 bg-black/80 backdrop-blur-md z-50 flex items-center justify-center p-4"
          >
            <motion.div
              initial={{ opacity: 0, scale: 0.9, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.9, y: 20 }}
              transition={{ type: "spring", stiffness: 300, damping: 25 }}
              onClick={(e) => e.stopPropagation()}
              className="relative bg-gradient-to-b from-[#0F2E32] to-[#0A2326] border border-[#2F6B62]/40 rounded-3xl p-6 sm:p-8 w-full max-w-md shadow-2xl shadow-black/80 overflow-hidden text-center"
            >
              {/* Gold glow in top corner */}
              <div className="absolute -top-24 -left-24 w-48 h-48 bg-[#FCAE2F]/10 rounded-full blur-3xl pointer-events-none" />

              {/* Close Button */}
              <button
                onClick={handleCloseModal}
                className="absolute top-4 right-4 text-[#8FA5A0] hover:text-white transition-colors p-1 z-10"
                aria-label="Zamknij"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>

              {modalPlatform === "ios" ? (
                <>
                  <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mx-auto mb-4 border border-white/10">
                    <span className="text-2xl">🍏</span>
                  </div>

                  <h3 className="font-serif text-xl font-bold text-[#F2F0EA] mb-2">
                    {t("Aplikacja iOS", "iOS App")}
                  </h3>

                  <p className="font-sans text-xs text-[#8FA5A0] leading-relaxed mb-4">
                    {t(
                      "Pobierz oficjalną aplikację Superwizor AI bezpośrednio z App Store, aby bezpiecznie nagrywać sesje terapeutyczne na swoim iPhonie.",
                      "Download the official Superwizor AI app directly from the App Store to securely record therapy sessions on your iPhone."
                    )}
                  </p>

                  {/* QR Code */}
                  <div className="p-3 bg-white rounded-2xl w-[150px] h-[150px] flex items-center justify-center mx-auto mb-1.5 shadow-lg border border-white/10">
                    <img
                      src={`https://api.qrserver.com/v1/create-qr-code/?size=126x126&data=${encodeURIComponent(APP_STORE_URL)}`}
                      alt="QR Code iOS"
                      className="w-[126px] h-[126px]"
                    />
                  </div>
                  <p className="text-[10px] text-[#8FA5A0] font-mono mb-6">
                    {t("Zeskanuj telefonem, aby pobrać", "Scan with phone to download")}
                  </p>

                  <div className="flex flex-col gap-2.5">
                    {/* CTA button */}
                    <a
                      href={APP_STORE_URL}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center justify-center gap-3 px-5 py-3.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/15 text-white transition-all text-xs font-semibold cursor-pointer w-full hover:border-[#FCAE2F]/40 hover:shadow-[0_2px_12px_rgba(252,174,47,0.15)] text-center"
                    >
                      <svg className="w-5 h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 4.17c.66-.81 1.11-1.93.99-3.06-.96.04-2.13.64-2.82 1.45-.6.69-1.12 1.84-.98 2.94.1.08.21.12.33.12.87 0 1.98-.54 2.48-1.45z"/>
                      </svg>
                      <div className="flex flex-col text-left">
                        <span className="text-[8px] text-white/50 font-normal uppercase tracking-wider leading-none mb-0.5">
                          Download on the
                        </span>
                        <span className="text-xs font-bold leading-none">
                          App Store
                        </span>
                      </div>
                    </a>
                  </div>
                </>
              ) : (
                <>
                  {/* Android Icon */}
                  <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mx-auto mb-4 border border-white/10">
                    <svg className="w-6 h-6 text-white" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M3 20.285V3.716c0-.525.308-.94.757-1.077L14.654 12 3.757 21.362A1.14 1.14 0 013 20.285zM15.908 13.084l2.842 2.463L5.342 2.874l10.566 10.21zM19.98 12.569c.563-.326.563-.858 0-1.184l-2.909-1.686L14.654 12l2.417 2.253 2.909-1.684zM5.342 21.126L18.75 14.56l-2.842-2.56-10.566 9.126z"/>
                    </svg>
                  </div>

                  <h3 className="font-serif text-xl font-bold text-[#F2F0EA] mb-2">
                    {t("Aplikacja Android (Wkrótce)", "Android App (Coming Soon)")}
                  </h3>

                  <p className="font-sans text-xs text-[#8FA5A0] leading-relaxed mb-6">
                    {t(
                      "Wersja na system Android jest obecnie w fazie testów wewnętrznych. Zostanie opublikowana w Google Play już wkrótce.",
                      "The Android version is currently in internal testing. It will be published on Google Play soon."
                    )}
                  </p>

                  {/* Mocked/Blurred QR Code Container */}
                  <div className="relative p-3 bg-white/5 rounded-2xl w-[150px] h-[150px] flex items-center justify-center mx-auto mb-6 border border-white/10 overflow-hidden">
                    <div className="absolute inset-0 bg-gradient-to-br from-[#FCAE2F]/20 to-transparent opacity-35" />
                    <div className="relative w-[126px] h-[126px] bg-white/[0.03] rounded-xl flex flex-col items-center justify-center gap-2 border border-white/5 backdrop-blur-sm">
                      <span className="text-3xl animate-pulse">⏳</span>
                      <span className="text-[10px] font-mono text-[#FCAE2F] font-bold uppercase tracking-wider">
                        Coming Soon
                      </span>
                    </div>
                  </div>

                  {/* Disabled Badge Button */}
                  <button
                    disabled
                    className="flex items-center justify-center gap-3 px-5 py-3.5 rounded-xl bg-white/5 border border-white/5 text-white/30 text-xs font-semibold cursor-not-allowed w-full"
                  >
                    <svg className="w-5 h-5 text-white/30" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M3 20.285V3.716c0-.525.308-.94.757-1.077L14.654 12 3.757 21.362A1.14 1.14 0 013 20.285zM15.908 13.084l2.842 2.463L5.342 2.874l10.566 10.21zM19.98 12.569c.563-.326.563-.858 0-1.184l-2.909-1.686L14.654 12l2.417 2.253 2.909-1.684zM5.342 21.126L18.75 14.56l-2.842-2.56-10.566 9.126z"/>
                    </svg>
                    <div className="flex flex-col text-left">
                      <span className="text-[8px] text-white/20 font-normal uppercase tracking-wider leading-none mb-0.5">
                        Get it on
                      </span>
                      <span className="text-xs font-bold leading-none">
                        Google Play
                      </span>
                    </div>
                  </button>
                </>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </section>
  );
}
