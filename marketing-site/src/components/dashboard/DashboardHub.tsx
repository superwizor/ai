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

const APP_URL = "https://superwizor-app.web.app/";
const TESTFLIGHT_URL = "https://testflight.apple.com/join/WkjaAX9r";

export function DashboardHub({ locale }: { locale: string }) {
  const { user: fbUser } = useAuth();
  const prefix = locale === "en" ? "/en" : "";
  const [greeting, setGreeting] = useState("");

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

  return (
    <section className="relative overflow-hidden bg-gradient-to-b from-[#0A2326] to-[#0D1B1E] pt-28 pb-20 sm:pt-36 sm:pb-28 min-h-[80vh]">
      {/* Decorative ambient glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[800px] bg-[radial-gradient(ellipse_at_center,_rgba(245,166,35,0.06)_0%,_transparent_70%)] pointer-events-none" />

      <div className="relative mx-auto max-w-3xl px-5">
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

        {/* --- Two Hub Cards --- */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
          {/* Card 1: Open App */}
          <a
            href={APP_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="group relative rounded-2xl p-6 sm:p-8 bg-gradient-to-br from-[#004D54] to-[#003A40] border border-[#2F6B62]/30 shadow-xl hover:shadow-2xl hover:shadow-[#004D54]/30 transition-all duration-300 hover:-translate-y-1"
          >
            {/* Icon */}
            <div className="w-14 h-14 rounded-xl bg-[#F5A623]/10 flex items-center justify-center mb-5 group-hover:bg-[#F5A623]/20 transition-colors">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z" />
                <polyline points="17 21 17 13 7 13 7 21" />
                <polyline points="7 3 7 8 15 8" />
              </svg>
            </div>

            <h2 className="font-serif text-xl font-bold text-[#F2F0EA] mb-2">
              {locale === "en" ? "Open the App" : "Otwórz aplikację"}
            </h2>
            <p className="font-sans text-sm text-[#8FA5A0] leading-relaxed mb-4">
              {locale === "en"
                ? "Start a session, review reports, manage patient files."
                : "Rozpocznij sesję, przeglądaj raporty, zarządzaj kartotekami."}
            </p>

            {/* App links */}
            <div className="flex flex-wrap gap-2">
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10">
                🌐 Web App
              </span>
              <span
                className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10 cursor-pointer hover:bg-white/10 transition-colors"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  window.open(TESTFLIGHT_URL, "_blank");
                }}
              >
                 TestFlight (iOS)
              </span>
            </div>

            {/* Arrow */}
            <div className="absolute top-6 right-6 w-8 h-8 rounded-full bg-[#F5A623]/10 flex items-center justify-center group-hover:bg-[#F5A623]/20 transition-colors">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="7" y1="17" x2="17" y2="7" />
                <polyline points="7 7 17 7 17 17" />
              </svg>
            </div>
          </a>

          {/* Card 2: Manage Account */}
          <Link
            href={`${prefix}/account`}
            className="group relative rounded-2xl p-6 sm:p-8 bg-[#0F2E32] border border-[#2F6B62]/20 shadow-lg hover:shadow-xl transition-all duration-300 hover:-translate-y-1"
          >
            {/* Icon */}
            <div className="w-14 h-14 rounded-xl bg-white/5 flex items-center justify-center mb-5 group-hover:bg-white/10 transition-colors">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#8FA5A0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                <circle cx="12" cy="7" r="4" />
              </svg>
            </div>

            <h2 className="font-serif text-xl font-bold text-[#F2F0EA] mb-2">
              {locale === "en" ? "Manage Account" : "Zarządzaj kontem"}
            </h2>
            <p className="font-sans text-sm text-[#8FA5A0] leading-relaxed mb-4">
              {locale === "en"
                ? "Update your profile, organization details, and subscription."
                : "Zaktualizuj profil, dane organizacji i subskrypcję."}
            </p>

            {/* Quick links */}
            <div className="flex flex-wrap gap-2">
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10">
                {locale === "en" ? "Profile" : "Profil"}
              </span>
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10">
                {locale === "en" ? "Subscription" : "Subskrypcja"}
              </span>
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white/5 text-[11px] font-mono text-[#8FA5A0] border border-white/10">
                {locale === "en" ? "Organization" : "Organizacja"}
              </span>
            </div>

            {/* Arrow */}
            <div className="absolute top-6 right-6 w-8 h-8 rounded-full bg-white/5 flex items-center justify-center group-hover:bg-white/10 transition-colors">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#8FA5A0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="9 18 15 12 9 6" />
              </svg>
            </div>
          </Link>
        </div>

        {/* --- Not logged in state --- */}
        {!fbUser && (
          <div className="mt-10 text-center p-6 rounded-xl bg-[#0F2E32] border border-[#2F6B62]/20">
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
            className="font-sans text-xs text-[#8FA5A0] hover:text-[#F5A623] transition-colors underline underline-offset-2"
          >
            {locale === "en" ? "Upgrade your plan" : "Rozszerz plan"}
          </Link>
          <Link
            href={`${prefix}/kontakt`}
            className="font-sans text-xs text-[#8FA5A0] hover:text-[#F5A623] transition-colors underline underline-offset-2"
          >
            {locale === "en" ? "Contact us" : "Kontakt"}
          </Link>
          <a
            href="mailto:kontakt@superwizor.ai"
            className="font-sans text-xs text-[#8FA5A0] hover:text-[#F5A623] transition-colors underline underline-offset-2"
          >
            kontakt@superwizor.ai
          </a>
        </div>
      </div>
    </section>
  );
}
