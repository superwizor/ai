// OnboardingWizard — 6-step post-registration wizard.
//
// Plan Phase 3:
//   Step 1: Email verification (Firebase link check)
//   Step 2: Profile details (first name, last name, professional title)
//   Step 3: Phone number (required for anti-abuse + Marcin's contact base)
//   Step 4: Practice setup (practice name, size, default modality)
//   Step 5: Preferences (optional checkboxes: what do you need most?)
//   Step 6: Done → redirect to /dashboard
//
// Resume: step stored in localStorage so closing browser doesn't lose progress.
// Skip: steps 4 and 5 are skippable.

"use client";

import { useState, useEffect, useCallback } from "react";
import { useAuth } from "@/lib/firebase/auth-provider";
import { useRouter } from "next/navigation";

const STORAGE_KEY = "sw_onboarding_step";

type OnboardingStep = 1 | 2 | 3 | 4 | 5 | 6;

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
    return 1;
  });

  // Persist step
  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, String(step));
  }, [step]);

  // Step 1: auto-advance if email already verified
  useEffect(() => {
    if (step === 1 && fbUser?.emailVerified) {
      setStep(2);
    }
  }, [step, fbUser?.emailVerified]);

  // Step 6: redirect to dashboard
  useEffect(() => {
    if (step === 6) {
      localStorage.removeItem(STORAGE_KEY);
      const timer = setTimeout(() => {
        router.push(`${prefix}/dashboard`);
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [step, router, prefix]);

  const next = useCallback(() => {
    setStep((s) => Math.min(s + 1, 6) as OnboardingStep);
  }, []);

  const totalSteps = 5; // visual steps (step 6 is just the redirect)
  const visualStep = Math.min(step, 5);

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

  const t = (pl: string, en: string) => (locale === "en" ? en : pl);

  return (
    <div className="mx-auto max-w-lg px-5 pt-28 pb-20 sm:pt-36">
      {/* --- Progress Bar --- */}
      {step < 6 && (
        <div className="mb-10">
          <div className="flex items-center justify-between mb-2">
            <span className="font-mono text-[10px] uppercase tracking-[0.2em] text-[#8FA5A0]">
              {t(`Krok ${visualStep} z ${totalSteps}`, `Step ${visualStep} of ${totalSteps}`)}
            </span>
            <span className="font-mono text-[10px] text-[#8FA5A0]">
              {Math.round((visualStep / totalSteps) * 100)}%
            </span>
          </div>
          <div className="h-1.5 bg-[#1A3A3E] rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-[#F5A623] to-[#E09500] rounded-full transition-all duration-500 ease-out"
              style={{ width: `${(visualStep / totalSteps) * 100}%` }}
            />
          </div>
        </div>
      )}

      {/* --- Step 1: Email Verification --- */}
      {step === 1 && (
        <StepCard
          title={t("Zweryfikuj swój email", "Verify your email")}
          subtitle={t(
            "Wysłaliśmy link weryfikacyjny na Twój adres email. Kliknij w link, aby kontynuować.",
            "We sent a verification link to your email. Click the link to continue."
          )}
          icon="✉️"
        >
          <p className="font-sans text-sm text-[#8FA5A0] mt-4">
            {fbUser?.email && (
              <span className="font-mono text-xs text-[#F5A623]">
                {fbUser.email}
              </span>
            )}
          </p>
          <button
            onClick={async () => {
              // Reload to check verification status
              await fbUser?.reload();
              if (fbUser?.emailVerified) {
                setStep(2);
              }
            }}
            className="mt-6 w-full py-3 rounded-xl bg-[#004D54] text-white font-sans font-bold text-sm uppercase tracking-wider hover:bg-[#003A40] transition-colors"
          >
            {t("Sprawdź weryfikację", "Check verification")}
          </button>
          <button
            onClick={() => setStep(2)}
            className="mt-2 w-full py-2 text-[#8FA5A0] font-sans text-xs hover:text-white transition-colors"
          >
            {t("Pomiń na razie", "Skip for now")}
          </button>
        </StepCard>
      )}

      {/* --- Step 2: Profile Details --- */}
      {step === 2 && (
        <StepCard
          title={t("Twój profil", "Your profile")}
          subtitle={t(
            "Podstawowe dane, które pomogą nam dopasować raporty.",
            "Basic details to help us tailor your reports."
          )}
          icon="👤"
        >
          <div className="space-y-4 mt-6">
            <InputField
              label={t("Imię", "First name")}
              value={profileData.firstName}
              onChange={(v) =>
                setProfileData((d) => ({ ...d, firstName: v }))
              }
              placeholder={t("np. Anna", "e.g. Anna")}
              required
            />
            <InputField
              label={t("Nazwisko", "Last name")}
              value={profileData.lastName}
              onChange={(v) =>
                setProfileData((d) => ({ ...d, lastName: v }))
              }
              placeholder={t("np. Kowalska", "e.g. Smith")}
              required
            />
            <InputField
              label={t("Tytuł zawodowy (opcjonalnie)", "Professional title (optional)")}
              value={profileData.professionalTitle}
              onChange={(v) =>
                setProfileData((d) => ({ ...d, professionalTitle: v }))
              }
              placeholder={t(
                "np. psycholog, psychoterapeuta",
                "e.g. psychologist, psychotherapist"
              )}
            />
          </div>
          <button
            onClick={next}
            disabled={!profileData.firstName || !profileData.lastName}
            className="mt-6 w-full py-3 rounded-xl bg-[#F5A623] text-[#1B2522] font-sans font-bold text-sm uppercase tracking-wider hover:bg-[#E09500] transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {t("Dalej", "Continue")}
          </button>
        </StepCard>
      )}

      {/* --- Step 3: Phone Number --- */}
      {step === 3 && (
        <StepCard
          title={t("Numer telefonu", "Phone number")}
          subtitle={t(
            "Ze względu na bezpieczeństwo danych klinicznych, wymagamy weryfikacji numeru telefonu.",
            "For the security of clinical data, we require phone verification."
          )}
          icon="📱"
        >
          <div className="space-y-4 mt-6">
            <InputField
              label={t("Numer telefonu", "Phone number")}
              value={phone}
              onChange={setPhone}
              placeholder="+48 600 000 000"
              required
              type="tel"
            />
            <p className="font-sans text-[11px] text-[#8FA5A0]/60 leading-relaxed">
              {t(
                "Twój numer jest bezpieczny. Nie wysyłamy SMS-ów marketingowych automatycznie.",
                "Your number is safe. We don't send automated marketing SMS."
              )}
            </p>
          </div>
          <button
            onClick={next}
            disabled={!phone || phone.length < 9}
            className="mt-6 w-full py-3 rounded-xl bg-[#F5A623] text-[#1B2522] font-sans font-bold text-sm uppercase tracking-wider hover:bg-[#E09500] transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {t("Dalej", "Continue")}
          </button>
        </StepCard>
      )}

      {/* --- Step 4: Practice Setup --- */}
      {step === 4 && (
        <StepCard
          title={t("Twoja praktyka", "Your practice")}
          subtitle={t(
            "Opowiedz nam o swojej pracy. Możesz to zmienić później.",
            "Tell us about your work. You can change this later."
          )}
          icon="🏥"
        >
          <div className="space-y-4 mt-6">
            <InputField
              label={t("Nazwa praktyki / gabinetu", "Practice name")}
              value={practiceData.practiceName}
              onChange={(v) =>
                setPracticeData((d) => ({ ...d, practiceName: v }))
              }
              placeholder={t("np. Gabinet Terapii XYZ", "e.g. XYZ Therapy Practice")}
            />

            <div>
              <label className="block font-sans text-xs font-bold text-[#8FA5A0] uppercase tracking-wider mb-2">
                {t("Wielkość praktyki", "Practice size")}
              </label>
              <div className="grid grid-cols-3 gap-2">
                {[
                  { value: "solo", label: t("Solo", "Solo") },
                  { value: "small", label: t("2-5 osób", "2-5 people") },
                  { value: "clinic", label: t("6+ osób", "6+ people") },
                ].map(({ value, label }) => (
                  <button
                    key={value}
                    onClick={() =>
                      setPracticeData((d) => ({ ...d, practiceSize: value }))
                    }
                    className={`py-2.5 px-3 rounded-xl font-sans text-xs font-bold transition-all border ${
                      practiceData.practiceSize === value
                        ? "bg-[#004D54] text-white border-[#2F6B62]"
                        : "bg-[#0F2E32] text-[#8FA5A0] border-[#1A3A3E] hover:border-[#2F6B62]"
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="block font-sans text-xs font-bold text-[#8FA5A0] uppercase tracking-wider mb-2">
                {t("Główny nurt terapii", "Primary therapy modality")}
              </label>
              <select
                value={practiceData.modality}
                onChange={(e) =>
                  setPracticeData((d) => ({ ...d, modality: e.target.value }))
                }
                className="w-full py-2.5 px-3 rounded-xl bg-[#0F2E32] text-[#F2F0EA] border border-[#1A3A3E] font-sans text-sm focus:border-[#F5A623] focus:outline-none"
              >
                <option value="UNIV">
                  {t("Uniwersalny / Integracyjny", "Universal / Integrative")}
                </option>
                <option value="CBT">
                  {t("Poznawczo-Behawioralny (CBT)", "Cognitive-Behavioral (CBT)")}
                </option>
                <option value="PSYCHO">
                  {t("Psychodynamiczny", "Psychodynamic")}
                </option>
                <option value="GESTALT">Gestalt</option>
                <option value="PPT">{t("Pozytywny (PPT)", "Positive (PPT)")}</option>
                <option value="ST">
                  {t("Terapia Schematów (ST)", "Schema Therapy (ST)")}
                </option>
                <option value="SYS">
                  {t("Systemowa", "Systemic (Couples/Families)")}
                </option>
                <option value="EFT">
                  {t("Skoncentrowana na Emocjach (EFT)", "Emotionally Focused (EFT)")}
                </option>
                <option value="COACH">Coaching (ICF/GROW)</option>
              </select>
            </div>
          </div>

          <div className="flex gap-3 mt-6">
            <button
              onClick={next}
              className="flex-1 py-3 rounded-xl bg-[#8FA5A0]/20 text-[#8FA5A0] font-sans font-bold text-xs uppercase tracking-wider hover:bg-[#8FA5A0]/30 transition-colors"
            >
              {t("Pomiń", "Skip")}
            </button>
            <button
              onClick={next}
              className="flex-[2] py-3 rounded-xl bg-[#F5A623] text-[#1B2522] font-sans font-bold text-sm uppercase tracking-wider hover:bg-[#E09500] transition-colors"
            >
              {t("Dalej", "Continue")}
            </button>
          </div>
        </StepCard>
      )}

      {/* --- Step 5: Preferences --- */}
      {step === 5 && (
        <StepCard
          title={t("Czego najbardziej potrzebujesz?", "What do you need most?")}
          subtitle={t(
            "Pomaga nam to dostosować Twoje doświadczenie. Możesz wybrać kilka opcji.",
            "This helps us tailor your experience. You can pick multiple."
          )}
          icon="🎯"
        >
          <div className="space-y-2 mt-6">
            {[
              {
                id: "transcription",
                label: t(
                  "Automatyczna transkrypcja sesji",
                  "Automatic session transcription"
                ),
              },
              {
                id: "reports",
                label: t(
                  "Raporty kliniczne i notatki",
                  "Clinical reports and notes"
                ),
              },
              {
                id: "progress",
                label: t(
                  "Śledzenie postępu klienta między sesjami",
                  "Tracking client progress between sessions"
                ),
              },
              {
                id: "action_plan",
                label: t(
                  "Plan działania i zadania dla klienta",
                  "Action plans and tasks for clients"
                ),
              },
              {
                id: "documentation",
                label: t(
                  "Porządek w dokumentacji",
                  "Organized documentation"
                ),
              },
              {
                id: "rag",
                label: t(
                  "Analiza horyzontalna (wgląd w wiele sesji)",
                  "Horizontal analysis (insights across sessions)"
                ),
              },
            ].map(({ id, label }) => (
              <button
                key={id}
                onClick={() => {
                  setPreferences((prev) =>
                    prev.includes(id)
                      ? prev.filter((p) => p !== id)
                      : [...prev, id]
                  );
                }}
                className={`w-full text-left py-3 px-4 rounded-xl font-sans text-sm transition-all border ${
                  preferences.includes(id)
                    ? "bg-[#004D54] text-white border-[#2F6B62]"
                    : "bg-[#0F2E32] text-[#8FA5A0] border-[#1A3A3E] hover:border-[#2F6B62]"
                }`}
              >
                <span className="mr-2">
                  {preferences.includes(id) ? "✓" : "○"}
                </span>
                {label}
              </button>
            ))}
          </div>

          <div className="flex gap-3 mt-6">
            <button
              onClick={next}
              className="flex-1 py-3 rounded-xl bg-[#8FA5A0]/20 text-[#8FA5A0] font-sans font-bold text-xs uppercase tracking-wider hover:bg-[#8FA5A0]/30 transition-colors"
            >
              {t("Pomiń", "Skip")}
            </button>
            <button
              onClick={next}
              className="flex-[2] py-3 rounded-xl bg-[#F5A623] text-[#1B2522] font-sans font-bold text-sm uppercase tracking-wider hover:bg-[#E09500] transition-colors"
            >
              {t("Gotowe", "Done")}
            </button>
          </div>
        </StepCard>
      )}

      {/* --- Step 6: Done --- */}
      {step === 6 && (
        <div className="text-center py-12">
          <div className="text-6xl mb-6">🎉</div>
          <h2 className="font-serif text-2xl sm:text-3xl font-bold text-[#F2F0EA] mb-3">
            {t("Wszystko gotowe!", "You're all set!")}
          </h2>
          <p className="font-sans text-base text-[#8FA5A0] mb-6">
            {t(
              "Za chwilę przeniesiesz się do swojego panelu.",
              "You'll be redirected to your dashboard in a moment."
            )}
          </p>
          <div className="w-8 h-8 mx-auto border-2 border-[#F5A623] border-t-transparent rounded-full animate-spin" />
        </div>
      )}
    </div>
  );
}

/* ─── Shared Components ──────────────────────────────────────── */

function StepCard({
  title,
  subtitle,
  icon,
  children,
}: {
  title: string;
  subtitle: string;
  icon: string;
  children: React.ReactNode;
}) {
  return (
    <div className="rounded-2xl bg-[#0F2E32] border border-[#1A3A3E] p-6 sm:p-8 shadow-xl">
      <div className="text-3xl mb-3">{icon}</div>
      <h2 className="font-serif text-xl sm:text-2xl font-bold text-[#F2F0EA] mb-2">
        {title}
      </h2>
      <p className="font-sans text-sm text-[#8FA5A0] leading-relaxed">
        {subtitle}
      </p>
      {children}
    </div>
  );
}

function InputField({
  label,
  value,
  onChange,
  placeholder,
  required,
  type = "text",
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  required?: boolean;
  type?: string;
}) {
  return (
    <div>
      <label className="block font-sans text-xs font-bold text-[#8FA5A0] uppercase tracking-wider mb-1.5">
        {label}
        {required && <span className="text-[#F5A623] ml-0.5">*</span>}
      </label>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full py-2.5 px-3 rounded-xl bg-[#0A2326] text-[#F2F0EA] border border-[#1A3A3E] font-sans text-sm placeholder:text-[#4E5A55] focus:border-[#F5A623] focus:outline-none transition-colors"
      />
    </div>
  );
}
