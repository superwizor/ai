// OnboardingWizard — Premium 5-step post-registration wizard with Framer Motion.
//
// Design: Full-bleed cards, each step is its own visual world.
// Animations: slide + fade transitions between steps via AnimatePresence.
// Progress: Beautiful dots (not a thin bar).
//
//   Step 1: Email verification — pulse animation on ✉️
//   Step 2: Profile — "Miło Cię poznać" — first/last name, title
//   Step 3: Phone — country-aware input with privacy reassurance
//   Step 4: Practice — visual card selection (not dropdowns)
//   Step 5: Preferences — icon tiles in 2×3 grid with bounce
//   Step 6: Done — confetti-style sparkle + personalized greeting

"use client";

import { useState, useEffect, useCallback, type ReactNode } from "react";
import { useAuth } from "@/lib/firebase/auth-provider";
import { useRouter } from "next/navigation";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { identityClient } from "@/lib/connect/clients";
import { UpdateProfileRequestSchema } from "@superwizor/proto-ts/identity/v1/identity_pb";
import { motion, AnimatePresence } from "framer-motion";
import { getModalityCatalog, type ModalityRow } from "@/lib/clinical/modalities";

const STORAGE_KEY = "sw_onboarding_step";
const APP_STORE_URL = "https://apps.apple.com/app/superwizor-ai/id6774975751";
const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=ai.superwizor.superwizor";
type OnboardingStep = 4 | 5 | 6 | 7 | 8;

const LABELS_FALLBACK: Record<string, Record<"pl" | "en", string>> = {
  UNIV: { pl: "Integracyjny", en: "Integrative" },
  CBT: { pl: "CBT", en: "CBT" },
  PSYCHO: { pl: "Psychodynamiczny", en: "Psychodynamic" },
  GESTALT: { pl: "Gestalt", en: "Gestalt" },
  PPT: { pl: "Pozytywna (PPT)", en: "Positive (PPT)" },
  ST: { pl: "Schematów", en: "Schema" },
  SYS: { pl: "Systemowa", en: "Systemic" },
  EFT: { pl: "EFT", en: "EFT" },
  COACH: { pl: "Coaching", en: "Coaching" },
};

// Emoji icons for each modality — matching Flutter app's Material Icons concept
const MODALITY_ICONS: Record<string, string> = {
  UNIV: "🔗",     // hub_outlined → interconnected/integrative
  CBT: "🧠",      // psychology_outlined → cognitive
  PSYCHO: "🧘",   // self_improvement_outlined → introspection
  GESTALT: "🎯",  // center_focus_strong → figure/ground
  PPT: "☀️",      // wb_sunny_outlined → positive
  ST: "🧩",       // view_module_outlined → schemas/patterns
  SYS: "👨‍👩‍👧‍👦",  // family_restroom_outlined → family/systemic
  EFT: "❤️",      // favorite_outline → emotions-focused
  COACH: "📈",    // trending_up_outlined → growth/coaching
};

