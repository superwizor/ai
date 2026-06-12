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

const STORAGE_KEY = "sw_onboarding_step";
type OnboardingStep = 1 | 2 | 3 | 4 | 5 | 6;

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
        if (n >= 1 && n <= 6) return n as OnboardingStep;
      }
    }
    return 4;
  });

  const [direction, setDirection] = useState(1);

  // Persist step
  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, String(step));
  }, [step]);

  // Step 1: auto-advance if verified
  useEffect(() => {
    if (step === 1 && fbUser?.emailVerified) {
      setDirection(1);
      setStep(2);
    }
  }, [step, fbUser?.emailVerified]);

  // Step 6: redirect
  useEffect(() => {
    if (step === 6) {
      localStorage.removeItem(STORAGE_KEY);
      const timer = setTimeout(() => {
        router.push(`${prefix}/dashboard`);
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [step, router, prefix]);

  const goNext = useCallback(() => {
    setDirection(1);
    setStep((s) => Math.min(s + 1, 6) as OnboardingStep);
  }, []);

  // Form state
  const [profileData, setProfileData] = useState({
    firstName: "",
    lastName: "",
    professionalTitle: "",
  });
  const [phone, setPhone] = useState("");
  const [practiceData, setPracticeData] = useState({
    practiceName: "",
    practiceSize: "solo",
    modality: "UNIV",
  });
  const [preferences, setPreferences] = useState<string[]>([]);
  const [otherText, setOtherText] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const t = useCallback((pl: string, en: string) => (locale === "en" ? en : pl), [locale]);

  // ─── Backend Saves ─────────────────────────────────────────

  const saveProfile = useCallback(async () => {
    setSaving(true);
    setError(null);
    try {
      await identityClient.updateProfile(
        create(UpdateProfileRequestSchema, {
          firstName: profileData.firstName,
          lastName: profileData.lastName,
          professionalTitle: profileData.professionalTitle || "",
          phoneNumber: phone || "",
        }),
      );
      setDirection(1);
      setStep(3);
    } catch (e) {
      console.error("[onboarding] saveProfile failed", e);
      setError(t("Nie udało się zapisać profilu. Spróbuj ponownie.", "Failed to save profile. Please try again."));
    } finally {
      setSaving(false);
    }
  }, [profileData, phone, t]);

  const savePhone = useCallback(async () => {
    setSaving(true);
    setError(null);
    try {
      await identityClient.updateProfile(
        create(UpdateProfileRequestSchema, { phoneNumber: phone }),
      );
      setDirection(1);
      setStep(4);
    } catch (e) {
      console.error("[onboarding] savePhone failed", e);
      setError(t("Nie udało się zapisać numeru.", "Failed to save phone number."));
    } finally {
      setSaving(false);
    }
  }, [phone, t]);

  const handleDone = useCallback(async (skipped: boolean) => {
    setSaving(true);
    setError(null);
    try {
      // 1. If not skipped, save Modality (Step 4) to user profile
      if (!skipped && practiceData.modality) {
        await identityClient.updateProfile(
          create(UpdateProfileRequestSchema, {
            defaultModalityId: practiceData.modality,
          }),
        );
      }

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
          transcription: t("Transkrypcja sesji", "Session transcription"),
          reports: t("Raporty kliniczne", "Clinical reports"),
          progress: t("Śledzenie postępu", "Progress tracking"),
          action_plan: t("Plan działania", "Action plans"),
          documentation: t("Porządek w dokumentacji", "Organized docs"),
          rag: t("Analiza wielu sesji", "Multi-session analysis"),
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
          className="flex items-center gap-3 mb-10"
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
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
        </motion.div>
      )}

      {/* Step Cards */}
      <div className="w-full max-w-md relative">
        <AnimatePresence mode="wait" custom={direction}>
          {/* ── Step 1: Email Verification ── */}
          {step === 1 && (
            <StepCard key="step1" direction={direction}>
              <motion.div
                className="text-6xl mb-6 text-center"
                animate={{ scale: [1, 1.1, 1] }}
                transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
              >
                ✉️
              </motion.div>
              <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] text-center mb-3">
                {t("Potwierdź swój adres", "Confirm your email")}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] text-center leading-relaxed mb-2">
                {t(
                  "Wysłaliśmy link weryfikacyjny. Kliknij w niego, a potem wróć tutaj.",
                  "We sent a verification link. Click it, then come back here.",
                )}
              </p>
              {fbUser?.email && (
                <p className="text-center mb-6">
                  <span className="font-mono text-xs text-[#F5A623] bg-[#F5A623]/5 px-3 py-1 rounded-full">
                    {fbUser.email}
                  </span>
                </p>
              )}
              <PrimaryButton
                onClick={async () => {
                  await fbUser?.reload();
                  if (fbUser?.emailVerified) {
                    setDirection(1);
                    setStep(2);
                  }
                }}
                label={t("Sprawdź weryfikację", "Check verification")}
              />
              <SkipButton onClick={() => { setDirection(1); setStep(2); }} label={t("Pomiń na razie", "Skip for now")} />
            </StepCard>
          )}

          {/* ── Step 2: Profile ── */}
          {step === 2 && (
            <StepCard key="step2" direction={direction}>
              <div className="text-5xl mb-4 text-center">👋</div>
              <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] text-center mb-2">
                {t("Miło Cię poznać", "Nice to meet you")}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] text-center leading-relaxed mb-8">
                {t(
                  "Podstawowe dane, które pomogą nam dopasować raporty do Twojej pracy.",
                  "Basic details to help us tailor reports to your practice.",
                )}
              </p>
              <motion.div className="space-y-5" variants={stagger} initial="initial" animate="animate">
                <motion.div variants={childFade}>
                  <InputField label={t("Imię", "First name")} value={profileData.firstName} onChange={(v) => setProfileData((d) => ({ ...d, firstName: v }))} placeholder={t("np. Anna", "e.g. Anna")} required autoFocus />
                </motion.div>
                <motion.div variants={childFade}>
                  <InputField label={t("Nazwisko", "Last name")} value={profileData.lastName} onChange={(v) => setProfileData((d) => ({ ...d, lastName: v }))} placeholder={t("np. Kowalska", "e.g. Smith")} required />
                </motion.div>
                <motion.div variants={childFade}>
                  <InputField label={t("Tytuł zawodowy", "Professional title")} value={profileData.professionalTitle} onChange={(v) => setProfileData((d) => ({ ...d, professionalTitle: v }))} placeholder={t("np. psycholog kliniczny, psychoterapeuta CBT", "e.g. clinical psychologist, CBT therapist")} />
                </motion.div>
              </motion.div>
              {error && <ErrorMsg text={error} />}
              <PrimaryButton
                onClick={saveProfile}
                disabled={!profileData.firstName || !profileData.lastName || saving}
                label={saving ? t("Zapisuję...", "Saving...") : t("Dalej", "Continue")}
              />
            </StepCard>
          )}

          {/* ── Step 3: Phone ── */}
          {step === 3 && (
            <StepCard key="step3" direction={direction}>
              <div className="text-5xl mb-4 text-center">📱</div>
              <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] text-center mb-2">
                {t("Jak się z Tobą skontaktować?", "How can we reach you?")}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] text-center leading-relaxed mb-8">
                {t(
                  "Twój numer jest bezpieczny. Używamy go wyłącznie do weryfikacji konta.",
                  "Your number is safe. We only use it for account verification.",
                )}
              </p>
              <motion.div variants={fadeUp} initial="initial" animate="animate">
                <InputField label={t("Numer telefonu", "Phone number")} value={phone} onChange={setPhone} placeholder="+48 600 000 000" required type="tel" autoFocus />
                <p className="font-sans text-[11px] text-[#8FA5A0]/50 mt-2 leading-relaxed">
                  {t(
                    "Nie wysyłamy SMS-ów marketingowych automatycznie. Marcin może zadzwonić — ale tylko po to, żeby pomóc.",
                    "We don't send automated marketing SMS. Marcin may call — but only to help.",
                  )}
                </p>
              </motion.div>
              {error && <ErrorMsg text={error} />}
              <PrimaryButton
                onClick={savePhone}
                disabled={!phone || phone.length < 9 || saving}
                label={saving ? t("Zapisuję...", "Saving...") : t("Dalej", "Continue")}
              />
            </StepCard>
          )}

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
                      >
                        <span className="text-2xl">{emoji}</span>
                        <span className={`font-sans text-xs font-bold ${practiceData.practiceSize === value ? "text-white" : "text-[#8FA5A0]"}`}>
                          {label}
                        </span>
                      </motion.button>
                    ))}
                  </div>
                </motion.div>

                {/* Modality — horizontal pills */}
                <motion.div variants={childFade}>
                  <label className="block font-sans text-xs font-bold text-[#8FA5A0] uppercase tracking-wider mb-3">
                    {t("Nurt terapii", "Therapy modality")}
                  </label>
                  <div className="flex flex-wrap gap-2">
                    {[
                      { value: "UNIV", label: t("Integracyjny", "Integrative") },
                      { value: "CBT", label: "CBT" },
                      { value: "PSYCHO", label: t("Psychodynamiczny", "Psychodynamic") },
                      { value: "GESTALT", label: "Gestalt" },
                      { value: "ST", label: t("Schematów", "Schema") },
                      { value: "SYS", label: t("Systemowa", "Systemic") },
                      { value: "EFT", label: "EFT" },
                      { value: "COACH", label: "Coaching" },
                    ].map(({ value, label }) => (
                      <motion.button
                        key={value}
                        onClick={() => setPracticeData((d) => ({ ...d, modality: value }))}
                        className={`px-3.5 py-2 rounded-full font-sans text-xs font-medium transition-all border ${
                          practiceData.modality === value
                            ? "bg-[#F5A623]/10 text-[#F5A623] border-[#F5A623]/30"
                            : "bg-[#0F2E32] text-[#8FA5A0] border-[#1A3A3E] hover:border-[#2F6B62]"
                        }`}
                        whileHover={{ scale: 1.05 }}
                        whileTap={{ scale: 0.95 }}
                      >
                        {label}
                      </motion.button>
                    ))}
                  </div>
                </motion.div>
              </motion.div>

              <div className="flex gap-3 mt-8">
                <SkipInline onClick={goNext} label={t("Pomiń", "Skip")} disabled={saving} />
                <PrimaryButtonInline onClick={goNext} label={t("Dalej", "Continue")} disabled={saving} />
              </div>
            </StepCard>
          )}

          {/* ── Step 5: Preferences ── */}
          {step === 5 && (
            <StepCard key="step5" direction={direction}>
              <div className="text-5xl mb-4 text-center">🎯</div>
              <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] text-center mb-2">
                {t("Na co najbardziej czekasz?", "What do you look forward to?")}
              </h2>
              <p className="font-sans text-sm text-[#8FA5A0] text-center leading-relaxed mb-8">
                {t("Wybierz co chcesz — można kilka.", "Pick what you like — multiple is fine.")}
              </p>

              <motion.div className="grid grid-cols-2 gap-3" variants={stagger} initial="initial" animate="animate">
                {[
                  { id: "transcription", emoji: "🎙️", label: t("Transkrypcja sesji", "Session transcription") },
                  { id: "reports", emoji: "📊", label: t("Raporty kliniczne", "Clinical reports") },
                  { id: "progress", emoji: "📈", label: t("Śledzenie postępu", "Progress tracking") },
                  { id: "action_plan", emoji: "📋", label: t("Plan działania", "Action plans") },
                  { id: "documentation", emoji: "🗂️", label: t("Porządek w dokumentacji", "Organized docs") },
                  { id: "rag", emoji: "🔮", label: t("Analiza wielu sesji", "Multi-session analysis") },
                  { id: "other", emoji: "✍️", label: t("INNE", "OTHER") },
                ].map(({ id, emoji, label }) => (
                  <motion.button
                    key={id}
                    onClick={() =>
                      setPreferences((prev) =>
                        prev.includes(id) ? prev.filter((p) => p !== id) : [...prev, id],
                      )
                    }
                    className={`flex flex-col items-center gap-2 py-4 px-3 rounded-2xl border transition-all ${
                      preferences.includes(id)
                        ? "bg-[#004D54] border-[#2F6B62] shadow-[0_0_20px_rgba(79,192,151,0.1)]"
                        : "bg-[#0F2E32] border-[#1A3A3E] hover:border-[#2F6B62]"
                    }`}
                    variants={childFade}
                    whileHover={{ scale: 1.03 }}
                    whileTap={{ scale: 0.95 }}
                  >
                    <span className="text-2xl">{emoji}</span>
                    <span className={`font-sans text-xs font-medium text-center leading-tight ${preferences.includes(id) ? "text-white" : "text-[#8FA5A0]"}`}>
                      {label}
                    </span>
                    {preferences.includes(id) && (
                      <motion.span
                        initial={{ scale: 0 }}
                        animate={{ scale: 1 }}
                        className="text-[#F5A623] text-xs"
                      >
                        ✓
                      </motion.span>
                    )}
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
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ type: "spring", stiffness: 200, damping: 20 }}
              className="text-center py-12"
            >
              {/* Sparkle animation */}
              <div className="relative inline-block mb-6">
                <motion.div
                  className="text-7xl"
                  animate={{ rotate: [0, 5, -5, 0] }}
                  transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
                >
                  🎉
                </motion.div>
                {[...Array(8)].map((_, i) => (
                  <motion.div
                    key={i}
                    className="absolute w-2 h-2 rounded-full"
                    style={{
                      background: i % 2 === 0 ? "#F5A623" : "#4FC097",
                      top: "50%",
                      left: "50%",
                    }}
                    animate={{
                      x: [0, Math.cos((i * Math.PI) / 4) * 60],
                      y: [0, Math.sin((i * Math.PI) / 4) * 60],
                      opacity: [1, 0],
                      scale: [1, 0.3],
                    }}
                    transition={{
                      duration: 1.5,
                      repeat: Infinity,
                      delay: i * 0.15,
                      ease: "easeOut",
                    }}
                  />
                ))}
              </div>

              <motion.h2
                className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] mb-3"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3 }}
              >
                {profileData.firstName
                  ? t(`Witaj, ${profileData.firstName}!`, `Welcome, ${profileData.firstName}!`)
                  : t("Wszystko gotowe!", "You're all set!")}
              </motion.h2>
              <motion.p
                className="font-sans text-base text-[#8FA5A0] mb-8"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.5 }}
              >
                {t(
                  "Twoje konto jest gotowe. Za chwilę przeniesiesz się do panelu.",
                  "Your account is ready. You'll be redirected to your dashboard shortly.",
                )}
              </motion.p>
              <motion.div
                className="w-8 h-8 mx-auto border-2 border-[#F5A623] border-t-transparent rounded-full"
                animate={{ rotate: 360 }}
                transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
              />
            </motion.div>
          )}
        </AnimatePresence>
      </div>
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
      className="rounded-3xl bg-gradient-to-b from-[#0F2E32] to-[#0A2326] border border-[#1A3A3E] p-6 sm:p-10 shadow-2xl shadow-black/20"
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
      className="flex-1 py-3 rounded-xl bg-[#8FA5A0]/10 text-[#8FA5A0] font-sans font-bold text-xs uppercase tracking-wider hover:bg-[#8FA5A0]/20 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
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
