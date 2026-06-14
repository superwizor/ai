"use client";

import { useState, useRef, useEffect } from "react";
import { useTranslations, useLocale } from "next-intl";

type FeatureKey = "record" | "transcript" | "report" | "continuity" | "modality" | "folder";

const FEATURE_ICONS: Record<FeatureKey, React.ReactNode> = {
  record: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
      <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
      <path d="M19 10v2a7 7 0 0 1-14 0v-2M12 19v3M8 22h8" />
    </svg>
  ),
  transcript: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
      <path d="M8 10h.01M12 10h.01M16 10h.01" />
    </svg>
  ),
  report: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="16" y1="13" x2="8" y2="13" />
      <line x1="16" y1="17" x2="8" y2="17" />
    </svg>
  ),
  continuity: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
      <path d="M10 12a2 2 0 1 0 0-4 3 3 0 1 0 0 6 4 4 0 1 0 0-8 5 5 0 1 0 0 10h11" />
    </svg>
  ),
  modality: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
      <line x1="4" y1="21" x2="4" y2="14" />
      <line x1="4" y1="10" x2="4" y2="3" />
      <line x1="12" y1="21" x2="12" y2="12" />
      <line x1="12" y1="8" x2="12" y2="3" />
      <line x1="20" y1="21" x2="20" y2="16" />
      <line x1="20" y1="12" x2="20" y2="3" />
      <line x1="1" y1="14" x2="7" y2="14" />
      <line x1="9" y1="8" x2="15" y2="8" />
      <line x1="17" y1="16" x2="23" y2="16" />
    </svg>
  ),
  folder: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5">
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <path d="M3 10h18" />
      <path d="M9 14h.01" />
      <path d="M15 14h.01" />
      <path d="M9 17h6" />
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
  <blockquote className="border-l-2 border-white/20 bg-white/[0.02] pl-3 py-1.5 my-1.5 text-[11px] lg:text-[14px] text-white/80 italic rounded-r font-sans leading-relaxed">
    {children}
  </blockquote>
);

const INITIAL_EMAIL_DRAFT_PL = `Cześć Marku,

Przesyłam podsumowanie naszego planu działania z dzisiejszej sesji. Ustaliliśmy, że w tym tygodniu skupimy się na Dzienniku Myśli Automatycznych (model A-B-C), aby lepiej zrozumieć sytuacje, w których czujesz się „zablokowany”.

Twoje zadanie domowe:
Gdy poczujesz spadek energii, frustrację lub ból głowy, spróbuj zapisać:
1. Sytuację (Gdzie byłeś i z kim?)
2. Myśli (Co dokładnie przebiegło Ci przez głowę?)
3. Emocje (Co poczułeś i jak silne to było na skali 0-100%?)
4. Reakcję (Co zrobiłeś w tamtym momencie?)

Wskazówka: Jeśli poczujesz opór lub myśl, że „to nic nie da” – to zupełnie naturalne. Spróbuj mimo to zapisać cokolwiek. Traktujemy to jako mały eksperyment i zbieranie danych, bez presji.

Do zobaczenia na kolejnej sesji,
Twój Terapeuta`;

const INITIAL_EMAIL_DRAFT_EN = `Hi Mark,

Here is the summary of the homework we agreed on during today's session. This week, we will focus on the Automatic Thoughts Journal (A-B-C model) to better understand the moments you feel "blocked."

Your homework:
When you feel a drop in energy, frustration, or a headache, try to write down:
1. The situation (Where were you and with whom?)
2. Thoughts (What exactly crossed your mind?)
3. Emotions (What did you feel and how strong was it on a 0-100% scale?)
4. Reaction (What did you do in that moment?)

Tip: If you feel resistance or a thought that "it won't help" – this is completely natural. Try to write down anything. Let's treat it as a small experiment to gather data, without pressure.

See you at our next session,
Your Therapist`;

const DISLIKE_OPTIONS_PL = [
  "Za długi",
  "Za krótki",
  "Zły ton",
  "Za dużo cytatów",
  "Za mało cytatów",
  "Niedokładna interpretacja",
  "Brakuje mocnych stron klienta",
  "Brakuje kontekstu / złe akcenty",
  "Inne"
];

const DISLIKE_OPTIONS_EN = [
  "Too long",
  "Too short",
  "Wrong tone",
  "Too many quotes",
  "Too few quotes",
  "Inaccurate interpretation",
  "Missing client strengths",
  "Missing context / wrong emphasis",
  "Other"
];

interface RecordTabContentProps {
  isPl: boolean;
  setToast: (msg: string | null) => void;
}

function RecordTabContent({ isPl, setToast }: RecordTabContentProps) {
  const [recordingSeconds, setRecordingSeconds] = useState(3);
  const [isTimerRunning, setIsTimerRunning] = useState<boolean>(true);

  useEffect(() => {
    if (!isTimerRunning) return;
    const interval = setInterval(() => {
      setRecordingSeconds((prev) => (prev + 1) % 3600);
    }, 1000);
    return () => clearInterval(interval);
  }, [isTimerRunning]);

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60).toString().padStart(2, "0");
    const s = (secs % 60).toString().padStart(2, "0");
    return `${m}:${s}`;
  };

  return (
    <div className="animate-[fadeIn_0.3s_ease-out_both] flex flex-col flex-1 justify-between text-left h-full">
      {/* Top bar with back and info */}
      <div className="flex items-center justify-between w-full mb-4 shrink-0">
        <button className="p-1 text-white/60 hover:text-white cursor-pointer" aria-label="Back">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
          </svg>
        </button>
        <div className="text-center">
          <div className="text-[9px] uppercase tracking-widest text-white/50 font-bold font-mono">
            {isPl ? "14 CZERWCA 2026" : "JUNE 14, 2026"}
          </div>
          <h3 className="font-sans font-bold text-[15px] sm:text-[17px] text-white mt-0.5 leading-snug">
            {isPl ? "Próbny Klient" : "Demo Client"}
          </h3>
          <p className="text-[#fcae2f] italic font-serif text-[11px] sm:text-xs">
            {isPl ? "Sesja #5" : "Session #5"}
          </p>
        </div>
        <button className="p-1 text-white/60 hover:text-white cursor-pointer" aria-label="Info">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 111.063.852l-.708 2.836a.75.75 0 001.063.852l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" />
          </svg>
        </button>
      </div>

      {/* Center Waveform & Ripple Area */}
      <div className="flex-1 flex flex-col items-center justify-center relative my-6">
        {/* Ripple circles */}
        {recordingSeconds > 0 && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-[1]">
            {Array.from({ length: 3 }, (_, i) => i + 1).map((num) => (
              <div 
                key={num}
                style={{ 
                  animationName: `recording-ripple`,
                  animationDuration: `6s`,
                  animationTimingFunction: `cubic-bezier(0.05, 0.95, 0.1, 1)`,
                  animationIterationCount: `infinite`,
                  animationDelay: `${(num - 1) * 2}s`,
                  animationPlayState: isTimerRunning ? "running" : "paused" 
                }} 
                className="absolute w-44 h-44 rounded-full border-2 border-[#fcae2f]/50" 
              />
            ))}
          </div>
        )}

        {/* Middle Circle */}
        <div className="relative w-40 h-40 sm:w-44 sm:h-44 rounded-full bg-[#032226] border border-[#fcae2f]/20 shadow-[0_0_30px_rgba(252,174,47,0.12)] flex flex-col items-center justify-center z-10 select-none">
          {/* Live Waveform */}
          <div className="flex items-center gap-[4px] mb-3 h-10 shrink-0">
            {[12, 24, 16, 34, 22, 28, 20, 14, 32, 26, 18, 30, 24, 12, 22, 16, 10].map((h, i) => (
              <div
                key={i}
                style={{
                  height: recordingSeconds === 0 ? "4px" : `${h}px`,
                  animationName: recordingSeconds === 0 ? "none" : "waveform",
                  animationDuration: "1.2s",
                  animationTimingFunction: "ease-in-out",
                  animationIterationCount: "infinite",
                  animationDirection: "alternate",
                  animationDelay: `${i * 0.07}s`,
                  transformOrigin: "center",
                  animationPlayState: isTimerRunning ? "running" : "paused"
                }}
                className="w-[3px] bg-white/95 rounded-full shadow-[0_0_8px_rgba(255,255,255,0.4)]"
              />
            ))}
          </div>
          {/* Recording status text */}
          <div className="text-[10px] text-white/60 font-semibold tracking-wide uppercase font-sans">
            {recordingSeconds === 0 
              ? (isPl ? "Nagrywanie zatrzymane" : "Recording stopped")
              : (!isTimerRunning 
                  ? (isPl ? "Nagrywanie wstrzymane" : "Recording paused") 
                  : (isPl ? "Nagrywanie trwa" : "Recording"))
            }
          </div>
          {/* Timer */}
          <div className="text-2xl sm:text-3xl font-bold font-sans mt-0.5 text-white tracking-widest">
            {formatTime(recordingSeconds)}
          </div>
        </div>
      </div>

      {/* Bottom control buttons */}
      <div className="flex items-center justify-center gap-6 mb-2 shrink-0">
        <button 
          onClick={(e) => {
            e.stopPropagation();
            if (recordingSeconds === 0) {
              setRecordingSeconds(3);
              setIsTimerRunning(true);
              setToast(isPl ? "Rozpoczęto nagrywanie!" : "Recording started!");
            } else {
              setIsTimerRunning(!isTimerRunning);
              setToast(isTimerRunning 
                ? (isPl ? "Wstrzymano nagrywanie" : "Recording paused")
                : (isPl ? "Wznowiono nagrywanie" : "Recording resumed")
              );
            }
            setTimeout(() => setToast(null), 1500);
          }}
          className="w-11 h-11 rounded-full border-2 border-[#fcae2f] flex items-center justify-center text-[#fcae2f] hover:bg-[#fcae2f]/10 active:scale-95 transition-all cursor-pointer" 
          aria-label="Pause/Resume"
        >
          {isTimerRunning && recordingSeconds > 0 ? (
            <svg className="w-4.5 h-4.5 fill-current" viewBox="0 0 24 24">
              <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" />
            </svg>
          ) : (
            <svg className="w-4.5 h-4.5 fill-current ml-0.5" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
          )}
        </button>
        <button 
          onClick={(e) => {
            e.stopPropagation();
            if (recordingSeconds > 0) {
              setRecordingSeconds(0);
              setIsTimerRunning(false);
              setToast(isPl ? "Zapisano nagranie sesji!" : "Session recording saved!");
              setTimeout(() => setToast(null), 2000);
            }
          }}
          className={`w-13 h-13 rounded-full bg-[#d84515] flex items-center justify-center text-white hover:brightness-110 active:scale-95 transition-all shadow-md cursor-pointer ${
            recordingSeconds === 0 ? "opacity-40 cursor-not-allowed" : ""
          }`} 
          aria-label="Stop"
        >
          <div className="w-4 h-4 bg-white rounded-[3px]" />
        </button>
      </div>
    </div>
  );
}

