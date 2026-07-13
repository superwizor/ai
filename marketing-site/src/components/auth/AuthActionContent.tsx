"use client";

import { useEffect, useState, useCallback, Suspense, useRef } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { useTranslations, useLocale } from "next-intl";
import { motion, AnimatePresence } from "framer-motion";
import {
  applyActionCode,
  verifyPasswordResetCode,
  confirmPasswordReset,
} from "firebase/auth";
import { getFirebaseAuth } from "@/lib/firebase/init";

type Status =
  | "initializing"
  | "verifying"
  | "success"
  | "checking-code"
  | "reset-form"
  | "reset-submitting"
  | "reset-success"
  | "error"
  | "unsupported";

type Particle = {
  id: number;
  x: number;
  y: number;
  color: string;
  size: number;
  delay: number;
  duration: number;
  rotate: number;
  shape: "circle" | "square" | "triangle";
};

// Web Audio API Synthesizer for a premium, clean iOS-style success chime.
function playSuccessSound() {
  const AudioContext = window.AudioContext || (window as any).webkitAudioContext;
  if (!AudioContext) return;
  const ctx = new AudioContext();
  const startTime = ctx.currentTime;

  // C5 -> E5 -> G5 -> C6 staggered progression
  const chordFreqs = [523.25, 659.25, 783.99, 1046.50];

  chordFreqs.forEach((freq, index) => {
    const osc = ctx.createOscillator();
    const gainNode = ctx.createGain();

    osc.type = "sine";
    osc.frequency.setValueAtTime(freq, startTime);

    const harmonicOsc = ctx.createOscillator();
    const harmonicGain = ctx.createGain();
    harmonicOsc.type = "triangle";
    harmonicOsc.frequency.setValueAtTime(freq * 2, startTime);

    const noteStart = startTime + index * 0.06;

    gainNode.gain.setValueAtTime(0, startTime);
    gainNode.gain.linearRampToValueAtTime(0.12, noteStart + 0.03);
    gainNode.gain.exponentialRampToValueAtTime(0.0001, noteStart + 0.8);

    harmonicGain.gain.setValueAtTime(0, startTime);
    harmonicGain.gain.linearRampToValueAtTime(0.04, noteStart + 0.02);
    harmonicGain.gain.exponentialRampToValueAtTime(0.0001, noteStart + 0.3);

    osc.connect(gainNode);
    gainNode.connect(ctx.destination);
    harmonicOsc.connect(harmonicGain);
    harmonicGain.connect(ctx.destination);

    osc.start(noteStart);
    osc.stop(noteStart + 1.0);
    harmonicOsc.start(noteStart);
    harmonicOsc.stop(noteStart + 0.5);
  });
}

const consumedCodes = new Set<string>();

