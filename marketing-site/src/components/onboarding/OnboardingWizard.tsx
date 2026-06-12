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

import { useState, useEffect, useCallback } from "react";
import { useAuth } from "@/lib/firebase/auth-provider";
import { useRouter } from "next/navigation";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { identityClient } from "@/lib/connect/clients";
import { UpdateProfileRequestSchema } from "@superwizor/proto-ts/identity/v1/identity_pb";
import { motion, AnimatePresence } from "framer-motion";
import { getModalityCatalog, type ModalityRow } from "@/lib/clinical/modalities";

const STORAGE_KEY = "sw_onboarding_step";
const TESTFLIGHT_URL = "https://testflight.apple.com/join/WkjaAX9r";
type OnboardingStep = 4 | 5 | 6;

const LABELS_FALLBACK: Record<string, Record<"pl" | "en", string>> = {
  UNIV: { pl: "Integracyjny", en: "Integrative" },
  CBT: { pl: "CBT", en: "CBT" },
  PSYCHO: { pl: "Psychodynamiczny", en: "Psychodynamic" },
  GESTALT: { pl: "Gestalt", en: "Gestalt" },
  ST: { pl: "Schematów", en: "Schema" },
  SYS: { pl: "Systemowa", en: "Systemic" },
  EFT: { pl: "EFT", en: "EFT" },
  COACH: { pl: "Coaching", en: "Coaching" },
};

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
        if (n === 4 || n === 5 || n === 6) return n as OnboardingStep;
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

  // Persist step
  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, String(step));
  }, [step]);

  // Step 6: clear local storage only, no auto redirect
  useEffect(() => {
    if (step === 6) {
      localStorage.removeItem(STORAGE_KEY);
    }
  }, [step]);

  const goNext = useCallback(() => {
    setDirection(1);
    setStep((s) => Math.min(s + 1, 6) as OnboardingStep);
  }, []);

  // Form state
  const [practiceData, setPracticeData] = useState({
    practiceName: "",
    practiceSize: "solo",
    modality: "",
  });
  const [preferences, setPreferences] = useState<string[]>([]);
  const [otherText, setOtherText] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const t = useCallback((pl: string, en: string) => (locale === "en" ? en : pl), [locale]);

  const handleDone = useCallback(async (skipped: boolean) => {
    setSaving(true);
    setError(null);
    try {
      // 1. Save Modality (Step 4) to user profile. If skipped, use default Integrative UNIV
      const activeMod = !skipped && practiceData.modality
        ? modalities.find((m) => m.systemCode === practiceData.modality)
        : null;
      const modalityId = activeMod ? activeMod.id : "33e66b8d-8a71-4770-96f3-42e13297a7e7"; // fallback to UNIV UUID
      await identityClient.updateProfile(
        create(UpdateProfileRequestSchema, {
          defaultModalityId: modalityId,
        }),
      );

      // 2. Fetch profile to get database UUID
      const me = await identityClient.getMyProfile(create(EmptySchema, {}));
      const userId = me.id;

      // 3. Prepare CRM Note text
      if (!skipped) {
        const modalityLabel = {
          UNIV: t("Integracyjny", "Integrative"),
          CBT: "CBT",
          PSYCHO: t("Psychodynamiczny", "Psychodynamic"),
          GESTALT: "Gestalt",
          ST: t("Schematów", "Schema"),
          SYS: t("Systemowa", "Systemic"),
          EFT: "EFT",
          COACH: "Coaching",
        }[practiceData.modality] || practiceData.modality;

        const sizeLabel = {
          solo: "Solo",
          small: t("2-5 osób", "2-5 people"),
          clinic: t("6+ osób", "6+ people"),
        }[practiceData.practiceSize] || practiceData.practiceSize;

        const prefLabels: Record<string, string> = {
          transcription: t("Dokładna transkrypcja i notatki z sesji", "Accurate session transcriptions & notes"),
          reports: t("Automatyczne podsumowania i raporty kliniczne", "Automated summaries & clinical reports"),
          patterns: t("Analiza historii i wątków z wielu sesji klienta", "Analyzing patterns across multiple client sessions"),
          modality: t("Raporty dopasowane do mojego nurtu", "Reports tailored to my therapy modality"),
          gdpr: t("Pełne bezpieczeństwo danych i zgodność z RODO", "Full GDPR compliance & secure data storage"),
          review: t("Błyskawiczne przygotowanie przed sesją (wgląd w 3 minuty)", "Quick review before sessions (3-minute prep)"),
          other: t("INNE", "OTHER"),
        };

        const selectedPrefs = preferences
          .map(p => prefLabels[p] || p)
          .join(", ");

        const crmNoteBody = [
          `[Automatyczny Onboarding - Kwestionariusz]`,
          `• Nurt terapii: ${modalityLabel}`,
          `• Wielkość praktyki: ${sizeLabel}`,
          `• Oczekiwania: ${selectedPrefs || t("Brak wybranych", "None selected")}`,
          preferences.includes("other") && otherText.trim()
            ? `• Inne szczegóły: ${otherText.trim()}`
            : null
        ]
          .filter(Boolean)
          .join("\n");

        // Post CRM note
        await fetch("/api/admin/crm/notes", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            target_user_id: userId,
            body: crmNoteBody,
          }),
        });
      } else {
        // If skipped, we can log that onboarding was skipped
        await fetch("/api/admin/crm/notes", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            target_user_id: userId,
            body: `[Automatyczny Onboarding] Pominięty przez użytkownika.`,
          }),
        });
      }

      // Go to step 6 (Done)
      setDirection(1);
      setStep(6);
    } catch (e) {
      console.error("[onboarding] Save onboarding failed", e);
      // If it fails, let's still let them proceed to step 6 so we don't block them from using the app
      setDirection(1);
      setStep(6);
    } finally {
      setSaving(false);
    }
  }, [practiceData, preferences, otherText, t]);
  const visualStep = Math.min(step, 5);

  // ─── Render ────────────────────────────────────────────────

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-5 py-12">
      {/* Progress Dots */}
      {step < 6 && (
        <motion.div
          className="flex flex-col items-center gap-2.5 mb-10 text-center"
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          {step >= 4 ? (
            <div className="flex flex-col items-center gap-2">
              <span className="px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider bg-ember/15 text-ember border border-ember/25 animate-pulse">
                {locale === "pl" ? "Ostatnie 2 kroki" : "Last 2 steps"}
              </span>
              <div className="flex items-center gap-3 mt-1">
                {[4, 5].map((n) => (
                  <motion.div
                    key={n}
                    className={`rounded-full transition-all duration-300 ${
                      n === step
                        ? "w-8 h-3 bg-gradient-to-r from-[#F5A623] to-[#E09500]"
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
      <div className="w-full max-w-md relative">
        <AnimatePresence mode="wait" custom={direction}>
          {/* ── Step 4: Practice ── */}
          {step === 4 && (
            <StepCard key="step4" direction={direction}>
              <div className="text-5xl mb-4 text-center">🏥</div>
              <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] text-center mb-2">
                {t("Opowiedz o swojej praktyce", "Tell us about your practice")}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] text-center leading-relaxed mb-8">
                {t("Możesz to zmienić później.", "You can change this later.")}
              </p>

              {/* Practice size — visual cards */}
              <motion.div variants={stagger} initial="initial" animate="animate">
                <motion.div variants={childFade}>
                  <label className="block font-sans text-xs font-bold text-[#8FA5A0] uppercase tracking-wider mb-3">
                    {t("Wielkość praktyki", "Practice size")}
                  </label>
                  <div className="grid grid-cols-3 gap-3 mb-6">
                    {[
                      { value: "solo", emoji: "🧘", label: "Solo" },
                      { value: "small", emoji: "👥", label: t("2-5 osób", "2-5 people") },
                      { value: "clinic", emoji: "🏥", label: t("6+ osób", "6+ people") },
                    ].map(({ value, emoji, label }) => (
                      <motion.button
                        key={value}
                        onClick={() => setPracticeData((d) => ({ ...d, practiceSize: value }))}
                        className={`flex flex-col items-center gap-2 py-4 px-3 rounded-2xl border transition-all ${
                          practiceData.practiceSize === value
                            ? "bg-[#004D54] border-[#2F6B62] shadow-[0_0_20px_rgba(79,192,151,0.1)]"
                            : "bg-[#0F2E32] border-[#1A3A3E] hover:border-[#2F6B62]"
                        }`}
                        whileHover={{ scale: 1.03 }}
                        whileTap={{ scale: 0.97 }}
                        type="button"
                      >
                        <span className="text-2xl">{emoji}</span>
                        <span className={`font-sans text-xs font-bold ${practiceData.practiceSize === value ? "text-white" : "text-[#8FA5A0]"}`}>
                          {label}
                        </span>
                      </motion.button>
                    ))}
                  </div>
                </motion.div>

                {/* Modality — Dropdown Select */}
                <motion.div variants={childFade}>
                  <label className="block font-sans text-xs font-bold text-[#8FA5A0] uppercase tracking-wider mb-1">
                    {t("Nurt terapii", "Therapy modality")}
                  </label>
                  <p className="font-sans text-[11px] text-[#8FA5A0]/80 mb-3 leading-normal normal-case font-normal">
                    {t("w której zwykle prowadzisz sesje z klientami", "in which you usually conduct sessions with clients")}
                  </p>
                  <div className="relative group">
                    <select
                      value={practiceData.modality}
                      onChange={(e) => setPracticeData((d) => ({ ...d, modality: e.target.value }))}
                      className="w-full rounded-xl bg-[#0A2326] border border-[#1A3A3E] pl-4 pr-10 py-3.5 font-sans text-sm text-[#F2F0EA] focus:outline-none focus:border-[#F5A623] focus:ring-1 focus:ring-[#F5A623]/30 hover:border-[#2F6B62] transition-all cursor-pointer appearance-none"
                    >
                      <option value="" disabled>
                        {t("— Wybierz nurt terapii —", "— Choose therapy modality —")}
                      </option>
                      {(modalities.length > 0
                        ? modalities.map((m) => ({ value: m.systemCode, label: m.labels[locale as "pl" | "en"] || m.displayName }))
                        : [
                            { value: "UNIV", label: LABELS_FALLBACK.UNIV[locale as "pl" | "en"] },
                            { value: "CBT", label: LABELS_FALLBACK.CBT[locale as "pl" | "en"] },
                            { value: "PSYCHO", label: LABELS_FALLBACK.PSYCHO[locale as "pl" | "en"] },
                            { value: "GESTALT", label: LABELS_FALLBACK.GESTALT[locale as "pl" | "en"] },
                            { value: "ST", label: LABELS_FALLBACK.ST[locale as "pl" | "en"] },
                            { value: "SYS", label: LABELS_FALLBACK.SYS[locale as "pl" | "en"] },
                            { value: "EFT", label: LABELS_FALLBACK.EFT[locale as "pl" | "en"] },
                            { value: "COACH", label: LABELS_FALLBACK.COACH[locale as "pl" | "en"] },
                          ]
                      ).map(({ value, label }) => (
                        <option key={value} value={value}>
                          {label}
                        </option>
                      ))}
                    </select>
                    <div className="absolute inset-y-0 right-0 flex items-center pr-4 pointer-events-none text-[#8FA5A0]/60 group-focus-within:text-[#F5A623] group-hover:text-[#8FA5A0] transition-colors">
                      <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
                      </svg>
                    </div>
                  </div>
                </motion.div>
              </motion.div>

              <PrimaryButton
                onClick={goNext}
                label={t("Dalej", "Continue")}
                disabled={saving || !practiceData.modality}
              />
            </StepCard>
          )}

          {/* ── Step 5: Preferences ── */}
          {step === 5 && (
            <StepCard key="step5" direction={direction}>
              {/* Back Arrow link */}
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

              <div className="text-5xl mb-4 text-center mt-3">🎯</div>
              <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] text-center mb-2">
                {t("Na co najbardziej czekasz?", "What do you look forward to?")}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] text-center leading-relaxed mb-8">
                {t("Wybierz co chcesz — można kilka.", "Pick what you like — multiple is fine.")}
              </p>

              <motion.div
                className="flex flex-col gap-2.5 max-h-[340px] overflow-y-auto pr-1.5 scrollbar-thin scrollbar-thumb-white/10"
                variants={stagger}
                initial="initial"
                animate="animate"
              >
                {[
                  { id: "transcription", emoji: "🎙️", label: t("Dokładna transkrypcja i notatki z sesji", "Accurate session transcriptions & notes") },
                  { id: "reports", emoji: "📊", label: t("Automatyczne podsumowania i raporty kliniczne", "Automated summaries & clinical reports") },
                  { id: "patterns", emoji: "🔮", label: t("Analiza historii i wątków z wielu sesji klienta", "Analyzing patterns across multiple client sessions") },
                  { id: "modality", emoji: "📋", label: t("Raporty dopasowane do mojego nurtu", "Reports tailored to my therapy modality") },
                  { id: "gdpr", emoji: "🛡️", label: t("Pełne bezpieczeństwo danych i zgodność z RODO", "Full GDPR compliance & secure data storage") },
                  { id: "review", emoji: "⚡", label: t("Błyskawiczne przygotowanie przed sesją (wgląd w 3 minuty)", "Quick review before sessions (3-minute prep)") },
                  { id: "other", emoji: "✍️", label: t("INNE", "OTHER") },
                ].map(({ id, emoji, label }) => (
                  <motion.button
                    key={id}
                    onClick={() =>
                      setPreferences((prev) =>
                        prev.includes(id) ? prev.filter((p) => p !== id) : [...prev, id],
                      )
                    }
                    className={`flex items-center justify-between w-full p-4 rounded-xl border text-left transition-all cursor-pointer ${
                      preferences.includes(id)
                        ? "bg-[#004D54]/75 border-[#2F6B62] shadow-[0_2px_12px_rgba(79,192,151,0.08)]"
                        : "bg-[#0F2E32]/50 border-[#1A3A3E] hover:border-[#2F6B62]"
                    }`}
                    variants={childFade}
                    whileHover={{ scale: 1.01, x: 2 }}
                    whileTap={{ scale: 0.99 }}
                  >
                    <div className="flex items-center gap-3.5">
                      <span className="text-xl w-8 h-8 flex items-center justify-center bg-white/5 rounded-lg border border-white/5 select-none">{emoji}</span>
                      <span className={`font-sans text-xs font-semibold leading-snug pr-4 ${preferences.includes(id) ? "text-[#FAFAFA]" : "text-[#8FA5A0]"}`}>
                        {label}
                      </span>
                    </div>

                    {/* Checkbox circle on right */}
                    <div className={`w-5 h-5 rounded-full flex items-center justify-center border-2 transition-all flex-shrink-0 ${
                      preferences.includes(id)
                        ? "border-[#F5A623] bg-[#F5A623]"
                        : "border-[#8FA5A0]/30 bg-transparent"
                    }`}>
                      {preferences.includes(id) && (
                        <svg className="w-3.5 h-3.5 text-[#1B2522]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3.5}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                      )}
                    </div>
                  </motion.button>
                ))}
              </motion.div>

              <AnimatePresence>
                {preferences.includes("other") && (
                  <motion.div
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: "auto" }}
                    exit={{ opacity: 0, height: 0 }}
                    className="mt-5 space-y-2 text-left overflow-hidden"
                  >
                    <label className="block font-sans text-xs font-bold text-[#8FA5A0] uppercase tracking-wider">
                      {t("Napisz nam, na co najbardziej czekasz — to dla nas ważne:", "Tell us what you look forward to most — it's important to us:")}
                    </label>
                    <textarea
                      value={otherText}
                      onChange={(e) => setOtherText(e.target.value)}
                      placeholder={t("Wpisz swoje oczekiwania...", "Write your expectations here...")}
                      rows={3}
                      className="w-full py-3 px-4 rounded-xl bg-[#0A2326] text-[#F2F0EA] border border-[#1A3A3E] font-sans text-sm placeholder:text-[#4E5A55] focus:border-[#F5A623] focus:shadow-[0_0_0_3px_rgba(245,166,35,0.1)] focus:outline-none transition-all resize-none"
                    />
                  </motion.div>
                )}
              </AnimatePresence>

              <div className="flex gap-3 mt-8">
                <SkipInline onClick={() => handleDone(true)} label={t("Pomiń", "Skip")} disabled={saving} />
                <PrimaryButtonInline onClick={() => handleDone(false)} label={saving ? t("Zapisuję...", "Saving...") : t("Gotowe", "Done")} disabled={saving} />
              </div>
            </StepCard>
          )}

          {/* ── Step 6: Done ── */}
          {step === 6 && (
            <motion.div
              key="step6"
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
              <div className="bg-[#0F2E32] border border-[#1A3A3E] p-6 rounded-2xl flex flex-col items-center gap-6 justify-center my-6">
                <div className="flex flex-col sm:flex-row items-center gap-6 justify-center w-full">
                  {/* QR Code (hidden on small screens, shown on desktop) */}
                  <div className="hidden sm:flex flex-col items-center gap-2">
                     <div className="p-3 bg-white rounded-2xl shadow-lg w-[140px] h-[140px] flex items-center justify-center">
                       <img
                         src={`https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=${encodeURIComponent(TESTFLIGHT_URL)}`}
                         alt="QR Code"
                         className="w-[120px] h-[120px]"
                       />
                     </div>
                     <span className="text-[10px] text-[#8FA5A0]/60 font-sans tracking-wide">
                       {t("Zeskanuj telefonem", "Scan with phone")}
                     </span>
                  </div>

                  {/* Vertical divider */}
                  <div className="hidden sm:block w-[1px] h-[120px] bg-[#1A3A3E]" />

                  {/* App Badges */}
                  <div className="flex flex-col gap-3 w-full sm:w-auto">
                     {/* iOS App Store */}
                     <button
                       onClick={() => handleOpenModal("ios")}
                       className="flex items-center gap-3 px-4 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-white transition-all text-xs font-semibold cursor-pointer w-full sm:w-[170px]"
                     >
                       <svg className="w-5 h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                         <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 4.17c.66-.81 1.11-1.93.99-3.06-.96.04-2.13.64-2.82 1.45-.6.69-1.12 1.84-.98 2.94.1.08.21.12.33.12.87 0 1.98-.54 2.48-1.45z"/>
                       </svg>
                       <div className="flex flex-col text-left">
                         <span className="text-[9px] text-white/50 font-normal uppercase tracking-wider leading-none mb-0.5">Download on the</span>
                         <span className="text-xs font-bold leading-none">App Store</span>
                       </div>
                     </button>

                     {/* Android Google Play */}
                     <button
                       onClick={() => handleOpenModal("android")}
                       className="flex items-center gap-3 px-4 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-white transition-all text-xs font-semibold cursor-pointer w-full sm:w-[170px]"
                     >
                       <svg className="w-5 h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                         <path d="M3 20.285V3.716c0-.525.308-.94.757-1.077L14.654 12 3.757 21.362A1.14 1.14 0 013 20.285zM15.908 13.084l2.842 2.463L5.342 2.874l10.566 10.21zM19.98 12.569c.563-.326.563-.858 0-1.184l-2.909-1.686L14.654 12l2.417 2.253 2.909-1.684zM5.342 21.126L18.75 14.56l-2.842-2.56-10.566 9.126z"/>
                       </svg>
                       <div className="flex flex-col text-left">
                         <span className="text-[9px] text-white/50 font-normal uppercase tracking-wider leading-none mb-0.5">Get it on</span>
                         <span className="text-xs font-bold leading-none">Google Play</span>
                       </div>
                     </button>
                  </div>
                </div>
              </div>

              <button
                onClick={() => {
                  localStorage.removeItem(STORAGE_KEY);
                  router.push(`${prefix}/dashboard`);
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
                      className="block text-[11px] text-[#8FA5A0] hover:text-[#FCAE2F] transition-colors underline mb-2"
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

                  <div className="relative p-3 bg-white/5 rounded-2xl w-[150px] h-[150px] flex items-center justify-center mx-auto mb-6 border border-white/10 overflow-hidden">
                    <div className="absolute inset-0 bg-gradient-to-br from-[#FCAE2F]/20 to-transparent opacity-35" />
                    <div className="relative w-[126px] h-[126px] bg-white/[0.03] rounded-xl flex flex-col items-center justify-center gap-2 border border-white/5 backdrop-blur-sm">
                      <span className="text-3xl animate-pulse">⏳</span>
                      <span className="text-[10px] font-mono text-[#FCAE2F] font-bold uppercase tracking-wider">
                        Coming Soon
                      </span>
                    </div>
                  </div>

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
