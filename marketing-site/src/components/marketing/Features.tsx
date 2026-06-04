"use client";

import { useState } from "react";
import { useTranslations, useLocale } from "next-intl";

type FeatureKey = "report" | "transcript" | "continuity" | "modality";

const FEATURE_ICONS: Record<FeatureKey, React.ReactNode> = {
  report: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="16" y1="13" x2="8" y2="13" />
      <line x1="16" y1="17" x2="8" y2="17" />
      <polyline points="10 9 9 9 8 9" />
    </svg>
  ),
  transcript: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
      <path d="M8 10h.01M12 10h.01M16 10h.01" />
    </svg>
  ),
  continuity: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="16" y1="13" x2="8" y2="13" />
      <line x1="16" y1="17" x2="8" y2="17" />
      <polyline points="10 9 9 9 8 9" />
    </svg>
  ),
  modality: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
      <circle cx="12" cy="12" r="3.5" />
      <circle cx="6" cy="6" r="2.5" />
      <circle cx="18" cy="6" r="2.5" />
      <circle cx="12" cy="19" r="2.5" />
      <line x1="7.7" y1="7.7" x2="10.2" y2="10.2" />
      <line x1="16.3" y1="7.7" x2="13.8" y2="10.2" />
      <line x1="12" y1="15.5" x2="12" y2="16.5" />
    </svg>
  ),
};

interface ModalityItem {
  id: string;
  label: string;
  labelEn: string;
  icon: React.ReactNode;
}

const MODALITIES_LIST: ModalityItem[] = [
  {
    id: "UNIV",
    label: "Uniwersalny / Integracyjny",
    labelEn: "Universal / Integrative",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" className="w-4.5 h-4.5">
        <circle cx="12" cy="12" r="3.5" />
        <circle cx="6" cy="6" r="2.5" />
        <circle cx="18" cy="6" r="2.5" />
        <circle cx="12" cy="19" r="2.5" />
        <line x1="7.7" y1="7.7" x2="10.2" y2="10.2" />
        <line x1="16.3" y1="7.7" x2="13.8" y2="10.2" />
        <line x1="12" y1="15.5" x2="12" y2="16.5" />
      </svg>
    )
  },
  {
    id: "CBT",
    label: "Poznawczo-Behawioralny (CBT)",
    labelEn: "Cognitive-Behavioral (CBT)",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4.5 h-4.5">
        <path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .5 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5" />
        <path d="M9 18h6" />
        <path d="M10 22h4" />
        <circle cx="12" cy="9" r="2" />
        <path d="M12 6V7M12 11v1M9 9h1M14 9h1" />
      </svg>
    )
  },
  {
    id: "PSYCHO",
    label: "Psychodynamiczny",
    labelEn: "Psychodynamic",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4.5 h-4.5">
        <path d="M12 6a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" />
        <path d="M12 9c-2.68 0-4.8 1.39-5.74 3.5a3 3 0 0 0 2.54 4.5h6.4a3 3 0 0 0 2.54-4.5C16.8 10.39 14.68 9 12 9Z" />
        <path d="M5 21a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2" />
      </svg>
    )
  },
  {
    id: "GESTALT",
    label: "Gestalt",
    labelEn: "Gestalt",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4.5 h-4.5">
        <path d="M3 7V5a2 2 0 0 1 2-2h2" />
        <path d="M17 3h2a2 2 0 0 1 2 2v2" />
        <path d="M21 17v2a2 2 0 0 1-2 2h-2" />
        <path d="M7 21H5a2 2 0 0 1-2-2v-2" />
        <circle cx="12" cy="12" r="3" />
      </svg>
    )
  },
  {
    id: "PPT",
    label: "Pozytywny (PPT)",
    labelEn: "Positive (PPT)",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4.5 h-4.5">
        <circle cx="12" cy="12" r="5" />
        <line x1="12" y1="1" x2="12" y2="3" />
        <line x1="12" y1="21" x2="12" y2="23" />
        <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
        <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
        <line x1="1" y1="12" x2="3" y2="12" />
        <line x1="21" y1="12" x2="23" y2="12" />
        <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
        <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
      </svg>
    )
  },
  {
    id: "ST",
    label: "Terapia Schematów (ST)",
    labelEn: "Schema Therapy (ST)",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4.5 h-4.5">
        <rect x="3" y="3" width="7" height="7" />
        <rect x="14" y="3" width="7" height="7" />
        <rect x="14" y="14" width="7" height="7" />
        <rect x="3" y="14" width="7" height="7" />
      </svg>
    )
  },
  {
    id: "SYS",
    label: "Systemowa (dla par i rodzin)",
    labelEn: "Systemic (for couples & families)",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4.5 h-4.5">
        <circle cx="12" cy="6" r="2" />
        <path d="M12 9c-2.2 0-4 1.8-4 4v2h8v-2c0-2.2-1.8-4-4-4Z" />
        <circle cx="7" cy="8" r="1.5" />
        <path d="M7 11c-1.5 0-2.5 1-2.5 2.5v1h5v-1c0-1.5-1-2.5-2.5-2.5Z" />
        <circle cx="17" cy="8" r="1.5" />
        <path d="M17 11c-1.5 0-2.5 1-2.5 2.5v1h5v-1c0-1.5-1-2.5-2.5-2.5Z" />
      </svg>
    )
  },
  {
    id: "EFT",
    label: "Skoncentrowana na Emocjach (EFT)",
    labelEn: "Emotion-Focused (EFT)",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4.5 h-4.5">
        <path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z" />
      </svg>
    )
  },
  {
    id: "COACH",
    label: "Coaching (ICF/GROW)",
    labelEn: "Coaching (ICF/GROW)",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-4.5 h-4.5">
        <polyline points="23 6 13.5 15.5 8.5 10.5 1 18" />
        <polyline points="17 6 23 6 23 12" />
      </svg>
    )
  }
];

const Quote = ({ children }: { children: React.ReactNode }) => (
  <blockquote className="border-l-2 border-[#5bf4bc]/45 bg-[#5bf4bc]/5 pl-2.5 py-1 my-1.5 text-[10.5px] text-mist/95 italic rounded-r">
    {children}
  </blockquote>
);