// Premium SVG icons for modalities — flat, calm, psychotherapy-appropriate
const svgClass = "w-6 h-6";
const MODALITY_SVG_ICONS: Record<string, (active: boolean) => ReactNode> = {
  UNIV: (a) => <svg className={svgClass} viewBox="0 0 24 24" fill="none" stroke={a ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 3v6M12 15v6M3 12h6M15 12h6M5.6 5.6l4.3 4.3M14.1 14.1l4.3 4.3M5.6 18.4l4.3-4.3M14.1 9.9l4.3-4.3"/></svg>,
  CBT: (a) => <svg className={svgClass} viewBox="0 0 24 24" fill="none" stroke={a ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M12 2a7 7 0 0 1 7 7c0 3-1.5 5-3 6.5V18a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2v-2.5C6.5 14 5 12 5 9a7 7 0 0 1 7-7z"/><path d="M9 22h6"/><path d="M10 14.5c.6-.4 1.3-.5 2-.5s1.4.1 2 .5"/></svg>,
  PSYCHO: (a) => <svg className={svgClass} viewBox="0 0 24 24" fill="none" stroke={a ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10"/><path d="M12 2c2.8 0 5 4.5 5 10s-2.2 10-5 10"/><path d="M2 12h10"/><path d="M12 7c-2 2-2 5 0 7"/></svg>,
  GESTALT: (a) => <svg className={svgClass} viewBox="0 0 24 24" fill="none" stroke={a ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5"/></svg>,
  PPT: (a) => <svg className={svgClass} viewBox="0 0 24 24" fill="none" stroke={a ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/></svg>,
  ST: (a) => <svg className={svgClass} viewBox="0 0 24 24" fill="none" stroke={a ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>,
  SYS: (a) => <svg className={svgClass} viewBox="0 0 24 24" fill="none" stroke={a ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="7" r="3"/><circle cx="5" cy="17" r="2.5"/><circle cx="19" cy="17" r="2.5"/><path d="M12 10v2M9 14l-2.5 1.5M15 14l2.5 1.5"/></svg>,
  EFT: (a) => <svg className={svgClass} viewBox="0 0 24 24" fill="none" stroke={a ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M12 21c-4-3.5-8-6.5-8-10.5C4 7 7 4.5 9.5 4.5c1.5 0 2.5.7 2.5.7s1-.7 2.5-.7C17 4.5 20 7 20 10.5c0 4-4 7-8 10.5z"/></svg>,
  COACH: (a) => <svg className={svgClass} viewBox="0 0 24 24" fill="none" stroke={a ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/></svg>,
};

// SVG icon components for Step 5 — sessions, work format, counter
const SvgSeedling = ({ active }: { active: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={active ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M12 22V10"/><path d="M5 10c0-4 3-7 7-7"/><path d="M19 10c0-4-3-7-7-7"/><path d="M5 10c0 3 2.5 5 7 5"/><path d="M19 10c0 3-2.5 5-7 5"/></svg>;
const SvgTree = ({ active }: { active: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={active ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M12 22V13"/><path d="M12 13L8 9l4-6 4 6-4 4z"/><path d="M7 13c-2 0-4 1-4 4h18c0-3-2-4-4-4"/></svg>;
const SvgForest = ({ active }: { active: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={active ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M12 22v-8"/><path d="M7 22v-5"/><path d="M17 22v-5"/><path d="M12 14l-4-5 4-6 4 6-4 5z"/><path d="M7 17l-3-4 3-4.5 3 4.5-3 4z"/><path d="M17 17l-3-4 3-4.5 3 4.5-3 4z"/></svg>;
const SvgChart = () => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="12" width="4" height="9" rx="1"/><rect x="10" y="7" width="4" height="14" rx="1"/><rect x="17" y="3" width="4" height="18" rx="1"/></svg>;
const SvgMonitor = ({ active }: { active: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={active ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>;
const SvgBuilding = ({ active }: { active: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={active ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M3 21h18M5 21V7l7-4 7 4v14"/><path d="M9 10h2v2H9zM13 10h2v2h-2zM9 15h2v2H9zM13 15h2v2h-2z"/></svg>;
const SvgShuffle = ({ active }: { active: boolean }) => <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke={active ? "#F2F0EA" : "#8FA5A0"} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><polyline points="16 3 21 3 21 8"/><line x1="4" y1="20" x2="21" y2="3"/><polyline points="21 16 21 21 16 21"/><line x1="15" y1="15" x2="21" y2="21"/><line x1="4" y1="4" x2="9" y2="9"/></svg>;

// ─── Animations ──────────────────────────────────────────────

const cardVariants = {
  enter: (direction: number) => ({
    x: direction > 0 ? 300 : -300,
    opacity: 0,
    scale: 0.95,
  }),
  center: {
    x: 0,
    opacity: 1,
    scale: 1,
  },
  exit: (direction: number) => ({
    x: direction < 0 ? 300 : -300,
    opacity: 0,
    scale: 0.95,
  }),
};

const fadeUp = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0, transition: { delay: 0.2, duration: 0.5 } },
};

const stagger = {
  animate: { transition: { staggerChildren: 0.08 } },
};

const childFade = {
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0, transition: { duration: 0.4 } },
};

// ─── Component ───────────────────────────────────────────────

export function OnboardingWizard({ locale }: { locale: string }) {
  const { user: fbUser } = useAuth();
  const router = useRouter();
  const prefix = locale === "en" ? "/en" : "";

  const [step, setStep] = useState<OnboardingStep>(() => {
    if (typeof window !== "undefined") {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        const n = parseInt(saved, 10);
        if (n === 4 || n === 5 || n === 6 || n === 7 || n === 8) return n as OnboardingStep;
      }
    }
    return 4;
  });

  const [direction, setDirection] = useState(1);
  const [modalities, setModalities] = useState<ReadonlyArray<ModalityRow>>([]);
  const [modalPlatform, setModalPlatform] = useState<"ios" | "android" | null>(null);
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
    let cancelled = false;
    getModalityCatalog()
      .then((rows) => {
        if (!cancelled) setModalities(rows);
      })
      .catch((err) => {
        console.error("[onboarding] modality fetch failed", err);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  // Entry guard (docs/38): a therapist whose nurt is already set —
  // e.g. chosen on the accept-invite (password) screen — must never be
  // asked again. Whatever path led here (stale redirect, bookmark),
  // bounce straight to the dashboard. Errors fall through: the wizard
  // is a safe place for a user whose profile we can't read.
  useEffect(() => {
    let cancelled = false;
    identityClient
      .getMyProfile(create(EmptySchema, {}))
      .then((me) => {
        if (!cancelled) {
          if (me.defaultModalityId) {
            router.replace(locale === "en" ? "/en/dashboard/" : "/pl/dashboard/");
          } else if (step > 6) {
            // Safety guard: if localStorage says we are on step 7/8, but backend says
            // profile is incomplete (new account reusing same browser), force step 4.
            setStep(4);
            setDirection(-1);
          }
        }
      })
      .catch(() => {
        // Signed-out / no profile yet — the wizard handles both.
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Persist step
  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, String(step));
  }, [step]);

  // Step 8: clear local storage only, no auto redirect
  useEffect(() => {
    if (step === 8) {
      localStorage.removeItem(STORAGE_KEY);
    }
  }, [step]);

  // Cross-tab sync: listen for onboarding completion from other tabs
  useEffect(() => {
    try {
      const ch = new BroadcastChannel("sw_onboarding");
      ch.onmessage = (e) => {
        if (e.data?.type === "onboarding_complete") {
          localStorage.removeItem(STORAGE_KEY);
          router.replace(locale === "en" ? "/en/dashboard/" : "/pl/dashboard/");
        }
      };
      return () => ch.close();
    } catch {
      return undefined;
    }
  }, [router, locale]);

  const goNext = useCallback(() => {
    setDirection(1);
    setStep((s) => Math.min(s + 1, 8) as OnboardingStep);
  }, []);

  // Form state
  const [selectedModality, setSelectedModality] = useState("");
  const [weeklySessions, setWeeklySessions] = useState<"up_to_7" | "up_to_20" | "more_than_20" | "">("");
  const [workFormat, setWorkFormat] = useState<"online" | "in_person" | "hybrid" | "">("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const t = useCallback((pl: string, en: string) => (locale === "en" ? en : pl), [locale]);

  const handleDone = useCallback(async (skipped: boolean) => {
    setSaving(true);
    setError(null);

    // ── 1. CRITICAL PATH: Save modality to profile ──────────────────
    // This is the gate that Dashboard checks (me.defaultModalityId).
    // If this fails, user MUST stay on this step and retry.
    const activeMod = !skipped && selectedModality
      ? modalities.find((m) => m.systemCode === selectedModality)
      : null;
    const modalityId = activeMod ? activeMod.id : "33e66b8d-8a71-4770-96f3-42e13297a7e7"; // fallback UNIV

    try {
      await identityClient.updateProfile(
        create(UpdateProfileRequestSchema, {
          defaultModalityId: modalityId,
        }),
      );
    } catch (e) {
      console.error("[onboarding] updateProfile failed — cannot proceed", e);
      setError(
        locale === "en"
          ? "Failed to save your preferences. Please try again."
          : "Nie udało się zapisać preferencji. Spróbuj ponownie."
      );
      setSaving(false);
      return; // ← hard stop, stay on Step 6
    }

    // ── 2. PROCEED: modality is persisted, user can safely navigate ──
    setDirection(1);
    setStep(7);
    setSaving(false);

    // Notify other tabs that onboarding profile is now complete
    try { new BroadcastChannel("sw_onboarding").postMessage({ type: "onboarding_complete" }); } catch {}

    // ── 3. BEST-EFFORT: CRM telemetry note (fire-and-forget) ────────
    // A failure here does NOT block the user. We log it and move on.
    try {
      const me = await identityClient.getMyProfile(create(EmptySchema, {}));
      const userId = me.id;

      const crmNoteBody = skipped
        ? `[Automatyczny Onboarding] Pominięty przez użytkownika.`
        : [
            `[Automatyczny Onboarding - Kwestionariusz]`,
            `• Nurt terapii: ${LABELS_FALLBACK[selectedModality]?.[locale as "pl" | "en"] || selectedModality}`,
            `• Szacowana liczba sesji: ${weeklySessions
              ? {
                  up_to_7: t("Do 7 sesji w tygodniu (ok. 30/miesiąc — Plan Podstawowy)", "Up to 7 sessions/week (~30/month — Basic Plan)"),
                  up_to_20: t("Do 20 sesji w tygodniu (ok. 90/miesiąc — Plan Profesjonalny)", "Up to 20 sessions/week (~90/month — Professional Plan)"),
                  more_than_20: t("Powyżej 20 sesji w tygodniu (Limit elastyczny — Pakiety dla Klinik)", "More than 20 sessions/week (Flexible limit — Clinic Packages)"),
                }[weeklySessions]
              : t("Nie wybrano", "Not selected")}`,
            `• Format pracy: ${workFormat
              ? {
                  online: t("Online (zdalnie)", "Online (remote)"),
                  in_person: t("Stacjonarnie w gabinecie", "In-person at the office"),
                  hybrid: t("Hybrydowo (oba formaty)", "Hybrid (both formats)"),
                }[workFormat]
              : t("Nie wybrano", "Not selected")}`,
          ].join("\n");

      fetch("/api/admin/crm/notes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ target_user_id: userId, body: crmNoteBody }),
      }).catch((err) => console.warn("[onboarding] CRM note failed (non-blocking)", err));
    } catch (err) {
      console.warn("[onboarding] CRM note skipped — profile fetch failed (non-blocking)", err);
    }
  }, [selectedModality, weeklySessions, workFormat, modalities, locale, t]);

  // Animated monthly sessions counter
  const monthlyTarget = weeklySessions === "up_to_7" ? 30 : weeklySessions === "up_to_20" ? 87 : 0;
  const [monthlyCount, setMonthlyCount] = useState(0);
  useEffect(() => {
    if (!monthlyTarget) { setMonthlyCount(0); return; }
    setMonthlyCount(0);
    const duration = 800; // ms
    const steps = 30;
    const increment = monthlyTarget / steps;
    let current = 0;
    const timer = setInterval(() => {
      current += increment;
      if (current >= monthlyTarget) {
        setMonthlyCount(monthlyTarget);
        clearInterval(timer);
      } else {
        setMonthlyCount(Math.round(current));
      }
    }, duration / steps);
    return () => clearInterval(timer);
  }, [monthlyTarget]);
  const visualStep = Math.min(step, 6);

  // ─── Render ────────────────────────────────────────────────

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-5 py-12" style={{ fontSize: '110%' }}>
      {/* Progress Dots */}
      {step < 8 && (
        <motion.div
          className="flex flex-col items-center gap-2.5 mb-10 text-center"
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          {step >= 4 ? (
            <div className="flex flex-col items-center gap-2">
              <span className="px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider bg-ember/15 text-ember border border-ember/25 animate-pulse">
                {locale === "pl" ? "Ostatnie kroki" : "Final steps"}
              </span>
              <div className="flex items-center gap-3 mt-1">
                {[4, 5, 6, 7].map((n) => (
                  <motion.div
                    key={n}
                    className={`rounded-full transition-all duration-300 ${
                      n === step
                        ? "w-8 h-3 bg-gradient-to-r from-[#F5A623] to-[#E09500]"
                        : n < step
                          ? "w-3 h-3 bg-[#F5A623]/40"
                          : "w-3 h-3 bg-[#1A3A3E]"
                    }`}
                    layout
                    transition={{ type: "spring", stiffness: 300, damping: 25 }}
                  />
                ))}
              </div>
            </div>
          ) : (
            <div className="flex items-center gap-3">
              {[1, 2, 3, 4, 5].map((n) => (
                <motion.div
                  key={n}
                  className={`rounded-full transition-all duration-300 ${
                    n === visualStep
                      ? "w-8 h-3 bg-gradient-to-r from-[#F5A623] to-[#E09500]"
                      : n < visualStep
                        ? "w-3 h-3 bg-[#F5A623]/40"
                        : "w-3 h-3 bg-[#1A3A3E]"
                  }`}
                  layout
                  transition={{ type: "spring", stiffness: 300, damping: 25 }}
                />
              ))}
            </div>
          )}
        </motion.div>
      )}

      {/* Step Cards */}
      <div className="w-full max-w-lg relative">
        <AnimatePresence mode="wait" custom={direction}>
          {/* ── Step 4: Therapy Modality — visual icon cards ── */}
          {step === 4 && (
            <StepCard key="step4" direction={direction}>
              <div className="w-12 h-12 mx-auto mb-4 rounded-2xl bg-[#0F2E32] border border-[#2F6B62]/40 flex items-center justify-center">
                <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="#8FA5A0" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/><path d="M8 7h8M8 11h5"/></svg>
              </div>
              <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] text-center mb-3">
                {t("Wybierz swój nurt", "Choose your modality")}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0]/80 text-center leading-relaxed mb-8">
                {t(
                  "W jakim nurcie najczęściej prowadzisz sesje? Możesz to zmienić później.",
                  "Which modality do you use most often? You can change this later."
                )}
              </p>

              <div className="grid grid-cols-3 gap-2.5 mb-6">
                {(modalities.length > 0
                  ? modalities.map((m) => ({ code: m.systemCode, label: m.labels[locale as "pl" | "en"] || m.displayName }))
                  : [
                      { code: "UNIV", label: LABELS_FALLBACK.UNIV[locale as "pl" | "en"] },
                      { code: "CBT", label: LABELS_FALLBACK.CBT[locale as "pl" | "en"] },
                      { code: "PSYCHO", label: LABELS_FALLBACK.PSYCHO[locale as "pl" | "en"] },
                      { code: "GESTALT", label: LABELS_FALLBACK.GESTALT[locale as "pl" | "en"] },
                      { code: "PPT", label: LABELS_FALLBACK.PPT[locale as "pl" | "en"] },
                      { code: "ST", label: LABELS_FALLBACK.ST[locale as "pl" | "en"] },
                      { code: "SYS", label: LABELS_FALLBACK.SYS[locale as "pl" | "en"] },
                      { code: "EFT", label: LABELS_FALLBACK.EFT[locale as "pl" | "en"] },
                      { code: "COACH", label: LABELS_FALLBACK.COACH[locale as "pl" | "en"] },
                    ]
                ).map(({ code, label }) => (
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
                    <div className="w-8 h-8 rounded-xl bg-[#0A2326] border border-[#1A3A3E] flex items-center justify-center flex-shrink-0">
                      {MODALITY_SVG_ICONS[code]?.(selectedModality === code) || MODALITY_SVG_ICONS.UNIV(selectedModality === code)}
                    </div>
                    <span className={`font-sans text-[10px] font-bold leading-tight ${
                      selectedModality === code ? "text-white" : "text-[#8FA5A0]"
                    }`}>
                      {label}
                    </span>
                  </motion.button>
                ))}
              </div>

              <PrimaryButton
                onClick={goNext}
                label={t("Dalej", "Continue")}
                disabled={saving || !selectedModality}
              />
            </StepCard>
          )}

          {/* ── Step 5: Weekly Sessions (separate step) ── */}
          {step === 5 && (
            <StepCard key="step5" direction={direction}>
              {/* Back Arrow */}
              <button
                type="button"
                onClick={() => {
                  setDirection(-1);
                  setStep(4);
                }}
                className="absolute top-6 left-6 flex items-center gap-1.5 text-xs font-bold text-[#8FA5A0] hover:text-white transition-colors cursor-pointer"
              >
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                </svg>
                <span>{t("Wróć", "Back")}</span>
              </button>

              <h2 className="font-serif text-xl sm:text-2xl font-bold text-[#F2F0EA] text-center mb-3 mt-8">
                {t("Ile sesji prowadzisz w tygodniu?", "How many sessions per week?")}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0]/80 text-center leading-relaxed mb-8">
                {t(
                  "Pomoże nam dopasować odpowiedni plan.",
                  "Helps us match the right plan for you."
                )}
              </p>

              <div className="grid grid-cols-1 gap-2.5 mb-5">
                {[
                  { id: "up_to_7", pl: "Do 7 sesji / tydz.", en: "Up to 7 sessions / week" },
                  { id: "up_to_20", pl: "Do 20 sesji / tydz.", en: "Up to 20 sessions / week" },
                  { id: "more_than_20", pl: "Powyżej 20 sesji / tydz.", en: "Over 20 sessions / week" },
                ].map(({ id, pl, en }) => (
                  <button
                    key={id}
                    type="button"
                    onClick={() => setWeeklySessions(id as any)}
                    className={`flex items-center gap-3.5 p-4 rounded-xl border text-left transition-all ${
                      weeklySessions === id
                        ? "bg-[#004D54]/75 border-[#2F6B62] shadow-[0_2px_10px_rgba(79,192,151,0.06)]"
                        : "bg-[#0F2E32]/40 border-[#1A3A3E] hover:border-[#2F6B62]/60"
                    }`}
                  >
                    <span className="flex-shrink-0">{id === "up_to_7" ? <SvgSeedling active={weeklySessions === id} /> : id === "up_to_20" ? <SvgTree active={weeklySessions === id} /> : <SvgForest active={weeklySessions === id} />}</span>
                    <div className="flex-1">
                      <span className={`block font-sans text-sm font-bold ${weeklySessions === id ? "text-white" : "text-[#8FA5A0]"}`}>
                        {t(pl, en)}
                      </span>
                    </div>
                  </button>
                ))}
              </div>

              {/* Animated monthly counter */}
              {weeklySessions && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  transition={{ duration: 0.3, ease: "easeOut" }}
                  className="mb-5 rounded-xl border border-[#2F6B62]/30 bg-[#0A2326]/60 p-4 flex items-center gap-3"
                >
                  <span className="flex-shrink-0"><SvgChart /></span>
                  <div className="flex-1">
                    <span className="font-sans text-[10px] text-[#8FA5A0] uppercase tracking-wider">
                      {t("Miesięcznie to około", "Monthly that's about")}
                    </span>
                    <div className="flex items-baseline gap-1.5 mt-0.5">
                      <span className="font-serif text-2xl font-bold text-[#F5A623] tabular-nums">
                        {weeklySessions === "more_than_20" ? "80+" : `~${monthlyCount}`}
                      </span>
                      <span className="font-sans text-xs text-[#8FA5A0]">
                        {t("sesji / miesiąc", "sessions / month")}
                      </span>
                    </div>
                    <span className="font-sans text-[10px] text-[#8FA5A0]/60 mt-0.5 block">
                      {weeklySessions === "up_to_7"
                        ? t("Plan Podstawowy", "Basic Plan")
                        : weeklySessions === "up_to_20"
                          ? t("Plan Profesjonalny", "Professional Plan")
                          : t("Skontaktuj się, dopasujemy plan", "Contact us, we'll match a plan")}
                    </span>
                  </div>
                </motion.div>
              )}

              <PrimaryButton
                onClick={goNext}
                label={t("Dalej", "Continue")}
                disabled={saving || !weeklySessions}
              />
            </StepCard>
          )}

          {/* ── Step 6: Work Format (separate step) ── */}
          {step === 6 && (
            <StepCard key="step6" direction={direction}>
              {/* Back Arrow */}
              <button
                type="button"
                onClick={() => {
                  setDirection(-1);
                  setStep(5);
                }}
                className="absolute top-6 left-6 flex items-center gap-1.5 text-xs font-bold text-[#8FA5A0] hover:text-white transition-colors cursor-pointer"
              >
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                </svg>
                <span>{t("Wróć", "Back")}</span>
              </button>

              <h2 className="font-serif text-xl sm:text-2xl font-bold text-[#F2F0EA] text-center mb-3 mt-8">
                {t("Jak pracujesz?", "How do you work?")}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0]/80 text-center leading-relaxed mb-8">
                {t(
                  "Wybierz format, który najczęściej stosujesz.",
                  "Choose the format you use most often."
                )}
              </p>

              <div className="grid grid-cols-1 gap-2.5 mb-6">
                {[
                  { id: "online", pl: "Online", en: "Online", descPl: "sesje zdalne (wideo / telefon)", descEn: "remote sessions (video / phone)" },
                  { id: "in_person", pl: "W gabinecie", en: "In-person", descPl: "sesje stacjonarne", descEn: "face-to-face sessions" },
                  { id: "hybrid", pl: "Hybrydowo", en: "Hybrid", descPl: "mieszany format, oba rodzaje", descEn: "mix of both formats" },
                ].map(({ id, pl, en, descPl, descEn }) => (
                  <button
                    key={id}
                    type="button"
                    onClick={() => setWorkFormat(id as any)}
                    className={`flex items-center gap-3.5 p-4 rounded-xl border text-left transition-all ${
                      workFormat === id
                        ? "bg-[#004D54]/75 border-[#2F6B62] shadow-[0_2px_10px_rgba(79,192,151,0.06)]"
                        : "bg-[#0F2E32]/40 border-[#1A3A3E] hover:border-[#2F6B62]/60"
                    }`}
                  >
                    <span className="flex-shrink-0">{id === "online" ? <SvgMonitor active={workFormat === id} /> : id === "in_person" ? <SvgBuilding active={workFormat === id} /> : <SvgShuffle active={workFormat === id} />}</span>
                    <div className="flex-1">
                      <span className={`block font-sans text-sm font-bold ${workFormat === id ? "text-white" : "text-[#8FA5A0]"}`}>
                        {t(pl, en)}
                      </span>
                      <span className={`block font-sans text-xs mt-0.5 ${workFormat === id ? "text-[#8FA5A0]" : "text-[#8FA5A0]/50"}`}>
                        {t(descPl, descEn)}
                      </span>
                    </div>
                  </button>
                ))}
              </div>

              {error && (
                <div className="mb-3 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-300 text-xs font-sans text-center">
                  {error}
                </div>
              )}

              <div className="flex gap-3">
                <SkipInline onClick={() => handleDone(true)} label={t("Pomiń", "Skip")} disabled={saving} />
                <PrimaryButtonInline
                  onClick={() => handleDone(false)}
                  label={saving ? t("Zapisuję...", "Saving...") : t("Dalej", "Continue")}
                  disabled={saving || !workFormat}
                />
              </div>
            </StepCard>
          )}

          {/* ── Step 7: Account Management Info ── */}
          {step === 7 && (
            <StepCard key="step7" direction={direction}>
              {/* Back Arrow */}
              <button
                type="button"
                onClick={() => {
                  setDirection(-1);
                  setStep(6);
                }}
                className="absolute top-6 left-6 flex items-center gap-1.5 text-xs font-bold text-[#8FA5A0] hover:text-white transition-colors cursor-pointer"
              >
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                </svg>
                <span>{t("Wróć", "Back")}</span>
              </button>

              <div className="w-12 h-12 mx-auto mb-4 mt-6 rounded-2xl bg-[#0F2E32] border border-[#2F6B62]/40 flex items-center justify-center">
                <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="#8FA5A0" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
              </div>
              <h2 className="font-serif text-xl sm:text-2xl font-bold text-[#F2F0EA] text-center mb-3 leading-tight">
                {t(
                  "Pamiętaj: Subskrypcje kupujesz tylko na stronie WWW!",
                  "Remember: Subscriptions are managed only on the website!"
                )}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0]/80 text-center leading-relaxed mb-8">
                {t(
                  "Zarządzaj swoim kontem logując się na www.superwizor.ai",
                  "Manage your account by logging in at www.superwizor.ai"
                )}
              </p>

              <motion.div className="flex flex-col gap-3 mb-6" variants={stagger} initial="initial" animate="animate">
                {[
                  { key: "plan", label: t("Zmiana planu i subskrypcji", "Change plan & subscription"), svg: <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16"/><path d="M16 16h5v5"/></svg> },
                  { key: "invoice", label: t("Faktury i historia płatności", "Invoices & payment history"), svg: <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z"/><path d="M8 7h8M8 11h8M8 15h4"/></svg> },
                  { key: "profile", label: t("Dane profilu i organizacji", "Profile & organization data"), svg: <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg> },
                ].map(({ key, label, svg }) => (
                  <motion.div
                    key={key}
                    variants={childFade}
                    className="flex items-center gap-4 p-4 rounded-xl bg-[#0F2E32]/50 border border-[#1A3A3E]"
                  >
                    <span className="w-9 h-9 flex items-center justify-center bg-[#F5A623]/10 rounded-lg border border-[#F5A623]/20 flex-shrink-0">{svg}</span>
                    <span className="font-sans text-sm font-semibold text-[#F2F0EA]">{label}</span>
                  </motion.div>
                ))}
              </motion.div>

              {/* Mobile app reminder callout */}
              <div className="rounded-xl border border-[#F5A623]/20 bg-[#F5A623]/5 p-4 mb-4">
                <div className="flex items-start gap-3">
                  <svg className="w-5 h-5 flex-shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="#F5A623" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/></svg>
                  <p className="font-sans text-xs text-[#8FA5A0] leading-relaxed">
                    {t(
                      "Aplikacja mobilna służy tylko do nagrywania sesji i przeglądania raportów.",
                      "The mobile app is only for recording sessions and reviewing reports."
                    )}
                  </p>
                </div>
              </div>

              <PrimaryButton
                onClick={goNext}
                label={t("Rozumiem, dalej", "Got it, continue")}
              />
            </StepCard>
          )}

          {/* ── Step 8: Done ── */}
          {step === 8 && (
            <motion.div
              key="step7"
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ type: "spring", stiffness: 200, damping: 20 }}
              className="text-center py-6"
            >
              {/* Confetti 🎉 */}
              <div className="relative inline-block mb-4">
                <motion.div
                  className="text-6xl"
                  animate={{ rotate: [0, 5, -5, 0] }}
                  transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
                >
                  🎉
                </motion.div>
              </div>

              <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] mb-2">
                {t("Wszystko gotowe!", "You're all set!")}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] leading-relaxed mb-6 max-w-sm mx-auto">
                {t(
                  "Teraz pobierz aplikację mobilną na swój telefon, aby nagrywać sesje.",
                  "Now, download the mobile app on your phone to record sessions."
                )}
              </p>

              {/* Download & QR Section inside a premium card */}
              <div className="bg-[#0F2E32] border border-[#1A3A3E] p-6 rounded-2xl my-6">
                <div className="flex flex-col sm:flex-row items-stretch gap-6 justify-center w-full">
                  {/* iOS Group */}
                  <div className="flex-1 flex flex-col items-center gap-4">
                     {/* iOS App Store */}
                     <a
                       href={APP_STORE_URL}
                       target="_blank"
                       rel="noopener noreferrer"
                       className="flex items-center gap-3 px-4 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-white transition-all text-xs font-semibold cursor-pointer w-full sm:w-[170px] justify-center"
                     >
                       <svg className="w-5 h-5 text-white flex-shrink-0" viewBox="0 0 24 24" fill="currentColor">
                         <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 4.17c.66-.81 1.11-1.93.99-3.06-.96.04-2.13.64-2.82 1.45-.6.69-1.12 1.84-.98 2.94.1.08.21.12.33.12.87 0 1.98-.54 2.48-1.45z"/>
                       </svg>
                       <div className="flex flex-col text-left">
                         <span className="text-[9px] text-white/50 font-normal uppercase tracking-wider leading-none mb-0.5">Download on the</span>
                         <span className="text-xs font-bold leading-none">App Store</span>
                       </div>
                     </a>

                     {/* iOS QR Code (hidden on small screens, shown on desktop) */}
                     <div className="hidden sm:flex flex-col items-center gap-2">
                        <div className="p-3 bg-white rounded-2xl shadow-lg w-[140px] h-[140px] flex items-center justify-center">
                          <img
                            src={`https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=${encodeURIComponent(APP_STORE_URL)}`}
                            alt="App Store QR Code"
                            className="w-[120px] h-[120px]"
                          />
                        </div>
                        <span className="text-[10px] text-[#8FA5A0]/60 font-sans tracking-wide">
                          {t("Zeskanuj dla iOS", "Scan for iOS")}
                        </span>
                     </div>
                  </div>

                  {/* Vertical divider */}
                  <div className="hidden sm:block w-[1px] bg-[#1A3A3E] self-stretch my-2" />

                  {/* Android Group */}
                  <div className="flex-1 flex flex-col items-center gap-4">
                     {/* Android Google Play */}
                     <a
                       href={PLAY_STORE_URL}
                       target="_blank"
                       rel="noopener noreferrer"
                       className="flex items-center gap-3 px-4 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-white transition-all text-xs font-semibold cursor-pointer w-full sm:w-[170px] justify-center"
                     >
                       <svg className="w-5 h-5 text-white flex-shrink-0" viewBox="0 0 24 24" fill="currentColor">
                         <path d="M3 20.285V3.716c0-.525.308-.94.757-1.077L14.654 12 3.757 21.362A1.14 1.14 0 013 20.285zM15.908 13.084l2.842 2.463L5.342 2.874l10.566 10.21zM19.98 12.569c.563-.326.563-.858 0-1.184l-2.909-1.686L14.654 12l2.417 2.253 2.909-1.684zM5.342 21.126L18.75 14.56l-2.842-2.56-10.566 9.126z"/>
                       </svg>
                       <div className="flex flex-col text-left">
                         <span className="text-[9px] text-white/50 font-normal uppercase tracking-wider leading-none mb-0.5">Get it on</span>
                         <span className="text-xs font-bold leading-none">Google Play</span>
                       </div>
                     </a>

                     {/* Android QR Code (hidden on small screens, shown on desktop) */}
                     <div className="hidden sm:flex flex-col items-center gap-2">
                        <div className="p-3 bg-white rounded-2xl shadow-lg w-[140px] h-[140px] flex items-center justify-center">
                          <img
                            src={`https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=${encodeURIComponent(PLAY_STORE_URL)}`}
                            alt="Google Play QR Code"
                            className="w-[120px] h-[120px]"
                          />
                        </div>
                        <span className="text-[10px] text-[#8FA5A0]/60 font-sans tracking-wide">
                          {t("Zeskanuj dla Androida", "Scan for Android")}
                        </span>
                     </div>
                  </div>
                </div>
              </div>

              <button
                onClick={() => {
                  localStorage.removeItem(STORAGE_KEY);
                  router.replace(`${prefix}/dashboard`);
                }}
                className="w-full flex items-center justify-center py-4 px-6 rounded-2xl bg-ember text-obsidian font-sans font-bold text-xs uppercase tracking-wider shadow-lg shadow-black/25 hover:brightness-110 active:scale-[0.99] transition-all cursor-pointer mt-4"
              >
                {t("Zainstalowałem. Przejdź do panelu ➔", "I installed it. Go to dashboard ➔")}
              </button>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* TestFlight Installation Guide Modal Overlay */}
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
                  <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mx-auto mb-4 border border-white/10">
                    <svg className="w-6 h-6 text-white" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M3 20.285V3.716c0-.525.308-.94.757-1.077L14.654 12 3.757 21.362A1.14 1.14 0 013 20.285zM15.908 13.084l2.842 2.463L5.342 2.874l10.566 10.21zM19.98 12.569c.563-.326.563-.858 0-1.184l-2.909-1.686L14.654 12l2.417 2.253 2.909-1.684zM5.342 21.126L18.75 14.56l-2.842-2.56-10.566 9.126z"/>
                    </svg>
                  </div>

                  <h3 className="font-serif text-xl font-bold text-[#F2F0EA] mb-2">
                    {t("Aplikacja Android", "Android App")}
                  </h3>

                  <p className="font-sans text-xs text-[#8FA5A0] leading-relaxed mb-4">
                    {t(
                      "Pobierz oficjalną aplikację Superwizor AI bezpośrednio z Google Play, aby bezpiecznie nagrywać sesje terapeutyczne na swoim telefonie z systemem Android.",
                      "Download the official Superwizor AI app directly from Google Play to securely record therapy sessions on your Android phone."
                    )}
                  </p>

                  {/* QR Code */}
                  <div className="p-3 bg-white rounded-2xl w-[150px] h-[150px] flex items-center justify-center mx-auto mb-1.5 shadow-lg border border-white/10">
                    <img
                      src={`https://api.qrserver.com/v1/create-qr-code/?size=126x126&data=${encodeURIComponent(PLAY_STORE_URL)}`}
                      alt="QR Code Android"
                      className="w-[126px] h-[126px]"
                    />
                  </div>
                  <p className="text-[10px] text-[#8FA5A0] font-mono mb-6">
                    {t("Zeskanuj telefonem, aby pobrać", "Scan with phone to download")}
                  </p>

                  <div className="flex flex-col gap-2.5">
                    {/* CTA button */}
                    <a
                      href={PLAY_STORE_URL}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center justify-center gap-3 px-5 py-3.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/15 text-white transition-all text-xs font-semibold cursor-pointer w-full hover:border-[#FCAE2F]/40 hover:shadow-[0_2px_12px_rgba(252,174,47,0.15)] text-center"
                    >
                      <svg className="w-5 h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M3 20.285V3.716c0-.525.308-.94.757-1.077L14.654 12 3.757 21.362A1.14 1.14 0 013 20.285zM15.908 13.084l2.842 2.463L5.342 2.874l10.566 10.21zM19.98 12.569c.563-.326.563-.858 0-1.184l-2.909-1.686L14.654 12l2.417 2.253 2.909-1.684zM5.342 21.126L18.75 14.56l-2.842-2.56-10.566 9.126z"/>
                      </svg>
                      <div className="flex flex-col text-left">
                        <span className="text-[8px] text-white/50 font-normal uppercase tracking-wider leading-none mb-0.5">
                          Get it on
                        </span>
                        <span className="text-xs font-bold leading-none">
                          Google Play
                        </span>
                      </div>
                    </a>
                  </div>
                </>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ─── Shared Components ───────────────────────────────────────

function StepCard({ children, direction }: { children: React.ReactNode; direction: number }) {
  return (
    <motion.div
      custom={direction}
      variants={cardVariants}
      initial="enter"
      animate="center"
      exit="exit"
      transition={{ type: "spring", stiffness: 300, damping: 30 }}
      className="relative rounded-3xl bg-gradient-to-b from-[#0F2E32] to-[#0A2326] border border-[#1A3A3E] p-6 sm:p-10 shadow-2xl shadow-black/20"
    >
      {children}
    </motion.div>
  );
}

function InputField({
  label, value, onChange, placeholder, required, type = "text", autoFocus,
}: {
  label: string; value: string; onChange: (v: string) => void; placeholder?: string; required?: boolean; type?: string; autoFocus?: boolean;
}) {
  return (
    <div>
      <label className="block font-sans text-xs font-bold text-[#8FA5A0] uppercase tracking-wider mb-2">
        {label}
        {required && <span className="text-[#F5A623] ml-0.5">*</span>}
      </label>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        autoFocus={autoFocus}
        className="w-full py-3 px-4 rounded-xl bg-[#0A2326] text-[#F2F0EA] border border-[#1A3A3E] font-sans text-sm placeholder:text-[#4E5A55] focus:border-[#F5A623] focus:shadow-[0_0_0_3px_rgba(245,166,35,0.1)] focus:outline-none transition-all"
      />
    </div>
  );
}

function PrimaryButton({ onClick, disabled, label }: { onClick: () => void; disabled?: boolean; label: string }) {
  return (
    <motion.button
      onClick={onClick}
      disabled={disabled}
      className="mt-8 w-full py-3.5 rounded-xl bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#1B2522] font-sans font-bold text-sm uppercase tracking-wider hover:shadow-[0_4px_20px_rgba(245,166,35,0.3)] transition-shadow disabled:opacity-40 disabled:cursor-not-allowed"
      whileHover={!disabled ? { scale: 1.01 } : undefined}
      whileTap={!disabled ? { scale: 0.98 } : undefined}
    >
      {label}
    </motion.button>
  );
}

function PrimaryButtonInline({ onClick, label, disabled }: { onClick: () => void; label: string; disabled?: boolean }) {
  return (
    <motion.button
      onClick={onClick}
      disabled={disabled}
      className="flex-[2] py-3.5 rounded-xl bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#1B2522] font-sans font-bold text-sm uppercase tracking-wider hover:shadow-[0_4px_20px_rgba(245,166,35,0.3)] transition-shadow disabled:opacity-40 disabled:cursor-not-allowed"
      whileHover={!disabled ? { scale: 1.01 } : undefined}
      whileTap={!disabled ? { scale: 0.98 } : undefined}
    >
      {label}
    </motion.button>
  );
}

function SkipButton({ onClick, label }: { onClick: () => void; label: string }) {
  return (
    <button
      onClick={onClick}
      className="mt-3 w-full py-2.5 text-[#8FA5A0] font-sans text-xs hover:text-white transition-colors"
    >
      {label}
    </button>
  );
}

function SkipInline({ onClick, label, disabled }: { onClick: () => void; label: string; disabled?: boolean }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="flex-1 py-3.5 rounded-xl bg-[#8FA5A0]/10 text-[#8FA5A0] font-sans font-bold text-xs uppercase tracking-wider hover:bg-[#8FA5A0]/20 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
    >
      {label}
    </button>
  );
}

function ErrorMsg({ text }: { text: string }) {
  return (
    <motion.p
      initial={{ opacity: 0, y: -5 }}
      animate={{ opacity: 1, y: 0 }}
      className="mt-3 font-sans text-xs text-red-400 text-center"
    >
      {text}
    </motion.p>
  );
}