export function Features() {
  const t = useTranslations("b.features");
  const tItem = useTranslations("b.features.items");
  const locale = useLocale();
  const isPl = locale === "pl";
  const tHero = useTranslations("hero");

  const [activeTab, setActiveTab] = useState<FeatureKey>("record");
  const [selectedClientName, setSelectedClientName] = useState<string>("");
  const [modalitySubTab, setModalitySubTab] = useState<"choose" | "settings">("choose");
  const [reportSubTab, setReportSubTab] = useState<string>("summary");
  const [isEmailMode, setIsEmailMode] = useState<boolean>(false);
  const [isAnalyzingView, setIsAnalyzingView] = useState<boolean>(false);

  const [expandedSection, setExpandedSection] = useState<'none' | 'wstrzymane' | 'zakonczone'>('none');
  const [activeSettingSheet, setActiveSettingSheet] = useState<string | null>(null);
  const [settingValues, setSettingValues] = useState<Record<string, string>>({
    length: "Standardowa",
    tone: "Kliniczny",
    quotes: "Kluczowe (3-5)",
    jargon: "Domyślny",
    assertiveness: "Zrównoważony",
    strengths: "Standardowy",
    sections: "Standardowe",
    additional: "Brak"
  });

  const getSettingSheetTitle = (id: string) => {
    switch (id) {
      case "length": return isPl ? "Długość raportu" : "Report length";
      case "tone": return isPl ? "Ton" : "Tone";
      case "quotes": return isPl ? "Liczba cytatów z sesji" : "Number of session quotes";
      case "jargon": return isPl ? "Język opisu (konceptualizacji)" : "Conceptualization language";
      case "assertiveness": return isPl ? "Stopień asertywności hipotez" : "Hypothesis assertiveness level";
      case "strengths": return isPl ? "Akcent na mocnych stronach" : "Emphasis on strengths";
      case "sections": return isPl ? "Sekcje do rozwinięcia" : "Sections to expand";
      case "additional": return isPl ? "Dodatkowe wskazówki" : "Additional instructions";
      default: return "";
    }
  };

  const getSettingSheetOptions = (id: string) => {
    switch (id) {
      case "length":
        return [
          { value: isPl ? "Krótka" : "Short", label: isPl ? "Krótki (zwięzłe podsumowanie)" : "Short (concise summary)" },
          { value: isPl ? "Standardowa" : "Standard", label: isPl ? "Standardowy (optymalny)" : "Standard (optimal)" },
          { value: isPl ? "Szczegółowa" : "Detailed", label: isPl ? "Szczegółowy (pełna konceptualizacja)" : "Detailed (full conceptualization)" }
        ];
      case "tone":
        return [
          { value: isPl ? "Kliniczny" : "Clinical", label: isPl ? "Profesjonalny & Kliniczny" : "Professional & Clinical" },
          { value: isPl ? "Empatyczny" : "Empathetic", label: isPl ? "Empatyczny & Humanistyczny" : "Empathetic & Humanistic" },
          { value: isPl ? "Techniczny" : "Technical", label: isPl ? "Strukturyzowany & Techniczny" : "Structured & Technical" }
        ];
      case "quotes":
        return [
          { value: isPl ? "Brak" : "None", label: isPl ? "Brak (tylko synteza)" : "None (synthesis only)" },
          { value: isPl ? "Kluczowe (3-5)" : "Key (3-5)", label: isPl ? "Kluczowe cytaty (3-5)" : "Key quotes (3-5)" },
          { value: isPl ? "Maksymalna" : "Maximum", label: isPl ? "Maksymalna (bogata ilustracja)" : "Maximum (rich illustration)" }
        ];
      case "jargon":
        return [
          { value: isPl ? "Domyślny" : "Default", label: isPl ? "Domyślny (neutralny)" : "Default (neutral)" },
          { value: isPl ? "Ścisły" : "Strict", label: isPl ? "Ścisły (specyficzny dla nurtu)" : "Strict (modality-specific)" },
          { value: isPl ? "Przystępny" : "Accessible", label: isPl ? "Przystępny (dla klienta)" : "Accessible (for client)" }
        ];
      case "assertiveness":
        return [
          { value: isPl ? "Medyczny" : "Medical", label: isPl ? "Medyczny (ostrożne hipotezy)" : "Medical (cautious hypotheses)" },
          { value: isPl ? "Zrównoważony" : "Balanced", label: isPl ? "Zrównoważony" : "Balanced" },
          { value: isPl ? "Kreatywny" : "Creative", label: isPl ? "Kreatywny (odważne wnioski)" : "Creative (bold assertions)" }
        ];
      case "strengths":
        return [
          { value: isPl ? "Standardowy" : "Standard", label: isPl ? "Standardowy" : "Standard" },
          { value: isPl ? "Wysoki" : "High", label: isPl ? "Wysoki (zasoby i rezyliencja)" : "High (resources & resilience)" }
        ];
      case "sections":
        return [
          { value: isPl ? "Standardowe" : "Standard", label: isPl ? "Wszystkie sekcje standardowe" : "All standard sections" },
          { value: isPl ? "Interwencje" : "Interventions", label: isPl ? "Rozszerzona sekcja interwencji" : "Expanded interventions section" },
          { value: isPl ? "Przeciwprzeniesienie" : "Countertransference", label: isPl ? "Rozszerzona sekcja przeciwprzeniesienia" : "Expanded countertransference" }
        ];
      case "additional":
        return [
          { value: isPl ? "Brak" : "None", label: isPl ? "Brak" : "None" },
          { value: isPl ? "DSM-5 / ICD-11" : "DSM-5 / ICD-11", label: isPl ? "Uwzględnij kryteria DSM-5 / ICD-11" : "Include DSM-5 / ICD-11 criteria" },
          { value: isPl ? "Superwizja" : "Supervision", label: isPl ? "Formatuj pod superwizję" : "Format for supervision" }
        ];
      default: return [];
    }
  };



  const buttonsContainerRef = useRef<HTMLDivElement>(null);

  const changeTab = (tab: FeatureKey) => {
    setActiveTab(tab);
    setIsAnalyzingView(false);
    
    // Smoothly scroll the active button into view on mobile horizontal overflow
    setTimeout(() => {
      const container = buttonsContainerRef.current;
      const activeBtn = container?.querySelector(`[data-feature="${tab}"]`) as HTMLElement | null;
      if (container && activeBtn) {
        const buttonOffsetLeft = activeBtn.offsetLeft;
        const buttonWidth = activeBtn.offsetWidth;
        const containerWidth = container.clientWidth;
        const targetScrollLeft = buttonOffsetLeft - (containerWidth / 2) + (buttonWidth / 2);
        container.scrollTo({
          left: targetScrollLeft,
          behavior: "smooth"
        });
      }
    }, 50);
  };

  const handleClientClick = (clientName: string) => {
    setSelectedClientName(clientName);
    changeTab("continuity");
  };

  const reportScrollRef = useRef<HTMLDivElement>(null);
  const tabsRowRef = useRef<HTMLDivElement>(null);
  const isScrollingRef = useRef<boolean>(false);
  const scrollTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const handleSubTabClick = (tabId: string) => {
    setReportSubTab(tabId);
    isScrollingRef.current = true;
    const container = reportScrollRef.current;
    const target = container?.querySelector(`#sec-${tabId}`);
    if (container && target) {
      const containerTop = container.getBoundingClientRect().top;
      const targetTop = target.getBoundingClientRect().top;
      const scrollOffset = targetTop - containerTop + container.scrollTop - 8;
      container.scrollTo({
        top: scrollOffset,
        behavior: "smooth"
      });
      
      if (scrollTimeoutRef.current) clearTimeout(scrollTimeoutRef.current);
      scrollTimeoutRef.current = setTimeout(() => {
        isScrollingRef.current = false;
      }, 450);
    }
  };

  const handleReportScroll = () => {
    if (isScrollingRef.current) return;
    const container = reportScrollRef.current;
    if (!container) return;

    const sectionIds = ["summary", "observations", "plan", "proposals", "threads", "supervision", "diagnosis"];
    let activeSection = "summary";
    const containerTop = container.getBoundingClientRect().top;

    for (const id of sectionIds) {
      const el = container.querySelector(`#sec-${id}`);
      if (el) {
        const rect = el.getBoundingClientRect();
        if (rect.top <= containerTop + 30) {
          activeSection = id;
        }
      }
    }

    if (activeSection !== reportSubTab) {
      setReportSubTab(activeSection);
      const tabsRow = tabsRowRef.current;
      const tabButton = tabsRow?.querySelector(`#tab-btn-${activeSection}`) as HTMLElement | null;
      if (tabsRow && tabButton) {
        const rowRect = tabsRow.getBoundingClientRect();
        const btnRect = tabButton.getBoundingClientRect();
        if (btnRect.left < rowRect.left || btnRect.right > rowRect.right) {
          const buttonOffsetLeft = tabButton.offsetLeft;
          const buttonWidth = tabButton.offsetWidth;
          const rowWidth = tabsRow.clientWidth;
          const targetScrollLeft = buttonOffsetLeft - (rowWidth / 2) + (buttonWidth / 2);
          tabsRow.scrollTo({
            left: targetScrollLeft,
            behavior: "smooth"
          });
        }
      }
    }
  };

  const handleSendEmail = () => {
    setEmailState("sending");
    setTimeout(() => {
      setEmailState("idle");
      setIsEmailMode(false);
      showToast(isPl ? "Plan działania wysłano do klienta!" : "Action plan sent to client!");
    }, 1200);
  };
  const [selectedModality, setSelectedModality] = useState<string>("UNIV");
  const [transcriptFilter, setTranscriptFilter] = useState<"all" | "therapist" | "client">("all");

  const [toast, setToast] = useState<string | null>(null);
  const [activeDialog, setActiveDialog] = useState<"dislike" | "email" | null>(null);
  const [emailState, setEmailState] = useState<"idle" | "sending" | "sent">("idle");
  const [dislikeSelectedChips, setDislikeSelectedChips] = useState<number[]>([]);
  const [emailDraftPl, setEmailDraftPl] = useState(INITIAL_EMAIL_DRAFT_PL);
  const [emailDraftEn, setEmailDraftEn] = useState(INITIAL_EMAIL_DRAFT_EN);

  const [isLiked, setIsLiked] = useState(false);
  const [isDisliked, setIsDisliked] = useState(false);

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 3000);
  };

  const handleCopy = (type: "report" | "transcript" = "report") => {
    const textToCopy = type === "report"
      ? (isPl ? "Pogorszenie samopoczucia, bóle głowy i brak postępu..." : "Deterioration of well-being, headaches and lack of progress...")
      : (isPl ? "Dzień dobry. Cieszę się, że się widzimy..." : "Good morning. I'm glad to see you...");
    navigator.clipboard.writeText(textToCopy).catch(() => {});
    showToast(
      type === "report"
        ? (isPl ? "Raport skopiowano do schowka!" : "Report copied to clipboard!")
        : (isPl ? "Transkrypcję skopiowano do schowka!" : "Transcript copied to clipboard!")
    );
  };

  const tabs: FeatureKey[] = ["record", "transcript", "report", "continuity", "modality", "folder"];
  const handleNextTab = (e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    const currentIndex = tabs.indexOf(activeTab);
    const nextIndex = (currentIndex + 1) % tabs.length;
    changeTab(tabs[nextIndex]);
  };
  const handlePrevTab = (e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    const currentIndex = tabs.indexOf(activeTab);
    const prevIndex = (currentIndex - 1 + tabs.length) % tabs.length;
    changeTab(tabs[prevIndex]);
  };

  const reportSubTabs = [
    { id: "summary", label: "Podsumowanie sesji", labelEn: "Session summary" },
    { id: "observations", label: "Wnikliwe obserwacje", labelEn: "Insightful observations" },
    { id: "plan", label: "Plan działania klienta", labelEn: "Client action plan" },
    { id: "proposals", label: "Propozycje interwencji", labelEn: "Intervention proposals" },
    { id: "threads", label: "Wątki do pogłębienia", labelEn: "Threads to deepen" },
    { id: "supervision", label: "Wskazówki superwizyjne", labelEn: "Supervisory tips" },
    { id: "diagnosis", label: "Wstępna konceptualizacja", labelEn: "Preliminary case formulation" },
  ];

  return (
    <section id="features" className="relative w-full bg-[#FBFAF7] text-[#1B2522] py-24 sm:py-32 overflow-hidden border-y border-[#E2DED5]/60">
      {/* Background Grid Pattern */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,rgba(0,0,0,0.015)_1px,transparent_1px),linear-gradient(to_bottom,rgba(0,0,0,0.015)_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_50%,#000_70%,transparent_100%)] pointer-events-none" />

      {/* Decorative side glows */}
      <div className="absolute top-1/2 left-0 -translate-y-1/2 w-[350px] h-[350px] bg-[#5bf4bc]/[0.03] rounded-full blur-[100px] pointer-events-none" />
      <div className="absolute top-1/2 right-0 -translate-y-1/2 w-[350px] h-[350px] bg-ember/[0.03] rounded-full blur-[100px] pointer-events-none" />

      <div className="relative mx-auto w-full max-w-[1200px] px-2 sm:px-6">
        
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
          <div className="lg:col-span-5 flex flex-col justify-start min-w-0">
            <div 
              ref={buttonsContainerRef}
              className="flex items-stretch overflow-x-auto gap-3 pb-4 scrollbar-none snap-x snap-mandatory lg:grid lg:grid-cols-1 lg:gap-3 w-full"
            >
              {(["record", "transcript", "report", "continuity", "modality", "folder"] as const).map((key) => {
                const isActive = activeTab === key;
                return (
                  <div key={key} className="flex flex-col snap-center shrink-0 w-[270px] sm:w-[290px] lg:w-full">
                    <button
                      onClick={() => changeTab(key)}
                      data-feature={key}
                      className={`flex flex-row items-center justify-between text-left rounded-xl p-4 transition-all duration-300 cursor-pointer border w-full ${
                        isActive
                          ? "bg-gradient-to-br from-[#004D54] to-[#002E32] text-white border-transparent shadow-[0_12px_32px_-12px_rgba(0,77,84,0.35)]"
                          : "bg-white border border-[#E2DED5]/80 hover:bg-[#EDEAE3]/50 text-[#1B2522]"
                      }`}
                    >
                      <div className="flex-1">
                        <h3 className={`font-display text-sm sm:text-[15px] lg:text-base font-bold tracking-tight flex items-center gap-1.5 transition-colors ${
                          isActive ? "text-white" : "text-[#1B2522]"
                        }`}>
                          <span>{tItem(`${key}.title`)}</span>
                          {isActive && <span className="text-[#5bf4bc] text-xs">✦</span>}
                        </h3>
                      </div>
                      <div className={`w-8 h-8 rounded-lg flex items-center justify-center border transition-colors duration-300 shrink-0 ml-3 ${
                        isActive
                          ? "bg-white/10 border-white/20 text-[#5bf4bc]"
                          : "bg-[#004D54]/[0.06] border-[#004D54]/[0.1] text-[#004D54]"
                      }`}>
                        {FEATURE_ICONS[key]}
                      </div>
                    </button>
 
                    {/* Separate description block below button */}
                    <div className={`hidden lg:grid transition-all duration-300 ease-in-out ${
                      isActive ? "grid-rows-[1fr] opacity-100 mt-2.5" : "grid-rows-[0fr] opacity-0"
                    }`}>
                      <div className="overflow-hidden">
                        <div className={`relative p-4 rounded-xl border text-left leading-relaxed font-sans text-xs sm:text-[13px] transition-all duration-300 shadow-md ${
                          isActive
                            ? "bg-gradient-to-br from-[#08363a] to-[#042528] border-[#08363a]/30 text-white/90 shadow-black/15"
                            : "bg-[#FBFAF7]/50 border-black/5 text-[#4E5A55]"
                        }`}>
                          {tItem.rich(`${key}.body`, {
                            bold: (chunks) => (
                              <strong className={`font-bold ${isActive ? "text-white" : "text-[#1B2522]"}`}>
                                {chunks}
                              </strong>
                            ),
                            enter: (chunks) => <span className="block mt-2 sm:mt-2.5">{chunks}</span>
                          })}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Right Side: High-Fidelity App Demo Mockup (1:1 Replica, High Contrast) */}
          <div className="lg:col-span-7 flex flex-col justify-center relative">
            
            {/* White Backing Glow (outside the overflow-hidden frame to let it expand onto the dark background) */}
            <div className="absolute -inset-10 bg-[radial-gradient(circle_at_center,rgba(0,77,84,0.06),transparent_65%)] blur-[60px] pointer-events-none animate-pulse z-0" />
            
            {/* Wrapper for mockup and outside arrows on desktop */}
            <div className="relative w-full max-w-[460px] lg:max-w-[540px] mx-auto">
              
              {/* Left Arrow Button (Outside on Desktop, Hidden on Mobile) */}
              <button
                onClick={handlePrevTab}
                className="hidden lg:flex absolute left-[-60px] xl:left-[-70px] top-1/2 -translate-y-1/2 z-30 w-11 h-11 rounded-full bg-[#004D54]/95 text-white items-center justify-center transition border border-[#B2DFD8]/20 shadow-lg hover:scale-105 active:scale-95 backdrop-blur-[2px] opacity-80 hover:opacity-100 transition-all duration-300 cursor-pointer"
                aria-label="Previous tab"
              >
                <svg className="w-5 h-5 stroke-[2.5]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path d="M15 19l-7-7 7-7" />
                </svg>
              </button>

              {/* Right Arrow Button (Outside on Desktop, Hidden on Mobile) */}
              <button
                onClick={handleNextTab}
                className="hidden lg:flex absolute right-[-60px] xl:right-[-70px] top-1/2 -translate-y-1/2 z-30 w-11 h-11 rounded-full bg-[#004D54]/95 text-white items-center justify-center transition border border-[#B2DFD8]/20 shadow-lg hover:scale-105 active:scale-95 backdrop-blur-[2px] opacity-80 hover:opacity-100 transition-all duration-300 cursor-pointer"
                aria-label="Next tab"
              >
                <svg className="w-5 h-5 stroke-[2.5]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path d="M9 5l7 7-7 7" />
                </svg>
              </button>

              {/* Live demo frame */}
              <div 
                onClick={handleNextTab}
                className="relative w-full rounded-[24px] p-[1.5px] bg-[#2C3533] overflow-hidden shadow-[0_30px_60px_-15px_rgba(27,37,34,0.18)] border border-white/[0.06] z-10 cursor-pointer group hover:shadow-2xl transition-all duration-300"
              >
                {/* Phone/Tablet Screen Interface */}
                <div 
                  onClick={(e) => e.stopPropagation()}
                  style={{
                    '--screen-bg': '#06383e',
                    '--card-bg': 'rgba(255, 255, 255, 0.04)',
                    '--card-border': 'rgba(255, 255, 255, 0.08)',
                    '--text-pri': '#FFFFFF',
                    '--text-pri-90': 'rgba(255, 255, 255, 0.9)',
                    '--text-sec': 'rgba(255, 255, 255, 0.65)',
                    '--text-sec-50': 'rgba(255, 255, 255, 0.45)',
                    '--accent-color': '#5bf4bc',
                    '--accent-bg-light': 'rgba(91, 244, 188, 0.06)',
                    '--accent-border-light': 'rgba(91, 244, 188, 0.12)',
                    '--gold-color': '#fcae2f',
                    '--gold-bg-light': 'rgba(252, 174, 47, 0.06)',
                    '--gold-border-light': 'rgba(252, 174, 47, 0.12)',
                    '--toggle-bg': '#042327',
                    '--toggle-active-bg': '#fcae2f',
                    '--toggle-active-text': '#072023',
                    '--back-btn-bg': '#072a2e',
                    '--back-btn-hover': '#0a3539',
                    '--back-btn-text': 'rgba(255, 255, 255, 0.9)',
                    '--footer-border': 'rgba(255, 255, 255, 0.06)',
                  } as React.CSSProperties}
                  className="relative w-full rounded-[22.5px] overflow-hidden bg-[var(--screen-bg)] pt-5 pb-6 px-2.5 sm:px-5 lg:px-6 h-[580px] lg:h-[690px] flex flex-col justify-between select-text transition-all duration-300 text-[var(--text-pri)]"
                >

                {/* Main Dynamic View Content */}
                <div className="flex-1 flex flex-col justify-start min-h-0">
                  
                  {/* ──────────────────────────────────────────────────────────── */}
                  {/* TAB 0: RECORD VIEW (Safe analysis in progress) */}
                  {/* ──────────────────────────────────────────────────────────── */}
                  {activeTab === "record" && (
                    <RecordTabContent isPl={isPl} setToast={setToast} />
                  )}

                  {/* ──────────────────────────────────────────────────────────── */}
                  {/* TAB 1: REPORT VIEW (1:1 Screnn_app_raport.PNG) */}
                  {/* ──────────────────────────────────────────────────────────── */}
                  {activeTab === "report" && (
                    <div className="animate-[fadeIn_0.3s_ease-out_both] flex flex-col flex-1 relative min-h-0">
                      {isEmailMode ? (
                        <div className="flex flex-col flex-1 justify-between text-left animate-[fadeIn_0.2s_ease-out]">
                          {/* App Bar matching Screenshot 4 */}
                          <div className="flex items-center gap-3.5 mb-3 shrink-0">
                            <button 
                              onClick={() => setIsEmailMode(false)}
                              className="w-8 h-8 rounded-full bg-[var(--back-btn-bg)] hover:bg-[var(--back-btn-hover)] border border-white/5 flex items-center justify-center text-[var(--back-btn-text)] transition-all cursor-pointer shadow-md"
                              aria-label="Back"
                            >
                              <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                              </svg>
                            </button>
                            <h3 className="font-sans font-bold text-[14px] text-[var(--text-pri)] tracking-wide">{isPl ? "Plan działania" : "Action plan"}</h3>
                          </div>

                          {/* Plan Card (stretched flex-1) */}
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-2xl p-4 shadow-xl flex-1 flex flex-col transition-all duration-300 min-h-0">
                            {/* Email Composer Header */}
                            <div className="space-y-1.5 mb-2.5 pb-2.5 border-b border-[var(--card-border)] text-[10px] font-sans shrink-0">
                              <div className="flex items-center gap-1.5 text-[var(--text-sec-50)]">
                                <span className="w-8 shrink-0">{isPl ? "Do:" : "To:"}</span>
                                <span className="text-[var(--accent-color)] font-medium">m.kowalski@gmail.com</span>
                              </div>
                              <div className="flex items-center gap-1.5 text-[var(--text-sec-50)]">
                                <span className="w-8 shrink-0">{isPl ? "Temat:" : "Subject:"}</span>
                                <span className="text-[var(--text-pri-90)] font-medium truncate">
                                  {isPl ? "Twój plan działania z sesji (31.05.2026)" : "Your action plan from session (31.05.2026)"}
                                </span>
                              </div>
                            </div>

                            <textarea
                              value={isPl ? emailDraftPl : emailDraftEn}
                              onChange={(e) => {
                                if (isPl) {
                                  setEmailDraftPl(e.target.value);
                                } else {
                                  setEmailDraftEn(e.target.value);
                                }
                              }}
                              className="w-full flex-1 bg-transparent text-[var(--text-pri-90)] text-[11px] leading-relaxed focus:outline-none resize-none scrollbar-thin overflow-y-auto"
                              placeholder={isPl ? "Wpisz tekst planu..." : "Enter plan text..."}
                            />
                          </div>

                          {/* Action Buttons */}
                          <div className="flex gap-2 mt-3 shrink-0">
                            <button
                              onClick={() => {
                                showToast(isPl ? "Zapisano plan działania!" : "Action plan saved!");
                                setIsEmailMode(false);
                              }}
                              className="flex-1 py-1.5 rounded-xl border border-[var(--card-border)] text-[var(--text-sec)] hover:text-[var(--text-pri)] text-xs font-bold cursor-pointer transition-colors text-center"
                            >
                              {isPl ? "Zapisz" : "Save"}
                            </button>
                            <button
                              onClick={handleSendEmail}
                              disabled={emailState === "sending"}
                              className="flex-1 py-1.5 rounded-xl bg-[var(--toggle-active-bg)] text-[var(--toggle-active-text)] hover:opacity-90 disabled:opacity-75 text-xs font-bold cursor-pointer transition-colors text-center flex items-center justify-center gap-1.5"
                            >
                              {emailState === "sending" ? (
                                <>
                                  <svg className="animate-spin h-3.5 w-3.5 text-current" fill="none" viewBox="0 0 24 24">
                                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                                  </svg>
                                  <span>{isPl ? "Wysyłanie..." : "Sending..."}</span>
                                </>
                              ) : (
                                <span>{isPl ? "Zapisz i wyślij" : "Save & send"}</span>
                              )}
                            </button>
                          </div>
                        </div>
                      ) : (
                        <>
                          {/* App Bar */}
                          <div className="flex justify-between items-center mb-3">
                            <button 
                              className="w-8 h-8 rounded-full bg-[var(--back-btn-bg)] hover:bg-[var(--back-btn-hover)] border border-white/5 flex items-center justify-center text-[var(--back-btn-text)] transition-all cursor-pointer shadow-md"
                              aria-label="Back"
                            >
                              <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                              </svg>
                            </button>
                            <h3 className="font-sans font-bold text-[16px] text-[var(--text-pri)] tracking-wide">Raport</h3>
                            <div className="flex items-center gap-3.5 text-[var(--text-sec)]">
                              {/* Thumbs Up icon (like) */}
                              <svg 
                                onClick={(e) => { 
                                  e.stopPropagation(); 
                                  const nextLiked = !isLiked;
                                  setIsLiked(nextLiked); 
                                  if (nextLiked) {
                                    setIsDisliked(false);
                                    showToast(isPl ? "Dzięki za pozytywną ocenę." : "Thanks for the positive rating."); 
                                  }
                                }} 
                                className={`w-[18px] h-[18px] transition-all cursor-pointer ${
                                  isLiked ? "text-[var(--gold-color)]" : "text-[var(--text-sec)] hover:text-[var(--gold-color)]"
                                }`} 
                                fill={isLiked ? "var(--gold-color)" : "none"}
                                stroke="currentColor" 
                                strokeWidth="2" 
                                viewBox="0 0 24 24" 
                                aria-label="Like"
                              >
                                <path d="M14 9V5a3 3 0 0 0-3-3l-4 9v11h11.28a2 2 0 0 0 2-1.7l1.38-9a2 2 0 0 0-2-2.3zM7 22H4a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2h3" />
                              </svg>

                              {/* Thumbs Down icon (dislike) */}
                              <svg 
                                onClick={(e) => { 
                                  e.stopPropagation(); 
                                  const nextDisliked = !isDisliked;
                                  setIsDisliked(nextDisliked); 
                                  if (nextDisliked) {
                                    setIsLiked(false);
                                    setActiveDialog("dislike"); 
                                  }
                                }} 
                                className={`w-[18px] h-[18px] transition-all cursor-pointer ${
                                  isDisliked ? "text-[#ff4b4b]" : "text-[var(--text-sec)] hover:text-[#ff4b4b]"
                                }`} 
                                fill={isDisliked ? "#ff4b4b" : "none"}
                                stroke={isDisliked ? "#ff4b4b" : "currentColor"} 
                                strokeWidth="2" 
                                viewBox="0 0 24 24" 
                                aria-label="Dislike"
                              >
                                <path d="M10 15v4a3 3 0 0 0 3 3l4-9V2H5.72a2 2 0 0 0-2 1.7l-1.38 9a2 2 0 0 0 2 2.3zm8-13h3a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2h-3" />
                              </svg>

                              {/* Envelope send icon */}
                              <svg 
                                onClick={(e) => { 
                                  e.stopPropagation(); 
                                  setIsEmailMode(true); 
                                }} 
                                className="w-[18px] h-[18px] text-[var(--text-sec)] hover:text-[var(--accent-color)] transition-colors cursor-pointer" 
                                fill="none" 
                                stroke="currentColor" 
                                strokeWidth="2" 
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                viewBox="0 0 24 24" 
                                aria-label="Send email"
                              >
                                <rect width="20" height="16" x="2" y="4" rx="2" />
                                <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
                              </svg>

                              {/* Copy icon */}
                              <svg onClick={(e) => { e.stopPropagation(); handleCopy(); }} className="w-[18px] h-[18px] text-[var(--text-sec)] hover:text-[var(--accent-color)] transition-colors cursor-pointer" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24" aria-label="Copy">
                                <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                              </svg>
                            </div>
                          </div>

                          {/* Pill Toggle Tab */}
                          <div className="bg-[var(--toggle-bg)] rounded-lg p-1 flex items-center mb-4 border border-[var(--card-border)] select-none">
                            <span 
                              onClick={() => setActiveTab("transcript")}
                              className="flex-1 text-center py-1.5 text-xs text-[var(--text-sec)] font-semibold cursor-pointer transition-colors hover:text-[var(--text-pri)]"
                            >
                              {isPl ? "Transkrypcja" : "Transcript"}
                            </span>
                            <span 
                              onClick={() => setActiveTab("report")}
                              className="flex-1 text-center py-1.5 text-xs bg-[var(--toggle-active-bg)] text-[var(--toggle-active-text)] font-bold rounded-md cursor-pointer transition-colors"
                            >
                              {isPl ? "Raport" : "Report"}
                            </span>
                          </div>

                      {/* Sub-tabs Row — horizontally scrollable */}
                      <div ref={tabsRowRef} className="flex gap-2.5 mb-4 overflow-x-auto scrollbar-none pb-1 shrink-0">
                        {reportSubTabs.map((subTab) => (
                          <button
                            key={subTab.id}
                            id={`tab-btn-${subTab.id}`}
                            onClick={() => handleSubTabClick(subTab.id)}
                            className={`px-3.5 py-1.5 rounded-full text-xs font-bold whitespace-nowrap transition-colors cursor-pointer shrink-0 border ${
                              reportSubTab === subTab.id
                                ? "border-[var(--gold-border-light)] bg-[var(--accent-bg-light)] text-[var(--gold-color)]"
                                : "border-[var(--card-border)] text-[var(--text-sec-50)] hover:text-[var(--text-pri)] hover:border-[var(--text-sec-50)]/30"
                            }`}
                          >
                            {isPl ? subTab.label : subTab.labelEn}
                          </button>
                        ))}
                      </div>

                      {/* Scrollable Report Content */}
                      <div 
                        ref={reportScrollRef}
                        onScroll={handleReportScroll}
                        className="flex-1 space-y-4 overflow-y-auto pr-0.5 scrollbar-thin select-text scroll-smooth min-h-0 pb-6"
                      >
                        
                        {/* Session Title Header & Overview */}
                        <div id="sec-summary" className="space-y-4 pt-1">
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] border-l-4 border-l-[var(--gold-color)] rounded-r-xl p-4 shadow-md text-left transition-all duration-300">
                            <div className="flex items-start gap-2.5 mb-1.5">
                              <span className="text-[var(--gold-color)] text-sm mt-0.5">✦</span>
                              <h4 className="font-sans font-bold text-[var(--text-pri)] text-[13px] lg:text-[15px] leading-snug">
                                {isPl ? "Pogorszenie samopoczucia, bóle głowy i brak postępu" : "Deterioration of well-being, headaches and lack of progress"}
                              </h4>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13px] leading-relaxed text-[var(--text-pri-90)]">
                              <strong className="text-[var(--gold-color)]">{isPl ? "PODSUMOWANIE: " : "SUMMARY: "}</strong>
                              {isPl 
                                ? "Klient zgłasza pogorszenie samopoczucia, nietypowe bóle głowy i brak chęci do działania, pomimo wcześniejszej poprawy. Odczuwa brak postępu i poczucie „mechanicznego uszkodzenia”, co prowadzi do myśli depresyjnych. Terapeuta dopytuje o objawy i próby radzenia sobie."
                                : "The client reports a deterioration of well-being, unusual headaches, and a lack of desire to act, despite prior improvement. He feels a lack of progress and a sense of 'mechanical damage', leading to depressive thoughts. The therapist inquires about symptoms and coping attempts."}
                            </p>
                          </div>

                        {/* SECTION 1: PODSUMOWANIE SESJI */}
                          <div className="bg-[var(--card-bg)] rounded-xl p-4 border border-[var(--card-border)] text-left transition-all duration-300 space-y-3">
                            <div className="text-[9px] lg:text-[11px] uppercase tracking-wider text-[var(--accent-color)] font-mono mb-0.5 font-bold">
                              {isPl ? "Raport • Część I" : "Report • Part I"}
                            </div>
                            <h4 className="font-sans text-[13.5px] lg:text-[15.5px] font-bold text-[var(--text-pri)] mb-3 pb-1 border-b border-[var(--card-border)]">
                              <span>{isPl ? "Podsumowanie sesji" : "Session Summary"}</span>
                            </h4>
                            
                            {/* 1. Problem docelowy */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-1">
                              <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--gold-color)] block">{isPl ? "1. Problem docelowy sesji" : "1. Target Problem"}</span>
                              <p className="text-[11px] lg:text-[12.5px] text-[var(--text-pri-90)] leading-relaxed">
                                {isPl 
                                  ? "Klient zgłasza pogarszające się samopoczucie fizyczne i psychiczne, brak energii i motywacji, oraz utrwalone poczucie „mechanicznego uszkodzenia” pomimo podejmowanych prób."
                                  : "The client reports deteriorating physical and mental well-being, lack of energy and motivation, and a persistent sense of 'mechanical damage' despite attempts made."}
                              </p>
                            </div>

                            {/* 2. Model poznawczy A-B-C */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-3">
                              <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--gold-color)] block">{isPl ? "2. Model poznawczy (A-B-C)" : "2. Cognitive Model (A-B-C)"}</span>
                              <div className="grid grid-cols-1 gap-2.5">
                                <div className="border-l-2 border-[var(--accent-color)]/30 bg-[var(--accent-bg-light)] px-3 py-2 rounded-r">
                                  <span className="block text-[9px] uppercase font-bold text-[var(--accent-color)] tracking-wider">{isPl ? "A. Sytuacja (Wyzwalacz)" : "A. Situation (Trigger)"}</span>
                                  <span className="text-[11px] text-[var(--text-pri-90)] mt-0.5 block leading-relaxed">
                                    {isPl ? "Pogarszające się samopoczucie fizyczne (bóle głowy, „zatokowe”) i psychiczne (brak chęci, depresyjność)." : "Deteriorating physical and mental well-being."}
                                  </span>
                                </div>
                                <div className="border-l-2 border-[var(--gold-color)]/30 bg-[var(--gold-bg-light)] px-3 py-2 rounded-r">
                                  <span className="block text-[9px] uppercase font-bold text-[var(--gold-color)] tracking-wider">{isPl ? "B. Myśli automatyczne (Cytaty z sesji)" : "B. Automatic Thoughts"}</span>
                                  <div className="mt-1.5 space-y-1.5">
                                    <Quote>{isPl ? "jestem jakoś za, zablokowany właśnie że to jakoś uszkodzenie mam mechaniczne" : "I am somehow blocked, that I have mechanical damage"}</Quote>
                                    <Quote>{isPl ? "nie widzę już żadnych specjalnych zmian kurczę" : "I don't see any special changes anymore"}</Quote>
                                  </div>
                                </div>
                                <div className="border-l-2 border-[var(--accent-color)]/30 bg-[var(--accent-bg-light)] px-3 py-2 rounded-r">
                                  <span className="block text-[9px] uppercase font-bold text-[var(--accent-color)] tracking-wider">{isPl ? "C. Konsekwencje (Emocje & Reakcje)" : "C. Consequences"}</span>
                                  <span className="text-[11px] text-[var(--text-pri-90)] mt-0.5 block leading-relaxed">
                                    {isPl ? "Poczucie słabości, frustracja, „depresyjnie”; próby spacerów, branie leków, „zmuszanie się” do każdej czynności." : "Feeling of weakness, frustration, 'depressive'; attempts to walk, taking medication."}
                                  </span>
                                </div>
                              </div>
                            </div>

                            {/* 3. Zastosowane techniki */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-1">
                              <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--gold-color)] block">{isPl ? "3. Zastosowane techniki CBT" : "3. Applied CBT Techniques"}</span>
                              <p className="text-[11px] lg:text-[12.5px] text-[var(--text-pri-90)] leading-relaxed">
                                {isPl 
                                  ? "Terapeuta próbował identyfikować myśli automatyczne (pytanie o „uszkodzenie mechaniczne”) i stosował wstępne pytania sokratyczne („co by ci pomogło?”). Wspomniano o psychoedukacji (techniki oddechowe, spacery) z poprzedniej sesji."
                                  : "The therapist tried to identify automatic thoughts and used Socratic questions."}
                              </p>
                            </div>

                            {/* 4. Zadanie domowe */}
                            <div className="bg-[#ffa3a3]/10 border border-[#ffa3a3]/25 rounded-xl p-3.5 flex items-start gap-2.5">
                              <span className="text-[#ffa3a3] text-[13px] mt-0.5">⚠️</span>
                              <div>
                                <span className="text-[9px] uppercase tracking-wider font-bold text-[#ffa3a3] block">{isPl ? "4. Ustalony plan działania (Zadanie)" : "4. Homework Assigned"}</span>
                                <p className="text-[11px] lg:text-[12.5px] text-[#ffa3a3] font-semibold leading-relaxed mt-0.5">
                                  {isPl ? "Brak wyraźnie ustalonego, konkretnego zadania domowego na koniec sesji." : "No clearly established, specific homework at the end of the session."}
                                </p>
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* SECTION 2: WNIKLIWE OBSERWACJE */}
                        <div id="sec-observations" className="space-y-4 pt-1">
                          <div className="bg-[var(--card-bg)] rounded-xl p-4 border border-[var(--card-border)] text-left transition-all duration-300 space-y-3.5">
                            <div className="text-[9px] lg:text-[11px] uppercase tracking-wider text-[var(--accent-color)] font-mono mb-0.5 font-bold">
                              {isPl ? "Raport • Część II" : "Report • Part II"}
                            </div>
                            <h4 className="font-sans text-[13.5px] lg:text-[15.5px] font-bold text-[var(--text-pri)] mb-3 pb-1 border-b border-[var(--card-border)] flex items-center justify-between">
                              <span>{isPl ? "Wnikliwe obserwacje" : "Insightful Observations"}</span>
                            </h4>
                            
                            {/* Obs #1 */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-3">
                              <div className="flex items-center justify-between">
                                <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Obserwacja #1" : "Observation #1"}</span>
                                <span className="text-[9px] px-2 py-0.5 bg-[var(--gold-bg-light)] text-[var(--gold-color)] rounded-full border border-[var(--gold-border-light)] font-bold">{isPl ? "Przekonanie" : "Belief"}</span>
                              </div>
                              <h5 className="font-sans font-bold text-[12px] lg:text-[13.5px] text-[var(--text-pri)] leading-snug">
                                {isPl ? "Utrwalone przekonanie o „mechanicznym uszkodzeniu”" : "Persistent belief in 'mechanical damage'"}
                              </h5>
                              <div className="space-y-1.5">
                                <span className="block text-[8px] uppercase tracking-widest font-mono text-[var(--text-sec-50)]">{isPl ? "Dowody z transkrypcji:" : "Transcription evidence:"}</span>
                                <Quote>{isPl ? "jestem jakoś za, zablokowany właśnie że to jakoś uszkodzenie mam mechaniczne" : "I have mechanical damage"}</Quote>
                                <Quote>{isPl ? "to właśnie nie mogę Robię, próbuję, ale to właśnie odbija od tego właśnie wszystkiego" : "I try, but everything bounces off of it"}</Quote>
                                <Quote>{isPl ? "Wydaje się, że właśnie już wcześniej byłem ten, tylko że jako dziecko to było mniej zauważalne po prostu że wcześniej jakoś dysfunkcję po prostu nie" : "It seems I was like this before, but as a child it was less noticeable"}</Quote>
                              </div>
                              <div className="bg-[var(--accent-bg-light)] border border-[var(--accent-border-light)] rounded-xl p-3 text-[11px] lg:text-[12.5px] leading-relaxed text-[var(--text-pri-90)] mt-2">
                                <strong className="text-[var(--accent-color)] block mb-0.5">{isPl ? "Analiza w modelu CBT:" : "CBT Analysis:"}</strong>
                                {isPl 
                                  ? "To przekonanie działa jako zniekształcenie poznawcze (personalizacja/katastrofizacja), przypisując wewnętrzną wadę do jego stanu. Utrudnia dostrzeżenie możliwości zmiany, wzmacniając bezradność."
                                  : "Acts as personalization/catastrophizing. Hinders change, reinforcing helplessness."}
                              </div>
                            </div>

                            {/* Obs #2 */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-3">
                              <div className="flex items-center justify-between">
                                <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Obserwacja #2" : "Observation #2"}</span>
                                <span className="text-[9px] px-2 py-0.5 bg-[var(--gold-bg-light)] text-[var(--gold-color)] rounded-full border border-[var(--gold-border-light)] font-bold">{isPl ? "Zachowanie" : "Behavior"}</span>
                              </div>
                              <h5 className="font-sans font-bold text-[12px] lg:text-[13.5px] text-[var(--text-pri)] leading-snug">
                                {isPl ? "Wzorzec behawioralny: „Zmuszanie się” bez poczucia sensu" : "Forcing oneself without meaning"}
                              </h5>
                              <div className="space-y-1.5">
                                <span className="block text-[8px] uppercase tracking-widest font-mono text-[var(--text-sec-50)]">{isPl ? "Dowody z transkrypcji:" : "Transcription evidence:"}</span>
                                <Quote>{isPl ? "muszę ręcznie kurde każdą czynność po prostu kurczę nad każdą czynnością po prostu muszę muszę ją nie ma tego automatyzmu takiego..." : "I have to manually do every single action"}</Quote>
                              </div>
                              <div className="bg-[var(--accent-bg-light)] border border-[var(--accent-border-light)] rounded-xl p-3 text-[11px] lg:text-[12.5px] leading-relaxed text-[var(--text-pri-90)] mt-2">
                                <strong className="text-[var(--accent-color)] block mb-0.5">{isPl ? "Analiza w modelu CBT:" : "CBT Analysis:"}</strong>
                                {isPl 
                                  ? "Zachowanie napędzane poczuciem obowiązku, a nie motywacją. Wzmaga negatywne myśli o braku postępu, co prowadzi do wyczerpania i utrwalenia cyklu depresyjnego."
                                  : "Behavior driven by duty, reinforcing thoughts of no progress. Leads to exhaustion."}
                              </div>
                            </div>

                            {/* Obs #3 */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-3">
                              <div className="flex items-center justify-between">
                                <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Obserwacja #3" : "Observation #3"}</span>
                                <span className="text-[9px] px-2 py-0.5 bg-[var(--gold-bg-light)] text-[var(--gold-color)] rounded-full border border-[var(--gold-border-light)] font-bold">{isPl ? "Deficyt" : "Deficit"}</span>
                              </div>
                              <h5 className="font-sans font-bold text-[12px] lg:text-[13.5px] text-[var(--text-pri)] leading-snug">
                                {isPl ? "Brak precyzyjnej identyfikacji myśli automatycznych" : "Lack of precise thought identification"}
                              </h5>
                              <div className="space-y-1">
                                <span className="block text-[8px] uppercase tracking-widest font-mono text-[var(--text-sec-50)]">{isPl ? "Opis i dowody z sesji:" : "Session description:"}</span>
                                <p className="text-[11px] lg:text-[12px] text-[var(--text-pri-90)] leading-relaxed">
                                  {isPl ? "Klient opisuje ogólne stany („słabo się czuję”, „depresyjnie”) i przekonania („uszkodzenie mechaniczne”), ale terapeuta nie prowadzi go do szczegółowej analizy konkretnych sytuacji w modelu A-B-C." : "Client describes general states but therapist doesn't lead to ABC analysis."}
                                </p>
                              </div>
                              <div className="bg-[var(--accent-bg-light)] border border-[var(--accent-border-light)] rounded-xl p-3 text-[11px] lg:text-[12.5px] leading-relaxed text-[var(--text-pri-90)] mt-2">
                                <strong className="text-[var(--accent-color)] block mb-0.5">{isPl ? "Analiza w modelu CBT:" : "CBT Analysis:"}</strong>
                                {isPl 
                                  ? "Brak precyzji utrudnia restrukturyzację. Bez konkretnych przykładów klient pozostaje w ogólnym poczuciu beznadziei, a terapeuta nie ma punktu zaczepienia."
                                  : "Hinders cognitive restructuring, leaving client in generalized hopelessness."}
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* SECTION 3: PLAN DZIAŁANIA KLIENTA */}
                        <div id="sec-plan" className="space-y-4 pt-1">
                          <div className="bg-[var(--card-bg)] rounded-xl p-4 border border-[var(--card-border)] text-left transition-all duration-300 space-y-3.5">
                            <div className="text-[9px] lg:text-[11px] uppercase tracking-wider text-[var(--accent-color)] font-mono mb-0.5 font-bold">
                              {isPl ? "Raport • Część III" : "Report • Part III"}
                            </div>
                            <h4 className="font-sans text-[13.5px] lg:text-[15.5px] font-bold text-[var(--text-pri)] mb-3 pb-1 border-b border-[var(--card-border)] flex items-center justify-between">
                              <span>{isPl ? "Plan działania klienta" : "Client Action Plan"}</span>
                            </h4>
                            
                            {/* Zadanie #1 */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-3">
                              <div className="flex items-center justify-between">
                                <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Zadanie #1" : "Task #1"}</span>
                                <span className="text-[9px] px-2.5 py-0.5 bg-[#5bf4bc]/10 text-[#5bf4bc] rounded-full border border-[#5bf4bc]/20 font-bold">{isPl ? "Dziennik" : "Journal"}</span>
                              </div>
                              <h5 className="font-sans font-bold text-[13px] lg:text-[14px] text-[var(--text-pri)] leading-snug">
                                {isPl ? "Dziennik Myśli Automatycznych (A-B-C)" : "Automatic Thoughts Journal (A-B-C)"}
                              </h5>
                              
                              <div className="space-y-1">
                                <span className="text-[9px] uppercase font-bold text-[var(--gold-color)] tracking-wider block">{isPl ? "Cel terapeutyczny" : "Therapeutic Goal"}</span>
                                <p className="text-[11px] lg:text-[12px] text-[var(--text-pri-90)] leading-relaxed">
                                  {isPl ? "Zwiększenie świadomości związku między sytuacjami, myślami, emocjami i zachowaniami; zebranie danych do restrukturyzacji poznawczej." : "Increase awareness of thoughts and behaviors."}
                                </p>
                              </div>
                              
                              <div className="space-y-1.5 p-3 bg-white/[0.015] border border-[var(--card-border)] rounded-xl">
                                <span className="text-[9px] uppercase font-bold text-[var(--gold-color)] tracking-wider block">{isPl ? "Szczegółowa instrukcja" : "Instructions"}</span>
                                <p className="text-[11px] text-[var(--text-sec)] leading-relaxed">
                                  {isPl ? "Zapisuj przez najbliższy tydzień 3-5 razy dziennie, kiedy poczujesz się gorzej (np. „słabo,” „zablokowany”):" : "Record 3-5 times a day when feeling worse:"}
                                </p>
                                <div className="grid grid-cols-2 gap-2 mt-1">
                                  <div className="p-2 bg-[var(--toggle-bg)] rounded border border-[var(--card-border)] text-[10px]">
                                    <strong className="text-[var(--accent-color)] block">1. Sytuacja</strong>
                                    <span className="text-[var(--text-sec)]">{isPl ? "Co się wydarzyło? Gdzie?" : "What happened? Where?"}</span>
                                  </div>
                                  <div className="p-2 bg-[var(--toggle-bg)] rounded border border-[var(--card-border)] text-[10px]">
                                    <strong className="text-[var(--accent-color)] block">2. Myśl</strong>
                                    <span className="text-[var(--text-sec)]">{isPl ? "Co pomyślałeś dokładnie?" : "What did you think?"}</span>
                                  </div>
                                  <div className="p-2 bg-[var(--toggle-bg)] rounded border border-[var(--card-border)] text-[10px]">
                                    <strong className="text-[var(--accent-color)] block">3. Emocja</strong>
                                    <span className="text-[var(--text-sec)]">{isPl ? "Co poczułeś? (0-100%)" : "What did you feel? (0-100%)"}</span>
                                  </div>
                                  <div className="p-2 bg-[var(--toggle-bg)] rounded border border-[var(--card-border)] text-[10px]">
                                    <strong className="text-[var(--accent-color)] block">4. Zachowanie</strong>
                                    <span className="text-[var(--text-sec)]">{isPl ? "Co wtedy zrobiłeś?" : "What did you do?"}</span>
                                  </div>
                                </div>
                              </div>
                              
                              <div className="bg-[var(--gold-bg-light)] border border-[var(--gold-border-light)] rounded-xl p-3 text-[10.5px] leading-relaxed text-[var(--text-pri-90)]">
                                <strong className="text-[var(--gold-color)] block mb-0.5">{isPl ? "Potencjalne trudności i jak sobie radzić:" : "Difficulties & Tip:"}</strong>
                                {isPl 
                                  ? "Poczucie, że „to nic nie da”, trudność w identyfikacji myśli. Wskazówka: „Po prostu spróbuj to zapisać, nawet jeśli wydaje się to bez sensu. To tylko zbieranie danych, nie musisz tego oceniać.”" 
                                  : "Resistance. Tip: 'Just try to write it down, treat it as a small experiment.'"}
                              </div>
                            </div>

                            {/* Zadanie #2 */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-3">
                              <div className="flex items-center justify-between">
                                <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Zadanie #2" : "Task #2"}</span>
                                <span className="text-[9px] px-2.5 py-0.5 bg-[#5bf4bc]/10 text-[#5bf4bc] rounded-full border border-[#5bf4bc]/20 font-bold">{isPl ? "Eksperyment" : "Experiment"}</span>
                              </div>
                              <h5 className="font-sans font-bold text-[13px] lg:text-[14px] text-[var(--text-pri)] leading-snug">
                                {isPl ? "Eksperyment behawioralny: „Małe kroki ku aktywności”" : "Behavioral Experiment: 'Small steps to activity'"}
                              </h5>
                              
                              <div className="space-y-1">
                                <span className="text-[9px] uppercase font-bold text-[var(--gold-color)] tracking-wider block">{isPl ? "Cel terapeutyczny" : "Therapeutic Goal"}</span>
                                <p className="text-[11px] lg:text-[12px] text-[var(--text-pri-90)] leading-relaxed">
                                  {isPl ? "Przełamanie poczucia „mechanicznego uszkodzenia” i „zmuszania się” poprzez doświadczenie małego sukcesu i zebranie danych o wpływie aktywności na nastrój." : "Breaking the sense of 'forcing oneself'."}
                                </p>
                              </div>
                              
                              <div className="space-y-2.5 p-3 bg-white/[0.015] border border-[var(--card-border)] rounded-xl text-[11px] text-[var(--text-sec)]">
                                <div>
                                  <strong className="text-[var(--accent-color)] block text-[9px] uppercase font-bold tracking-wider">{isPl ? "Przekonanie do przetestowania:" : "Belief to test:"}</strong>
                                  <span className="italic">„Robię, próbuję, ale to właśnie odbija od tego wszystkiego / nic mi nie pomaga.”</span>
                                </div>
                                <div className="pt-2 border-t border-[var(--card-border)]">
                                  <strong className="text-[var(--accent-color)] block text-[9px] uppercase font-bold tracking-wider">{isPl ? "Sposób przeprowadzenia:" : "Method:"}</strong>
                                  <span>{isPl ? "Wybierz jedną, bardzo małą aktywność, którą kiedyś lubiłeś lub która jest neutralna (np. posłuchanie jednej piosenki, 5 minut czytania, krótki spacer wokół bloku). Wykonaj ją raz dziennie przez 3 dni." : "Choose one tiny activity. Perform it once a day for 3 days."}</span>
                                </div>
                                <div className="pt-2 border-t border-[var(--card-border)]">
                                  <strong className="text-[var(--accent-color)] block text-[9px] uppercase font-bold tracking-wider">{isPl ? "Przewidywania klienta & Obserwacja:" : "Predictions & Observation:"}</strong>
                                  <span>{isPl ? "Zapisz przewidywania (0-100%). Po wykonaniu aktywności oceń nastrój (0-10) i poziom „zablokowania” (0-10)." : "Before activity write predicted mood (%), after rate mood (0-10)."}</span>
                                </div>
                              </div>
                              
                              <div className="bg-[var(--gold-bg-light)] border border-[var(--gold-border-light)] rounded-xl p-3 text-[10.5px] leading-relaxed text-[var(--text-pri-90)]">
                                <strong className="text-[var(--gold-color)] block mb-0.5">{isPl ? "Potencjalne trudności i jak sobie radzić:" : "Difficulties & Tip:"}</strong>
                                {isPl 
                                  ? "Opór, poczucie braku sensu. Wskazówka: „Pamiętaj, że to jest eksperyment. Nie chodzi o to, żeby od razu poczuć się świetnie, ale żeby zebrać dane. Nawet jeśli będzie tak, jak przewidujesz, to też jest cenna informacja.”" 
                                  : "Resistance, pointlessness. Tip: 'Remember this is an experiment to collect data.'"}
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* SECTION 4: PROPOZYCJE INTERWENCJI */}
                        <div id="sec-proposals" className="space-y-4 pt-1">
                          <div className="bg-[var(--card-bg)] rounded-xl p-4 border border-[var(--card-border)] text-left transition-all duration-300 space-y-3.5">
                            <div className="text-[9px] lg:text-[11px] uppercase tracking-wider text-[var(--accent-color)] font-mono mb-0.5 font-bold">
                              {isPl ? "Raport • Część IV" : "Report • Part IV"}
                            </div>
                            <h4 className="font-sans text-[13.5px] lg:text-[15.5px] font-bold text-[var(--text-pri)] mb-3 pb-1 border-b border-[var(--card-border)] flex items-center justify-between">
                              <span>{isPl ? "Propozycje interwencji" : "Intervention Proposals"}</span>
                            </h4>
                            
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-3">
                              <div className="flex items-center justify-between">
                                <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Propozycja #1" : "Proposal #1"}</span>
                                <span className="text-[9px] px-2.5 py-0.5 bg-[#a855f7]/10 text-[#a855f7] rounded-full border border-[#a855f7]/20 font-bold">{isPl ? "Protokół" : "Protocol"}</span>
                              </div>
                              <h5 className="font-sans font-bold text-[13px] lg:text-[14px] text-[var(--text-pri)] leading-snug">
                                {isPl ? "Restrukturyzacja poznawcza przekonania o „mechanicznym uszkodzeniu”" : "Cognitive Restructuring of 'mechanical damage' belief"}
                              </h5>
                              
                              <div className="space-y-1.5 p-3 bg-[var(--accent-bg-light)] border border-[var(--accent-border-light)] rounded-xl text-[11px] text-[var(--text-pri-90)]">
                                <div>
                                  <strong className="text-[var(--accent-color)] block text-[9px] uppercase font-bold tracking-wider">{isPl ? "Cel główny:" : "Main Goal:"}</strong>
                                  <span>{isPl ? "Podważenie i osłabienie przekonania klienta o jego „mechanicznym uszkodzeniu” i „dysfunkcji,” które wzmacnia jego poczucie beznadziei i bierności." : "Challenge and weaken the client's belief in 'mechanical damage'."}</span>
                                </div>
                                <div className="pt-2 border-t border-[var(--accent-border-light)]">
                                  <strong className="text-[var(--accent-color)] block text-[9px] uppercase font-bold tracking-wider">{isPl ? "Podstawy teoretyczne:" : "Theoretical basis:"}</strong>
                                  <span>{isPl ? "Przekonania klienta o jego stanie są prawdopodobnie zniekształceniami poznawczymi (np. katastrofizacja, etykietowanie), które utrzymują cykl depresyjny. Restrukturyzacja ma na celu zastąpienie ich bardziej realistycznymi i adaptacyjnymi myślami." : "Beliefs are cognitive distortions maintaining the cycle."}</span>
                                </div>
                              </div>

                              <div className="space-y-2">
                                <strong className="text-[var(--gold-color)] block text-[9px] uppercase font-bold tracking-wider">{isPl ? "Scenariusz krok po kroku:" : "Step-by-step scenario:"}</strong>
                                <div className="space-y-1.5 font-sans text-[11px] text-[var(--text-sec)]">
                                  <div className="flex gap-2.5 items-start bg-white/[0.01] p-2 rounded border border-[var(--card-border)]">
                                    <span className="font-bold text-[var(--accent-color)] shrink-0 font-mono text-[10px]">Krok 1</span>
                                    <div>
                                      <strong className="text-[var(--text-pri)] block text-[10.5px]">{isPl ? "Identyfikacja przekonania:" : "Identify belief:"}</strong>
                                      {isPl ? "„Mówi pan, że czuje się pan 'mechanicznie uszkodzony'. Co dokładnie ma pan na myśli?”" : "„You say you feel 'mechanically damaged'. What exactly do you mean?”"}
                                    </div>
                                  </div>
                                  <div className="flex gap-2.5 items-start bg-white/[0.01] p-2 rounded border border-[var(--card-border)]">
                                    <span className="font-bold text-[var(--accent-color)] shrink-0 font-mono text-[10px]">Krok 2</span>
                                    <div>
                                      <strong className="text-[var(--text-pri)] block text-[10.5px]">{isPl ? "Poszukiwanie dowodów:" : "Look for evidence:"}</strong>
                                      {isPl ? "„Jakie są dowody na to, że jest pan 'mechanicznie uszkodzony'? A jakie są dowody przeciwko temu?”" : "„What evidence supports this? What contradicts it?”"}
                                    </div>
                                  </div>
                                  <div className="flex gap-2.5 items-start bg-white/[0.01] p-2 rounded border border-[var(--card-border)]">
                                    <span className="font-bold text-[var(--accent-color)] shrink-0 font-mono text-[10px]">Krok 3</span>
                                    <div>
                                      <strong className="text-[var(--text-pri)] block text-[10.5px]">{isPl ? "Alternatywne wyjaśnienia:" : "Alternative explanations:"}</strong>
                                      {isPl ? "„Gdyby ktoś inny opisał swoje objawy w ten sposób, jakie inne wyjaśnienia mogłyby przyjść panu do głowy?”" : "„If someone else had these symptoms, what else could explain them?”"}
                                    </div>
                                  </div>
                                  <div className="flex gap-2.5 items-start bg-white/[0.01] p-2 rounded border border-[var(--card-border)]">
                                    <span className="font-bold text-[var(--accent-color)] shrink-0 font-mono text-[10px]">Krok 4</span>
                                    <div>
                                      <strong className="text-[var(--text-pri)] block text-[10.5px]">{isPl ? "Konsekwencje przekonania:" : "Consequences:"}</strong>
                                      {isPl ? "„Jakie są konsekwencje myślenia o sobie w ten sposób? Jak to wpływa na działania?”" : "„How does thinking this way affect your mood and behavior?”"}
                                    </div>
                                  </div>
                                  <div className="flex gap-2.5 items-start bg-white/[0.01] p-2 rounded border border-[var(--card-border)]">
                                    <span className="font-bold text-[var(--accent-color)] shrink-0 font-mono text-[10px]">Krok 5</span>
                                    <div>
                                      <strong className="text-[var(--text-pri)] block text-[10.5px]">{isPl ? "Alternatywna myśl:" : "Alternative thought:"}</strong>
                                      {isPl ? "„Gdyby miał pan opisać swój stan w inny sposób, który byłby równie prawdziwy, ale mniej obciążający?”" : "„How could you describe this in a way that is less heavy?”"}
                                    </div>
                                  </div>
                                </div>
                              </div>
                              
                              <div className="bg-[var(--gold-bg-light)] border border-[var(--gold-border-light)] rounded-xl p-3 text-[10.5px] leading-relaxed text-[var(--text-pri-90)]">
                                <strong className="text-[var(--gold-color)] block mb-0.5">{isPl ? "Na co zwrócić uwagę:" : "What to look out for:"}</strong>
                                {isPl 
                                  ? "Klient może być bardzo przywiązany do tego przekonania. Ważne jest, aby podejść do tego z empatią i ciekawością, a nie konfrontacyjnie. Skupić się na zbieraniu danych i konsekwencjach, a nie na „poprawianiu” klienta."
                                  : "The client may be attached to this belief. Approach with empathy and curiosity."}
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* SECTION 5: WĄTKI DO POGŁĘBIENIA */}
                        <div id="sec-threads" className="space-y-4 pt-1">
                          <div className="bg-[var(--card-bg)] rounded-xl p-4 border border-[var(--card-border)] text-left transition-all duration-300 space-y-3.5">
                            <div className="text-[9px] lg:text-[11px] uppercase tracking-wider text-[var(--accent-color)] font-mono mb-0.5 font-bold">
                              {isPl ? "Raport • Część V" : "Report • Part V"}
                            </div>
                            <h4 className="font-sans text-[13.5px] lg:text-[15.5px] font-bold text-[var(--text-pri)] mb-3 pb-1 border-b border-[var(--card-border)] flex items-center justify-between">
                              <span>{isPl ? "Wątki do pogłębienia" : "Threads to Deepen"}</span>
                            </h4>
                            
                            {/* 1. Przekonania pośredniczące */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-3">
                              <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Konceptualizacja • Przekonania pośredniczące" : "Formulation • Intermediate Beliefs"}</span>
                              <div className="space-y-2 text-[11px] text-[var(--text-pri-90)]">
                                <div className="bg-[var(--toggle-bg)] border border-[var(--card-border)] p-3 rounded-lg leading-relaxed">
                                  <strong className="text-[var(--gold-color)] block mb-1">{isPl ? "„Jeśli nie widzę natychmiastowych zmian/postępu, to znaczy, że nic nie działa i jestem beznadziejny/uszkodzony.”" : "„If I don't see immediate changes, it means nothing works and I am hopeless.”"}</strong>
                                  <span className="text-[var(--text-sec)] text-[10.5px]">{isPl ? "Uzasadnienie: „nie widzę już żadnych zmian”, „brak postępu”. Założenie to prowadzi do szybkiej rezygnacji." : "Based on complaints of no progress."}</span>
                                </div>
                                <div className="bg-[var(--toggle-bg)] border border-[var(--card-border)] p-3 rounded-lg leading-relaxed">
                                  <strong className="text-[var(--gold-color)] block mb-1">{isPl ? "„Muszę wszystko robić perfekcyjnie i z pełnym zaangażowaniem, inaczej to nie ma sensu.”" : "„I must do everything perfectly, otherwise it has no meaning.”"}</strong>
                                  <span className="text-[var(--text-sec)] text-[10.5px]">{isPl ? "Uzasadnienie: „muszę ręcznie każdą czynność... nie ma tego automatyzmu”. Prowadzi to do wyczerpania." : "Based on lack of automaticity."}</span>
                                </div>
                              </div>
                            </div>

                            {/* 2. Przekonania rdzenne */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-2.5">
                              <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Konceptualizacja • Przekonania rdzenne (Core Beliefs)" : "Formulation • Core Beliefs"}</span>
                              <div className="grid grid-cols-2 gap-2 text-[11px]">
                                <div className="p-3 bg-[var(--toggle-bg)] border border-[var(--card-border)] rounded-lg text-center">
                                  <span className="block text-[8px] uppercase tracking-wider text-[var(--text-sec-50)] font-bold mb-1">{isPl ? "O sobie" : "Self"}</span>
                                  <strong className="text-[var(--text-pri)]">„Jestem wadliwy / niekompetentny”</strong>
                                </div>
                                <div className="p-3 bg-[var(--toggle-bg)] border border-[var(--card-border)] rounded-lg text-center">
                                  <span className="block text-[8px] uppercase tracking-wider text-[var(--text-sec-50)] font-bold mb-1">{isPl ? "O świecie / wpływie" : "Control"}</span>
                                  <strong className="text-[var(--text-pri)]">„Jestem bezradny / brak wpływu”</strong>
                                </div>
                              </div>
                            </div>

                            {/* 3. Pytania do eksploracji */}
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-2">
                              <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Pytania do dalszej eksploracji" : "Questions for session"}</span>
                              <div className="space-y-1.5 font-sans text-[11px] text-[var(--text-pri-90)]">
                                <div className="flex items-start gap-2 bg-[var(--toggle-bg)] p-2 rounded border border-[var(--card-border)]">
                                  <span className="text-[var(--gold-color)] font-bold shrink-0">?</span>
                                  <span>{isPl ? "„Co to dla pana oznacza, że jest pan 'mechanicznie uszkodzony'? Co to mówi o panu jako osobie?” (Strzałka w dół)" : "„What does being mechanically damaged mean to you?”"}</span>
                                </div>
                                <div className="flex items-start gap-2 bg-[var(--toggle-bg)] p-2 rounded border border-[var(--card-border)]">
                                  <span className="text-[var(--gold-color)] font-bold shrink-0">?</span>
                                  <span>{isPl ? "„Gdyby to 'uszkodzenie' zniknęło, co by się zmieniło w pana życiu? Co by pan wtedy robił?”" : "„If this damage disappeared, what would you do?”"}</span>
                                </div>
                                <div className="flex items-start gap-2 bg-[var(--toggle-bg)] p-2 rounded border border-[var(--card-border)]">
                                  <span className="text-[var(--gold-color)] font-bold shrink-0">?</span>
                                  <span>{isPl ? "„Czy były w pana życiu momenty, kiedy czuł się pan mniej 'zablokowany' lub 'uszkodzony'? Co wtedy było inaczej?”" : "„Were there moments you felt less damaged?”"}</span>
                                </div>
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* SECTION 6: WSKAZÓWKI SUPERWIZYJNE */}
                        <div id="sec-supervision" className="space-y-4 pt-1">
                          <div className="bg-[var(--card-bg)] rounded-xl p-4 border border-[var(--card-border)] text-left transition-all duration-300 space-y-3.5">
                            <div className="text-[9px] lg:text-[11px] uppercase tracking-wider text-[var(--accent-color)] font-mono mb-0.5 font-bold">
                              {isPl ? "Raport • Część VI" : "Report • Part VI"}
                            </div>
                            <h4 className="font-sans text-[13.5px] lg:text-[15.5px] font-bold text-[var(--text-pri)] mb-3 pb-1 border-b border-[var(--card-border)] flex items-center justify-between">
                              <span>{isPl ? "Wskazówki superwizyjne" : "Supervisory Tips"}</span>
                            </h4>
                            
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-3">
                              <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Superwizja" : "Supervision"}</span>
                              
                              <div className="space-y-3.5 text-[11px] text-[var(--text-pri-90)]">
                                <div className="bg-[var(--toggle-bg)] border border-[var(--card-border)] p-3 rounded-lg">
                                  <span className="block text-[8px] uppercase tracking-wider text-[var(--gold-color)] font-bold mb-1">{isPl ? "1. Ocena struktury sesji" : "1. Session Structure"}</span>
                                  <p className="leading-relaxed text-[var(--text-sec)]">
                                    {isPl ? "Sesja rozpoczęła się otwartym pytaniem, ale szybko przeszła w eksplorację objawów fizycznych. Brak wyraźnego ustalenia agendy na początku sesji oraz podsumowania i zadania domowego na koniec sesji. Wymaga większej struktury." : "Agenda was missing, structure was weak."}
                                  </p>
                                </div>

                                <div className="bg-[var(--toggle-bg)] border border-[var(--card-border)] p-3 rounded-lg">
                                  <span className="block text-[8px] uppercase tracking-wider text-[var(--gold-color)] font-bold mb-1">{isPl ? "2. Analiza kompetencji terapeuty" : "2. Therapist Competencies"}</span>
                                  <p className="leading-relaxed text-[var(--text-sec)]">
                                    {isPl ? "Terapeuta wykazał empatię wobec bólu fizycznego, lecz dialog sokratyczny był zbyt ogólny. Zabrakło aktywnego identyfikowania zniekształceń poznawczych (np. „mechaniczne uszkodzenie”) i ich podważania." : "Empathetic but Socratic dialogue was too general."}
                                  </p>
                                </div>

                                <div className="bg-[var(--toggle-bg)] border border-[var(--card-border)] p-3 rounded-lg">
                                  <span className="block text-[8px] uppercase tracking-wider text-[var(--gold-color)] font-bold mb-1">{isPl ? "3. Potencjalne myśli automatyczne terapeuty" : "3. Potential Therapist Thoughts"}</span>
                                  <Quote>{isPl ? "„Muszę zrozumieć fizyczne objawy klienta, zanim przejdę do psychiki.” lub „Klient jest w zbyt złym stanie, by go konfrontować.”" : "„Must understand physical first.”"}</Quote>
                                </div>
                              </div>

                              <div className="bg-[#122B2E] p-4 rounded-xl border border-[#5bf4bc]/30 text-[#5bf4bc] mt-2 text-[11px] lg:text-[12.5px] leading-relaxed">
                                <strong className="text-[var(--gold-color)] block mb-1">{isPl ? "Refleksja Superwizora AI:" : "AI Supervisor Reflection:"}</strong>
                                {isPl
                                  ? "Kluczowym wyzwaniem w tej sesji było przejście od ogólnych skarg klienta na samopoczucie i poczucie „uszkodzenia” do konkretnych myśli automatycznych i wzorców behawioralnych. Terapeuta potrzebuje bardziej aktywnie strukturyzować sesję, precyzniej identyfikować myśli i emocje oraz wprowadzać konkretne interwencje CBT, takie jak dziennik myśli czy eksperymenty behawioralne, aby przełamać cykl bierności i beznadziei."
                                  : "The main challenge was transitioning from general complaints to automatic thoughts."}
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* SECTION 7: WSTĘPNE HIPOTEZY DIAGNOSTYCZNE */}
                        <div id="sec-diagnosis" className="space-y-4 pt-1">
                          <div className="bg-[var(--card-bg)] rounded-xl p-4 border border-[var(--card-border)] text-left transition-all duration-300 space-y-3.5">
                            <div className="text-[9px] lg:text-[11px] uppercase tracking-wider text-[var(--accent-color)] font-mono mb-0.5 font-bold">
                              {isPl ? "Raport • Część VII" : "Report • Part VII"}
                            </div>
                            <h4 className="font-sans text-[13.5px] lg:text-[15.5px] font-bold text-[var(--text-pri)] mb-3 pb-1 border-b border-[var(--card-border)] flex items-center justify-between">
                              <span>{isPl ? "Wstępna konceptualizacja" : "Preliminary Case Formulation"}</span>
                            </h4>
                            
                            <div className="bg-white/[0.015] border border-[var(--card-border)] rounded-xl p-3.5 space-y-3">
                              <span className="text-[9px] uppercase tracking-wider font-bold text-[var(--accent-color)]">{isPl ? "Konceptualizacja Przypadku" : "Case Formulation"}</span>
                              
                              <div className="space-y-3.5 text-[11px] text-[var(--text-pri-90)]">
                                <div className="bg-[var(--toggle-bg)] border border-[var(--card-border)] p-3 rounded-lg">
                                  <span className="block text-[8px] uppercase tracking-wider text-[var(--gold-color)] font-bold mb-1">{isPl ? "1. Historia & Doświadczenia z dzieciństwa" : "1. Childhood Background"}</span>
                                  <p className="leading-relaxed text-[var(--text-sec)]">
                                    {isPl ? "Klient wspomina o „dysfunkcjach” zauważalnych już w dzieciństwie, które z wiekiem stawały się bardziej obserwowalne. Sugeruje to długotrwały wzorzec trudności, który mógł ukształtować negatywne przekonania o sobie." : "Long-term difficulties starting in childhood."}
                                  </p>
                                </div>

                                <div className="bg-[var(--toggle-bg)] border border-[var(--card-border)] p-3 rounded-lg">
                                  <span className="block text-[8px] uppercase tracking-wider text-[var(--gold-color)] font-bold mb-1">{isPl ? "2. Przekonania kluczowe (Core Beliefs)" : "2. Core Beliefs"}</span>
                                  <div className="flex gap-2.5 mt-1 font-bold flex-wrap">
                                    <span className="px-2 py-1 bg-red-500/10 border border-[#ffa3a3]/30 rounded text-[#ffa3a3] text-[10px]">„Jestem wadliwy/niekompetentny”</span>
                                    <span className="px-2 py-1 bg-red-500/10 border border-[#ffa3a3]/30 rounded text-[#ffa3a3] text-[10px]">„Jestem bezradny/brak wpływu”</span>
                                  </div>
                                </div>

                                <div className="bg-[var(--toggle-bg)] border border-[var(--card-border)] p-3 rounded-lg">
                                  <span className="block text-[8px] uppercase tracking-wider text-[var(--gold-color)] font-bold mb-1">{isPl ? "3. Przekonania pośredniczące (Zasady)" : "3. Rules & Assumptions"}</span>
                                  <p className="leading-relaxed text-[var(--text-sec)]">
                                    {isPl ? "„Jeśli coś nie działa od razu, to znaczy, że jestem beznadziejny i nie ma sensu próbować dalej,” oraz „Muszę się zmuszać do wszystkiego, bo inaczej nic nie zrobię, ale i tak to nic nie da”." : "Intermediate assumptions."}
                                  </p>
                                </div>

                                <div className="bg-[var(--toggle-bg)] border border-[var(--card-border)] p-3 rounded-lg">
                                  <span className="block text-[8px] uppercase tracking-wider text-[var(--gold-color)] font-bold mb-1">{isPl ? "4. Strategie kompensacyjne" : "4. Coping Strategies"}</span>
                                  <p className="leading-relaxed text-[var(--text-sec)]">
                                    {isPl ? "Próby forsownego „zmuszania się” do aktywności przy braku wewnętrznej motywacji. Jest to wyczerpujące, nie przynosi satysfakcji i wzmacnia beznadziejność, prowadząc do wypalenia." : "Forcing activities without motivation, leading to exhaustion."}
                                  </p>
                                </div>
                              </div>

                              <div className="space-y-2 pt-2 border-t border-[var(--card-border)]">
                                <span className="block text-[8.5px] uppercase tracking-wider text-[var(--gold-color)] font-bold">{isPl ? "5. Cykl poznawczy (Cognitive Loop)" : "5. Problematic Cognitive Loop"}</span>
                                <div className="p-3 bg-[var(--toggle-bg)] rounded-xl border border-[var(--card-border)] text-[10.5px] font-sans space-y-2 text-white/90">
                                  <div className="flex items-center gap-2">
                                    <span className="w-5 h-5 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-[#5bf4bc] font-bold font-mono text-[9px]">1</span>
                                    <span><strong className="text-[#5bf4bc]">{isPl ? "Sytuacja: " : "Situation: "}</strong>{isPl ? "Spadek nastroju / ból głowy" : "Mood drop / headache"}</span>
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <span className="w-5 h-5 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-[#5bf4bc] font-bold font-mono text-[9px]">2</span>
                                    <span><strong className="text-[#5bf4bc]">{isPl ? "Myśl: " : "Thought: "}</strong>{isPl ? "„Jestem zablokowany, mam mechaniczne uszkodzenie, nie ma postępu”" : "„I have mechanical damage”"}</span>
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <span className="w-5 h-5 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-[#5bf4bc] font-bold font-mono text-[9px]">3</span>
                                    <span><strong className="text-[#5bf4bc]">{isPl ? "Emocja: " : "Emotion: "}</strong>{isPl ? "Smutek, frustracja, beznadzieja" : "Sadness, frustration"}</span>
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <span className="w-5 h-5 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-[#5bf4bc] font-bold font-mono text-[9px]">4</span>
                                    <span><strong className="text-[#5bf4bc]">{isPl ? "Zachowanie: " : "Behavior: "}</strong>{isPl ? "„Zmuszanie się” do aktywności, bierność, unikanie" : "Forcing oneself"}</span>
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <span className="w-5 h-5 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-[#5bf4bc] font-bold font-mono text-[9px]">5</span>
                                    <span><strong className="text-[#5bf4bc]">{isPl ? "Skutek: " : "Physiological: "}</strong>{isPl ? "Dalsze wyczerpanie, poczucie słabości" : "Fatigue"}</span>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </>
                  )}
                    </div>
                  )}
                  {/* ──────────────────────────────────────────────────────────── */}
                  {activeTab === "transcript" && (
                    <div className="animate-[fadeIn_0.3s_ease-out_both] flex flex-col flex-1 relative min-h-0">
                      {/* App Bar */}
                      <div className="flex justify-between items-center mb-3">
                        <span className="text-white text-base cursor-pointer">⟨</span>
                        <h3 className="font-sans font-bold text-[15px] text-white tracking-wide">Transkrypcja</h3>
                        <div className="flex items-center gap-3 text-white">
                          <svg onClick={(e) => { e.stopPropagation(); handleCopy("transcript"); }} className="w-4 h-4 text-white/80 hover:text-[var(--accent-color)] transition-colors cursor-pointer" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24" aria-label="Copy">
                            <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                          </svg>
                        </div>
                      </div>

                      {/* Pill Toggle Tab */}
                      <div className="bg-[var(--toggle-bg)] rounded-lg p-1 flex items-center mb-4 border border-[var(--card-border)] select-none">
                        <span 
                          onClick={() => setActiveTab("transcript")}
                          className="flex-1 text-center py-1.5 text-xs bg-[var(--toggle-active-bg)] text-[var(--toggle-active-text)] font-bold rounded-md cursor-pointer transition-colors"
                        >
                          {isPl ? "Transkrypcja" : "Transcript"}
                        </span>
                        <span 
                          onClick={() => setActiveTab("report")}
                          className="flex-1 text-center py-1.5 text-xs text-[var(--text-sec)] font-semibold cursor-pointer transition-colors hover:text-[var(--text-pri)]"
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
                          onClick={() => setTranscriptFilter("client")}
                          className={`px-4 py-1.5 rounded-full text-[11px] font-bold cursor-pointer shrink-0 transition-colors ${
                            transcriptFilter === "client"
                              ? "bg-[#ffb12c] text-[#0a1e20]"
                              : "bg-[#0f3432] border border-white/10 text-white/80 hover:bg-[#13403e]"
                          }`}
                        >
                          {transcriptFilter === "client" && "✓ "}{isPl ? "Klient" : "Client"}
                        </button>
                      </div>

                      {/* Search Bar */}
                      <div className="bg-[var(--toggle-bg)] border border-[var(--card-border)] rounded-lg px-3 py-1.5 flex items-center gap-2 mb-4">
                        <svg className="w-3.5 h-3.5 text-[var(--text-sec-50)]" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                          <circle cx="11" cy="11" r="8" />
                          <line x1="21" y1="21" x2="16.65" y2="16.65" />
                        </svg>
                        <span className="text-[11px] text-[var(--text-sec-50)]">{isPl ? "Szukaj w transkrypcji..." : "Search transcript..."}</span>
                      </div>

                      {/* Dialogue List */}
                      <div className="flex-1 space-y-2 overflow-y-auto pr-0.5 scrollbar-thin select-text text-left min-h-0 pb-6">
                        
                        {/* 1 */}
                        {(transcriptFilter === "all" || transcriptFilter === "therapist") && (
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both] lg:p-4 transition-all duration-300">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[var(--gold-color)] font-sans text-[11px] lg:text-[13.5px] font-bold">{isPl ? "Terapeuta" : "Therapist"}</span>
                              <span className="text-[9.5px] text-[var(--text-sec-50)] font-mono">00:00 - 00:08</span>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13.5px] leading-relaxed text-[var(--text-pri-90)]">
                              {isPl 
                                ? "Dzień dobry. Cieszę się, że się widzimy. Na czym chciałbyś się dzisiaj skoncentrować w naszej pracy?"
                                : "Good morning. I'm glad to see you. What would you like to focus on in our session today?"}
                            </p>
                          </div>
                        )}

                        {/* 2 */}
                        {(transcriptFilter === "all" || transcriptFilter === "client") && (
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both] lg:p-4 transition-all duration-300">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[var(--accent-color)] font-sans text-[11px] lg:text-[13.5px] font-bold">{isPl ? "Klient" : "Client"}</span>
                              <span className="text-[9.5px] text-[var(--text-sec-50)] font-mono">00:08 - 00:22</span>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13.5px] leading-relaxed text-[var(--text-pri-90)]">
                              {isPl 
                                ? "Dzień dobry. Szczerze mówiąc, ostatnio czuję się znacznie gorzej. Mimo że po poprzednich sesjach była lekka poprawa, to teraz znowu brakuje mi chęci do działania. Towarzyszą mi też te nietypowe, silne bóle głowy..."
                                : "Good morning. Honestly, I've been feeling much worse lately. Even though there was a slight improvement after the previous sessions, now I lack the desire to act again. I'm also experiencing those unusual, severe headaches..."}
                            </p>
                          </div>
                        )}

                        {/* 3 */}
                        {(transcriptFilter === "all" || transcriptFilter === "therapist") && (
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both] lg:p-4 transition-all duration-300">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[var(--gold-color)] font-sans text-[11px] lg:text-[13.5px] font-bold">{isPl ? "Terapeuta" : "Therapist"}</span>
                              <span className="text-[9.5px] text-[var(--text-sec-50)] font-mono">00:22 - 00:31</span>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13.5px] leading-relaxed text-[var(--text-pri-90)]">
                              {isPl 
                                ? "Rozumiem. Te dolegliwości fizyczne z pewnością bardzo utrudniają codzienne funkcjonowanie. Czy to jest podobne do tego ucisku zatok, o którym rozmawialiśmy?"
                                : "I understand. Those physical ailments certainly make daily functioning very difficult. Is it similar to that sinus pressure we talked about?"}
                            </p>
                          </div>
                        )}

                        {/* 4 */}
                        {(transcriptFilter === "all" || transcriptFilter === "client") && (
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both] lg:p-4 transition-all duration-300">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[var(--accent-color)] font-sans text-[11px] lg:text-[13.5px] font-bold">{isPl ? "Klient" : "Client"}</span>
                              <span className="text-[9.5px] text-[var(--text-sec-50)] font-mono">00:31 - 00:52</span>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13.5px] leading-relaxed text-[var(--text-pri-90)]">
                              {isPl 
                                ? "Tak, te bóle są takie zatokowe, okropnie silne. Kiedy się pojawiają, czuję się całkowicie bezradny. Cały czas wraca do mnie myśl, że jestem jakoś zablokowany, że to jakoś uszkodzenie mam mechaniczne, które uniemożliwia mi działanie."
                                : "Yes, these headaches are like sinus pains, awfully strong. When they appear, I feel completely helpless. The thought keeps coming back that I am somehow blocked, that I have mechanical damage that prevents from functioning."}
                            </p>
                          </div>
                        )}

                        {/* 5 */}
                        {(transcriptFilter === "all" || transcriptFilter === "therapist") && (
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both] lg:p-4 transition-all duration-300">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[var(--gold-color)] font-sans text-[11px] lg:text-[13.5px] font-bold">{isPl ? "Terapeuta" : "Therapist"}</span>
                              <span className="text-[9.5px] text-[var(--text-sec-50)] font-mono">00:52 - 01:04</span>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13.5px] leading-relaxed text-[var(--text-pri-90)]">
                              {isPl 
                                ? "„Uszkodzenie mechaniczne” – to bardzo wyraziste określenie. Co dokładnie kryje się pod tym poczuciem? Jak na to reagujesz na co dzień?"
                                : "“Mechanical damage” – that is a very vivid term. What exactly lies behind that feeling? How do you react to it on a daily basis?"}
                            </p>
                          </div>
                        )}

                        {/* 6 */}
                        {(transcriptFilter === "all" || transcriptFilter === "client") && (
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both] lg:p-4 transition-all duration-300">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[var(--accent-color)] font-sans text-[11px] lg:text-[13.5px] font-bold">{isPl ? "Klient" : "Client"}</span>
                              <span className="text-[9.5px] text-[var(--text-sec-50)] font-mono">01:04 - 01:21</span>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13.5px] leading-relaxed text-[var(--text-pri-90)]">
                              {isPl 
                                ? "Próbuję z tym walczyć, robić to, co ustaliliśmy. Staram się wychodzić na spacery, biorę leki, ale szczerze mówiąc, nie widzę już żadnych specjalnych zmian. Mam poczucie, że wszystko, co robię, odbija się od tego muru."
                                : "I try to fight it, to do what we agreed on. I try to go for walks, I take my medication, but honestly, I don't see any special changes anymore. I feel like everything I do just bounces off this wall."}
                            </p>
                          </div>
                        )}

                        {/* 7 */}
                        {(transcriptFilter === "all" || transcriptFilter === "therapist") && (
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both] lg:p-4 transition-all duration-300">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[var(--gold-color)] font-sans text-[11px] lg:text-[13.5px] font-bold">{isPl ? "Terapeuta" : "Therapist"}</span>
                              <span className="text-[9.5px] text-[var(--text-sec-50)] font-mono">01:21 - 01:32</span>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13.5px] leading-relaxed text-[var(--text-pri-90)]">
                              {isPl 
                                ? "Zauważam tu silne poczucie bezradności i braku postępu. Czy pamiętasz, kiedy pierwszy raz poczułeś się w ten sposób?"
                                : "I notice a strong sense of helplessness and lack of progress. Do you remember when you first felt this way?"}
                            </p>
                          </div>
                        )}

                        {/* 8 */}
                        {(transcriptFilter === "all" || transcriptFilter === "client") && (
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both] lg:p-4 transition-all duration-300">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[var(--accent-color)] font-sans text-[11px] lg:text-[13.5px] font-bold">{isPl ? "Klient" : "Client"}</span>
                              <span className="text-[9.5px] text-[var(--text-sec-50)] font-mono">01:32 - 01:54</span>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13.5px] leading-relaxed text-[var(--text-pri-90)]">
                              {isPl 
                                ? "Wydaje się, że to było we mnie od dawna. Tylko że jako dziecko to było mniej zauważalne, po prostu wcześniej tę dysfunkcję jakoś ignorowałem. Z wiekiem jednak te problemy zaczęły się coraz bardziej piętrzyć."
                                : "It seems this has been in me for a long time. It's just that as a child it was less noticeable, I somehow ignored this dysfunction before. But with age, these problems started to pile up more and more."}
                            </p>
                          </div>
                        )}

                        {/* 9 */}
                        {(transcriptFilter === "all" || transcriptFilter === "therapist") && (
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both] lg:p-4 transition-all duration-300">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[var(--gold-color)] font-sans text-[11px] lg:text-[13.5px] font-bold">{isPl ? "Terapeuta" : "Therapist"}</span>
                              <span className="text-[9.5px] text-[var(--text-sec-50)] font-mono">01:54 - 02:05</span>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13.5px] leading-relaxed text-[var(--text-pri-90)]">
                              {isPl 
                                ? "A jak to przekłada się na Twoje codzienne obowiązki w tym momencie? Co dzieje się, kiedy próbujesz po prostu realizować plan dnia?"
                                : "And how does that translate to your daily responsibilities at the moment? What happens when you just try to carry out your daily plan?"}
                            </p>
                          </div>
                        )}

                        {/* 10 */}
                        {(transcriptFilter === "all" || transcriptFilter === "client") && (
                          <div className="bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 shadow-sm animate-[fadeIn_0.3s_ease-out_both] lg:p-4 transition-all duration-300">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-[var(--accent-color)] font-sans text-[11px] lg:text-[13.5px] font-bold">{isPl ? "Klient" : "Client"}</span>
                              <span className="text-[9.5px] text-[var(--text-sec-50)] font-mono">02:05 - 02:28</span>
                            </div>
                            <p className="font-sans text-[11px] lg:text-[13.5px] leading-relaxed text-[var(--text-pri-90)]">
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
                    <div className="animate-[fadeIn_0.3s_ease-out_both] flex flex-col flex-1 relative min-h-0">
                      {/* App Bar */}
                      <div className="flex justify-between items-center mb-4">
                        <span 
                          onClick={() => {
                            setIsAnalyzingView(false);
                            setActiveTab("report");
                          }}
                          className="text-white text-base cursor-pointer font-bold text-lg select-none hover:text-white/80 transition-colors"
                        >
                          ⟨
                        </span>
                        <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                          <path d="M12 20h9" />
                          <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z" />
                        </svg>
                      </div>

                      {/* Header Title Info */}
                      <div className="mb-4">
                        <h3 className="font-sans font-bold text-2xl lg:text-3xl text-[#fcae2f] italic tracking-wide">
                          {selectedClientName || (isPl ? "Klient Marek" : "Client Mark")}
                        </h3>
                        <p className="font-sans text-[11.5px] lg:text-[13.5px] text-white/70 mt-0.5">
                          Nad czym dzisiaj pracujemy?
                        </p>
                      </div>

                      {/* Session Connection Info (horizontal continuity) */}
                      <div className="mb-6 text-left select-none px-1">
                        <h4 className="font-sans font-bold text-white text-[13.5px] lg:text-[14.5px] tracking-wide mb-1 leading-snug">
                          {isPl ? "Ciągłość relacji z sesji na sesję" : "Continuity across sessions"}
                        </h4>
                        <p className="font-sans text-[11.5px] lg:text-[12.5px] text-white/95 leading-relaxed font-semibold">
                          {isPl 
                            ? "System automatycznie łączy wątki z poprzednich spotkań, dbając o nieprzerwaną ciągłość procesu terapeutycznego bez konieczności pamiętania każdego szczegółu."
                            : "The system automatically links threads from past meetings, ensuring uninterrupted continuity of the therapeutic process without having to remember every detail."}
                        </p>
                      </div>

                      {/* Session Cards list with glowing vertical RAG connector line */}
                      <div className="relative flex-1 pl-11 space-y-3 overflow-y-auto pr-0.5 scrollbar-thin min-h-0 pb-6">
                        
                        {/* Clean vertical straight connector line */}
                        <div className="absolute left-[23px] top-6 bottom-6 w-[2px] bg-white/10 z-0">
                          {/* Active yellow/orange segment from card 6 to card 5 */}
                          <div className="h-[20%] bg-[#ffb12c]" />
                        </div>

                        {/* Sesja 6 card (Active AI analyzing) */}
                        <div 
                          onClick={() => {
                            setIsAnalyzingView(true);
                            setActiveTab("report");
                          }}
                          className="relative flex items-center z-10 cursor-pointer group"
                        >
                          <div className="absolute -left-9.5 w-7.5 h-7.5 rounded-full bg-[#0e3b33] border border-[#ffb12c] flex items-center justify-center font-sans font-bold text-[11px] text-[#ffb12c] shadow-lg transition-transform group-hover:scale-105">
                            #6
                          </div>
                          <div className="flex-1 bg-[var(--card-bg)] border border-[var(--accent-border-light)] rounded-xl p-3 flex items-center justify-between hover:bg-[var(--back-btn-hover)] hover:border-[var(--accent-color)]/50 transition-all duration-300">
                            <div>
                              <div className="font-sans text-[12.5px] lg:text-[14.5px] font-bold text-[var(--text-pri)]">{isPl ? "Sesja 6" : "Session 6"}</div>
                              <div className="font-sans text-[9.5px] lg:text-[11.5px] text-[var(--text-sec)]/80 mt-0.5 flex items-center gap-1.5 flex-wrap">
                                <span>{isPl ? "2 Cze · 10:29" : "2 Jun · 10:29"}</span>
                                <span className="bg-amber-500/10 text-amber-400 text-[8px] lg:text-[9.5px] px-1.5 py-0.5 rounded-full font-bold flex items-center gap-1 shrink-0 border border-amber-500/20 animate-pulse">
                                  <span className="w-1 h-1 rounded-full bg-amber-400 animate-ping" /> {isPl ? "Analizuje przez AI" : "AI analyzing"}
                                </span>
                              </div>
                            </div>
                            <span className="text-white/60 text-sm">⋮</span>
                          </div>
                        </div>

                        {/* Sesja 5 card */}
                        <div 
                          onClick={() => {
                            setIsAnalyzingView(false);
                            setActiveTab("report");
                          }}
                          className="relative flex items-center z-10 cursor-pointer group"
                        >
                          <div className="absolute -left-9.5 w-7.5 h-7.5 rounded-full bg-[#112d2a] border border-[#5bf4bc]/30 flex items-center justify-center font-sans font-bold text-[11px] text-[#5bf4bc] shadow-md transition-transform group-hover:scale-105">
                            #5
                          </div>
                          <div className="flex-1 bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 flex items-center justify-between hover:bg-[var(--back-btn-hover)] hover:border-[var(--accent-color)]/30 transition-all duration-300">
                            <div>
                              <div className="font-sans text-[12.5px] lg:text-[14.5px] font-bold text-[var(--text-pri)]">{isPl ? "Sesja 5" : "Session 5"}</div>
                              <div className="font-sans text-[9.5px] lg:text-[11.5px] text-[var(--text-sec)]/80 mt-0.5 flex items-center gap-1.5 flex-wrap">
                                <span>{isPl ? "24 Maj · 17:41" : "24 May · 17:41"}</span>
                                <span className="bg-[#0F3B32] text-[#5bf4bc] text-[8px] lg:text-[9.5px] px-1.5 py-0.5 rounded-full font-bold flex items-center gap-1 shrink-0 border border-[#5bf4bc]/20">
                                  <span className="w-1 h-1 rounded-full bg-[#5bf4bc]" /> {isPl ? "Nowy raport" : "New report"}
                                </span>
                              </div>
                            </div>
                            <span className="text-white/50 text-sm">⋮</span>
                          </div>
                        </div>

                        {/* Sesja 4 card */}
                        <div 
                          onClick={() => {
                            setIsAnalyzingView(false);
                            setActiveTab("report");
                          }}
                          className="relative flex items-center z-10 cursor-pointer group"
                        >
                          <div className="absolute -left-9.5 w-7.5 h-7.5 rounded-full bg-[#112d2a] border border-white/10 flex items-center justify-center font-sans font-bold text-[11px] text-white/70 shadow-sm transition-transform group-hover:scale-105">
                            #4
                          </div>
                          <div className="flex-1 bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 flex items-center justify-between hover:bg-[var(--back-btn-hover)] hover:border-[var(--accent-color)]/30 transition-all duration-300">
                            <div>
                              <div className="font-sans text-[12.5px] lg:text-[14.5px] font-bold text-[var(--text-pri)]">{isPl ? "Sesja 4" : "Session 4"}</div>
                              <div className="font-sans text-[9.5px] lg:text-[12px] text-white/50 mt-0.5">{isPl ? "16 Maj · 23:32" : "16 May · 23:32"}</div>
                            </div>
                            <span className="text-white/50 text-sm">⋮</span>
                          </div>
                        </div>

                        {/* Sesja 3 card */}
                        <div 
                          onClick={() => {
                            setIsAnalyzingView(false);
                            setActiveTab("report");
                          }}
                          className="relative flex items-center z-10 cursor-pointer group"
                        >
                          <div className="absolute -left-9.5 w-7.5 h-7.5 rounded-full bg-[#112d2a] border border-white/10 flex items-center justify-center font-sans font-bold text-[11px] text-white/70 shadow-sm transition-transform group-hover:scale-105">
                            #3
                          </div>
                          <div className="flex-1 bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 flex items-center justify-between hover:bg-[var(--back-btn-hover)] hover:border-[var(--accent-color)]/30 transition-all duration-300">
                            <div>
                              <div className="font-sans text-[12.5px] lg:text-[14.5px] font-bold text-[var(--text-pri)]">{isPl ? "Sesja 3" : "Session 3"}</div>
                              <div className="font-sans text-[9.5px] lg:text-[12px] text-white/50 mt-0.5">{isPl ? "10 Maj · 14:15" : "10 May · 14:15"}</div>
                            </div>
                            <span className="text-white/50 text-sm">⋮</span>
                          </div>
                        </div>

                        {/* Sesja 2 card */}
                        <div 
                          onClick={() => {
                            setIsAnalyzingView(false);
                            setActiveTab("report");
                          }}
                          className="relative flex items-center z-10 cursor-pointer group"
                        >
                          <div className="absolute -left-9.5 w-7.5 h-7.5 rounded-full bg-[#112d2a] border border-white/10 flex items-center justify-center font-sans font-bold text-[11px] text-white/70 shadow-sm transition-transform group-hover:scale-105">
                            #2
                          </div>
                          <div className="flex-1 bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 flex items-center justify-between hover:bg-[var(--back-btn-hover)] hover:border-[var(--accent-color)]/30 transition-all duration-300">
                            <div>
                              <div className="font-sans text-[12.5px] lg:text-[14.5px] font-bold text-[var(--text-pri)]">{isPl ? "Sesja 2" : "Session 2"}</div>
                              <div className="font-sans text-[9.5px] lg:text-[12px] text-white/50 mt-0.5">{isPl ? "3 Maj · 11:20" : "3 May · 11:20"}</div>
                            </div>
                            <span className="text-white/50 text-sm">⋮</span>
                          </div>
                        </div>

                        {/* Sesja 1 card */}
                        <div 
                          onClick={() => {
                            setIsAnalyzingView(false);
                            setActiveTab("report");
                          }}
                          className="relative flex items-center z-10 cursor-pointer group"
                        >
                          <div className="absolute -left-9.5 w-7.5 h-7.5 rounded-full bg-[#112d2a] border border-white/10 flex items-center justify-center font-sans font-bold text-[11px] text-white/70 shadow-sm transition-transform group-hover:scale-105">
                            #1
                          </div>
                          <div className="flex-1 bg-[var(--card-bg)] border border-[var(--card-border)] rounded-xl p-3 flex items-center justify-between hover:bg-[var(--back-btn-hover)] hover:border-[var(--accent-color)]/30 transition-all duration-300">
                            <div>
                              <div className="font-sans text-[12.5px] lg:text-[14.5px] font-bold text-[var(--text-pri)]">{isPl ? "Sesja 1" : "Session 1"}</div>
                              <div className="font-sans text-[9.5px] lg:text-[12px] text-white/50 mt-0.5">{isPl ? "28 Kwi · 15:45" : "28 Apr · 15:45"}</div>
                            </div>
                            <span className="text-white/50 text-sm">⋮</span>
                          </div>
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
                    <div className="animate-[fadeIn_0.3s_ease-out_both] flex flex-col flex-1 relative min-h-0">
                      {/* Modal Bar indicator */}
                      <div className="w-12 h-1 bg-white/20 rounded-full mx-auto mb-3" />

                      {/* Pill Toggle for Modality Sub-tabs */}
                      <div className="bg-[var(--toggle-bg)] rounded-lg p-0.5 flex items-center mb-4 border border-[var(--card-border)] select-none shrink-0">
                        <button 
                          onClick={() => setModalitySubTab("choose")}
                          className={`flex-1 text-center py-1 text-[11px] font-bold rounded-md transition-colors cursor-pointer ${
                            modalitySubTab === "choose"
                              ? "bg-[var(--toggle-active-bg)] text-[var(--toggle-active-text)]"
                              : "text-[var(--text-sec)] hover:text-white"
                          }`}
                        >
                          {isPl ? "Wybierz nurt" : "Choose modality"}
                        </button>
                        <button 
                          onClick={() => setModalitySubTab("settings")}
                          className={`flex-1 text-center py-1 text-[11px] font-bold rounded-md transition-colors cursor-pointer ${
                            modalitySubTab === "settings"
                              ? "bg-[var(--toggle-active-bg)] text-[var(--toggle-active-text)]"
                              : "text-[var(--text-sec)] hover:text-white"
                          }`}
                        >
                          {isPl ? "Preferencje" : "Preferences"}
                        </button>
                      </div>

                      {modalitySubTab === "choose" ? (
                        <>
                          {/* Headers */}
                          <div className="mb-3 text-left shrink-0">
                            <h3 className="font-sans font-bold text-xl text-[var(--text-pri)]">
                              {isPl ? "Wybierz swój nurt" : "Choose your modality"}
                            </h3>
                            <p className="font-sans text-[11px] text-[var(--text-sec)] italic leading-relaxed mt-1">
                              {isPl 
                                ? "To ustawienie wpływa na generowane raporty. Możesz je zmienić w każdej chwili."
                                : "This setting affects generated reports. You can change it at any time."}
                            </p>
                          </div>

                          {/* Modality options list — SHOWING ALL 9 OPTIONS */}
                          <div className="flex-1 space-y-0.5 overflow-y-auto pr-1.5 scrollbar-thin min-h-0 pb-6">
                            {MODALITIES_LIST.map((m) => {
                              const isSelected = selectedModality === m.id;
                              return (
                                <div
                                  key={m.id}
                                  onClick={() => setSelectedModality(m.id)}
                                  className={`transition-all duration-200 p-2.5 flex items-center justify-between border cursor-pointer ${
                                    isSelected
                                      ? "bg-[#0b3c40] border-transparent rounded-xl shadow-[0_4px_20px_rgba(0,0,0,0.15)] my-1"
                                      : "bg-transparent border-transparent border-b border-white/[0.05] hover:bg-white/[0.02]"
                                  }`}
                                >
                                  <div className="flex items-center gap-3.5">
                                    <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 transition-colors duration-200 ${
                                      isSelected
                                        ? "bg-[#ffb12c]/15 text-[#ffb12c]"
                                        : "bg-[#042528] text-white/60"
                                    }`}>
                                      {m.icon}
                                    </div>
                                    <span className={`font-sans text-[12.5px] transition-colors duration-200 ${
                                      isSelected ? "font-semibold text-white" : "text-white/80"
                                    }`}>
                                      {isPl ? m.label : m.labelEn}
                                    </span>
                                  </div>
                                  {isSelected && (
                                    <div className="w-[18px] h-[18px] rounded-full bg-[#ffb12c] flex items-center justify-center text-[#06383e] text-[10px] font-extrabold shrink-0 animate-[fadeIn_0.2s_ease-out]">
                                      ✓
                                    </div>
                                  )}
                                </div>
                              );
                            })}
                          </div>
                        </>
                      ) : (
                        <div className="text-left animate-[fadeIn_0.2s_ease-out] flex-1 flex flex-col justify-start min-h-0">
                          {/* Headers */}
                          <div className="flex items-center justify-between mb-4 shrink-0 px-1">
                            <div>
                              <h3 className="font-serif text-2xl font-bold text-[#fcae2f] italic leading-tight">
                                {isPl ? "Ustawienia" : "Settings"}
                              </h3>
                              <p className="font-sans text-[8.5px] font-bold tracking-widest text-[#8ba4a6] uppercase mt-0.5">
                                {isPl ? "DOSTOSUJ SWOJE DOŚWIADCZENIE" : "CUSTOMIZE YOUR EXPERIENCE"}
                              </p>
                            </div>
                            <button 
                              onClick={() => setModalitySubTab("choose")}
                              className="w-7.5 h-7.5 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-white/60 hover:text-white cursor-pointer active:scale-95 transition-all"
                              aria-label="Close settings"
                            >
                              <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2.5">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                              </svg>
                            </button>
                          </div>

                          {/* Scrollable list of settings */}
                          <div className="flex-1 space-y-4 overflow-y-auto pr-1.5 scrollbar-thin min-h-0 pb-6">
                            {/* PREFERENCJE RAPORTÓW SECTION */}
                            <div className="space-y-2">
                              <span className="font-sans text-[9px] uppercase font-bold tracking-wider text-[#8ba4a6] px-1">
                                {isPl ? "PREFERENCJE RAPORTÓW" : "REPORT PREFERENCES"}
                              </span>
                              
                              <div className="space-y-2">
                                {[
                                  {
                                    id: "length",
                                    label: isPl ? "Długość raportu" : "Report length",
                                    value: settingValues.length,
                                    icon: (
                                      <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M3 10h18M3 14h18M3 6h18M3 18h18" />
                                      </svg>
                                    )
                                  },
                                  {
                                    id: "tone",
                                    label: isPl ? "Ton" : "Tone",
                                    value: settingValues.tone,
                                    icon: (
                                      <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 16v-2m0 2a2 2 0 100-4m0 4a2 2 0 110-4m0-4v-2m0 2V4" />
                                      </svg>
                                    )
                                  },
                                  {
                                    id: "quotes",
                                    label: isPl ? "Liczba cytatów z sesji" : "Number of quotes",
                                    value: settingValues.quotes,
                                    icon: (
                                      <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                                      </svg>
                                    )
                                  },
                                  {
                                    id: "jargon",
                                    label: isPl ? "Język opisu (konceptualizacji)" : "Conceptualization language",
                                    value: settingValues.jargon,
                                    icon: (
                                      <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                                      </svg>
                                    )
                                  },
                                  {
                                    id: "assertiveness",
                                    label: isPl ? "Stopień asertywności hipotez" : "Hypothesis assertiveness level",
                                    value: settingValues.assertiveness,
                                    icon: (
                                      <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l.707-.707m2.808 13.064a3 3 0 01-2.244-2.577 3.5 3.5 0 013.123-3.79c.642-.062 1.252-.455 1.554-1.042A6 6 0 0118 12c0 2.22-.8 4.24-2.126 5.8a1 1 0 01-.774.38H12v1m-2-1h4" />
                                      </svg>
                                    )
                                  },
                                  {
                                    id: "strengths",
                                    label: isPl ? "Akcent na mocnych stronach" : "Emphasis on strengths",
                                    value: settingValues.strengths,
                                    icon: (
                                      <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-7.682-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                                      </svg>
                                    )
                                  },
                                  {
                                    id: "sections",
                                    label: isPl ? "Sekcje do rozwinięcia" : "Sections to expand",
                                    value: settingValues.sections,
                                    icon: (
                                      <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
                                      </svg>
                                    )
                                  },
                                  {
                                    id: "additional",
                                    label: isPl ? "Dodatkowe wskazówki" : "Additional instructions",
                                    value: settingValues.additional,
                                    icon: (
                                      <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                                      </svg>
                                    )
                                  }
                                ].map((item) => (
                                  <div 
                                    key={item.id}
                                    onClick={() => setActiveSettingSheet(item.id)}
                                    className="bg-[#163639]/40 border border-[#1d4447]/45 rounded-xl p-2.5 flex items-center justify-between shadow-sm hover:bg-[#163639]/70 hover:border-[#2f6b62]/40 transition-all duration-200 cursor-pointer"
                                  >
                                    <div className="flex items-center gap-3">
                                      <div className="w-7.5 h-7.5 rounded-full bg-[#042528] text-[#ffb12c] flex items-center justify-center shrink-0 border border-white/5">
                                        {item.icon}
                                      </div>
                                      <div>
                                        <div className="font-sans text-[11.5px] font-bold text-white leading-snug">
                                          {item.label}
                                        </div>
                                        <div className="font-sans text-[9px] text-[#8ba4a6] mt-0.5">
                                          {item.value}
                                        </div>
                                      </div>
                                    </div>
                                    <svg className="w-3.5 h-3.5 text-[#8ba4a6]/60" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                                      <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                                    </svg>
                                  </div>
                                ))}
                              </div>
                            </div>

                            {/* WSPARCIE SECTION */}
                            <div className="space-y-2 border-t border-white/5 pt-3">
                              <span className="font-sans text-[9px] uppercase font-bold tracking-wider text-[#8ba4a6] px-1">
                                {isPl ? "WSPARCIE" : "SUPPORT"}
                              </span>
                              <div className="bg-[#163639]/40 border border-[#1d4447]/45 rounded-xl p-2.5 flex items-center justify-between shadow-sm hover:bg-[#163639]/70 hover:border-[#2f6b62]/40 transition-all duration-200 cursor-pointer">
                                <div className="flex items-center gap-3">
                                  <div className="w-7.5 h-7.5 rounded-full bg-[#042528] text-[#ffb12c] flex items-center justify-center shrink-0 border border-white/5">
                                    <svg className="w-4.5 h-4.5" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                                      <rect width="20" height="16" x="2" y="4" rx="2" strokeLinecap="round" strokeLinejoin="round" />
                                      <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" strokeLinecap="round" strokeLinejoin="round" />
                                    </svg>
                                  </div>
                                  <div>
                                    <div className="font-sans text-[11.5px] font-bold text-white leading-snug">
                                      {isPl ? "Napisz do nas" : "Contact support"}
                                    </div>
                                  </div>
                                </div>
                                <svg className="w-3.5 h-3.5 text-[#8ba4a6]/60" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                                  <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                                </svg>
                              </div>
                            </div>
                          </div>
                        </div>
                      )}

                      {/* Bottom Sheet for interactive settings */}
                      {activeSettingSheet && (
                        <div 
                          className="absolute inset-0 bg-black/60 backdrop-blur-[1px] z-30 flex items-end justify-center animate-[fadeIn_0.2s_ease-out]"
                          onClick={() => setActiveSettingSheet(null)}
                        >
                          <div 
                            className="bg-[#0a474e] border-t border-[var(--card-border)] rounded-t-[24px] p-5 w-full shadow-2xl text-left animate-[slideUp_0.3s_cubic-bezier(0.16,1,0.3,1)_both]"
                            onClick={(e) => e.stopPropagation()}
                          >
                            <div className="w-12 h-1 bg-white/10 rounded-full mx-auto mb-4" />
                            
                            <div className="flex items-center justify-between mb-4 px-1">
                              <h4 className="font-sans font-bold text-white text-[13px] sm:text-[14px]">
                                {getSettingSheetTitle(activeSettingSheet)}
                              </h4>
                              <button 
                                onClick={() => setActiveSettingSheet(null)}
                                className="text-[#fcae2f] hover:text-[#e09825] text-xs font-bold px-2.5 py-1 bg-white/5 rounded-md border border-white/5 active:scale-95 transition-all cursor-pointer"
                              >
                                {isPl ? "Gotowe" : "Done"}
                              </button>
                            </div>
                            
                            <div className="space-y-1.5 max-h-[200px] overflow-y-auto pr-1 pb-4 scrollbar-none">
                              {getSettingSheetOptions(activeSettingSheet).map((opt) => {
                                const isSelected = settingValues[activeSettingSheet] === opt.value;
                                return (
                                  <div
                                    key={opt.value}
                                    onClick={() => {
                                      setSettingValues({ ...settingValues, [activeSettingSheet]: opt.value });
                                      setToast(isPl ? `Zmieniono: ${opt.value}` : `Updated: ${opt.value}`);
                                      setTimeout(() => setToast(null), 1500);
                                    }}
                                    className={`p-2.5 rounded-xl border flex items-center justify-between cursor-pointer transition-all ${
                                      isSelected 
                                        ? "bg-[#0b3c40] border-[#5bf4bc]/35 text-[#5bf4bc]" 
                                        : "bg-white/[0.02] border-white/5 text-white/70 hover:bg-white/[0.05]"
                                    }`}
                                  >
                                    <span className="text-[11.5px] font-medium">{opt.label}</span>
                                    {isSelected && <span className="text-xs">✓</span>}
                                  </div>
                                );
                              })}
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  )}

                  {/* ──────────────────────────────────────────────────────────── */}
                  {/* TAB 5: FOLDER VIEW */}
                  {/* ──────────────────────────────────────────────────────────── */}
                  {activeTab === "folder" && (
                    <div onClick={(e) => e.stopPropagation()} className="animate-[fadeIn_0.3s_ease-out_both] flex flex-col flex-1 text-left h-full min-h-0 relative">
                      {/* Header bar */}
                      <div className="flex justify-between items-center mb-4 shrink-0 px-1 select-none">
                        <div className="flex items-center gap-2">
                          {/* Brandmark SVG Logo */}
                          <div className="w-7 h-7 rounded-full bg-[#042528] border border-[#ffb12c]/10 flex items-center justify-center text-[#ffb12c] shrink-0">
                            <svg className="w-4 h-4 fill-current" viewBox="0 0 1200 1200" xmlns="http://www.w3.org/2000/svg">
                              <path d="M600,0C269.17,0,0,269.17,0,600s269.17,600,600,600,600-269.17,600-600S930.83,0,600,0ZM600,1144.8c-300.4,0-544.8-244.4-544.8-544.8S299.6,55.2,600,55.2s544.8,244.4,544.8,544.8-244.4,544.8-544.8,544.8Z"/>
                              <path d="M729.21,278.76c5.62,0,10.17-4.55,10.17-10.17v-33.33c0-5.62-4.55-10.17-10.17-10.17h-212.62c-5.62,0-10.17,4.55-10.17,10.17v33.33c0,5.62,4.55,10.17,10.17,10.17h39.67v156.04h-39.67c-5.62,0-10.17,4.55-10.17,10.17v34.18c0,5.62,4.55,10.17,10.17,10.17h39.67v258.04h-39.67c-5.62,0-10.17,4.55-10.17,10.17v34.18c0,5.62,4.55,10.17,10.17,10.17h15.96c-8.55,9.24-14.57,20.23-17.18,32.12-12.75,2.81-24.67,9.19-34.28,18.78-27.29,27.34-27.29,71.83.03,99.19,9.62,9.58,21.51,15.96,34.23,18.76,2.8,12.76,9.19,24.67,18.81,34.25,13.23,13.24,30.85,20.54,49.58,20.54s36.35-7.3,49.56-20.53c9.62-9.61,16.01-21.51,18.81-34.26,12.72-2.81,24.64-9.19,34.23-18.77,27.37-27.35,27.37-71.84,0-99.2-9.62-9.58-21.51-15.94-34.23-18.76-2.62-11.91-8.65-22.89-17.21-32.12h18.54c5.62,0,10.17-4.55,10.17-10.17v-34.18c0-5.62-4.55-10.17-10.17-10.17h-42.22v-258.04h118c5.62,0,10.17-4.55,10.17-10.17v-34.18c0-5.62-4.55-10.17-10.17-10.17h-118v-51.6h68.16c5.62,0,10.17-4.56,10.17-10.17v-31.24c0-5.62-4.55-10.17-10.17-10.17h-68.16v-52.85h118ZM542.52,875.2c7.44,0,13.46-6.02,13.46-13.46,0-15.35,12.45-27.8,27.8-27.8s26.93,11.99,27.44,26.9c-.02.31,0,.58,0,.89,0,7.43,6.02,13.46,13.46,13.46h.71c15.35,0,27.8,12.45,27.8,27.8s-12.45,27.8-27.8,27.8h-.71c-7.43,0-13.46,6.02-13.46,13.46,0,.37-.03.68,0,1.05-.42,14.99-12.35,27.05-27.44,27.05s-27.8-12.45-27.8-27.8v-.3c0-7.43-6.02-13.46-13.46-13.46h-.45c-15.35,0-27.8-12.45-27.8-27.8s12.45-27.8,27.8-27.8h.45Z"/>
                            </svg>
                          </div>
                          <span className="font-sans font-bold text-xs tracking-wide text-white">Superwizor AI</span>
                        </div>
                        {/* Hamburger menu icon */}
                        <svg className="w-5 h-5 text-white/95" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                          <line x1="4" y1="6" x2="20" y2="6" strokeLinecap="round" />
                          <line x1="4" y1="12" x2="20" y2="12" strokeLinecap="round" />
                          <line x1="4" y1="18" x2="20" y2="18" strokeLinecap="round" />
                        </svg>
                      </div>

                      {/* Main Scrollable Content */}
                      <div className="flex-1 overflow-y-auto scrollbar-none pr-0.5 pb-6 space-y-4 min-h-0">
                        {/* Greeting */}
                        <div className="px-1 shrink-0">
                          <div className="font-serif text-2xl font-medium leading-tight">
                            {isPl ? (
                              <>Witaj, <span className="text-amber font-bold italic">Marku :)</span></>
                            ) : (
                              <>Hello, <span className="text-amber font-bold italic">Marc :)</span></>
                            )}
                          </div>
                          <div className="text-[11px] text-[#8ba4a6] mt-0.5">
                            {isPl ? "Z kim dzisiaj pracujemy?" : "Who are we working with today?"}
                          </div>
                        </div>

                        {/* Search Bar */}
                        <div onClick={(e) => e.stopPropagation()} className="bg-[#133235] border border-[#1b4043] rounded-lg px-3 py-1.5 flex items-center gap-2 mx-1 shrink-0">
                          <svg className="w-3.5 h-3.5 text-[#8ba4a6]" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                            <circle cx="11" cy="11" r="8" />
                            <line x1="21" y1="21" x2="16.65" y2="16.65" />
                          </svg>
                          <span className="text-[11px] text-[#8ba4a6]">
                            {isPl ? "Szukaj klienta..." : "Search client..."}
                          </span>
                        </div>

                        {/* Section Header */}
                        <div className="flex justify-between items-center px-1 shrink-0">
                          <span className="font-sans text-[10px] uppercase font-bold tracking-wider text-[#8ba4a6]">
                            {isPl ? "Twoje kartoteki" : "Your records"}
                          </span>
                          <span className="font-sans text-[10px] text-[#8ba4a6] font-semibold">5</span>
                        </div>

                        {/* Client List */}
                        <div className="space-y-2 px-0.5 shrink-0">
                          
                          {/* Item 1: Klient Anna */}
                          <div onClick={(e) => { e.stopPropagation(); handleClientClick(isPl ? "Klient Anna" : "Client Anna"); }} className="bg-[#0f4f56] border border-[#1c646d]/40 rounded-xl p-2.5 flex items-center justify-between shadow-sm cursor-pointer hover:bg-[#135c64] transition-colors">
                            <div className="flex items-center gap-2.5">
                              <div className="w-8 h-8 rounded-full bg-[#042528] border border-[#ffb12c]/20 flex items-center justify-center shrink-0 shadow-sm text-[#ffb12c] text-[12px] font-bold">
                                AK
                              </div>
                              <div>
                                <div className="font-sans text-[13px] font-bold text-white flex items-center gap-1">
                                  {isPl ? "Klient Anna" : "Client Anna"}
                                </div>
                                <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                  {isPl ? "Sesje: 1 · Ostatnio: 12 Cze" : "Sessions: 1 · Last: Jun 12"}
                                </div>
                              </div>
                            </div>
                            <div className="flex items-center gap-2 shrink-0">
                              <span className="px-1.5 py-0.5 text-[9px] font-bold font-sans rounded bg-[#5bf4bc]/10 border border-[#5bf4bc]/20 text-[#5bf4bc] uppercase tracking-wider">
                                {isPl ? "raport gotowy" : "report ready"}
                              </span>
                              <span className="text-[#8ba4a6] text-xs">⋮</span>
                            </div>
                          </div>

                          {/* Item 2: Próbny Klient */}
                          <div onClick={(e) => { e.stopPropagation(); handleClientClick(isPl ? "Próbny Klient" : "Demo Client"); }} className="bg-[#0f4f56] border border-[#1c646d]/40 rounded-xl p-2.5 flex items-center justify-between shadow-sm cursor-pointer hover:bg-[#135c64] transition-colors">
                            <div className="flex items-center gap-2.5">
                              <div className="w-8 h-8 rounded-full bg-[#0e3a3e] border border-white/5 flex items-center justify-center shrink-0 shadow-sm text-white text-[12px] font-bold">
                                PK
                              </div>
                              <div>
                                <div className="font-sans text-[13px] font-bold text-white">
                                  {isPl ? "Próbny Klient" : "Demo Client"}
                                </div>
                                <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                  {isPl ? "Sesje: 4 · Ostatnio: 31 Maj" : "Sessions: 4 · Last: May 31"}
                                </div>
                              </div>
                            </div>
                            <span className="text-[#8ba4a6] text-xs">⋮</span>
                          </div>

                          {/* Item 3: Klient Jakub */}
                          <div onClick={(e) => { e.stopPropagation(); handleClientClick(isPl ? "Klient Jakub" : "Client Jacob"); }} className="bg-[#0f4f56] border border-[#1c646d]/40 rounded-xl p-2.5 flex items-center justify-between shadow-sm cursor-pointer hover:bg-[#135c64] transition-colors">
                            <div className="flex items-center gap-2.5">
                              <div className="w-8 h-8 rounded-full bg-[#3d2a1b] border border-white/5 flex items-center justify-center shrink-0 shadow-sm text-sm">
                                👍
                              </div>
                              <div>
                                <div className="font-sans text-[13px] font-bold text-white">
                                  {isPl ? "Klient Jakub" : "Client Jacob"}
                                </div>
                                <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                  {isPl ? "Sesje: 1 · Ostatnio: 29 Maj" : "Sessions: 1 · Last: May 29"}
                                </div>
                              </div>
                            </div>
                            <span className="text-[#8ba4a6] text-xs">⋮</span>
                          </div>

                          {/* Item 4: Klient Paweł */}
                          <div onClick={(e) => { e.stopPropagation(); handleClientClick(isPl ? "Klient Paweł" : "Client Paul"); }} className="bg-[#0f4f56] border border-[#1c646d]/40 rounded-xl p-2.5 flex items-center justify-between shadow-sm cursor-pointer hover:bg-[#135c64] transition-colors">
                            <div className="flex items-center gap-2.5">
                              <div className="w-8 h-8 rounded-full bg-[#1b253d] border border-white/5 flex items-center justify-center shrink-0 shadow-sm text-sm">
                                👌
                              </div>
                              <div>
                                <div className="font-sans text-[13px] font-bold text-white">
                                  {isPl ? "Klient Paweł" : "Client Paul"}
                                </div>
                                <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                  {isPl ? "Sesje: 2 · Ostatnio: 28 Maj" : "Sessions: 2 · Last: May 28"}
                                </div>
                              </div>
                            </div>
                            <span className="text-[#8ba4a6] text-xs">⋮</span>
                          </div>

                          {/* Item 5: Klient Monika */}
                          <div onClick={(e) => { e.stopPropagation(); handleClientClick(isPl ? "Klient Monika" : "Client Monica"); }} className="bg-[#0f4f56] border border-[#1c646d]/40 rounded-xl p-2.5 flex items-center justify-between shadow-sm cursor-pointer hover:bg-[#135c64] transition-colors">
                            <div className="flex items-center gap-2.5">
                              <div className="w-8 h-8 rounded-full bg-[#3d1b1b] border border-white/5 flex items-center justify-center shrink-0 shadow-sm text-sm">
                                ✨
                              </div>
                              <div>
                                <div className="font-sans text-[13px] font-bold text-white">
                                  {isPl ? "Klient Monika" : "Client Monica"}
                                </div>
                                <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                  {isPl ? "Sesje: 7 · Ostatnio: 11 Maj" : "Sessions: 7 · Last: May 11"}
                                </div>
                              </div>
                            </div>
                            <span className="text-[#8ba4a6] text-xs">⋮</span>
                          </div>

                        </div>

                        {/* Collapsible Sections */}
                        <div className="space-y-3 pt-2">
                          {/* Wstrzymane */}
                          <div className="space-y-2">
                            <button 
                              onClick={(e) => {
                                e.stopPropagation();
                                setExpandedSection(expandedSection === 'wstrzymane' ? 'none' : 'wstrzymane');
                              }}
                              className="w-full flex items-center gap-2 px-1 py-1 text-[#8ba4a6]/95 hover:text-white transition-colors cursor-pointer select-none text-left"
                            >
                              <svg 
                                className={`w-3.5 h-3.5 transition-transform duration-200 ${expandedSection === 'wstrzymane' ? 'rotate-90' : ''}`} 
                                fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24"
                              >
                                <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                              </svg>
                              <span className="font-sans text-[11px] uppercase font-bold tracking-wider">
                                {isPl ? "Wstrzymane (4)" : "Paused (4)"}
                              </span>
                            </button>
                            
                            {expandedSection === 'wstrzymane' && (
                              <div className="space-y-2 pl-3 animate-[fadeIn_0.2s_ease-out]">
                                {[
                                  { name: isPl ? "Klient Weronika" : "Client Veronica", sessions: 3, date: isPl ? "15 Maj" : "May 15", initials: "KW" },
                                  { name: isPl ? "Klient Tomasz" : "Client Thomas", sessions: 5, date: isPl ? "12 Maj" : "May 12", initials: "KT" },
                                  { name: isPl ? "Klient Anna" : "Client Anna", sessions: 2, date: isPl ? "8 Maj" : "May 8", initials: "AK" },
                                  { name: isPl ? "Klient Piotr" : "Client Peter", sessions: 1, date: isPl ? "3 Maj" : "May 3", initials: "KP" }
                                ].map((client, idx) => (
                                  <div key={idx} onClick={(e) => { e.stopPropagation(); handleClientClick(client.name); }} className="bg-[#0f4f56]/50 border border-[#1c646d]/30 rounded-xl p-2.5 flex items-center justify-between shadow-sm opacity-80 animate-[fadeIn_0.2s_ease-out] cursor-pointer hover:bg-[#135c64]/50 transition-colors">
                                    <div className="flex items-center gap-2.5">
                                      <div className="w-8 h-8 rounded-full bg-[#1c2e30] border border-white/5 flex items-center justify-center shrink-0 text-[#8ba4a6] text-xs font-bold font-mono">
                                        {client.initials}
                                      </div>
                                      <div>
                                        <div className="font-sans text-[13px] font-bold text-white/95">
                                          {client.name}
                                        </div>
                                        <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                          {isPl ? `Sesje: ${client.sessions} · Ostatnio: ${client.date}` : `Sessions: ${client.sessions} · Last: ${client.date}`}
                                        </div>
                                      </div>
                                    </div>
                                    <span className="bg-[#2a2d21] text-[#eab308] text-[8px] px-1.5 py-0.5 rounded-full font-bold flex items-center gap-1 shrink-0 border border-[#eab308]/20">
                                      <span className="w-1.5 h-1.5 rounded-full bg-[#eab308]" />
                                      {isPl ? "Wstrzymane" : "Paused"}
                                    </span>
                                  </div>
                                ))}
                              </div>
                            )}
                          </div>

                          {/* Zakończone */}
                          <div className="space-y-2">
                            <button 
                              onClick={(e) => {
                                e.stopPropagation();
                                setExpandedSection(expandedSection === 'zakonczone' ? 'none' : 'zakonczone');
                              }}
                              className="w-full flex items-center gap-2 px-1 py-1 text-[#5bf4bc] hover:text-[#4ad6a2] transition-colors cursor-pointer select-none text-left"
                            >
                              <svg 
                                className={`w-3.5 h-3.5 transition-transform duration-200 ${expandedSection === 'zakonczone' ? 'rotate-90' : ''}`} 
                                fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24"
                              >
                                <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                              </svg>
                              <span className="font-sans text-[11px] uppercase font-bold tracking-wider">
                                {isPl ? "Zakończone (6)" : "Completed (6)"}
                              </span>
                            </button>
                            
                            {expandedSection === 'zakonczone' && (
                              <div className="space-y-2 pl-3 animate-[fadeIn_0.2s_ease-out]">
                                {[
                                  { name: isPl ? "Klient Monika" : "Client Monica", sessions: 12, date: isPl ? "25 Kwi" : "Apr 25", initials: "KM" },
                                  { name: isPl ? "Klient Karol" : "Client Charles", sessions: 8, date: isPl ? "18 Kwi" : "Apr 18", initials: "KK" },
                                  { name: isPl ? "Klient Zofia" : "Client Sophia", sessions: 10, date: isPl ? "10 Kwi" : "Apr 10", initials: "KZ" },
                                  { name: isPl ? "Klient Michał" : "Client Michael", sessions: 6, date: isPl ? "5 Kwi" : "Apr 5", initials: "KM" },
                                  { name: isPl ? "Klient Ewa" : "Client Eve", sessions: 15, date: isPl ? "28 Mar" : "Mar 28", initials: "KE" },
                                  { name: isPl ? "Klient Jan" : "Client John", sessions: 4, date: isPl ? "15 Mar" : "Mar 15", initials: "KJ" }
                                ].map((client, idx) => (
                                  <div key={idx} onClick={(e) => { e.stopPropagation(); handleClientClick(client.name); }} className="bg-[#0f4f56]/50 border border-[#1c646d]/30 rounded-xl p-2.5 flex items-center justify-between shadow-sm opacity-85 animate-[fadeIn_0.2s_ease-out] cursor-pointer hover:bg-[#135c64]/50 transition-colors">
                                    <div className="flex items-center gap-2.5">
                                      <div className="w-8 h-8 rounded-full bg-[#153a33] border border-white/5 flex items-center justify-center shrink-0 text-[#5bf4bc] text-xs font-bold font-mono">
                                        {client.initials}
                                      </div>
                                      <div>
                                        <div className="font-sans text-[13px] font-bold text-white/95">
                                          {client.name}
                                        </div>
                                        <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                          {isPl ? `Sesje: ${client.sessions} · Ostatnio: ${client.date}` : `Sessions: ${client.sessions} · Last: ${client.date}`}
                                        </div>
                                      </div>
                                    </div>
                                    <span className="bg-[#15352c] text-[#5bf4bc] text-[8px] px-1.5 py-0.5 rounded-full font-bold flex items-center gap-1 shrink-0 border border-[#5bf4bc]/20">
                                      <span className="w-1.5 h-1.5 rounded-full bg-[#5bf4bc]" />
                                      {isPl ? "Zakończona" : "Completed"}
                                    </span>
                                  </div>
                                ))}
                              </div>
                            )}
                          </div>
                        </div>

                      </div>

                      {/* Floating Action Button */}
                      <button 
                        onClick={(e) => {
                          e.stopPropagation();
                          setToast(isPl ? "Funkcja tworzenia kartoteki (wersja demonstracyjna)" : "Create record feature (demo)");
                          setTimeout(() => setToast(null), 2000);
                        }}
                        className="absolute bottom-4 right-4 w-12 h-12 rounded-2xl bg-[#fcae2f] hover:bg-[#e09825] shadow-lg border border-white/10 flex items-center justify-center text-[#06383e] active:scale-95 transition-all duration-200 cursor-pointer z-20"
                        aria-label="Add client"
                      >
                        <svg className="w-6 h-6 stroke-[3]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                        </svg>
                      </button>
                    </div>
                  )}

                  {/* Overlay Dialogs, Bottom Sheet & Toast */}
                  {toast && (
                    <div className="absolute top-[48px] left-4 right-4 bg-[#0a474e] border border-[var(--accent-color)]/20 rounded-xl p-3 shadow-[0_8px_32px_rgba(0,0,0,0.4)] z-50 animate-[fadeIn_0.2s_ease-out] flex items-center gap-3 select-none">
                      <div className="w-6 h-6 rounded-full bg-[var(--accent-bg-light)] border border-[var(--accent-border-light)] flex items-center justify-center text-[var(--accent-color)] text-xs font-bold shrink-0">
                        ✓
                      </div>
                      <span className="font-sans text-xs text-white/95 font-semibold leading-none">{toast}</span>
                    </div>
                  )}

                  {activeDialog === "dislike" && (
                    <div 
                      className="absolute inset-0 bg-black/60 backdrop-blur-[1px] z-30 flex items-end justify-center animate-[fadeIn_0.2s_ease-out]"
                      onClick={() => {
                        setActiveDialog(null);
                        setIsDisliked(false);
                      }}
                    >
                      <div 
                        className="bg-[#0a474e] border-t border-[var(--card-border)] rounded-t-[28px] p-5 w-full shadow-2xl text-left animate-[slideUp_0.3s_cubic-bezier(0.16,1,0.3,1)_both]"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {/* Bottom Sheet Handle */}
                        <div className="w-12 h-1 bg-white/10 rounded-full mx-auto mb-4" />

                        <div className="flex items-center gap-2 mb-1.5">
                          <div className="w-6 h-6 rounded-lg bg-[#ef4444]/10 border border-[#ef4444]/20 flex items-center justify-center text-[#ff4b4b] shrink-0">
                            <span className="text-xs font-bold">!</span>
                          </div>
                          <h4 className="font-sans font-bold text-[var(--text-pri)] text-[13px] sm:text-[14px] leading-snug">
                            {isPl ? "Co poszło nie tak?" : "What went wrong?"}
                          </h4>
                        </div>
                        <p className="font-sans text-[10.5px] text-[var(--text-sec-50)] mb-4 leading-relaxed">
                          {isPl 
                            ? "Wybierz jedną lub więcej kategorii. Pomoże nam to dostroić kolejne raporty." 
                            : "Select one or more categories. This will help us fine-tune future reports."}
                        </p>
                        
                        <div className="flex flex-wrap gap-1.5 mb-4">
                          {(isPl ? DISLIKE_OPTIONS_PL : DISLIKE_OPTIONS_EN).map((chip, idx) => {
                            const isSelected = dislikeSelectedChips.includes(idx);
                            return (
                              <button
                                key={chip}
                                onClick={() => {
                                  if (isSelected) {
                                    setDislikeSelectedChips(dislikeSelectedChips.filter((i) => i !== idx));
                                  } else {
                                    setDislikeSelectedChips([...dislikeSelectedChips, idx]);
                                  }
                                }}
                                className={`px-2.5 py-1.5 rounded-full text-[10px] font-bold border transition-colors cursor-pointer flex items-center gap-1 ${
                                  isSelected 
                                    ? "border-[#ff4b4b] bg-[#ff4b4b]/10 text-[#ff4b4b]" 
                                    : "border-white/10 text-white/60 hover:text-white hover:border-white/20 bg-transparent"
                                }`}
                              >
                                {isSelected && <span>✓</span>}
                                <span>{chip}</span>
                              </button>
                            );
                          })}
                        </div>

                        <div className="mb-4">
                          <label className="block text-[8.5px] uppercase tracking-wider text-[var(--text-sec-50)] font-mono mb-1 font-bold">
                            {isPl ? "Dodatkowy komentarz (opcjonalnie)" : "Additional comment (optional)"}
                          </label>
                          <textarea 
                            className="w-full bg-[var(--toggle-bg)] border border-[var(--card-border)] rounded-xl px-3 py-2 text-xs text-[var(--text-pri)] placeholder-[var(--text-sec-50)]/45 focus:outline-none focus:border-[#ff4b4b]/30 h-16 resize-none"
                            placeholder={isPl ? "Krótka notatka, max. 200 znaków..." : "Short note, max 200 chars..."}
                            maxLength={200}
                          />
                          <div className="text-right text-[8px] text-white/30 mt-0.5">0/200</div>
                        </div>
                        
                        <div className="flex gap-2.5">
                          <button
                            onClick={() => {
                              setActiveDialog(null);
                              setDislikeSelectedChips([]);
                              setIsDisliked(true);
                              showToast(isPl ? "Dziękujemy za przesłanie uwag." : "Thank you for sending your comments.");
                            }}
                            className="w-full py-2.5 rounded-xl bg-[#fcae2f] text-[#0a1e20] hover:bg-[#ffb12c] text-xs font-bold cursor-pointer transition-colors text-center"
                          >
                            {isPl ? "Wyślij ocenę" : "Send rating"}
                          </button>
                        </div>
                      </div>
                    </div>
                  )}

                  {activeDialog === "email" && (
                    <div 
                      className="absolute inset-0 bg-black/60 backdrop-blur-[1px] z-30 flex items-end justify-center animate-[fadeIn_0.2s_ease-out]"
                      onClick={() => {
                        setActiveDialog(null);
                        setEmailState("idle");
                      }}
                    >
                      <div 
                        className="bg-[#0a474e] border-t border-[var(--card-border)] rounded-t-3xl p-5 w-full shadow-2xl text-left animate-[slideUp_0.3s_cubic-bezier(0.16,1,0.3,1)_both]"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {/* Bottom Sheet Handle */}
                        <div className="w-12 h-1 bg-white/10 rounded-full mx-auto mb-4" />

                        <h4 className="font-sans font-bold text-[var(--text-pri)] text-[13px] sm:text-[14px] mb-1 leading-snug">
                          {isPl ? "Wyślij podsumowanie do klienta" : "Send summary to client"}
                        </h4>
                        <p className="font-sans text-[10.5px] text-[var(--text-sec-50)] mb-4 leading-relaxed">
                          {isPl 
                            ? "Prześlij bezpieczną, pozbawioną żargonu notatkę z zaleceniami po sesji." 
                            : "Send a secure, jargon-free summary note with recommendations directly to your client."}
                        </p>

                        {emailState === "idle" && (
                          <div className="space-y-3.5">
                            <div>
                              <label className="block text-[8.5px] uppercase tracking-wider text-[var(--text-sec-50)] font-mono mb-1 font-bold">
                                {isPl ? "E-mail odbiorcy" : "Recipient Email"}
                              </label>
                              <input 
                                type="email" 
                                defaultValue="klient@example.com" 
                                className="w-full bg-[var(--toggle-bg)] border border-[var(--card-border)] rounded-lg px-3 py-1.5 text-xs text-[var(--text-pri)] placeholder-[var(--text-sec-50)]/45 focus:outline-none focus:border-[var(--accent-color)]/40"
                                placeholder="email@klienta.pl"
                              />
                            </div>

                            <label className="flex items-start gap-2.5 cursor-pointer select-none">
                              <input 
                                type="checkbox" 
                                defaultChecked 
                                className="mt-0.5 accent-[#5bf4bc] rounded"
                              />
                              <span className="font-sans text-[10.5px] text-[var(--text-sec)]/90 leading-normal">
                                {isPl ? "Załącz zalecenia z planu działania klienta" : "Attach recommendations from client's action plan"}
                              </span>
                            </label>

                            <div className="flex gap-2.5 pt-2">
                              <button
                                onClick={() => { setActiveDialog(null); setEmailState("idle"); }}
                                className="flex-1 py-2 rounded-lg border border-white/10 text-white/70 hover:text-white text-xs font-bold cursor-pointer transition-colors"
                              >
                                {isPl ? "Anuluj" : "Cancel"}
                              </button>
                              <button
                                onClick={() => {
                                  setEmailState("sending");
                                  setTimeout(() => {
                                    setEmailState("sent");
                                    setTimeout(() => {
                                      setActiveDialog(null);
                                      setEmailState("idle");
                                      showToast(isPl ? "Wysłano pomyślnie!" : "Sent successfully!");
                                    }, 1000);
                                  }, 1200);
                                }}
                                className="flex-1 py-2 rounded-lg bg-[var(--accent-color)] text-[var(--toggle-active-text)] hover:opacity-90 text-xs font-bold cursor-pointer transition-colors flex items-center justify-center gap-1.5"
                              >
                                <span>{isPl ? "Wyślij bezpiecznie" : "Send securely"}</span>
                              </button>
                            </div>
                          </div>
                        )}

                        {emailState === "sending" && (
                          <div className="py-6 flex flex-col items-center justify-center gap-3">
                            <div className="w-6 h-6 border-2 border-white/10 border-t-[#5bf4bc] rounded-full animate-spin" />
                            <span className="font-sans text-xs text-[var(--text-sec)]">
                              {isPl ? "Szyfrowanie i wysyłanie..." : "Encrypting and sending..."}
                            </span>
                          </div>
                        )}

                        {emailState === "sent" && (
                          <div className="py-6 flex flex-col items-center justify-center gap-2 animate-[fadeIn_0.2s_ease-out]">
                            <div className="w-8 h-8 rounded-full bg-[var(--accent-bg-light)] border border-[var(--accent-border-light)] flex items-center justify-center text-[var(--accent-color)] text-lg">
                              ✓
                            </div>
                            <span className="font-sans text-xs font-bold text-[var(--text-pri)]">
                              {isPl ? "Wysłano bezpiecznie!" : "Sent securely!"}
                            </span>
                          </div>
                        )}
                      </div>
                    </div>
                  )}

                </div>

                {/* Footer bar Mockup */}
                <div className="flex justify-between items-center pt-4 border-t border-[var(--footer-border)] mt-4 text-[10px] lg:text-[12px] text-[var(--text-sec-50)]">
                  <span>{isPl ? "Zaszyfrowano kluczem AES-256-GCM" : "Encrypted with AES-256-GCM"}</span>
                  <span className="flex items-center gap-1">
                    <span className="w-1.5 h-1.5 rounded-full bg-[var(--accent-color)] animate-pulse" />
                    {isPl ? "Serwer UE: Zgodne z RODO" : "EU Server: GDPR Compliant"}
                  </span>
                </div>

              </div>
            </div>

            </div> {/* Closing the wrapper div */}

            {/* Pagination dots with navigation arrows */}
            <div className="flex lg:hidden justify-center items-center gap-4 mt-5 select-none animate-[fadeIn_0.5s_ease-out]" onClick={(e) => e.stopPropagation()}>
              {/* Left Arrow Button */}
              <button 
                onClick={handlePrevTab}
                className="w-7 h-7 rounded-full border border-[#004D54]/15 bg-white text-[#004D54] hover:bg-[#004D54]/5 active:scale-95 flex items-center justify-center transition-all cursor-pointer shadow-sm"
                aria-label="Previous tab"
              >
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                </svg>
              </button>

              {/* Pagination dots */}
              <div className="flex gap-2">
                {(["record", "transcript", "report", "continuity", "modality", "folder"] as const).map((key) => (
                  <button
                    key={key}
                    onClick={(e) => { e.stopPropagation(); setActiveTab(key); }}
                    className={`h-2 rounded-full transition-all duration-300 cursor-pointer ${
                      activeTab === key ? "w-6 bg-[#004D54]" : "w-2 bg-[#004D54]/20"
                    }`}
                    aria-label={`Go to tab ${key}`}
                  />
                ))}
              </div>

              {/* Right Arrow Button */}
              <button 
                onClick={handleNextTab}
                className="w-7 h-7 rounded-full border border-[#004D54]/15 bg-white text-[#004D54] hover:bg-[#004D54]/5 active:scale-95 flex items-center justify-center transition-all cursor-pointer shadow-sm"
                aria-label="Next tab"
              >
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                </svg>
              </button>
            </div>

            {/* Desktop Click Hint */}
            <div className="block lg:hidden text-center mt-3.5 text-[11.5px] text-[#004D54]/60 font-semibold select-none tracking-wide animate-[pulse_3s_infinite]">
              {isPl ? "✨ Kliknij ekran lub strzałki, aby przełączać funkcje" : "✨ Click screen or arrows to cycle features"}
            </div>



          </div>

        </div>

        {/* CTA Button */}
        <div className="mt-16 flex flex-col items-center">
          <a
            href="#cennik"
            className="group relative inline-flex items-center justify-center rounded-[12px] bg-[#004D54] text-frost font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 transition-all duration-300 hover:bg-[#002E32] active:scale-[0.97] whitespace-nowrap overflow-hidden"
          >
            <span className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-700" />
            <span className="relative">
              {tHero("ctaPrimary")}
            </span>
          </a>
        </div>

      </div>
      
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(6px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes slideUp {
          from { transform: translateY(100%); }
          to { transform: translateY(0); }
        }
        @keyframes recording-ripple {
          0% {
            transform: scale(0.1);
            opacity: 0.9;
          }
          100% {
            transform: scale(2.65);
            opacity: 0;
          }
        }
        @keyframes waveform {
          0% {
            transform: scaleY(0.35);
          }
          100% {
            transform: scaleY(1.25);
          }
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