export function Features() {
  const t = useTranslations("b.features");
  const tItem = useTranslations("b.features.items");
  const locale = useLocale();
  const isPl = locale === "pl";

  const [activeTab, setActiveTab] = useState<FeatureKey>("report");
  const [reportSubTab, setReportSubTab] = useState<string>("all");
  const [selectedModality, setSelectedModality] = useState<string>("UNIV");
  const [transcriptFilter, setTranscriptFilter] = useState<"all" | "therapist" | "patient">("all");

  const reportSubTabs = [
    { id: "all", label: "Cały raport", labelEn: "Full report" },
    { id: "summary", label: "Podsumowanie sesji", labelEn: "Session summary" },
    { id: "observations", label: "Wnikliwe obserwacje", labelEn: "Insightful observations" },
    { id: "plan", label: "Plan działania klienta", labelEn: "Client action plan" },
    { id: "proposals", label: "Propozycje interwencji", labelEn: "Intervention proposals" },
    { id: "threads", label: "Wątki do pogłębienia", labelEn: "Threads to deepen" },
    { id: "supervision", label: "Wskazówki superwizyjne", labelEn: "Supervisory tips" },
    { id: "diagnosis", label: "Wstępne hipotezy diagnostyczne", labelEn: "Preliminary diagnostic hypotheses" },
  ];

  return (
    <section className="relative w-full bg-[#FBFAF7] text-[#1B2522] py-24 sm:py-32 overflow-hidden border-y border-[#E2DED5]/60">
      {/* Background Grid Pattern */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,rgba(0,0,0,0.015)_1px,transparent_1px),linear-gradient(to_bottom,rgba(0,0,0,0.015)_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_50%,#000_70%,transparent_100%)] pointer-events-none" />

      {/* Decorative side glows */}
      <div className="absolute top-1/2 left-0 -translate-y-1/2 w-[350px] h-[350px] bg-[#5bf4bc]/[0.03] rounded-full blur-[100px] pointer-events-none" />
      <div className="absolute top-1/2 right-0 -translate-y-1/2 w-[350px] h-[350px] bg-ember/[0.03] rounded-full blur-[100px] pointer-events-none" />

      <div className="relative mx-auto w-full max-w-[1080px] px-6">
        
        {/* Header */}
        <div className="mb-16 text-center lg:text-left max-w-2xl">
          <p className="font-mono text-[10px] sm:text-xs uppercase text-[#004D54]/50 tracking-[3px] font-bold mb-3">
            {t("overline")}
          </p>
          <h2 className="font-display text-[#004D54] text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight leading-[1.12]">
            {t("heading")}
          </h2>
          <p className="font-serif text-[#4E5A55] text-base sm:text-lg mt-4 max-w-xl">
            {t("body")}
          </p>
        </div>

        {/* Bento Interactive Showroom */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
          
          {/* Left Side: Interactive Selector */}
          <div className="lg:col-span-5 flex flex-col justify-start">
            
            {/* Scrollable container on mobile, stacked list on desktop */}
            <div className="flex lg:flex-col gap-3 overflow-x-auto lg:overflow-x-visible pb-4 lg:pb-0 scrollbar-none snap-x snap-mandatory">
              
              {/* Tab 1: Report */}
              <button
                onClick={() => setActiveTab("report")}
                className={`snap-center min-w-[75vw] sm:min-w-[290px] lg:min-w-0 flex-shrink-0 text-left rounded-[20px] p-5 sm:p-6 transition-all duration-300 cursor-pointer border ${
                  activeTab === "report"
                    ? "bg-gradient-to-br from-[#004D54] to-[#002E32] text-white border-transparent shadow-[0_12px_32px_-12px_rgba(0,77,84,0.35)]"
                    : "bg-white border border-[#E2DED5]/80 hover:bg-[#EDEAE3]/50 text-[#1B2522]"
                }`}
              >
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-4 border transition-colors duration-300 ${
                  activeTab === "report"
                    ? "bg-white/10 border-white/20 text-[#5bf4bc]"
                    : "bg-[#004D54]/[0.06] border-[#004D54]/[0.1] text-[#004D54]"
                }`}>
                  {FEATURE_ICONS.report}
                </div>
                <h3 className={`font-display text-base sm:text-lg font-bold tracking-tight mb-1.5 flex items-center justify-between transition-colors ${
                  activeTab === "report" ? "text-white" : "text-[#1B2522]"
                }`}>
                  <span>{tItem("report.title")}</span>
                  {activeTab === "report" && <span className="text-[#5bf4bc] text-sm">✦</span>}
                </h3>
                <p className={`font-serif text-xs sm:text-[13px] leading-relaxed transition-colors ${
                  activeTab === "report" ? "text-frost/80" : "text-[#4E5A55]"
                }`}>
                  {tItem("report.body")}
                </p>
              </button>

              {/* Tab 2: Transcript */}
              <button
                onClick={() => setActiveTab("transcript")}
                className={`snap-center min-w-[75vw] sm:min-w-[290px] lg:min-w-0 flex-shrink-0 text-left rounded-[20px] p-5 sm:p-6 transition-all duration-300 cursor-pointer border ${
                  activeTab === "transcript"
                    ? "bg-gradient-to-br from-[#004D54] to-[#002E32] text-white border-transparent shadow-[0_12px_32px_-12px_rgba(0,77,84,0.35)]"
                    : "bg-white border border-[#E2DED5]/80 hover:bg-[#EDEAE3]/50 text-[#1B2522]"
                }`}
              >
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-4 border transition-colors duration-300 ${
                  activeTab === "transcript"
                    ? "bg-white/10 border-white/20 text-[#5bf4bc]"
                    : "bg-[#004D54]/[0.06] border-[#004D54]/[0.1] text-[#004D54]"
                }`}>
                  {FEATURE_ICONS.transcript}
                </div>
                <h3 className={`font-display text-base sm:text-lg font-bold tracking-tight mb-1.5 flex items-center justify-between transition-colors ${
                  activeTab === "transcript" ? "text-white" : "text-[#1B2522]"
                }`}>
                  <span>{tItem("transcript.title")}</span>
                  {activeTab === "transcript" && <span className="text-[#5bf4bc] text-sm">✦</span>}
                </h3>
                <p className={`font-serif text-xs sm:text-[13px] leading-relaxed transition-colors ${
                  activeTab === "transcript" ? "text-frost/80" : "text-[#4E5A55]"
                }`}>
                  {tItem("transcript.body")}
                </p>
              </button>

              {/* Tab 3: Continuity */}
              <button
                onClick={() => setActiveTab("continuity")}
                className={`snap-center min-w-[75vw] sm:min-w-[290px] lg:min-w-0 flex-shrink-0 text-left rounded-[20px] p-5 sm:p-6 transition-all duration-300 cursor-pointer border ${
                  activeTab === "continuity"
                    ? "bg-gradient-to-br from-[#004D54] to-[#002E32] text-white border-transparent shadow-[0_12px_32px_-12px_rgba(0,77,84,0.35)]"
                    : "bg-white border border-[#E2DED5]/80 hover:bg-[#EDEAE3]/50 text-[#1B2522]"
                }`}
              >
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-4 border transition-colors duration-300 ${
                  activeTab === "continuity"
                    ? "bg-white/10 border-white/20 text-[#5bf4bc]"
                    : "bg-[#004D54]/[0.06] border-[#004D54]/[0.1] text-[#004D54]"
                }`}>
                  {FEATURE_ICONS.continuity}
                </div>
                <h3 className={`font-display text-base sm:text-lg font-bold tracking-tight mb-1.5 flex items-center justify-between transition-colors ${
                  activeTab === "continuity" ? "text-white" : "text-[#1B2522]"
                }`}>
                  <span>{isPl ? "Dokumentacja i historia" : "Documentation & history"}</span>
                  {activeTab === "continuity" && <span className="text-[#5bf4bc] text-sm">✦</span>}
                </h3>
                <p className={`font-serif text-xs sm:text-[13px] leading-relaxed transition-colors ${
                  activeTab === "continuity" ? "text-frost/80" : "text-[#4E5A55]"
                }`}>
                  {isPl 
                    ? "Zapis wszystkich spotkań pacjenta na przejrzystej osi czasu wraz z oznaczeniem nowych raportów."
                    : "Record of all patient meetings on a clear timeline along with indicators for new reports."}
                </p>
              </button>

              {/* Tab 4: Modality */}
              <button
                onClick={() => setActiveTab("modality")}
                className={`snap-center min-w-[75vw] sm:min-w-[290px] lg:min-w-0 flex-shrink-0 text-left rounded-[20px] p-5 sm:p-6 transition-all duration-300 cursor-pointer border ${
                  activeTab === "modality"
                    ? "bg-gradient-to-br from-[#004D54] to-[#002E32] text-white border-transparent shadow-[0_12px_32px_-12px_rgba(0,77,84,0.35)]"
                    : "bg-white border border-[#E2DED5]/80 hover:bg-[#EDEAE3]/50 text-[#1B2522]"
                }`}
              >
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-4 border transition-colors duration-300 ${
                  activeTab === "modality"
                    ? "bg-white/10 border-white/20 text-[#5bf4bc]"
                    : "bg-[#004D54]/[0.06] border-[#004D54]/[0.1] text-[#004D54]"
                }`}>
                  {FEATURE_ICONS.modality}
                </div>
                <h3 className={`font-display text-base sm:text-lg font-bold tracking-tight mb-1.5 flex items-center justify-between transition-colors ${
                  activeTab === "modality" ? "text-white" : "text-[#1B2522]"
                }`}>
                  <span>{tItem("modality.title")}</span>
                  {activeTab === "modality" && <span className="text-[#5bf4bc] text-sm">✦</span>}
                </h3>
                <p className={`font-serif text-xs sm:text-[13px] leading-relaxed transition-colors ${
                  activeTab === "modality" ? "text-frost/80" : "text-[#4E5A55]"
                }`}>
                  {tItem("modality.body")}
                </p>
              </button>

            </div>

            {/* Pagination dots for mobile swipe indicator */}
            <div className="flex justify-center gap-2 mt-4 mb-2 lg:hidden">
              {(["report", "transcript", "continuity", "modality"] as const).map((key) => (
                <button
                  key={key}
                  onClick={() => setActiveTab(key)}
                  className={`h-2 rounded-full transition-all duration-300 ${
                    activeTab === key ? "w-6 bg-[#004D54]" : "w-2 bg-[#004D54]/20"
                  }`}
                  aria-label={`Go to tab ${key}`}
                />
              ))}
            </div>

          </div>

          {/* Right Side: High-Fidelity App Demo Mockup (1:1 Replica, High Contrast) */}
          <div className="lg:col-span-7 flex flex-col justify-center relative">
            
            {/* White Backing Glow (outside the overflow-hidden frame to let it expand onto the dark background) */}
            <div className="absolute -inset-10 bg-[radial-gradient(circle_at_center,rgba(0,77,84,0.06),transparent_65%)] blur-[60px] pointer-events-none animate-pulse z-0" />
            
            {/* Live demo frame */}
            <div className="relative w-full rounded-[24px] p-[1.5px] bg-[#E2DED5]/80 overflow-hidden shadow-[0_30px_60px_-15px_rgba(27,37,34,0.18)] border border-[#E2DED5]/45 z-10">
              
              {/* Phone/Tablet Screen Interface */}
              <div className="relative w-full rounded-[22.5px] overflow-hidden bg-nocturne pt-10 pb-5 px-4 sm:px-5 min-h-[500px] flex flex-col justify-between select-text">
                
                {/* 1:1 Fake Status Bar */}
                <div className="absolute top-1.5 left-0 right-0 px-6 flex justify-between items-center text-[10.5px] text-white font-sans z-20">
                  <span className="font-semibold flex items-center gap-1">
                    {activeTab === "report" ? "21:14" : activeTab === "transcript" ? "21:13" : activeTab === "continuity" ? "18:32" : "18:18"} 
                    <span className="text-[9px] ml-0.5">👤</span>
                  </span>
                  <div className="flex items-center gap-1.5">
                    <div className="flex items-end gap-[1px] h-2">
                      <div className="w-[1.5px] h-[3px] bg-white" />
                      <div className="w-[1.5px] h-[4.5px] bg-white" />
                      <div className="w-[1.5px] h-[6px] bg-white" />
                      <div className="w-[1.5px] h-[7.5px] bg-white" />
                    </div>
                    <svg className="w-2.5 h-2.5 fill-current" viewBox="0 0 24 24">
                      <path d="M12 21l-12-12c4-4 9-6 12-6s8 2 12 6l-12 12z" />
                    </svg>
                    {/* Battery percentage */}
                    <span className="font-semibold">
                      {activeTab === "report" || activeTab === "transcript" ? "35%" : activeTab === "continuity" ? "15%" : "70%"}
                    </span>
                    <div className="w-5 h-2.5 bg-white/20 rounded-[3px] p-[1px] flex items-center">
                      <div className={`h-full rounded-[1px] ${
                        activeTab === "continuity" ? "w-[15%] bg-red-500" : activeTab === "modality" ? "w-[70%] bg-emerald-400" : "w-[35%] bg-yellow-400"
                      }`} />
                    </div>
                  </div>
                </div>

                {/* Main Dynamic View Content */}
                <div className="flex-1 flex flex-col justify-start">
                  
                  {/* ──────────────────────────────────────────────────────────── */}
                  {/* TAB 1: REPORT VIEW (1:1 Screnn_app_raport.PNG) */}
                  {/* ──────────────────────────────────────────────────────────── */}
                  {activeTab === "report" && (
                    <div className="animate-[fadeIn_0.3s_ease-out_both] flex flex-col flex-1">
                      {/* App Bar */}
                      <div className="flex justify-between items-center mb-3">
                        <span className="text-white text-base cursor-pointer">⟨</span>
                        <h3 className="font-sans font-bold text-[15px] text-white tracking-wide">Raport</h3>
                        <div className="flex items-center gap-3 text-[#ffb12c]">
                          <span className="text-sm">👍</span>
                          <span className="text-sm opacity-60">👎</span>
                          <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                            <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                          </svg>
                        </div>
                      </div>

                      {/* Pill Toggle Tab */}
                      <div className="bg-[#071917] rounded-lg p-1 flex items-center mb-4 border border-white/5 select-none">
                        <span 
                          onClick={() => setActiveTab("transcript")}
                          className="flex-1 text-center py-1.5 text-xs text-white/70 font-semibold cursor-pointer transition-colors hover:text-white"
                        >
                          {isPl ? "Transkrypcja" : "Transcript"}
                        </span>
                        <span 
                          onClick={() => setActiveTab("report")}
                          className="flex-1 text-center py-1.5 text-xs bg-[#ffb12c] text-[#0a1e20] font-bold rounded-md cursor-pointer transition-colors"
                        >
                          {isPl ? "Raport" : "Report"}
                        </span>
                      </div>

                      {/* Sub-tabs Row — horizontally scrollable */}
                      <div className="flex gap-2.5 mb-4 overflow-x-auto scrollbar-none pb-1 shrink-0">
                        {reportSubTabs.map((subTab) => (
                          <button
                            key={subTab.id}
                            onClick={() => setReportSubTab(subTab.id)}
                            className={`px-3.5 py-1.5 rounded-full text-xs font-bold whitespace-nowrap transition-colors cursor-pointer shrink-0 border ${
                              reportSubTab === subTab.id
                                ? "border-[#ffb12c]/40 bg-[#133c37] text-[#ffb12c]"
                                : "border-white/10 text-white/50 hover:text-white/70 hover:border-white/20"
                            }`}
                          >
                            {isPl ? subTab.label : subTab.labelEn}
                          </button>
                        ))}
                      </div>

                      {/* Scrollable Report Content */}
                      <div className="space-y-4 max-h-[290px] overflow-y-auto pr-0.5 scrollbar-thin select-text">
                        
                        {/* Session Title Header & Overview */}
                        {(reportSubTab === "all" || reportSubTab === "summary") && (
                          <div className="bg-[#0b2d2f] border-l-4 border-[#ffb12c] rounded-r-xl p-4 shadow-md text-left">
                            <div className="flex items-start gap-2.5 mb-1.5">
                              <span className="text-[#ffb12c] text-sm mt-0.5">✦</span>
                              <h4 className="font-sans font-bold text-white text-[13px] leading-snug">
                                {isPl ? "Pogorszenie samopoczucia, bóle głowy i brak postępu" : "Deterioration of well-being, headaches and lack of progress"}
                              </h4>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              <strong className="text-[#ffb12c]">{isPl ? "PODSUMOWANIE: " : "SUMMARY: "}</strong>
                              {isPl 
                                ? "Pacjent zgłasza pogorszenie samopoczucia, nietypowe bóle głowy i brak chęci do działania, pomimo wcześniejszej poprawy. Odczuwa brak postępu i poczucie „mechanicznego uszkodzenia”, co prowadzi do myśli depresyjnych. Terapeuta dopytuje o objawy i próby radzenia sobie."
                                : "The patient reports a deterioration of well-being, unusual headaches, and a lack of desire to act, despite prior improvement. He feels a lack of progress and a sense of 'mechanical damage', leading to depressive thoughts. The therapist inquires about symptoms and coping attempts."}
                            </p>
                          </div>
                        )}

                        {/* SECTION 1: PODSUMOWANIE SESJI */}
                        {(reportSubTab === "all" || reportSubTab === "summary") && (
                          <div className="bg-[#0f3435]/65 rounded-xl p-4 border border-white/5 text-left">
                            <div className="text-[9px] uppercase tracking-wider text-ember font-mono mb-1.5 font-bold">
                              {isPl ? "Raport Kliniczny • Część I" : "Clinical Report • Part I"}
                            </div>
                            <h4 className="font-serif text-[13.5px] font-bold text-white mb-3 pb-1 border-b border-white/10 flex items-center justify-between">
                              <span>{isPl ? "Podsumowanie sesji" : "Session Summary"}</span>
                            </h4>
                            <div className="space-y-3.5 text-[11.5px] leading-relaxed text-mist font-sans">
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "1. Problem docelowy sesji: " : "1. Session target problem: "}</span>
                                <span>
                                  {isPl 
                                    ? "Klient zgłasza pogarszające się samopoczucie fizyczne i psychiczne, brak energii i motywacji, oraz utrwalone poczucie „mechanicznego uszkodzenia” pomimo podejmowanych prób."
                                    : "The client reports deteriorating physical and mental well-being, lack of energy and motivation, and a persistent sense of 'mechanical damage' despite attempts made."}
                                </span>
                              </div>
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "2. Kluczowy zidentyfikowany model poznawczy (A-B-C):" : "2. Key identified cognitive model (A-B-C):"}</span>
                                <div className="pl-3 mt-1.5 space-y-2 border-l border-[#5bf4bc]/20">
                                  <div>
                                    <span className="text-[#5bf4bc] font-bold">{isPl ? "• Sytuacja: " : "• Situation: "}</span>
                                    {isPl 
                                      ? "Pogarszające się samopoczucie fizyczne (bóle głowy, „zatokowe”) i psychiczne (brak chęci, depresyjność)."
                                      : "Deteriorating physical well-being (headaches, 'sinus') and mental well-being (lack of desire, depressiveness)."}
                                  </div>
                                  <div>
                                    <span className="text-[#5bf4bc] font-bold">{isPl ? "• Myśli automatyczne: " : "• Automatic thoughts: "}</span>
                                    <Quote>
                                      {isPl 
                                        ? "jestem jakoś za, zablokowany właśnie że to jakoś uszkodzenie mam mechaniczne"
                                        : "I am somehow blocked, that I have mechanical damage"}
                                    </Quote>
                                    <Quote>
                                      {isPl 
                                        ? "nie widzę już żadnych specjalnych zmian kurczę"
                                        : "I don't see any special changes anymore"}
                                    </Quote>
                                  </div>
                                  <div>
                                    <span className="text-[#5bf4bc] font-bold">{isPl ? "• Emocje i Zachowanie: " : "• Emotions and Behavior: "}</span>
                                    {isPl 
                                      ? "Poczucie słabości, frustracja, „depresyjnie”; próby spacerów, branie leków, „zmuszanie się” do każdej czynności."
                                      : "Feeling of weakness, frustration, 'depressive'; attempts to walk, taking medication, 'forcing himself' to do every activity."}
                                  </div>
                                </div>
                              </div>
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "3. Zastosowane techniki CBT: " : "3. Applied CBT techniques: "}</span>
                                <span>
                                  {isPl 
                                    ? "Terapeuta próbował identyfikować myśli automatyczne (pytanie o „uszkodzenie mechaniczne”) i stosował wstępne pytania sokratyczne („co by ci pomogło?”). Wspomniano o psychoedukacji (techniki oddechowe, spacery) z poprzedniej sesji."
                                    : "The therapist tried to identify automatic thoughts (asking about 'mechanical damage') and used initial Socratic questions ('what would help you?'). Mentioned psychoeducation (breathing techniques, walks) from the previous session."}
                                </span>
                              </div>
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "4. Ustalony plan działania (zadanie domowe): " : "4. Established action plan (homework): "}</span>
                                <span>
                                  {isPl 
                                    ? "Brak wyraźnie ustalonego, konkretnego zadania domowego na koniec sesji."
                                    : "No clearly established, specific homework at the end of the session."}
                                </span>
                              </div>
                            </div>
                          </div>
                        )}

                        {/* SECTION 2: WNIKLIWE OBSERWACJE */}
                        {(reportSubTab === "all" || reportSubTab === "observations") && (
                          <div className="bg-[#0f3435]/65 rounded-xl p-4 border border-white/5 text-left">
                            <div className="text-[9px] uppercase tracking-wider text-ember font-mono mb-1.5 font-bold">
                              {isPl ? "Raport Kliniczny • Część II" : "Clinical Report • Part II"}
                            </div>
                            <h4 className="font-serif text-[13.5px] font-bold text-white mb-3 pb-1 border-b border-white/10 flex items-center justify-between">
                              <span>{isPl ? "Wnikliwe obserwacje" : "Insightful Observations"}</span>
                            </h4>
                            <div className="space-y-4 text-[11.5px] leading-relaxed text-mist font-sans">
                              
                              <div className="space-y-1.5">
                                <div className="font-bold text-[#ffb12c]">{isPl ? "• Utrwalone przekonanie o „mechanicznym uszkodzeniu” / „dysfunkcji”" : "• Persistent belief in 'mechanical damage' / 'dysfunction'"}</div>
                                <div className="pl-2 border-l border-white/10 space-y-1.5">
                                  <div className="text-white/60 text-[9.5px] uppercase tracking-widest font-mono">{isPl ? "Dowody z sesji:" : "Session evidence:"}</div>
                                  <Quote>{isPl ? "jestem jakoś za, zablokowany właśnie że to jakoś uszkodzenie mam mechaniczne" : "I am somehow blocked, that I have mechanical damage"}</Quote>
                                  <Quote>{isPl ? "to właśnie nie mogę Robię, próbuję, ale to właśnie odbija od tego właśnie wszystkiego" : "I try, but everything bounces off of it"}</Quote>
                                  <Quote>{isPl ? "Wydaje się, że właśnie już wcześniej byłem ten, tylko że jako dziecko to było mniej zauważalne po prostu że wcześniej jakoś dysfunkcję po prostu nie" : "It seems I was like this before, but as a child it was less noticeable"}</Quote>
                                  <div className="mt-2">
                                    <span className="font-semibold text-emerald-400">{isPl ? "Analiza w modelu CBT: " : "CBT Analysis: "}</span>
                                    {isPl 
                                      ? "To przekonanie działa jako zniekształcenie poznawcze (personalizacja/katastrofizacja), przypisując wewnętrzną, niezmienną wadę do jego stanu. Utrudnia to dostrzeżenie możliwości zmiany i wzmacnia poczucie bezradności, prowadząc do braku motywacji i zachowań unikających (np. rezygnacji z prób, bo „i tak się odbija”). Kosztem jest chroniczne poczucie beznadziei i brak zaangażowania w aktywne strategie radzenia sobie."
                                      : "This belief acts as a cognitive distortion (personalization/catastrophizing), attributing an internal, unchangeable flaw to his state. It hinders seeing the possibility of change and reinforces helplessness, leading to lack of motivation and avoidant behaviors. The cost is chronic hopelessness and lack of engagement in active coping."}
                                  </div>
                                </div>
                              </div>

                              <div className="space-y-1.5 pt-2.5 border-t border-white/[0.05]">
                                <div className="font-bold text-[#ffb12c]">{isPl ? "• Wzorzec behawioralny: „Zmuszanie się” bez poczucia sensu" : "• Behavioral pattern: 'Forcing oneself' without a sense of meaning"}</div>
                                <div className="pl-2 border-l border-white/10 space-y-1.5">
                                  <div className="text-white/60 text-[9.5px] uppercase tracking-widest font-mono">{isPl ? "Dowody z sesji:" : "Session evidence:"}</div>
                                  <Quote>{isPl ? "muszę ręcznie kurde każdą czynność po prostu kurczę nad każdą czynnością po prostu muszę muszę ją nie ma tego automatyzmu takiego, tylko muszę jak coś robię to już muszę kurczę ten" : "I have to manually do every single action, there is no automaticity, I have to force it"}</Quote>
                                  <div className="mt-2">
                                    <span className="font-semibold text-emerald-400">{isPl ? "Analiza w modelu CBT: " : "CBT Analysis: "}</span>
                                    {isPl 
                                      ? "To zachowanie, choć pozornie aktywne, jest napędzane przez poczucie obowiązku i braku alternatyw, a nie przez wewnętrzną motywację czy poczucie skuteczności. W kontekście depresji, jest to typowy dla braku aktywacji behawioralnej, gdzie wysiłek jest ogromny, a nagroda minimalna, co wzmacnia negatywne myśli automatyczne o braku postępu i beznadziei. Prowadzi to do dalszego wyczerpania i utrwalenia cyklu depresyjnego."
                                      : "This behavior, though active, is driven by obligation and lack of alternatives, not internal motivation. In depression, this is typical of a lack of behavioral activation, reinforcing negative thoughts about lack of progress. Leads to further exhaustion and cycle reinforcement."}
                                  </div>
                                </div>
                              </div>

                              <div className="space-y-1.5 pt-2.5 border-t border-white/[0.05]">
                                <div className="font-bold text-[#ffb12c]">{isPl ? "• Brak precyzyjnej identyfikacji myśli automatycznych i ich związku z emocjami" : "• Lack of precise identification of automatic thoughts"}</div>
                                <div className="pl-2 border-l border-white/10 space-y-1.5">
                                  <div className="text-[#ffb12c] text-[10px] font-semibold">{isPl ? "Opis i dowody z sesji:" : "Session evidence:"}</div>
                                  <p className="text-[11px] text-white/95">
                                    {isPl 
                                      ? "Klient opisuje ogólne stany („słabo się czuję”, „depresyjnie”) i przekonania („uszkodzenie mechaniczne”), ale terapeuta nie prowadzi go do szczegółowej analizy konkretnych sytuacji, myśli i emocji w modelu A-B-C. Pytanie „co by ci pomogło?” jest zbyt ogólne."
                                      : "Client describes general states ('feeling weak', 'depressive') and beliefs ('mechanical damage') but therapist does not lead to detailed ABC analysis."}
                                  </p>
                                  <div className="mt-2">
                                    <span className="font-semibold text-emerald-400">{isPl ? "Analiza w modelu CBT: " : "CBT Analysis: "}</span>
                                    {isPl 
                                      ? "Brak precyzyjnej identyfikacji myśli automatycznych utrudnia ich restrukturyzację. Bez konkretnych przykładów, klient pozostaje w ogólnym poczuciu beznadziei, a terapeuta nie ma punktu zaczepienia do interwencji poznawczych. To kluczowy element CBT, który wymaga pogłębienia."
                                      : "Lack of precise identification makes cognitive restructuring difficult, leaving the client in generalized hopelessness with no specific point of intervention."}
                                  </div>
                                </div>
                              </div>

                            </div>
                          </div>
                        )}

                        {/* SECTION 3: PLAN DZIAŁANIA KLIENTA */}
                        {(reportSubTab === "all" || reportSubTab === "plan") && (
                          <div className="bg-[#0f3435]/65 rounded-xl p-4 border border-white/5 text-left">
                            <div className="text-[9px] uppercase tracking-wider text-ember font-mono mb-1.5 font-bold">
                              {isPl ? "Raport Kliniczny • Część III" : "Clinical Report • Part III"}
                            </div>
                            <h4 className="font-serif text-[13.5px] font-bold text-white mb-3 pb-1 border-b border-white/10 flex items-center justify-between">
                              <span>{isPl ? "Plan działania klienta" : "Client Action Plan"}</span>
                            </h4>
                            <div className="space-y-4 text-[11.5px] leading-relaxed text-mist font-sans">
                              
                              <div className="bg-[#0b2b29] p-3.5 rounded-lg border border-white/5 space-y-2">
                                <div className="font-bold text-[#ffb12c] text-xs">{isPl ? "• Zadanie: Dziennik Myśli Automatycznych (A-B-C)" : "• Task: Automatic Thoughts Journal (A-B-C)"}</div>
                                <div>
                                  <span className="font-semibold text-emerald-400">{isPl ? "Cel terapeutyczny: " : "Therapeutic goal: "}</span>
                                  {isPl ? "Zwiększenie świadomości związku między sytuacjami, myślami, emocjami i zachowaniami; zebranie danych do restrukturyzacji poznawczej." : "Increase awareness of the relationship between situations, thoughts, emotions, and behaviors."}
                                </div>
                                <div className="space-y-1.5 pl-2.5 border-l border-white/15">
                                  <div className="text-white/80 font-bold">{isPl ? "Szczegółowa instrukcja:" : "Detailed instruction:"}</div>
                                  <div className="text-white/90">{isPl ? "Klient ma zapisywać przez najbliższy tydzień 3-5 razy dziennie, kiedy poczuje się gorzej (np. „słabo,” „bez chęci,” „zablokowany”). Dla każdej sytuacji:" : "Client should record 3-5 times a day when feeling worse (e.g. 'weak', 'unmotivated', 'blocked'). For each situation:"}</div>
                                  <ol className="list-decimal pl-4 space-y-1 text-white/90">
                                    <li>{isPl ? "Sytuacja: Co się wydarzyło? Gdzie byłem? Z kim?" : "Situation: What happened? Where was I? With whom?"}</li>
                                    <li>{isPl ? "Myśli automatyczne: Co pomyślałem w tamtym momencie? (dokładne słowa)" : "Automatic thoughts: What did I think at that moment? (exact words)"}</li>
                                    <li>{isPl ? "Emocje: Jakie emocje poczułem? (np. smutek, lęk) i intensywność (0-100%)" : "Emotions: What emotions did I feel? (e.g., sadness, anxiety) and intensity (0-100%)"}</li>
                                    <li>{isPl ? "Zachowanie: Co zrobiłem?" : "Behavior: What did I do?"}</li>
                                  </ol>
                                </div>
                                <div className="bg-[#071917] p-2.5 rounded border border-white/5 text-[10.5px]">
                                  <span className="font-bold text-[#ffb12c]">{isPl ? "Potencjalne trudności i jak sobie radzić: " : "Potential difficulties & coping: "}</span>
                                  {isPl ? "Poczucie, że „to nic nie da”, trudność w identyfikacji myśli. Wskazówka: „Po prostu spróbuj to zapisać, nawet jeśli wydaje się to bez sensu. To tylko zbieranie danych, nie musisz tego oceniać.”" : "Feeling that 'it won't help', difficulty identifying thoughts. Tip: 'Just try to write it down, even if it feels pointless. It's just collecting data.'"}
                                </div>
                              </div>

                              <div className="bg-[#0b2b29] p-3.5 rounded-lg border border-white/5 space-y-2">
                                <div className="font-bold text-[#ffb12c] text-xs">{isPl ? "• Zadanie: Eksperyment behawioralny: „Małe kroki ku aktywności”" : "• Task: Behavioral Experiment: 'Small steps to activity'"}</div>
                                <div>
                                  <span className="font-semibold text-emerald-400">{isPl ? "Cel terapeutyczny: " : "Therapeutic goal: "}</span>
                                  {isPl ? "Przełamanie poczucia „mechanicznego uszkodzenia” i „zmuszania się” poprzez doświadczenie małego sukcesu i zebranie danych o wpływie aktywności na nastrój." : "Break the sense of 'mechanical damage' and 'forcing oneself' through a small success."}
                                </div>
                                <div className="space-y-1.5 pl-2.5 border-l border-white/15">
                                  <div className="text-white/80 font-bold">{isPl ? "Szczegółowa instrukcja:" : "Detailed instruction:"}</div>
                                  <ul className="list-disc pl-4 space-y-1 text-white/95">
                                    <li><span className="font-semibold text-[#5bf4bc]">{isPl ? "Przekonanie do przetestowania: " : "Belief to test: "}</span>{isPl ? "„Robię, próbuję, ale to właśnie odbija od tego wszystkiego / nic mi nie pomaga.”" : "„I try, but everything bounces off of it / nothing helps me.”"}</li>
                                    <li><span className="font-semibold text-[#5bf4bc]">{isPl ? "Sposób przeprowadzenia: " : "Method: "}</span>{isPl ? "Wybierz jedną, bardzo małą aktywność, którą kiedyś lubiłeś lub która jest neutralna (np. posłuchanie jednej piosenki, 5 minut czytania, krótki spacer wokół bloku). Wykonaj ją raz dziennie przez 3 dni." : "Choose one tiny activity. Perform it once a day for 3 days."}</li>
                                    <li><span className="font-semibold text-[#5bf4bc]">{isPl ? "Przewidywania klienta: " : "Predictions: "}</span>{isPl ? "Co się stanie, gdy to zrobisz? Jak się poczujesz? (np. „będę się zmuszał i nic to nie da”, „poczuję się tak samo źle”). Zapisz stopień wiary w %." : "What will happen? Rate belief in %."}</li>
                                    <li><span className="font-semibold text-[#5bf4bc]">{isPl ? "Co będziemy obserwować: " : "What to observe: "}</span>{isPl ? "Po wykonaniu aktywności, oceń swój nastrój (0-10) i poziom „zablokowania” (0-10). Zapisz, czy było to tak trudne, jak przewidywałeś." : "After, rate mood (0-10) and 'blockedness' (0-10)."}</li>
                                  </ul>
                                </div>
                                <div className="bg-[#071917] p-2.5 rounded border border-white/5 text-[10.5px]">
                                  <span className="font-bold text-[#ffb12c]">{isPl ? "Potencjalne trudności i jak sobie radzić: " : "Potential difficulties & coping: "}</span>
                                  {isPl ? "Opór, poczucie braku sensu. Wskazówka: „Pamiętaj, że to jest eksperyment. Nie chodzi o to, żeby od razu poczuć się świetnie, ale żeby zebrać dane. Nawet jeśli będzie tak, jak przewidujesz, to też jest cenna informacja.”" : "Resistance, pointlessness. Tip: 'Remember this is an experiment. It is not to feel great immediately, but to collect data.'"}
                                </div>
                              </div>

                            </div>
                          </div>
                        )}

                        {/* SECTION 4: PROPOZYCJE INTERWENCJI */}
                        {(reportSubTab === "all" || reportSubTab === "proposals") && (
                          <div className="bg-[#0f3435]/65 rounded-xl p-4 border border-white/5 text-left">
                            <div className="text-[9px] uppercase tracking-wider text-ember font-mono mb-1.5 font-bold">
                              {isPl ? "Raport Kliniczny • Część IV" : "Clinical Report • Part IV"}
                            </div>
                            <h4 className="font-serif text-[13.5px] font-bold text-white mb-3 pb-1 border-b border-white/10 flex items-center justify-between">
                              <span>{isPl ? "Propozycje interwencji" : "Intervention Proposals"}</span>
                            </h4>
                            <div className="space-y-3.5 text-[11.5px] leading-relaxed text-mist font-sans">
                              <div className="font-bold text-[#ffb12c]">{isPl ? "• Nazwa techniki: Restrukturyzacja poznawcza przekonania o „mechanicznym uszkodzeniu”" : "• Technique: Restructuring of the 'mechanical damage' belief"}</div>
                              <div>
                                <span className="font-semibold text-emerald-400">{isPl ? "Cel kliniczny: " : "Clinical goal: "}</span>
                                {isPl 
                                  ? "Podważenie i osłabienie przekonania klienta o jego „mechanicznym uszkodzeniu” i „dysfunkcji,” które wzmacnia jego poczucie beznadziei i bierności."
                                  : "Challenge and weaken the client's belief in 'mechanical damage' and 'dysfunction'."}
                              </div>
                              <div>
                                <span className="font-semibold text-emerald-400">{isPl ? "Podstawy teoretyczne: " : "Theoretical basis: "}</span>
                                {isPl 
                                  ? "Przekonania klienta o jego stanie są prawdopodobnie zniekształceniami poznawczymi (np. katastrofizacja, etykietowanie), które utrzymują cykl depresyjny. Restrukturyzacja ma na celu zastąpienie ich bardziej realistycznymi i adaptacyjnymi myślami."
                                  : "Beliefs are cognitive distortions maintaining the cycle. Restructuring aims to replace them with adaptive thoughts."}
                              </div>
                              <div className="space-y-2">
                                <span className="font-semibold text-emerald-400">{isPl ? "Scenariusz krok po kroku: " : "Step-by-step scenario: "}</span>
                                <ol className="list-decimal pl-4.5 space-y-1.5 text-white/90">
                                  <li>
                                    <span className="font-semibold">{isPl ? "Identyfikacja przekonania: " : "Identify belief: "}</span>
                                    {isPl ? "„Mówi pan, że czuje się pan 'mechanicznie uszkodzony' i że to 'dysfunkcja'. Co dokładnie ma pan na myśli, mówiąc 'mechanicznie uszkodzony'?”" : "„You say you feel 'mechanically damaged'. What exactly do you mean?”"}
                                  </li>
                                  <li>
                                    <span className="font-semibold">{isPl ? "Poszukiwanie dowodów: " : "Look for evidence: "}</span>
                                    {isPl ? "„Jakie są dowody na to, że jest pan 'mechanicznie uszkodzony'? A jakie są dowody przeciwko temu?” (np. „Czy są momenty, kiedy czuje się pan mniej 'uszkodzony'?”)" : "„What evidence supports this? What evidence contradicts it?”"}
                                  </li>
                                  <li>
                                    <span className="font-semibold">{isPl ? "Alternatywne wyjaśnienia: " : "Alternative explanations: "}</span>
                                    {isPl ? "„Gdyby ktoś inny opisał swoje objawy w ten sposób, jakie inne wyjaśnienia mogłyby przyjść panu do głowy, poza 'mechanicznym uszkodzeniem'?” (np. zmęczenie, depresja, stres)" : "„If someone else had these symptoms, what else could explain them?”"}
                                  </li>
                                  <li>
                                    <span className="font-semibold">{isPl ? "Konsekwencje przekonania: " : "Consequences of the belief: "}</span>
                                    {isPl ? "„Jakie są konsekwencje myślenia o sobie w ten sposób? Jak to wpływa na pana samopoczucie i działania?”" : "„How does thinking this way affect your mood and behavior?”"}
                                  </li>
                                  <li>
                                    <span className="font-semibold">{isPl ? "Formułowanie alternatywnej myśli: " : "Formulate alternative thought: "}</span>
                                    {isPl ? "„Gdyby miał pan opisać swój stan w inny sposób, który byłby równie prawdziwy, ale mniej obciążający, jak by to brzmiało?” (np. „Moje ciało i umysł reagują na stres”)" : "„How could you describe this in a way that is just as true but less heavy?”"}
                                  </li>
                                </ol>
                              </div>
                              <div className="bg-[#071917] p-2.5 rounded border border-white/5 text-[10.5px]">
                                <span className="font-bold text-[#ffb12c]">{isPl ? "Na co zwrócić uwagę: " : "What to look out for: "}</span>
                                {isPl 
                                  ? "Klient może być bardzo przywiązany do tego przekonania. Ważne jest, aby podejść do tego z empatią i ciekawością, a nie konfrontacyjnie. Skupić się na zbieraniu danych i konsekwencjach, a nie na „poprawianiu” klienta."
                                  : "The client may be attached to this belief. Approach with empathy and curiosity, focusing on consequences rather than 'correcting' them."}
                              </div>
                            </div>
                          </div>
                        )}

                        {/* SECTION 5: WĄTKI DO POGŁĘBIENIA */}
                        {(reportSubTab === "all" || reportSubTab === "threads") && (
                          <div className="bg-[#0f3435]/65 rounded-xl p-4 border border-white/5 text-left">
                            <div className="text-[9px] uppercase tracking-wider text-ember font-mono mb-1.5 font-bold">
                              {isPl ? "Raport Kliniczny • Część V" : "Clinical Report • Part V"}
                            </div>
                            <h4 className="font-serif text-[13.5px] font-bold text-white mb-3 pb-1 border-b border-white/10 flex items-center justify-between">
                              <span>{isPl ? "Wątki do pogłębienia" : "Threads to Deepen"}</span>
                            </h4>
                            <div className="space-y-3.5 text-[11.5px] leading-relaxed text-mist font-sans">
                              
                              <div>
                                <div className="font-bold text-[#ffb12c] mb-1">{isPl ? "1. Wstępne hipotezy dot. przekonań pośredniczących:" : "1. Hypotheses on intermediate beliefs:"}</div>
                                <ul className="list-disc pl-4 space-y-1.5">
                                  <li>
                                    {isPl 
                                      ? "„Jeśli nie widzę natychmiastowych zmian/postępu, to znaczy, że nic nie działa i jestem beznadziejny/uszkodzony.” Uzasadnienie: „nie widzę już żadnych specjalnych zmian kurczę”, „brak postępu”. Założenie to prowadzi do szybkiej rezygnacji."
                                      : "„If I don't see immediate changes, it means nothing works and I am hopeless.”"}
                                  </li>
                                  <li>
                                    {isPl 
                                      ? "„Muszę wszystko robić perfekcyjnie i z pełnym zaangażowaniem, inaczej to nie ma sensu.” Uzasadnienie: „muszę ręcznie każdą czynność... nie ma tego automatyzmu takiego”. Prowadzi to do wyczerpania."
                                      : "„I must do everything perfectly, otherwise it has no meaning.”"}
                                  </li>
                                </ul>
                              </div>

                              <div className="pt-2.5 border-t border-white/[0.05]">
                                <div className="font-bold text-[#ffb12c] mb-1">{isPl ? "2. Wstępne hipotezy dot. przekonań kluczowych (Core Beliefs):" : "2. Hypotheses on core beliefs:"}</div>
                                <ul className="list-disc pl-4 space-y-1">
                                  <li>{isPl ? "„Jestem wadliwy/niekompetentny” (W oparciu o „uszkodzenie mechaniczne”, „dysfunkcje”)" : "„I am defective/incompetent” (based on 'mechanical damage', 'dysfunctions')"}</li>
                                  <li>{isPl ? "„Jestem bezradny/nie mam wpływu” (W oparciu o „odbija od tego wszystkiego”)" : "„I am helpless” (based on 'everything bounces off')"}</li>
                                </ul>
                              </div>

                              <div className="pt-2.5 border-t border-white/[0.05]">
                                <div className="font-bold text-[#ffb12c] mb-1">{isPl ? "3. Pytania do dalszej eksploracji:" : "3. Questions for further exploration:"}</div>
                                <ul className="list-disc pl-4 space-y-1 text-white/90">
                                  <li>{isPl ? "„Co to dla pana oznacza, że jest pan 'mechanicznie uszkodzony'? Co to mówi o panu jako osobie?” (Technika strzałki w dół)" : "„What does being 'mechanically damaged' mean to you as a person?”"}</li>
                                  <li>{isPl ? "„Gdyby to 'uszkodzenie' zniknęło, co by się zmieniło w pana życiu? Co by pan wtedy robił?”" : "„If this 'damage' disappeared, what would you do in your life?”"}</li>
                                  <li>{isPl ? "„Czy były w pana życiu momenty, kiedy czuł się pan mniej 'zablokowany' lub 'uszkodzony'? Co wtedy było inaczej?”" : "„Were there moments you felt less blocked or damaged?”"}</li>
                                </ul>
                              </div>

                            </div>
                          </div>
                        )}

                        {/* SECTION 6: WSKAZÓWKI SUPERWIZYJNE */}
                        {(reportSubTab === "all" || reportSubTab === "supervision") && (
                          <div className="bg-[#0f3435]/65 rounded-xl p-4 border border-white/5 text-left">
                            <div className="text-[9px] uppercase tracking-wider text-ember font-mono mb-1.5 font-bold">
                              {isPl ? "Raport Kliniczny • Część VI" : "Clinical Report • Part VI"}
                            </div>
                            <h4 className="font-serif text-[13.5px] font-bold text-white mb-3 pb-1 border-b border-white/10 flex items-center justify-between">
                              <span>{isPl ? "Wskazówki superwizyjne" : "Supervisory Tips"}</span>
                            </h4>
                            <div className="space-y-3.5 text-[11.5px] leading-relaxed text-mist font-sans">
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "1. Ocena struktury sesji: " : "1. Evaluation of session structure: "}</span>
                                <span>
                                  {isPl 
                                    ? "Sesja rozpoczęła się otwartym pytaniem, ale szybko przeszła w eksplorację objawów fizycznych i ogólnego samopoczucia. Brak wyraźnego ustalenia agendy na początku sesji oraz podsumowania i zadania domowego na koniec. Terapeuta próbował dopytywać o szczegóły (np. bóle zatokowe), ale nie zawsze kierował rozmowę w stronę poznawczą."
                                    : "Session started open but quickly focused on physical symptoms. Lack of clear agenda at start and homework at end."}
                                </span>
                              </div>
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "2. Analiza kompetencji terapeuty: " : "2. Analysis of therapist competence: "}</span>
                                <span>
                                  {isPl 
                                    ? "Terapeuta wykazał empatię („No ból przeszkadza na pewno w życiu i to bardzo”) i próbował dopytywać o doświadczenia klienta. Jednakże, dialog sokratyczny był zbyt ogólny („co by ci pomogło?”) i nie doprowadził do konkretnych myśli automatycznych. Brak było aktywnego identyfikowania zniekształceń poznawczych (np. „mechaniczne uszkodzenie”) i ich podważania."
                                    : "Therapist showed empathy but Socratic dialogue was too general. Failed to identify or restructure cognitive distortions."}
                                </span>
                              </div>
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "3. Potencjalne myśli automatyczne terapeuty: " : "3. Potential therapist automatic thoughts: "}</span>
                                <Quote>
                                  {isPl
                                    ? "„Muszę zrozumieć fizyczne objawy klienta, zanim przejdę do psychiki.” lub „Klient jest w tak złym stanie, że muszę być bardzo delikatny i nie naciskać na konkretne myśli.”"
                                    : "„I must understand the physical symptoms first” or „The client is in such a bad state that I shouldn't push.”"}
                                </Quote>
                              </div>
                              <div className="bg-[#0b2b29] p-3 rounded border border-[#5bf4bc]/30 text-[#5bf4bc] mt-2.5">
                                <span className="font-bold text-[#ffb12c]">{isPl ? "Refleksja Superwizora AI: " : "AI Supervisor Reflection: "}</span>
                                {isPl
                                  ? "Kluczowym wyzwaniem w tej sesji było przejście od ogólnych skarg klienta na samopoczucie i poczucie „uszkodzenia” do konkretnych myśli automatycznych i wzorców behawioralnych. Terapeuta potrzebuje bardziej aktywnie strukturyzować sesję, precyzyjniej identyfikować myśli i emocje oraz wprowadzać konkretne interwencje CBT, takie jak dziennik myśli czy eksperymenty behawioralne, aby przełamać cykl bierności i beznadziei."
                                  : "The main challenge was transitioning from general complaints to automatic thoughts. Therapist needs active structure and CBT interventions."}
                              </div>
                            </div>
                          </div>
                        )}

                        {/* SECTION 7: WSTĘPNE HIPOTEZY DIAGNOSTYCZNE */}
                        {(reportSubTab === "all" || reportSubTab === "diagnosis") && (
                          <div className="bg-[#0f3435]/65 rounded-xl p-4 border border-white/5 text-left">
                            <div className="text-[9px] uppercase tracking-wider text-ember font-mono mb-1.5 font-bold">
                              {isPl ? "Raport Kliniczny • Część VII" : "Clinical Report • Part VII"}
                            </div>
                            <h4 className="font-serif text-[13.5px] font-bold text-white mb-3 pb-1 border-b border-white/10 flex items-center justify-between">
                              <span>{isPl ? "Wstępne hipotezy diagnostyczne" : "Preliminary Diagnostic Hypotheses"}</span>
                            </h4>
                            <div className="space-y-3.5 text-[11.5px] leading-relaxed text-mist font-sans">
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "1. Dane z dzieciństwa i kluczowe doświadczenia: " : "1. Childhood data & key experiences: "}</span>
                                <span>
                                  {isPl 
                                    ? "Klient wspomina o „dysfunkcjach” zauważalnych już w dzieciństwie, które „> z wiekiem to coraz bardziej zaczęło coraz bardziej się da, że tak powiem było było obserwowalne.” Sugeruje to długotrwały wzorzec trudności, który mógł ukształtować negatywne przekonania o sobie."
                                    : "Client mentions childhood dysfunctions that became more visible with age, suggesting a long-term pattern."}
                                </span>
                              </div>
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "2. Przekonania kluczowe: " : "2. Core beliefs: "}</span>
                                <span>
                                  {isPl 
                                    ? "Na podstawie wypowiedzi klienta („uszkodzenie mechaniczne,” „dysfunkcje,” „nie widzę zmian,” „zablokowany”) można hipotetyzować przekonania kluczowe o „Jestem wadliwy/niekompetentny” oraz „Jestem bezradny/nie mam wpływu”."
                                    : "Hypothesized core beliefs: 'I am defective/incompetent' and 'I am helpless'."}
                                </span>
                              </div>
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "3. Przekonania pośredniczące: " : "3. Intermediate beliefs: "}</span>
                                <span>
                                  {isPl 
                                    ? "Z przekonań kluczowych mogą wynikać zasady takie jak: „Jeśli coś nie działa od razu, to znaczy, że jestem beznadziejny i nie ma sensu próbować dalej,” oraz „Muszę się zmuszać do wszystkiego, bo inaczej nic nie zrobię, ale i tak to nic nie da”."
                                    : "Intermediate assumptions: 'If something doesn't work immediately, I'm hopeless' and 'I must force myself to do everything'."}
                                </span>
                              </div>
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "4. Strategie radzenia sobie (kompensacyjne): " : "4. Coping strategies: "}</span>
                                <span>
                                  {isPl 
                                    ? "Klient próbuje „zmuszać się” do aktywności i bierze leki, co jest próbą radzenia sobie, ale w sposób, który wydaje się być wyczerpujący i nieskuteczny, wzmacniając poczucie beznadziei. Może to być forma nadmiernej kompensacji za poczucie wadliwości, prowadząca do wypalenia."
                                    : "Forcing oneself to perform activities, which is exhausting and reinforces helplessness, leading to burnout."}
                                </span>
                              </div>
                              <div>
                                <span className="text-[#ffb12c] font-bold">{isPl ? "5. Typowa sekwencja problemowa (Cognitive Loop):" : "5. Typical problematic sequence (Cognitive Loop):"}</span>
                                <div className="mt-2 p-3 bg-[#071d1e] rounded-lg border border-white/5 text-[10.5px] font-sans space-y-2 text-white">
                                  <div className="flex items-center gap-2">
                                    <span className="w-5 h-5 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400 font-bold font-mono text-[10px]">1</span>
                                    <span><strong className="text-emerald-400">{isPl ? "Sytuacja: " : "Situation: "}</strong>{isPl ? "Spadek nastroju / ból głowy" : "Mood drop / headache"}</span>
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <span className="w-5 h-5 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400 font-bold font-mono text-[10px]">2</span>
                                    <span><strong className="text-emerald-400">{isPl ? "Myśl: " : "Thought: "}</strong>{isPl ? "„Jestem zablokowany, mam mechaniczne uszkodzenie, nie ma postępu”" : "„I have mechanical damage, everything bounces off”"}</span>
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <span className="w-5 h-5 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400 font-bold font-mono text-[10px]">3</span>
                                    <span><strong className="text-emerald-400">{isPl ? "Emocja: " : "Emotion: "}</strong>{isPl ? "Smutek, frustracja, beznadzieja" : "Sadness, frustration, helplessness"}</span>
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <span className="w-5 h-5 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400 font-bold font-mono text-[10px]">4</span>
                                    <span><strong className="text-emerald-400">{isPl ? "Zachowanie: " : "Behavior: "}</strong>{isPl ? "„Zmuszanie się” do aktywności, bierność, unikanie" : "Exhausting 'forcing oneself' or withdrawal"}</span>
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <span className="w-5 h-5 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400 font-bold font-mono text-[10px]">5</span>
                                    <span><strong className="text-emerald-400">{isPl ? "Skutek: " : "Physiological: "}</strong>{isPl ? "Dalsze wyczerpanie, poczucie słabości" : "Further fatigue and feeling of weakness"}</span>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </div>
                        )}

                      </div>
                    </div>
                  )}

                  {/* ──────────────────────────────────────────────────────────── */}
                  {/* TAB 2: TRANSCRIPT VIEW (1:1 Screnn_app_transrypcja.PNG) */}
                  {/* ──────────────────────────────────────────────────────────── */}
                  {activeTab === "transcript" && (
                    <div className="animate-[fadeIn_0.3s_ease-out_both] flex flex-col flex-1">
                      {/* App Bar */}
                      <div className="flex justify-between items-center mb-3">
                        <span className="text-white text-base cursor-pointer">⟨</span>
                        <h3 className="font-sans font-bold text-[15px] text-white tracking-wide">Transkrypcja</h3>
                        <div className="flex items-center gap-3 text-white">
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                            <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                          </svg>
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                            <circle cx="18" cy="5" r="3" />
                            <circle cx="6" cy="12" r="3" />
                            <circle cx="18" cy="19" r="3" />
                            <line x1="8.59" y1="13.51" x2="15.42" y2="17.49" />
                            <line x1="15.41" y1="6.51" x2="8.59" y2="10.49" />
                          </svg>
                        </div>
                      </div>

                      {/* Pill Toggle Tab */}
                      <div className="bg-[#071917] rounded-lg p-1 flex items-center mb-4 border border-white/5 select-none">
                        <span 
                          onClick={() => setActiveTab("transcript")}
                          className="flex-1 text-center py-1.5 text-xs bg-[#ffb12c] text-[#0a1e20] font-bold rounded-md cursor-pointer transition-colors"
                        >
                          {isPl ? "Transkrypcja" : "Transcript"}
                        </span>
                        <span 
                          onClick={() => setActiveTab("report")}
                          className="flex-1 text-center py-1.5 text-xs text-white/70 font-semibold cursor-pointer transition-colors hover:text-white"
                        >
                          {isPl ? "Raport" : "Report"}
                        </span>
                      </div>

                      {/* Speaker Filters */}
                      <div className="flex gap-2 mb-4 overflow-x-auto scrollbar-none">
                        <button
                          onClick={() => setTranscriptFilter("all")}
                          className={`px-4 py-1.5 rounded-full text-[11px] font-bold cursor-pointer shrink-0 transition-colors ${
                            transcriptFilter === "all"
                              ? "bg-[#ffb12c] text-[#0a1e20]"
                              : "bg-[#0f3432] border border-white/10 text-white/80 hover:bg-[#13403e]"
                          }`}
                        >
                          {transcriptFilter === "all" && "✓ "}{isPl ? "Wszyscy" : "All"}
                        </button>
                        <button
                          onClick={() => setTranscriptFilter("therapist")}
                          className={`px-4 py-1.5 rounded-full text-[11px] font-bold cursor-pointer shrink-0 transition-colors ${
                            transcriptFilter === "therapist"
                              ? "bg-[#ffb12c] text-[#0a1e20]"
                              : "bg-[#0f3432] border border-white/10 text-white/80 hover:bg-[#13403e]"
                          }`}
                        >
                          {transcriptFilter === "therapist" && "✓ "}{isPl ? "Terapeuta" : "Therapist"}
                        </button>
                        <button
                          onClick={() => setTranscriptFilter("patient")}
                          className={`px-4 py-1.5 rounded-full text-[11px] font-bold cursor-pointer shrink-0 transition-colors ${
                            transcriptFilter === "patient"
                              ? "bg-[#ffb12c] text-[#0a1e20]"
                              : "bg-[#0f3432] border border-white/10 text-white/80 hover:bg-[#13403e]"
                          }`}
                        >
                          {transcriptFilter === "patient" && "✓ "}{isPl ? "Pacjent" : "Patient"}
                        </button>
                      </div>

                      {/* Search Bar */}
                      <div className="bg-[#0b2b29] border border-white/10 rounded-lg px-3 py-1.5 flex items-center gap-2 mb-4">
                        <svg className="w-3.5 h-3.5 text-white/50" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                          <circle cx="11" cy="11" r="8" />
                          <line x1="21" y1="21" x2="16.65" y2="16.65" />
                        </svg>
                        <span className="text-[11px] text-white/50">{isPl ? "Szukaj w transkrypcji..." : "Search transcript..."}</span>
                      </div>

                      {/* Dialogue List */}
                      <div className="space-y-2 max-h-[240px] overflow-y-auto pr-0.5 scrollbar-thin select-text text-left">
                        
                        {/* 1 */}
                        {(transcriptFilter === "all" || transcriptFilter === "therapist") && (
                          <div className="bg-[#0f3435] border border-white/5 rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both]">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[#ffb12c] font-sans text-[11px] font-bold">{isPl ? "Terapeuta" : "Therapist"}</span>
                              <span className="text-[9.5px] text-white/50 font-mono">00:00 - 00:08</span>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              {isPl 
                                ? "Dzień dobry. Cieszę się, że się widzimy. Na czym chciałbyś się dzisiaj skoncentrować w naszej pracy?"
                                : "Good morning. I'm glad to see you. What would you like to focus on in our session today?"}
                            </p>
                          </div>
                        )}

                        {/* 2 */}
                        {(transcriptFilter === "all" || transcriptFilter === "patient") && (
                          <div className="bg-[#0f3435] border border-white/5 rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both]">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[#5bf4bc] font-sans text-[11px] font-bold">{isPl ? "Pacjent" : "Patient"}</span>
                              <span className="text-[9.5px] text-white/50 font-mono">00:08 - 00:22</span>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              {isPl 
                                ? "Dzień dobry. Szczerze mówiąc, ostatnio czuję się znacznie gorzej. Mimo że po poprzednich sesjach była lekka poprawa, to teraz znowu brakuje mi chęci do działania. Towarzyszą mi też te nietypowe, silne bóle głowy..."
                                : "Good morning. Honestly, I've been feeling much worse lately. Even though there was a slight improvement after the previous sessions, now I lack the desire to act again. I'm also experiencing those unusual, severe headaches..."}
                            </p>
                          </div>
                        )}

                        {/* 3 */}
                        {(transcriptFilter === "all" || transcriptFilter === "therapist") && (
                          <div className="bg-[#0f3435] border border-white/5 rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both]">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[#ffb12c] font-sans text-[11px] font-bold">{isPl ? "Terapeuta" : "Therapist"}</span>
                              <span className="text-[9.5px] text-white/50 font-mono">00:22 - 00:31</span>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              {isPl 
                                ? "Rozumiem. Te dolegliwości fizyczne z pewnością bardzo utrudniają codzienne funkcjonowanie. Czy to jest podobne do tego ucisku zatok, o którym rozmawialiśmy?"
                                : "I understand. Those physical ailments certainly make daily functioning very difficult. Is it similar to that sinus pressure we talked about?"}
                            </p>
                          </div>
                        )}

                        {/* 4 */}
                        {(transcriptFilter === "all" || transcriptFilter === "patient") && (
                          <div className="bg-[#0f3435] border border-white/5 rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both]">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[#5bf4bc] font-sans text-[11px] font-bold">{isPl ? "Pacjent" : "Patient"}</span>
                              <span className="text-[9.5px] text-white/50 font-mono">00:31 - 00:52</span>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              {isPl 
                                ? "Tak, te bóle są takie zatokowe, okropnie silne. Kiedy się pojawiają, czuję się całkowicie bezradny. Cały czas wraca do mnie myśl, że jestem jakoś zablokowany, że to jakoś uszkodzenie mam mechaniczne, które uniemożliwia mi działanie."
                                : "Yes, these headaches are like sinus pains, awfully strong. When they appear, I feel completely helpless. The thought keeps coming back that I am somehow blocked, that I have mechanical damage that prevents from functioning."}
                            </p>
                          </div>
                        )}

                        {/* 5 */}
                        {(transcriptFilter === "all" || transcriptFilter === "therapist") && (
                          <div className="bg-[#0f3435] border border-white/5 rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both]">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[#ffb12c] font-sans text-[11px] font-bold">{isPl ? "Terapeuta" : "Therapist"}</span>
                              <span className="text-[9.5px] text-white/50 font-mono">00:52 - 01:04</span>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              {isPl 
                                ? "„Uszkodzenie mechaniczne” – to bardzo wyraziste określenie. Co dokładnie kryje się pod tym poczuciem? Jak na to reagujesz na co dzień?"
                                : "“Mechanical damage” – that is a very vivid term. What exactly lies behind that feeling? How do you react to it on a daily basis?"}
                            </p>
                          </div>
                        )}

                        {/* 6 */}
                        {(transcriptFilter === "all" || transcriptFilter === "patient") && (
                          <div className="bg-[#0f3435] border border-white/5 rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both]">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[#5bf4bc] font-sans text-[11px] font-bold">{isPl ? "Pacjent" : "Patient"}</span>
                              <span className="text-[9.5px] text-white/50 font-mono">01:04 - 01:21</span>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              {isPl 
                                ? "Próbuję z tym walczyć, robić to, co ustaliliśmy. Staram się wychodzić na spacery, biorę leki, ale szczerze mówiąc, nie widzę już żadnych specjalnych zmian. Mam poczucie, że wszystko, co robię, odbija się od tego muru."
                                : "I try to fight it, to do what we agreed on. I try to go for walks, I take my medication, but honestly, I don't see any special changes anymore. I feel like everything I do just bounces off this wall."}
                            </p>
                          </div>
                        )}

                        {/* 7 */}
                        {(transcriptFilter === "all" || transcriptFilter === "therapist") && (
                          <div className="bg-[#0f3435] border border-white/5 rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both]">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[#ffb12c] font-sans text-[11px] font-bold">{isPl ? "Terapeuta" : "Therapist"}</span>
                              <span className="text-[9.5px] text-white/50 font-mono">01:21 - 01:32</span>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              {isPl 
                                ? "Zauważam tu silne poczucie bezradności i braku postępu. Czy pamiętasz, kiedy pierwszy raz poczułeś się w ten sposób?"
                                : "I notice a strong sense of helplessness and lack of progress. Do you remember when you first felt this way?"}
                            </p>
                          </div>
                        )}

                        {/* 8 */}
                        {(transcriptFilter === "all" || transcriptFilter === "patient") && (
                          <div className="bg-[#0f3435] border border-white/5 rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both]">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[#5bf4bc] font-sans text-[11px] font-bold">{isPl ? "Pacjent" : "Patient"}</span>
                              <span className="text-[9.5px] text-white/50 font-mono">01:32 - 01:54</span>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              {isPl 
                                ? "Wydaje się, że to było we mnie od dawna. Tylko że jako dziecko to było mniej zauważalne, po prostu wcześniej tę dysfunkcję jakoś ignorowałem. Z wiekiem jednak te problemy zaczęły się coraz bardziej piętrzyć."
                                : "It seems this has been in me for a long time. It's just that as a child it was less noticeable, I somehow ignored this dysfunction before. But with age, these problems started to pile up more and more."}
                            </p>
                          </div>
                        )}

                        {/* 9 */}
                        {(transcriptFilter === "all" || transcriptFilter === "therapist") && (
                          <div className="bg-[#0f3435] border border-white/5 rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both]">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[#ffb12c] font-sans text-[11px] font-bold">{isPl ? "Terapeuta" : "Therapist"}</span>
                              <span className="text-[9.5px] text-white/50 font-mono">01:54 - 02:05</span>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              {isPl 
                                ? "A jak to przekłada się na Twoje codzienne obowiązki w tym momencie? Co dzieje się, kiedy próbujesz po prostu realizować plan dnia?"
                                : "And how does that translate to your daily responsibilities at the moment? What happens when you just try to carry out your daily plan?"}
                            </p>
                          </div>
                        )}

                        {/* 10 */}
                        {(transcriptFilter === "all" || transcriptFilter === "patient") && (
                          <div className="bg-[#0f3435] border border-white/5 rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both]">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[#5bf4bc] font-sans text-[11px] font-bold">{isPl ? "Pacjent" : "Patient"}</span>
                              <span className="text-[9.5px] text-white/50 font-mono">02:05 - 02:28</span>
                            </div>
                            <p className="font-sans text-[11px] leading-relaxed text-white">
                              {isPl 
                                ? "To jest najgorsze – muszę ręcznie każdą czynność wykonywać. Nad każdą czynnością muszę się zastanawiać i zmuszać się do niej. Nie ma już tego automatyzmu, o którym rozmawialiśmy, tylko ciągła, męcząca walka z samym sobą."
                                : "That's the worst part – I have to manually do every single action. I have to think about every action and force myself to do it. There is no automaticity anymore, just a constant, exhausting struggle with myself."}
                            </p>
                          </div>
                        )}
                      </div>
                    </div>
                  )}

                  {/* ──────────────────────────────────────────────────────────── */}
                  {/* TAB 3: CONTINUITY VIEW (1:1 Screnn_app_widok dokumentacji.PNG) */}
                  {/* ──────────────────────────────────────────────────────────── */}
                  {activeTab === "continuity" && (
                    <div className="animate-[fadeIn_0.3s_ease-out_both] flex flex-col flex-1 relative min-h-[380px]">
                      {/* App Bar */}
                      <div className="flex justify-between items-center mb-4">
                        <span className="text-white text-base cursor-pointer">⟨</span>
                        <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                          <path d="M12 20h9" />
                          <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z" />
                        </svg>
                      </div>

                      {/* Header Title Info */}
                      <div className="mb-4">
                        <h3 className="font-serif font-bold text-2xl text-[#ffb12c] italic tracking-wide">
                          Nagraniowiec
                        </h3>
                        <p className="font-sans text-[11.5px] text-white/70 mt-0.5">
                          Nad czym dzisiaj pracujemy?
                        </p>
                      </div>

                      {/* Session Cards list */}
                      <div className="space-y-2.5 max-h-[240px] overflow-y-auto pr-0.5 scrollbar-thin">
                        
                        {/* Sesja 6 card (Active new report) */}
                        <div 
                          onClick={() => setActiveTab("report")}
                          className="bg-[#133c38] border border-[#5bf4bc]/30 rounded-xl p-3 flex items-center justify-between shadow-md cursor-pointer hover:bg-[#184a45] hover:border-[#5bf4bc]/50 transition-all duration-200 hover:scale-[1.01]"
                        >
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-lg bg-[#185342] border border-[#5bf4bc]/30 flex items-center justify-center font-sans font-bold text-[12px] text-[#5bf4bc]">
                              #6
                            </div>
                            <div>
                              <div className="font-sans text-[12.5px] font-bold text-white">{isPl ? "Sesja 6" : "Session 6"}</div>
                              <div className="font-sans text-[9.5px] text-white/60 mt-0.5 flex items-center gap-1.5 flex-wrap">
                                <span>{isPl ? "2 Cze" : "2 Jun"} · 10:29 – 10:30 · 1 min</span>
                                <span className="bg-[#1b5042] text-[#5bf4bc] text-[8px] px-1.5 py-0.5 rounded-full font-bold flex items-center gap-1 shrink-0">
                                  <span className="w-1 h-1 rounded-full bg-[#5bf4bc]" /> {isPl ? "Nowy raport" : "New report"}
                                </span>
                              </div>
                            </div>
                          </div>
                          <span className="text-white/60 text-sm">⋮</span>
                        </div>

                        {/* Sesja 5 card */}
                        <div 
                          onClick={() => setActiveTab("report")}
                          className="bg-[#0f3230]/70 border border-white/5 rounded-xl p-3 flex items-center justify-between cursor-pointer hover:bg-[#144441]/70 hover:border-white/10 transition-all duration-200 hover:scale-[1.01]"
                        >
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-lg bg-[#1f3f3c] flex items-center justify-center font-sans font-bold text-[12px] text-white/80">
                              #5
                            </div>
                            <div>
                              <div className="font-sans text-[12.5px] font-bold text-white">{isPl ? "Sesja 5" : "Session 5"}</div>
                              <div className="font-sans text-[9.5px] text-white/50 mt-0.5">{isPl ? "24 Maj" : "24 May"} · 17:41</div>
                            </div>
                          </div>
                          <span className="text-white/50 text-sm">⋮</span>
                        </div>

                        {/* Sesja 4 card */}
                        <div 
                          onClick={() => setActiveTab("report")}
                          className="bg-[#0f3230]/70 border border-white/5 rounded-xl p-3 flex items-center justify-between cursor-pointer hover:bg-[#144441]/70 hover:border-white/10 transition-all duration-200 hover:scale-[1.01]"
                        >
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-lg bg-[#1f3f3c] flex items-center justify-center font-sans font-bold text-[12px] text-white/80">
                              #4
                            </div>
                            <div>
                              <div className="font-sans text-[12.5px] font-bold text-white">{isPl ? "Sesja 4" : "Session 4"}</div>
                              <div className="font-sans text-[9.5px] text-white/50 mt-0.5">{isPl ? "16 Maj" : "16 May"} · 23:32</div>
                            </div>
                          </div>
                          <span className="text-white/50 text-sm">⋮</span>
                        </div>

                        {/* Sesja 3 card */}
                        <div 
                          onClick={() => setActiveTab("report")}
                          className="bg-[#0f3230]/70 border border-white/5 rounded-xl p-3 flex items-center justify-between cursor-pointer hover:bg-[#144441]/70 hover:border-white/10 transition-all duration-200 hover:scale-[1.01]"
                        >
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-lg bg-[#1f3f3c] flex items-center justify-center font-sans font-bold text-[12px] text-white/80">
                              #3
                            </div>
                            <div>
                              <div className="font-sans text-[12.5px] font-bold text-white">{isPl ? "Sesja 3" : "Session 3"}</div>
                              <div className="font-sans text-[9.5px] text-white/50 mt-0.5">{isPl ? "10 Maj" : "10 May"} · 14:15</div>
                            </div>
                          </div>
                          <span className="text-white/50 text-sm">⋮</span>
                        </div>

                        {/* Sesja 2 card */}
                        <div 
                          onClick={() => setActiveTab("report")}
                          className="bg-[#0f3230]/70 border border-white/5 rounded-xl p-3 flex items-center justify-between cursor-pointer hover:bg-[#144441]/70 hover:border-white/10 transition-all duration-200 hover:scale-[1.01]"
                        >
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-lg bg-[#1f3f3c] flex items-center justify-center font-sans font-bold text-[12px] text-white/80">
                              #2
                            </div>
                            <div>
                              <div className="font-sans text-[12.5px] font-bold text-white">{isPl ? "Sesja 2" : "Session 2"}</div>
                              <div className="font-sans text-[9.5px] text-white/50 mt-0.5">{isPl ? "3 Maj" : "3 May"} · 11:20</div>
                            </div>
                          </div>
                          <span className="text-white/50 text-sm">⋮</span>
                        </div>

                        {/* Sesja 1 card (Active AI analyzing) */}
                        <div 
                          onClick={() => setActiveTab("report")}
                          className="bg-[#0f3230]/70 border border-white/5 rounded-xl p-3 flex items-center justify-between cursor-pointer hover:bg-[#144441]/70 hover:border-white/10 transition-all duration-200 hover:scale-[1.01]"
                        >
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-lg bg-[#1f3f3c] flex items-center justify-center font-sans font-bold text-[12px] text-white/80">
                              #1
                            </div>
                            <div>
                              <div className="font-sans text-[12.5px] font-bold text-white">{isPl ? "Sesja 1" : "Session 1"}</div>
                              <div className="font-sans text-[9.5px] text-white/60 mt-0.5 flex items-center gap-1.5 flex-wrap">
                                <span>{isPl ? "28 Kwi" : "28 Apr"} · 15:45</span>
                                <span className="bg-amber-500/10 text-amber-400 text-[8.5px] px-1.5 py-0.5 rounded-full font-bold flex items-center gap-1 shrink-0 border border-amber-500/20 animate-pulse">
                                  <span className="w-1 h-1 rounded-full bg-amber-400" /> 
                                  {isPl ? "Analiza AI trwa..." : "AI analyzing..."}
                                </span>
                              </div>
                            </div>
                          </div>
                          <span className="text-white/50 text-sm">⋮</span>
                        </div>

                      </div>

                      {/* Yellow FAB button replica */}
                      <div className="absolute bottom-2 right-2 w-11 h-11 rounded-full bg-[#ffb12c] shadow-lg flex items-center justify-center text-[#0a1e20] cursor-pointer">
                        <span className="text-2xl stroke-3 font-bold">+</span>
                      </div>
                    </div>
                  )}

                  {/* ──────────────────────────────────────────────────────────── */}
                  {/* TAB 4: MODALITY VIEW (1:1 Screnn_app_nurty terapii.PNG) */}
                  {/* ──────────────────────────────────────────────────────────── */}
                  {activeTab === "modality" && (
                    <div className="animate-[fadeIn_0.3s_ease-out_both] flex flex-col flex-1">
                      {/* Modal Bar indicator */}
                      <div className="w-12 h-1 bg-white/20 rounded-full mx-auto mb-4" />

                      {/* Headers */}
                      <div className="mb-4">
                        <h3 className="font-sans font-bold text-xl text-white">
                          Wybierz swój nurt
                        </h3>
                        <p className="font-sans text-[11px] text-white/70 italic leading-relaxed mt-1">
                          To ustawienie wpływa na generowane raporty. Możesz je zmienić w każdej chwili.
                        </p>
                      </div>

                      {/* Modality options list — SHOWING ALL 9 OPTIONS FROM THE SCREENSHOT */}
                      <div className="space-y-1.5 max-h-[290px] overflow-y-auto pr-1.5 scrollbar-thin">
                        {MODALITIES_LIST.map((m) => {
                          const isSelected = selectedModality === m.id;
                          return (
                            <div
                              key={m.id}
                              onClick={() => setSelectedModality(m.id)}
                              className={`transition-all duration-200 rounded-xl p-3 flex items-center justify-between border cursor-pointer ${
                                isSelected
                                  ? "bg-[#123632] border-[#ffb12c]/40 shadow-md"
                                  : "bg-transparent hover:bg-white/[0.03] border-transparent"
                              }`}
                            >
                              <div className="flex items-center gap-3">
                                <div className={`w-7.5 h-7.5 rounded-full flex items-center justify-center shrink-0 transition-colors duration-200 ${
                                  isSelected
                                    ? "bg-[#ffb12c] text-[#0a1e20]"
                                    : "bg-[#112d2b] border border-white/10 text-[#5bf4bc]"
                                }`}>
                                  {m.icon}
                                </div>
                                <span className={`font-sans text-[12.5px] transition-colors duration-200 ${
                                  isSelected ? "font-bold text-white" : "text-white/90"
                                }`}>
                                  {isPl ? m.label : m.labelEn}
                                </span>
                              </div>
                              {isSelected && (
                                <div className="w-5 h-5 rounded-full bg-[#ffb12c] flex items-center justify-center text-[#0a1e20] text-xs font-bold shrink-0 animate-[fadeIn_0.2s_ease-out]">
                                  ✓
                                </div>
                              )}
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  )}

                </div>

                {/* Footer bar Mockup */}
                <div className="flex justify-between items-center pt-4 border-t border-white/[0.06] mt-4 text-[10px] text-white/50">
                  <span>{isPl ? "Zaszyfrowano kluczem AES-256-GCM" : "Encrypted with AES-256-GCM"}</span>
                  <span className="flex items-center gap-1">
                    <span className="w-1.5 h-1.5 rounded-full bg-[#5bf4bc] animate-pulse" />
                    {isPl ? "Serwer UE: Zgodne z RODO" : "EU Server: GDPR Compliant"}
                  </span>
                </div>

              </div>
            </div>

          </div>

        </div>

      </div>
      
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(6px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .scrollbar-none::-webkit-scrollbar { display: none; }
        .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
        
        .scrollbar-thin::-webkit-scrollbar { width: 4px; }
        .scrollbar-thin::-webkit-scrollbar-track { background: transparent; }
        .scrollbar-thin::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.06); border-radius: 9999px; }
      `}} />
    </section>
  );
}
