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
import { identityClient } from "@/lib/connect/clients";
import { UserRole } from "@superwizor/proto-ts/identity/v1/identity_pb";

const APP_URL = "https://superwizor-app.web.app/";
const TESTFLIGHT_URL = "https://testflight.apple.com/join/WkjaAX9r";

export function DashboardHub({ locale }: { locale: string }) {
  const { user: fbUser, status: authStatus } = useAuth();
  const router = useRouter();
  const prefix = locale === "en" ? "/en" : "";
  const [greeting, setGreeting] = useState("");
  const [modalPlatform, setModalPlatform] = useState<"ios" | "android" | null>(null);
  const [checkingOnboarding, setCheckingOnboarding] = useState(true);
  const [showInstructions, setShowInstructions] = useState(false);

  const handleOpenModal = (platform: "ios" | "android") => {
    setShowInstructions(false);
    setModalPlatform(platform);
  };

  const handleCloseModal = () => {
    setModalPlatform(null);
    setShowInstructions(false);
  };

  useEffect(() => {
    if (authStatus === "loading") return;
    if (authStatus === "signed-out" || !fbUser) {
      setCheckingOnboarding(false);
      return;
    }

    let active = true;
    (async () => {
      try {
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
      } catch (err) {
        console.error("[DashboardHub] load profile failed for onboarding check", err);
        if (active) {
          setCheckingOnboarding(false);
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
      setGreeting(
        hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
      );
    } else {
      setGreeting(
        hour < 12 ? "Dzień dobry" : hour < 18 ? "Dzień dobry" : "Dobry wieczór"
      );
    }
  }, [locale]);

  const displayName = fbUser?.displayName || fbUser?.email?.split("@")[0] || "";

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
        <div className="mb-12">
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
              {/* Icon */}
              <div className="w-14 h-14 rounded-xl bg-[#FCAE2F]/10 flex items-center justify-center mb-5 group-hover:bg-[#FCAE2F]/20 transition-colors border border-[#FCAE2F]/15">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#FCAE2F" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z" />
                  <polyline points="17 21 17 13 7 13 7 21" />
                  <polyline points="7 3 7 8 15 8" />
                </svg>
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
          <div
            className="group relative rounded-2xl p-6 sm:p-8 bg-gradient-to-br from-[#0B2A2D]/75 to-[#081E21]/75 border border-[#2F6B62]/25 shadow-xl hover:shadow-2xl hover:shadow-[#2F6B62]/15 transition-all duration-300 hover:-translate-y-1 flex flex-col justify-between backdrop-blur-md"
          >
            <div>
              {/* Icon */}
              <div className="w-14 h-14 rounded-xl bg-[#FCAE2F]/10 flex items-center justify-center mb-5 group-hover:bg-[#FCAE2F]/20 transition-colors border border-[#FCAE2F]/15">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#FCAE2F" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
                  <path d="M19 10v1a7 7 0 0 1-14 0v-1" />
                  <line x1="12" y1="19" x2="12" y2="22" />
                </svg>
              </div>

              <h2 className="font-serif text-xl font-bold text-[#F2F0EA] mb-2">
                {locale === "en" ? "Download on Phone" : "Ściągnij na telefon"}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] leading-relaxed mb-6">
                {locale === "en"
                  ? "Record clinical sessions directly from your mobile device placed on the desk."
                  : "Nagrywaj sesje terapeutyczne bezpośrednio z telefonu leżącego na biurku."}
              </p>
            </div>

            <div>
              {/* Badges / Platform buttons */}
              <div className="flex flex-col gap-2.5">
                {/* iOS App Store / TestFlight Button */}
                <button
                  type="button"
                  onClick={() => handleOpenModal("ios")}
                  className="group/btn flex items-center justify-between w-full px-4 py-3 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-white transition-all text-xs font-semibold cursor-pointer hover:border-[#FCAE2F]/40 shadow-sm"
                >
                  <div className="flex items-center gap-2.5">
                    <svg className="w-4 h-4 text-[#F2F0EA] group-hover/btn:text-[#FCAE2F] transition-colors" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 4.17c.66-.81 1.11-1.93.99-3.06-.96.04-2.13.64-2.82 1.45-.6.69-1.12 1.84-.98 2.94.1.08.21.12.33.12.87 0 1.98-.54 2.48-1.45z"/>
                    </svg>
                    <span>TestFlight (iOS)</span>
                  </div>
                  <span className="text-[10px] text-[#8FA5A0] group-hover/btn:text-[#FCAE2F] transition-colors font-mono font-bold">QR ➔</span>
                </button>
                {/* Google Play / Android Button */}
                <button
                  type="button"
                  onClick={() => handleOpenModal("android")}
                  className="group/btn flex items-center justify-between w-full px-4 py-3 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-white transition-all text-xs font-semibold cursor-pointer hover:border-[#FCAE2F]/40 shadow-sm"
                >
                  <div className="flex items-center gap-2.5">
                    <svg className="w-4 h-4 text-[#F2F0EA] group-hover/btn:text-[#FCAE2F] transition-colors" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M3 20.285V3.716c0-.525.308-.94.757-1.077L14.654 12 3.757 21.362A1.14 1.14 0 013 20.285zM15.908 13.084l2.842 2.463L5.342 2.874l10.566 10.21zM19.98 12.569c.563-.326.563-.858 0-1.184l-2.909-1.686L14.654 12l2.417 2.253 2.909-1.684zM5.342 21.126L18.75 14.56l-2.842-2.56-10.566 9.126z"/>
                    </svg>
                    <span>Google Play (Android)</span>
                  </div>
                  <span className="text-[10px] text-[#8FA5A0] group-hover/btn:text-[#FCAE2F] transition-colors font-mono font-bold">INFO ➔</span>
                </button>
              </div>
            </div>
          </div>

          {/* Card 3: Manage Account */}
          <Link
            href={`${prefix}/account`}
            className="group relative rounded-2xl p-6 sm:p-8 bg-gradient-to-br from-[#0F2E32]/75 to-[#0A2326]/75 border border-[#2F6B62]/20 shadow-xl hover:shadow-2xl transition-all duration-300 hover:-translate-y-1 flex flex-col justify-between backdrop-blur-md"
          >
            <div>
              {/* Icon */}
              <div className="w-14 h-14 rounded-xl bg-white/5 flex items-center justify-center mb-5 group-hover:bg-white/10 transition-colors border border-white/5">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#8FA5A0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                  <circle cx="12" cy="7" r="4" />
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

        {/* --- Helpful links --- */}
        <div className="mt-10 flex flex-wrap justify-center gap-4">
          <Link
            href={`${prefix}/upgrade`}
            className="font-sans text-xs text-[#8FA5A0] hover:text-[#FCAE2F] transition-colors underline underline-offset-2"
          >
            {locale === "en" ? "Upgrade your plan" : "Rozszerz plan"}
          </Link>
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
                    {t("Aplikacja iOS (TestFlight)", "iOS App (TestFlight)")}
                  </h3>

                  <p className="font-sans text-xs text-[#8FA5A0] leading-relaxed mb-4">
                    {t(
                      "TestFlight to oficjalna platforma firmy Apple do testowania wersji przedprodukcyjnych aplikacji przed ich debiutem w App Store. Pozwala ona bezpiecznie nagrywać sesje terapeutyczne na Twoim iPhonie.",
                      "TestFlight is Apple's official platform for pre-release app testing before they launch in the App Store. It allows you to securely record therapy sessions on your iPhone."
                    )}
                  </p>

                  {/* QR Code */}
                  <div className="p-3 bg-white rounded-2xl w-[150px] h-[150px] flex items-center justify-center mx-auto mb-1.5 shadow-lg border border-white/10">
                    <img
                      src={`https://api.qrserver.com/v1/create-qr-code/?size=126x126&data=${encodeURIComponent(TESTFLIGHT_URL)}`}
                      alt="QR Code iOS"
                      className="w-[126px] h-[126px]"
                    />
                  </div>
                  <p className="text-[10px] text-[#8FA5A0] font-mono mb-6">
                    {t("Zeskanuj telefonem, aby dołączyć", "Scan with phone to join")}
                  </p>

                  <div className="flex flex-col gap-2.5">
                    {/* CTA button */}
                    <a
                      href={TESTFLIGHT_URL}
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
                          App Store (TestFlight)
                        </span>
                      </div>
                    </a>

                    <a
                      href="https://apps.apple.com/us/app/testflight/id899247664"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="block text-[11px] text-[#8FA5A0] hover:text-white transition-colors underline mb-2"
                    >
                      {t("Pobierz samą aplikację TestFlight z App Store ➔", "Get TestFlight App standalone from App Store ➔")}
                    </a>

                    {/* Instruction Toggle */}
                    <button
                      type="button"
                      onClick={() => setShowInstructions(!showInstructions)}
                      className="mt-2 font-sans text-xs text-[#FCAE2F] hover:text-[#FCAE2F]/80 transition-colors inline-flex items-center gap-2 cursor-pointer font-bold border border-[#FCAE2F]/30 bg-[#FCAE2F]/5 hover:bg-[#FCAE2F]/10 px-4 py-2.5 rounded-xl w-full justify-center"
                    >
                      <span>{t("Instrukcja jak to zainstalować", "How to install instructions")}</span>
                      <svg
                        className={`w-4 h-4 transform transition-transform duration-200 ${showInstructions ? "rotate-180" : ""}`}
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                        strokeWidth={2.5}
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
                      </svg>
                    </button>

                    {/* Collapsible Steps */}
                    <AnimatePresence>
                      {showInstructions && (
                        <motion.div
                          initial={{ height: 0, opacity: 0 }}
                          animate={{ height: "auto", opacity: 1 }}
                          exit={{ height: 0, opacity: 0 }}
                          transition={{ duration: 0.3 }}
                          className="overflow-hidden mt-2 text-left border-t border-[#1A3A3E] pt-4"
                        >
                          <div className="space-y-4">
                            <div className="flex gap-3">
                              <span className="flex-shrink-0 w-6 h-6 rounded-full bg-[#FCAE2F]/10 border border-[#FCAE2F]/30 text-[#FCAE2F] text-xs font-mono font-bold flex items-center justify-center mt-0.5">
                                1
                              </span>
                              <div className="flex flex-col">
                                <span className="font-sans text-xs font-bold text-[#F2F0EA]">
                                  {t("Zainstaluj TestFlight", "Install TestFlight")}
                                </span>
                                <span className="font-sans text-[11px] text-[#8FA5A0] leading-normal mt-0.5">
                                  {t(
                                    "Pobierz i zainstaluj bezpłatną aplikację TestFlight od Apple ze sklepu App Store na swoim telefonie.",
                                    "Download and install the free Apple TestFlight app from the App Store on your phone."
                                  )}
                                </span>
                              </div>
                            </div>

                            <div className="flex gap-3">
                              <span className="flex-shrink-0 w-6 h-6 rounded-full bg-[#FCAE2F]/10 border border-[#FCAE2F]/30 text-[#FCAE2F] text-xs font-mono font-bold flex items-center justify-center mt-0.5">
                                2
                              </span>
                              <div className="flex flex-col">
                                <span className="font-sans text-xs font-bold text-[#F2F0EA]">
                                  {t("Dołącz do testów i zainstaluj", "Join beta & install")}
                                </span>
                                <span className="font-sans text-[11px] text-[#8FA5A0] leading-normal mt-0.5">
                                  {t(
                                    "Otwórz ten sam link (przycisk powyżej) na iPhonie lub zeskanuj kod QR aparatem, aby pobrać aplikację Superwizor AI.",
                                    "Open the link (button above) on your iPhone or scan the QR code with your camera to download the Superwizor AI app."
                                  )}
                                </span>
                              </div>
                            </div>
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
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
