"use client";

import { useState, useEffect, useCallback, type ReactNode } from "react";
import { motion, AnimatePresence } from "framer-motion";

// ─── Modality Labels ──────────────────────────────────────
const LABELS: Record<string, string> = {
  UNIV: "Integracyjny",
  CBT: "CBT",
  PSYCHO: "Psychodynamiczny",
  GESTALT: "Gestalt",
  PPT: "Pozytywna (PPT)",
  ST: "Schematów",
  SYS: "Systemowa",
  EFT: "EFT",
  COACH: "Coaching",
};

// ─── EMOJI Icons ──────────────────────────────────────────
const EMOJI_ICONS: Record<string, string> = {
  UNIV: "🔗",
  CBT: "🧠",
  PSYCHO: "🧘",
  GESTALT: "🎯",
  PPT: "☀️",
  ST: "🧩",
  SYS: "👨‍👩‍👧‍👦",
  EFT: "❤️",
  COACH: "📈",
};

// ─── SVG Icons (Lucide-style) ─────────────────────────────
const ic = "w-5 h-5";
const SVG_ICONS: Record<string, (a: boolean) => ReactNode> = {
  // Hub / Network — connected nodes
  UNIV: (a) => <svg className={ic} viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="1.5"/><circle cx="6" cy="6" r="1.5"/><circle cx="18" cy="6" r="1.5"/><circle cx="6" cy="18" r="1.5"/><circle cx="18" cy="18" r="1.5"/><path d="M12 12L6 6M12 12l6-6M12 12L6 18M12 12l6 6"/></svg>,
  // Lightbulb — cognitive insight
  CBT: (a) => <svg className={ic} viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/></svg>,
  // Layers — deep unconscious layers
  PSYCHO: (a) => <svg className={ic} viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="m12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z"/><path d="m6.08 9.5-3.5 1.6a1 1 0 0 0 0 1.81l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9a1 1 0 0 0 0-1.83l-3.5-1.59"/><path d="m6.08 14.5-3.5 1.6a1 1 0 0 0 0 1.81l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9a1 1 0 0 0 0-1.83l-3.5-1.59"/></svg>,
  // Concentric circles — figure/ground
  GESTALT: (a) => <svg className={ic} viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5"/></svg>,
  // Sun — positive psychology
  PPT: (a) => <svg className={ic} viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/></svg>,
  // Grid — schemas/patterns
  ST: (a) => <svg className={ic} viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>,
  // Users — systemic/family
  SYS: (a) => <svg className={ic} viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>,
  // Heart — emotion-focused
  EFT: (a) => <svg className={ic} viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/></svg>,
  // TrendingUp — coaching growth
  COACH: (a) => <svg className={ic} viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/></svg>,
};