function InnerContent() {
  const t = useTranslations("authAction");
  const locale = useLocale();
  const router = useRouter();
  const searchParams = useSearchParams();

  const [status, setStatus] = useState<Status>("initializing");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  
  // Password Reset Form Fields
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const newPasswordRef = useRef<HTMLInputElement>(null);
  const confirmPasswordRef = useRef<HTMLInputElement>(null);
  const [formError, setFormError] = useState<string | null>(null);

  // Confetti particles
  const [particles, setParticles] = useState<Particle[]>([]);

  const mode = searchParams?.get("mode") ?? "";
  const oobCode = searchParams?.get("oobCode") ?? "";

  const triggerConfetti = useCallback(() => {
    const generated: Particle[] = [];
    const colors = [
      "#F5A623", // Gold
      "#4FC097", // Emerald
      "#38B2AC", // Teal
      "#F6AD55", // Orange
      "#EC4899", // Pink
      "#3B82F6", // Blue
      "#A855F7", // Purple
      "#10B981", // Green
    ];
    const shapes: ("circle" | "square" | "triangle")[] = ["circle", "square", "triangle"];

    for (let i = 0; i < 70; i++) {
      const angle = (Math.random() * 120 + 210) * (Math.PI / 180); // 210 to 330 deg (upwards arch)
      const distance = 120 + Math.random() * 200;
      const x = Math.cos(angle) * distance;
      const y = Math.sin(angle) * distance;

      generated.push({
        id: i,
        x,
        y,
        color: colors[Math.floor(Math.random() * colors.length)],
        size: 5 + Math.random() * 6,
        delay: Math.random() * 0.15,
        duration: 1.4 + Math.random() * 0.6,
        rotate: Math.random() * 360,
        shape: shapes[Math.floor(Math.random() * shapes.length)],
      });
    }
    setParticles(generated);
  }, []);

  const processedRef = useRef(false);

  // Process Action Code on mount
  useEffect(() => {
    if (!mode || !oobCode) {
      setStatus("unsupported");
      return;
    }
    if (processedRef.current) return;
    processedRef.current = true;

    const auth = getFirebaseAuth();

    if (mode === "verifyEmail") {
      if (consumedCodes.has(oobCode)) {
        setStatus("success");
        setTimeout(() => {
          const continueUrl = searchParams?.get("continueUrl");
          if (continueUrl) {
            window.location.replace(continueUrl);
          } else {
            router.replace(`/${locale}/onboarding/`);
          }
        }, 1500);
        return;
      }
      setStatus("verifying");
      applyActionCode(auth, oobCode)
        .then(() => {
          consumedCodes.add(oobCode);
          setStatus("success");
          try {
            playSuccessSound();
            triggerConfetti();
          } catch (e) {
            console.warn("Chime blocked by browser autoplay policy:", e);
          }
          // Automatically redirect to onboarding or continueUrl after 3.5s
          setTimeout(() => {
            const continueUrl = searchParams?.get("continueUrl");
            if (continueUrl) {
              window.location.replace(continueUrl);
            } else {
              router.replace(`/${locale}/onboarding/`);
            }
          }, 3500);
        })
        .catch(async (err) => {
          console.error("[authAction] Verification error:", err);
          
          // Robust fallback: check if user is already verified (double-click/StrictMode reload)
          const authObj = getFirebaseAuth();
          if (authObj.currentUser) {
            try {
              await authObj.currentUser.reload();
              if (authObj.currentUser.emailVerified) {
                setStatus("success");
                setTimeout(() => {
                  const continueUrl = searchParams?.get("continueUrl");
                  if (continueUrl) {
                    window.location.replace(continueUrl);
                  } else {
                    router.replace(`/${locale}/onboarding/`);
                  }
                }, 2000);
                return;
              }
            } catch {}
          }
          
          setStatus("error");
          setErrorMessage(t("errorBody"));
        });
    } else if (mode === "resetPassword") {
      setStatus("checking-code");
      verifyPasswordResetCode(auth, oobCode)
        .then(() => {
          setStatus("reset-form");
        })
        .catch((err) => {
          console.error("[authAction] Password reset check failed:", err);
          setStatus("error");
          setErrorMessage(t("errorBody"));
        });
    } else {
      setStatus("unsupported");
    }
  }, [mode, oobCode, locale, router, t, triggerConfetti, searchParams]);

  // Handle password reset submission
  const handlePasswordReset = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    const finalNewPassword = newPasswordRef.current?.value || newPassword || "";
    const finalConfirmPassword = confirmPasswordRef.current?.value || confirmPassword || "";

    if (finalNewPassword.length < 8) {
      setFormError(t("errorPasswordTooShort"));
      return;
    }

    if (finalNewPassword !== finalConfirmPassword) {
      setFormError(t("errorPasswordsMismatch"));
      return;
    }

    setStatus("reset-submitting");
    const auth = getFirebaseAuth();

    try {
      await confirmPasswordReset(auth, oobCode, finalNewPassword);
      setStatus("reset-success");
      try {
        playSuccessSound();
      } catch {}
    } catch (err) {
      console.error("[authAction] Password reset confirm failed:", err);
      setStatus("error");
      setErrorMessage(t("errorBody"));
    }
  };

  const cleanPrefix = locale === "en" ? "/en" : "/pl";

  return (
    <div className="relative w-full max-w-md mx-auto text-center px-4">
      {/* Slow-rotating background glow to add premium atmosphere */}
      <div className="absolute -inset-10 -z-10 flex items-center justify-center opacity-25 blur-[100px] pointer-events-none">
        <div className="w-[250px] h-[250px] rounded-full bg-gradient-to-tr from-[#2F6B62] via-[#F5A623] to-[#004D54] animate-pulse-slow" />
      </div>

      {/* Confetti Container */}
      <div className="absolute inset-0 overflow-visible pointer-events-none z-50">
        {particles.map((p) => (
          <motion.div
            key={p.id}
            className="absolute"
            initial={{ x: 0, y: 0, scale: 0, rotate: 0, opacity: 1 }}
            animate={{
              x: p.x,
              y: [0, p.y * 0.4, p.y, p.y + 150], // Parabolic gravity path
              scale: [0, 1, 1, 0.7, 0],
              rotate: [0, p.rotate, p.rotate * 2.5, p.rotate * 4],
              opacity: [1, 1, 1, 0.9, 0],
            }}
            transition={{
              duration: p.duration,
              ease: [0.1, 0.8, 0.25, 1],
              delay: p.delay,
            }}
            style={{
              width: p.shape === "triangle" ? 0 : p.size,
              height: p.shape === "triangle" ? 0 : p.size,
              backgroundColor: p.shape !== "triangle" ? p.color : undefined,
              borderRadius: p.shape === "circle" ? "50%" : p.shape === "square" ? "4px" : undefined,
              borderLeft: p.shape === "triangle" ? `${p.size / 2}px solid transparent` : undefined,
              borderRight: p.shape === "triangle" ? `${p.size / 2}px solid transparent` : undefined,
              borderBottom: p.shape === "triangle" ? `${p.size}px solid ${p.color}` : undefined,
              left: "50%",
              top: "25%",
            }}
          />
        ))}
      </div>

      {/* Premium Glassmorphic Card */}
      <div className="relative rounded-3xl bg-gradient-to-b from-[#0F2E32]/95 to-[#0A2326]/98 border border-[#1A3A3E] p-6 sm:p-10 shadow-[0_20px_50px_rgba(0,0,0,0.5)] backdrop-blur-xl text-left">
        <AnimatePresence mode="wait">
          {/* STATE: INITIALIZING & LOADING VERIFICATION */}
          {(status === "initializing" || status === "verifying" || status === "checking-code") && (
            <motion.div
              key="loading"
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              transition={{ duration: 0.25 }}
              className="text-center py-8"
            >
              {/* Spinner */}
              <div className="relative w-16 h-16 mx-auto mb-6">
                <div className="absolute inset-0 rounded-full border-4 border-frost/10" />
                <div className="absolute inset-0 rounded-full border-4 border-t-ember border-r-transparent border-b-transparent border-l-transparent animate-spin" />
              </div>
              <h2 className="font-display text-frost text-2xl font-semibold tracking-wide mb-3">
                {status === "checking-code" ? t("verifyingTitle") : t("verifyingTitle")}
              </h2>
              <p className="font-sans text-mist/70 text-sm leading-relaxed max-w-xs mx-auto">
                {t("verifyingBody")}
              </p>
            </motion.div>
          )}

          {/* STATE: SUCCESS FOR EMAIL VERIFICATION */}
          {status === "success" && (
            <motion.div
              key="success"
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -15 }}
              transition={{ duration: 0.3 }}
              className="text-center py-6"
            >
              <div className="w-16 h-16 rounded-full bg-gradient-to-br from-[#2F6B62]/20 to-[#4FC097]/10 flex items-center justify-center mx-auto mb-6 border border-[#2F6B62]/50 shadow-[0_0_20px_rgba(79,192,151,0.2)]">
                <svg className="w-8 h-8 text-[#4FC097]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h2 className="font-display text-frost text-2xl font-bold mb-3">
                {t("successTitle")}
              </h2>
              <p className="font-sans text-mist/85 text-sm leading-relaxed mb-8 max-w-sm mx-auto">
                {t("successBody")}
              </p>
              <a
                href={`${cleanPrefix}/onboarding/`}
                className="relative inline-flex items-center justify-center w-full rounded-2xl bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#1B2522] font-sans font-bold text-xs uppercase tracking-wider px-6 py-4 shadow-lg shadow-black/25 hover:shadow-[0_8px_25px_rgba(245,166,35,0.3)] hover:scale-[1.01] active:scale-[0.99] transition-all duration-300"
              >
                {t("successCta")}
              </a>
            </motion.div>
          )}

          {/* STATE: PASSWORD RESET FORM */}
          {status === "reset-form" && (
            <motion.div
              key="reset-form"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.3 }}
            >
              <h2 className="font-display text-frost text-2xl font-bold mb-2">
                {t("resetPasswordTitle")}
              </h2>
              <p className="font-sans text-mist/70 text-sm mb-6 leading-relaxed">
                {t("resetPasswordBody")}
              </p>

              <form onSubmit={handlePasswordReset} className="grid gap-4" noValidate>
                <label className="grid gap-1.5">
                  <span className="font-sans text-[10px] font-semibold uppercase tracking-wider text-mist">
                    {t("newPasswordLabel")}
                  </span>
                  <input
                    ref={newPasswordRef}
                    type="password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    required
                    className="rounded-xl bg-frost/10 border border-frost/20 px-3.5 py-3 font-sans text-base text-frost focus:outline-none focus:border-ember focus:bg-frost/15 placeholder:text-mist/50 transition"
                  />
                  <span className="font-sans text-[10px] text-mist/50">
                    {t("passwordHint")}
                  </span>
                </label>

                <label className="grid gap-1.5">
                  <span className="font-sans text-[10px] font-semibold uppercase tracking-wider text-mist">
                    {t("confirmNewPasswordLabel")}
                  </span>
                  <input
                    ref={confirmPasswordRef}
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    required
                    className="rounded-xl bg-frost/10 border border-frost/20 px-3.5 py-3 font-sans text-base text-frost focus:outline-none focus:border-ember focus:bg-frost/15 placeholder:text-mist/50 transition"
                  />
                </label>

                {formError && (
                  <p role="alert" className="rounded-xl border border-magma/40 bg-magma/10 px-3.5 py-2.5 font-sans text-sm text-frost">
                    {formError}
                  </p>
                )}

                <button
                  type="submit"
                  className="w-full flex items-center justify-center py-4 px-6 rounded-2xl bg-ember text-obsidian shadow-[0_4px_14px_rgba(252,174,47,0.3)] hover:brightness-110 hover:-translate-y-0.5 transition-all duration-300 font-sans text-xs font-bold uppercase tracking-wider cursor-pointer"
                >
                  {t("resetPasswordSubmit")}
                </button>
              </form>
            </motion.div>
          )}

          {/* STATE: PASSWORD RESET SUBMITTING */}
          {status === "reset-submitting" && (
            <motion.div
              key="reset-submitting"
              className="text-center py-8"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
            >
              <div className="relative w-16 h-16 mx-auto mb-6">
                <div className="absolute inset-0 rounded-full border-4 border-frost/10" />
                <div className="absolute inset-0 rounded-full border-4 border-t-ember border-r-transparent border-b-transparent border-l-transparent animate-spin" />
              </div>
              <h2 className="font-display text-frost text-2xl font-semibold tracking-wide mb-3">
                {t("resetPasswordSubmitting")}
              </h2>
            </motion.div>
          )}

          {/* STATE: PASSWORD RESET SUCCESS */}
          {status === "reset-success" && (
            <motion.div
              key="reset-success"
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -15 }}
              transition={{ duration: 0.3 }}
              className="text-center py-6"
            >
              <div className="w-16 h-16 rounded-full bg-gradient-to-br from-[#2F6B62]/20 to-[#4FC097]/10 flex items-center justify-center mx-auto mb-6 border border-[#2F6B62]/50 shadow-[0_0_20px_rgba(79,192,151,0.2)]">
                <svg className="w-8 h-8 text-[#4FC097]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h2 className="font-display text-frost text-2xl font-bold mb-3">
                {t("resetPasswordSuccessTitle")}
              </h2>
              <p className="font-sans text-mist/85 text-sm leading-relaxed mb-8 max-w-sm mx-auto">
                {t("resetPasswordSuccessBody")}
              </p>
              <a
                href={`${cleanPrefix}/login`}
                className="relative inline-flex items-center justify-center w-full rounded-2xl bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#1B2522] font-sans font-bold text-xs uppercase tracking-wider px-6 py-4 shadow-lg shadow-black/25 hover:shadow-[0_8px_25px_rgba(245,166,35,0.3)] hover:scale-[1.01] active:scale-[0.99] transition-all duration-300"
              >
                {t("resetPasswordSuccessCta")}
              </a>
            </motion.div>
          )}

          {/* STATE: ERROR / INVALID CODE */}
          {status === "error" && (
            <motion.div
              key="error"
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              transition={{ duration: 0.25 }}
              className="text-center py-6"
            >
              <div className="w-16 h-16 rounded-full bg-gradient-to-br from-magma/20 to-magma/10 flex items-center justify-center mx-auto mb-6 border border-magma/40 shadow-[0_0_20px_rgba(216,69,21,0.15)]">
                <svg className="w-8 h-8 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <h2 className="font-display text-frost text-2xl font-bold mb-3">
                {t("errorTitle")}
              </h2>
              <p className="font-sans text-mist/75 text-sm leading-relaxed mb-8 max-w-sm mx-auto">
                {errorMessage ?? t("errorBody")}
              </p>
              
              {mode === "verifyEmail" ? (
                <a
                  href={searchParams?.get("continueUrl") || `${cleanPrefix}/register/therapist/verify-email`}
                  className="relative inline-flex items-center justify-center w-full rounded-2xl bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#1B2522] font-sans font-bold text-xs uppercase tracking-wider px-6 py-4 shadow-lg shadow-black/25 hover:shadow-[0_8px_25px_rgba(245,166,35,0.3)] hover:scale-[1.01] active:scale-[0.99] transition-all duration-300"
                >
                  {t("errorVerifyCta")}
                </a>
              ) : (
                <a
                  href={`${cleanPrefix}/`}
                  className="relative inline-flex items-center justify-center w-full rounded-2xl border border-frost/20 text-frost hover:bg-frost/5 font-sans font-bold text-xs uppercase tracking-wider px-6 py-4 transition-all duration-300"
                >
                  {t("errorCta")}
                </a>
              )}
            </motion.div>
          )}

          {/* STATE: UNSUPPORTED / MISSING PARAMS */}
          {status === "unsupported" && (
            <motion.div
              key="unsupported"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="text-center py-6"
            >
              <div className="w-16 h-16 rounded-full bg-gradient-to-br from-frost/10 to-frost/5 flex items-center justify-center mx-auto mb-6 border border-frost/25">
                <svg className="w-8 h-8 text-frost/80" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
              <h2 className="font-display text-frost text-2xl font-bold mb-3">
                {t("unsupportedTitle")}
              </h2>
              <p className="font-sans text-mist/75 text-sm leading-relaxed mb-8 max-w-sm mx-auto">
                {t("unsupportedBody")}
              </p>
              <a
                href={`${cleanPrefix}/`}
                className="relative inline-flex items-center justify-center w-full rounded-2xl border border-frost/20 text-frost hover:bg-frost/5 font-sans font-bold text-xs uppercase tracking-wider px-6 py-4 transition-all duration-300"
              >
                {t("errorCta")}
              </a>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}

export function AuthActionContent() {
  return (
    <Suspense fallback={
      <div className="relative rounded-3xl bg-gradient-to-b from-[#0F2E32]/95 to-[#0A2326]/98 border border-[#1A3A3E] p-10 shadow-[0_20px_50px_rgba(0,0,0,0.5)] backdrop-blur-xl w-full max-w-md mx-auto text-center">
        <div className="relative w-16 h-16 mx-auto mb-6">
          <div className="absolute inset-0 rounded-full border-4 border-frost/10" />
          <div className="absolute inset-0 rounded-full border-4 border-t-ember border-r-transparent border-b-transparent border-l-transparent animate-spin" />
        </div>
      </div>
    }>
      <InnerContent />
    </Suspense>
  );
}