// ─── Step 5 icons ─────────────────────────────────────────
const SvgSeedling = ({ a }: { a: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M7 20h10"/><path d="M10 20c5.5-2.5.8-6.4 3-10"/><path d="M9.5 9.4c1.1.8 1.8 2.2 2.3 3.7-2 .4-3.5.4-4.8-.3-1.2-.6-2.3-1.9-3-4.2 2.8-.5 4.4 0 5.5.8Z"/><path d="M14.1 6a7 7 0 0 0-1.1 4c1.9-.1 3.3-.6 4.3-1.4 1-1 1.6-2.3 1.7-4.6-2.7.1-4 1-4.9 2Z"/></svg>;
const SvgTree = ({ a }: { a: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M11 20a7 7 0 0 1-9.9 1.1"/><path d="M11 20H4.5C2.57 20 1 18.43 1 16.5S2.57 13 4.5 13H11"/><path d="M13 20h6.5c1.93 0 3.5-1.57 3.5-3.5S21.43 13 19.5 13H13"/><path d="M13 20a7 7 0 0 0 9.9 1.1"/><path d="M12 20V10"/><path d="m8 16 4-6 4 6"/><path d="m9 12 3-5 3 5"/></svg>;
const SvgForest = ({ a }: { a: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="m10 8 2-3 2 3"/><path d="m9 12 3-4 3 4"/><path d="m8 16 4-5 4 5"/><path d="M12 16v5"/><path d="M3 21h18"/></svg>;
const SvgChart = () => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="12" width="4" height="9" rx="1"/><rect x="10" y="7" width="4" height="14" rx="1"/><rect x="17" y="3" width="4" height="18" rx="1"/></svg>;
const SvgMonitor = ({ a }: { a: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>;
const SvgBuilding = ({ a }: { a: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M3 21h18M5 21V7l7-4 7 4v14"/><path d="M9 10h2v2H9zM13 10h2v2h-2zM9 15h2v2H9zM13 15h2v2h-2z"/></svg>;
const SvgShuffle = ({ a }: { a: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={a?"#F2F0EA":"#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M2 18h1.4c1.3 0 2.5-.6 3.3-1.7l6.1-8.6c.7-1.1 2-1.7 3.3-1.7H22"/><path d="m18 2 4 4-4 4"/><path d="M2 6h1.9c1.5 0 2.9.9 3.6 2.2"/><path d="M22 18h-5.9c-1.3 0-2.6-.7-3.3-1.8l-.5-.8"/><path d="m18 14 4 4-4 4"/></svg>;

// ─── Animations ───────────────────────────────────────────
const cardVariants = {
  enter: (d: number) => ({ x: d > 0 ? 300 : -300, opacity: 0, scale: 0.95 }),
  center: { x: 0, opacity: 1, scale: 1 },
  exit: (d: number) => ({ x: d < 0 ? 300 : -300, opacity: 0, scale: 0.95 }),
};

function StepCard({ children, direction }: { children: React.ReactNode; direction: number }) {
  return (
    <motion.div
      custom={direction}
      variants={cardVariants}
      initial="enter"
      animate="center"
      exit="exit"
      transition={{ type: "spring", stiffness: 300, damping: 30 }}
      className="w-full max-w-md mx-auto rounded-3xl bg-gradient-to-b from-[#0D2B2F] to-[#0A2326] border border-[#1A3A3E] shadow-2xl p-8 relative"
    >
      {children}
    </motion.div>
  );
}

// ─── Preview Page ─────────────────────────────────────────
type Step = 4 | 5 | 6 | 7;
export default function OnboardingPreview() {
  const [step, setStep] = useState<Step>(4);
  const [direction, setDirection] = useState(1);
  const [selectedModality, setSelectedModality] = useState("");
  const [weeklySessions, setWeeklySessions] = useState<"up_to_7" | "up_to_20" | "more_than_20" | "">("");
  const [workFormat, setWorkFormat] = useState<"online" | "in_person" | "hybrid" | "">("");
  const [useEmoji, setUseEmoji] = useState(false);

  // Animated monthly counter
  const monthlyTarget = weeklySessions === "up_to_7" ? 30 : weeklySessions === "up_to_20" ? 87 : 0;
  const [monthlyCount, setMonthlyCount] = useState(0);
  useEffect(() => {
    if (!monthlyTarget) { setMonthlyCount(0); return; }
    setMonthlyCount(0);
    const steps = 30;
    const increment = monthlyTarget / steps;
    let current = 0;
    const timer = setInterval(() => {
      current += increment;
      if (current >= monthlyTarget) { setMonthlyCount(monthlyTarget); clearInterval(timer); }
      else setMonthlyCount(Math.round(current));
    }, 800 / steps);
    return () => clearInterval(timer);
  }, [monthlyTarget]);

  const goTo = (n: Step) => { setDirection(n > step ? 1 : -1); setStep(n); };
  const modalities = Object.entries(LABELS).map(([code, label]) => ({ code, label }));

  return (
    <div className="min-h-screen bg-[#091E21] flex flex-col items-center justify-center px-5 py-10">
      {/* Toggle Emoji / SVG */}
      <div className="flex items-center gap-3 mb-6">
        <button
          onClick={() => setUseEmoji(false)}
          className={`px-4 py-2 rounded-xl font-sans text-xs font-bold transition-all cursor-pointer ${!useEmoji ? "bg-[#F5A623] text-[#0A2326]" : "bg-[#1A3A3E] text-[#8FA5A0] hover:bg-[#2F6B62]"}`}
        >
          ✦ SVG Ikonki
        </button>
        <button
          onClick={() => setUseEmoji(true)}
          className={`px-4 py-2 rounded-xl font-sans text-xs font-bold transition-all cursor-pointer ${useEmoji ? "bg-[#F5A623] text-[#0A2326]" : "bg-[#1A3A3E] text-[#8FA5A0] hover:bg-[#2F6B62]"}`}
        >
          😊 Emoji
        </button>
      </div>

      {/* Progress */}
      <div className="flex items-center gap-2.5 mb-8">
        {([4,5,6,7] as Step[]).map((n) => (
          <motion.div
            key={n}
            className={`rounded-full cursor-pointer transition-all duration-300 ${n === step ? "w-8 h-3 bg-gradient-to-r from-[#F5A623] to-[#E09500]" : n < step ? "w-3 h-3 bg-[#F5A623]/40" : "w-3 h-3 bg-[#1A3A3E]"}`}
            onClick={() => goTo(n)}
            layout
          />
        ))}
      </div>

      {/* Steps */}
      <div className="w-full max-w-md relative">
        <AnimatePresence mode="wait" custom={direction}>

          {/* ── Step 4: Modality ── */}
          {step === 4 && (
            <StepCard key="step4" direction={direction}>
              {useEmoji ? (
                <div className="text-4xl mb-4 text-center">🎓</div>
              ) : (
                <div className="w-12 h-12 mx-auto mb-4 rounded-2xl bg-[#0F2E32] border border-[#2F6B62]/40 flex items-center justify-center">
                  <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="#8FA5A0" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/><path d="M8 7h8M8 11h5"/></svg>
                </div>
              )}
              <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] text-center mb-2">Wybierz swój nurt</h2>
              <p className="font-sans text-sm text-[#8FA5A0] text-center leading-relaxed mb-6">
                W jakim nurcie najczęściej prowadzisz sesje? Możesz to zmienić później.
              </p>

              <div className="grid grid-cols-3 gap-2.5 mb-6">
                {modalities.map(({ code, label }) => (
                  <motion.button
                    key={code}
                    type="button"
                    onClick={() => setSelectedModality(code)}
                    className={`flex flex-col items-center gap-1.5 py-3.5 px-2 rounded-2xl border transition-all text-center ${
                      selectedModality === code
                        ? "bg-[#004D54] border-[#2F6B62] shadow-[0_0_20px_rgba(79,192,151,0.12)]"
                        : "bg-[#0F2E32]/60 border-[#1A3A3E] hover:border-[#2F6B62]"
                    }`}
                    whileHover={{ scale: 1.04 }}
                    whileTap={{ scale: 0.96 }}
                  >
                    {useEmoji ? (
                      <span className="text-2xl select-none">{EMOJI_ICONS[code]}</span>
                    ) : (
                      <div className="w-8 h-8 rounded-xl bg-[#0A2326] border border-[#1A3A3E] flex items-center justify-center">
                        {SVG_ICONS[code]?.(selectedModality === code)}
                      </div>
                    )}
                    <span className={`font-sans text-[10px] font-bold leading-tight ${selectedModality === code ? "text-white" : "text-[#8FA5A0]"}`}>
                      {label}
                    </span>
                  </motion.button>
                ))}
              </div>

              <button
                onClick={() => goTo(5)}
                disabled={!selectedModality}
                className="w-full py-3.5 rounded-xl font-sans text-sm font-bold tracking-wide bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#0A2326] disabled:opacity-40 transition-all hover:shadow-lg hover:shadow-[#F5A623]/20 cursor-pointer disabled:cursor-not-allowed"
              >
                DALEJ
              </button>
            </StepCard>
          )}

          {/* ── Step 5: Sessions (SEPARATE) ── */}
          {step === 5 && (
            <StepCard key="step5" direction={direction}>
              <button type="button" onClick={() => goTo(4)} className="absolute top-6 left-6 flex items-center gap-1.5 text-xs font-bold text-[#8FA5A0] hover:text-white transition-colors cursor-pointer">
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}><path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7"/></svg>
                <span>Wróć</span>
              </button>

              <h2 className="font-serif text-xl sm:text-2xl font-bold text-[#F2F0EA] text-center mb-1 mt-3">
                Ile sesji prowadzisz w tygodniu?
              </h2>
              <p className="font-sans text-[11px] text-[#8FA5A0] text-center leading-relaxed mb-6">
                Pomoże nam dopasować odpowiedni plan.
              </p>

              <div className="grid grid-cols-1 gap-2.5 mb-4">
                {[
                  { id: "up_to_7" as const, pl: "Do 7 sesji / tydz.", emoji: "🌱" },
                  { id: "up_to_20" as const, pl: "Do 20 sesji / tydz.", emoji: "🌿" },
                  { id: "more_than_20" as const, pl: "Powyżej 20 sesji / tydz.", emoji: "🌳" },
                ].map(({ id, pl, emoji }) => (
                  <button
                    key={id}
                    type="button"
                    onClick={() => setWeeklySessions(id)}
                    className={`flex items-center gap-3 p-3.5 rounded-xl border text-left transition-all ${
                      weeklySessions === id
                        ? "bg-[#004D54]/75 border-[#2F6B62] shadow-[0_2px_10px_rgba(79,192,151,0.06)]"
                        : "bg-[#0F2E32]/40 border-[#1A3A3E] hover:border-[#2F6B62]/60"
                    }`}
                  >
                    {useEmoji ? (
                      <span className="text-xl select-none">{emoji}</span>
                    ) : (
                      <span className="flex-shrink-0">
                        {id === "up_to_7" ? <SvgSeedling a={weeklySessions === id}/> : id === "up_to_20" ? <SvgTree a={weeklySessions === id}/> : <SvgForest a={weeklySessions === id}/>}
                      </span>
                    )}
                    <span className={`block font-sans text-sm font-bold ${weeklySessions === id ? "text-white" : "text-[#8FA5A0]"}`}>
                      {pl}
                    </span>
                  </button>
                ))}
              </div>

              {/* Animated monthly counter */}
              {weeklySessions && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  transition={{ duration: 0.3, ease: "easeOut" }}
                  className="mb-4 rounded-xl border border-[#2F6B62]/30 bg-[#0A2326]/60 p-4 flex items-center gap-3"
                >
                  {useEmoji ? (
                    <span className="text-lg select-none">📊</span>
                  ) : (
                    <span className="flex-shrink-0"><SvgChart /></span>
                  )}
                  <div className="flex-1">
                    <span className="font-sans text-[10px] text-[#8FA5A0] uppercase tracking-wider">
                      Miesięcznie to około
                    </span>
                    <div className="flex items-baseline gap-1.5 mt-0.5">
                      <span className="font-serif text-2xl font-bold text-[#F5A623] tabular-nums">
                        {weeklySessions === "more_than_20" ? "80+" : `~${monthlyCount}`}
                      </span>
                      <span className="font-sans text-xs text-[#8FA5A0]">sesji / miesiąc</span>
                    </div>
                    <span className="font-sans text-[10px] text-[#8FA5A0]/60 mt-0.5 block">
                      {weeklySessions === "up_to_7" ? "Plan Podstawowy" : weeklySessions === "up_to_20" ? "Plan Profesjonalny" : "Skontaktuj się — dopasujemy plan"}
                    </span>
                  </div>
                </motion.div>
              )}

              <button
                onClick={() => goTo(6)}
                disabled={!weeklySessions}
                className="w-full py-3.5 rounded-xl font-sans text-sm font-bold tracking-wide bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#0A2326] disabled:opacity-40 transition-all hover:shadow-lg cursor-pointer disabled:cursor-not-allowed"
              >
                DALEJ
              </button>
            </StepCard>
          )}

          {/* ── Step 6: Work Format (SEPARATE) ── */}
          {step === 6 && (
            <StepCard key="step6" direction={direction}>
              <button type="button" onClick={() => goTo(5)} className="absolute top-6 left-6 flex items-center gap-1.5 text-xs font-bold text-[#8FA5A0] hover:text-white transition-colors cursor-pointer">
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}><path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7"/></svg>
                <span>Wróć</span>
              </button>

              <h2 className="font-serif text-xl sm:text-2xl font-bold text-[#F2F0EA] text-center mb-1 mt-3">
                Jak pracujesz z klientami?
              </h2>
              <p className="font-sans text-[11px] text-[#8FA5A0] text-center leading-relaxed mb-6">
                Wybierz format, który najczęściej stosujesz.
              </p>

              <div className="grid grid-cols-1 gap-2.5 mb-6">
                {[
                  { id: "online" as const, pl: "Online", desc: "sesje zdalne (wideo / telefon)", emoji: "🧑‍💻" },
                  { id: "in_person" as const, pl: "W gabinecie", desc: "sesje stacjonarne", emoji: "🏢" },
                  { id: "hybrid" as const, pl: "Hybrydowo", desc: "mieszany format — oba rodzaje", emoji: "🔄" },
                ].map(({ id, pl, desc, emoji }) => (
                  <button
                    key={id}
                    type="button"
                    onClick={() => setWorkFormat(id)}
                    className={`flex items-center gap-3.5 p-4 rounded-xl border text-left transition-all ${
                      workFormat === id
                        ? "bg-[#004D54]/75 border-[#2F6B62] shadow-[0_2px_10px_rgba(79,192,151,0.06)]"
                        : "bg-[#0F2E32]/40 border-[#1A3A3E] hover:border-[#2F6B62]/60"
                    }`}
                  >
                    {useEmoji ? (
                      <span className="text-xl select-none">{emoji}</span>
                    ) : (
                      <span className="flex-shrink-0">
                        {id === "online" ? <SvgMonitor a={workFormat === id}/> : id === "in_person" ? <SvgBuilding a={workFormat === id}/> : <SvgShuffle a={workFormat === id}/>}
                      </span>
                    )}
                    <div className="flex-1">
                      <span className={`block font-sans text-sm font-bold ${workFormat === id ? "text-white" : "text-[#8FA5A0]"}`}>{pl}</span>
                      <span className="block font-sans text-xs text-[#8FA5A0]/60 mt-0.5">{desc}</span>
                    </div>
                  </button>
                ))}
              </div>

              <div className="flex gap-3">
                <button className="flex-1 py-3 rounded-xl font-sans text-xs font-bold text-[#8FA5A0] border border-[#1A3A3E] hover:border-[#2F6B62] transition-all cursor-pointer">
                  Pomiń
                </button>
                <button
                  onClick={() => goTo(7)}
                  disabled={!workFormat}
                  className="flex-[2] py-3 rounded-xl font-sans text-sm font-bold tracking-wide bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#0A2326] disabled:opacity-40 cursor-pointer disabled:cursor-not-allowed"
                >
                  DALEJ
                </button>
              </div>
            </StepCard>
          )}

          {/* ── Step 7: Subscription WWW Info ── */}
          {step === 7 && (
            <StepCard key="step7" direction={direction}>
              <button type="button" onClick={() => goTo(6)} className="absolute top-6 left-6 flex items-center gap-1.5 text-xs font-bold text-[#8FA5A0] hover:text-white transition-colors cursor-pointer">
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}><path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7"/></svg>
                <span>Wróć</span>
              </button>

              {useEmoji ? (
                <div className="text-4xl mb-4 text-center mt-3">🌐</div>
              ) : (
                <div className="w-12 h-12 mx-auto mb-4 mt-3 rounded-2xl bg-[#0F2E32] border border-[#2F6B62]/40 flex items-center justify-center">
                  <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="#8FA5A0" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
                </div>
              )}
              <h2 className="font-serif text-xl sm:text-2xl font-bold text-[#F2F0EA] text-center mb-2 leading-tight">
                Plan kupisz na stronie albo w aplikacji
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] text-center leading-relaxed mb-8">
                Subskrypcję wykupisz i zmienisz zarówno na www.superwizor.ai, jak i w aplikacji mobilnej.
              </p>

              <div className="flex flex-col gap-3 mb-6">
                {[
                  { emoji: "🔄", label: "Zmiana planu i subskrypcji", svg: <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16"/><path d="M16 16h5v5"/></svg> },
                  { emoji: "🧾", label: "Faktury i historia płatności", svg: <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z"/><path d="M8 7h8M8 11h8M8 15h4"/></svg> },
                  { emoji: "👤", label: "Dane profilu i organizacji", svg: <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg> },
                ].map(({ emoji, label, svg }, i) => (
                  <div key={i} className="flex items-center gap-4 p-4 rounded-xl bg-[#0F2E32]/50 border border-[#1A3A3E]">
                    <span className="w-9 h-9 flex items-center justify-center bg-[#F5A623]/10 rounded-lg border border-[#F5A623]/20 flex-shrink-0">
                      {useEmoji ? <span className="text-lg">{emoji}</span> : svg}
                    </span>
                    <span className="font-sans text-sm font-semibold text-[#F2F0EA]">{label}</span>
                  </div>
                ))}
              </div>

              {/* App reminder */}
              <div className="rounded-xl border border-[#F5A623]/20 bg-[#F5A623]/5 p-4 mb-6">
                <div className="flex items-start gap-3">
                  {useEmoji ? <span className="text-lg flex-shrink-0">📱</span> : (
                    <svg className="w-5 h-5 flex-shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/></svg>
                  )}
                  <p className="font-sans text-xs text-[#8FA5A0] leading-relaxed">
                    Do nagrywania sesji i przeglądania raportów użyj aplikacji mobilnej na iOS lub Android.
                  </p>
                </div>
              </div>

              <button className="w-full py-3.5 rounded-xl font-sans text-sm font-bold tracking-wide bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#0A2326] transition-all hover:shadow-lg cursor-pointer">
                GOTOWE — PRZEJDŹ DO APLIKACJI
              </button>
            </StepCard>
          )}

        </AnimatePresence>
      </div>

      {/* Step nav */}
      <div className="mt-8 flex gap-2">
        {([4,5,6,7] as Step[]).map((n) => (
          <button key={n} onClick={() => goTo(n)} className={`px-3 py-2 rounded-lg font-sans text-xs font-bold transition-all cursor-pointer ${step === n ? "bg-[#F5A623] text-[#0A2326]" : "bg-[#1A3A3E] text-[#8FA5A0] hover:bg-[#2F6B62]"}`}>
            {n === 4 ? "Nurt" : n === 5 ? "Sesje" : n === 6 ? "Format" : "WWW"}
          </button>
        ))}
      </div>
    </div>
  );
}
