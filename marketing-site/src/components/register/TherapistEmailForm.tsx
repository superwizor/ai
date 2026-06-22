// Therapist registration form (email/password and social path wizard)
//
// Flow (5 steps):
//   1. Pitch (Value proposition based on selected plan or trial)
//   2. Choose sign-up method (Google, Apple, or Email)
//   3. Credentials (Email/Password + ToS check)
//   4. Personal details (First Name, Last Name, Phone Number)
//   5. Specialization & preferences (Modality, Professional Title, Credentials, Language, Marketing)
//
// Zod-validated step-by-step.
//
// Failure modes:
//   - email-already-in-use → inline error + returns to Step 3
//   - weak-password / Firebase error → inline error
//   - identity-svc Connect error → toast + keep user on form

"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { FirebaseError } from "firebase/app";
import { motion, AnimatePresence } from "framer-motion";
import { ConnectError, Code } from "@connectrpc/connect";

import {
  therapistEmailSchema,
  type TherapistEmailForm as TherapFormType,
} from "@/lib/register/schema";
import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient } from "@/lib/connect/clients";
import {
  UserRole,
  CreateUserRequestSchema,
  UpdateProfileRequestSchema,
  CheckEmailExistsRequestSchema,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import {
  Checkbox,
  FieldShell,
  RadioGroup,
  Select,
  TextInput,
  PhoneInput,
} from "@/components/forms/Field";

import { lookupPlan, formatPrice } from "@/lib/billing/plans";
import type { PlanTier, BillingCycle } from "@/lib/billing/plans";
import { handlePostRegistrationRedirect } from "@/lib/register/post-registration";

type PitchVariant = "trial" | "solo" | "pro" | "beta";

function resolvePitch(plan: string | null): PitchVariant {
  if (!plan) return "trial";
  const lower = plan.toLowerCase();
  if (lower.startsWith("solo")) return "solo";
  if (lower.startsWith("pro")) return "pro";
  if (lower === "beta") return "beta";
  return "trial";
}

function renderPitchHeading(
  planSlug: string | null,
  variant: PitchVariant,
  locale: string,
  fallbackHeading: string,
  isForm: boolean = false
) {
  if (variant !== "solo" && variant !== "pro") {
    return fallbackHeading;
  }

  const isAnnual = planSlug ? planSlug.toLowerCase().endsWith("annual") : false;
  const cycle: BillingCycle = isAnnual ? "ANNUAL" : "MONTHLY";
  const tier: PlanTier = variant === "solo" ? "SOLO" : "PRO";
  const planRow = lookupPlan(tier, cycle);

  if (!planRow) {
    return fallbackHeading;
  }

  const formattedBase = formatPrice(locale, planRow.priceGross);
  const formattedIntro = planRow.priceIntroGross !== undefined
    ? formatPrice(locale, planRow.priceIntroGross)
    : null;

  let sessionText = "";
  if (locale === "en") {
    const cycleText = cycle === "ANNUAL" ? "year" : "month";
    sessionText = `${planRow.tokensPerPeriod} sessions / ${cycleText} · `;
  } else {
    const cycleText = cycle === "ANNUAL" ? "rok" : "miesiąc";
    sessionText = `${planRow.tokensPerPeriod} sesji / ${cycleText} · `;
  }

  const priceSuffix = locale === "en" ? " PLN" : " zł brutto";
  const strikeTextColor = isForm ? "text-frost/40" : "text-[#1B2522]/40";
  const activeTextColor = isForm ? "text-frost" : "text-[#1B2522]";

  if (formattedIntro) {
    return (
      <span className="flex items-center justify-center flex-wrap gap-x-1.5 leading-tight">
        <span>{sessionText}</span>
        <span className="whitespace-nowrap inline-flex items-center gap-x-1.5">
          <span className={`relative inline-block font-medium ${strikeTextColor}`}>
            <span className="opacity-70">{formattedBase}</span>
            <span className="absolute left-0 right-0 top-[52%] h-[2px] bg-[#fcae2f] -translate-y-1/2 rounded-full shadow-[0_0_3px_rgba(252,174,47,0.35)]" />
          </span>
          <span className={`font-extrabold ${activeTextColor}`}>
            {formattedIntro}
          </span>
          <span>{priceSuffix}</span>
        </span>
      </span>
    );
  }

  return (
    <span>
      {sessionText}
      {formattedBase}
      {priceSuffix}
    </span>
  );
}

type ContentBlock = {
  badge: string;
  heading: string;
  features: string[];
  footnote: string;
};

const PITCH_CONTENT: Record<PitchVariant, { pl: ContentBlock; en: ContentBlock }> = {
  trial: {
    pl: {
      badge: "Darmowy start",
      heading: "Zacznij od 5 sesji za darmo",
      features: [
        "5 sesji terapeutycznych przez 30 dni",
        "Pełny dostęp do wszystkich funkcji",
        "Bez podawania karty kredytowej",
        "Możliwość rezygnacji w każdej chwili",
      ],
      footnote: "Po rejestracji natychmiast przejdziesz do aplikacji.",
    },
    en: {
      badge: "Free start",
      heading: "Start with 5 free sessions",
      features: [
        "5 therapy sessions for 30 days",
        "Full access to all features",
        "No credit card required",
        "Cancel at any time",
      ],
      footnote: "After signing up you'll get immediate access to the app.",
    },
  },
  solo: {
    pl: {
      badge: "Plan Równowaga",
      heading: "30 sesji / miesiąc \u00b7 149 zł brutto",
      features: [
        "Pełny dostęp do wszystkich funkcji",
        "Raport w Twoim nurcie terapeutycznym",
        "Ciągłość między sesjami",
      ],
      footnote:
        "Załóż konto — po rejestracji przekierujemy Cię do bezpiecznej płatności.",
    },
    en: {
      badge: "Balance plan",
      heading: "30 sessions / month \u00b7 149 PLN",
      features: [
        "Full access to all features",
        "Reports in your therapeutic modality",
        "Session-to-session continuity",
      ],
      footnote:
        "Create your account first — after signup we'll redirect you to secure checkout.",
    },
  },
  pro: {
    pl: {
      badge: "Plan Rozkwit \u00b7 Najczęściej wybierany",
      heading: "90 sesji / miesiąc \u00b7 299 zł brutto",
      features: [
        "Pełny dostęp do wszystkich funkcji",
        "Raport w Twoim nurcie terapeutycznym",
        "Ciągłość między sesjami",
        "Idealny przy pełnym grafiku",
      ],
      footnote:
        "Załóż konto — po rejestracji przekierujemy Cię do bezpiecznej płatności.",
    },
    en: {
      badge: "Growth plan \u00b7 Most popular",
      heading: "90 sessions / month \u00b7 299 PLN",
      features: [
        "Full access to all features",
        "Reports in your therapeutic modality",
        "Session-to-session continuity",
        "Perfect for a full schedule",
      ],
      footnote:
        "Create your account first — after signup we'll redirect you to secure checkout.",
    },
  },
  beta: {
    pl: {
      badge: "Program Beta · Darmowy dostęp",
      heading: "120 sesji / miesiąc przez 2 miesiące",
      features: [
        "120 sesji terapeutycznych miesięcznie",
        "Pełny dostęp do wszystkich funkcji",
        "2 miesiące całkowicie za darmo",
        "Priorytetowe wsparcie zespołu",
      ],
      footnote: "Załóż konto — dostęp do programu beta zostanie aktywowany automatycznie.",
    },
    en: {
      badge: "Beta Program · Free access",
      heading: "120 sessions / month for 2 months",
      features: [
        "120 sessions therapy per month",
        "Full access to all features",
        "2 months completely free",
        "Priority team support",
      ],
      footnote: "Create your account — beta access will be activated automatically.",
    },
  },
};

const slideVariants = {
  enter: (direction: number) => ({
    x: direction > 0 ? 50 : -50,
    opacity: 0,
  }),
  center: {
    x: 0,
    opacity: 1,
    transition: {
      x: { type: "spring" as const, stiffness: 350, damping: 35 },
      opacity: { duration: 0.15 },
    },
  },
  exit: (direction: number) => ({
    x: direction < 0 ? 50 : -50,
    opacity: 0,
    transition: {
      x: { type: "spring" as const, stiffness: 350, damping: 35 },
      opacity: { duration: 0.15 },
    },
  }),
};

export function TherapistEmailForm() {

  const t = useTranslations("register.fields");
  const tCommon = useTranslations("register.common");
  const tErr = useTranslations("register.errors");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";
  const searchParams = useSearchParams();
  const planSlug = searchParams.get("plan");

  const [step, setStep] = useState<1 | 2 | 3 | 4 | 5>(1);
  const [direction, setDirection] = useState<1 | -1>(1);
  const [serverError, setServerError] = useState<string | null>(null);
  const [socialBusy, setSocialBusy] = useState(false);
  const [checkingEmail, setCheckingEmail] = useState(false);

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    trigger,
    control,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<TherapFormType>({
    resolver: zodResolver(therapistEmailSchema),
    defaultValues: {
      uiLanguage: locale === "en" ? "en" : "pl",
      hasMarketingConsent: false,
    },
  });

  const handleNext = async () => {
    setServerError(null);
    if (step === 1) {
      setDirection(1);
      setStep(2);
    } else if (step === 2) {
      setDirection(1);
      setStep(3);
    } else if (step === 3) {
      const isValid = await trigger(["email", "password", "hasAcceptedTos"]);
      if (isValid) {
        setCheckingEmail(true);
        try {
          const checkResp = await identityClient.checkEmailExists(
            create(CheckEmailExistsRequestSchema, { email: watch("email") })
          );
          if (checkResp.exists) {
            setError("email", {
              type: "manual",
              message: "email-already-in-use",
            });
            setServerError(tErr("emailAlreadyInUse"));
            return;
          }
          setDirection(1);
          setStep(4);
        } catch (e) {
          console.error("Failed to check email exists:", e);
          setServerError(tErr("networkError"));
        } finally {
          setCheckingEmail(false);
        }
      }
    } else if (step === 4) {
      const isValid = await trigger(["firstName", "lastName", "phoneNumber"]);
      if (isValid) {
        setDirection(1);
        setStep(5);
      }
    }
  };

  const handleBack = () => {
    setServerError(null);
    if (step > 1) {
      setDirection(-1);
      setStep((s) => (s - 1) as 1 | 2 | 3 | 4 | 5);
    }
  };

  const handleSocialUser = async (user: {
    uid: string;
    displayName: string | null;
    email: string | null;
  }) => {
    try {
      await identityClient.getUserByFirebaseUID({ firebaseUid: user.uid });
      window.location.href = prefix ? `${prefix}/dashboard/` : "/dashboard/";
      return;
    } catch (e) {
      if (!(e instanceof ConnectError) || e.code !== Code.NotFound) {
        throw e;
      }
    }

    const dn = user.displayName ?? "";
    const [firstName = "", ...rest] = dn.split(" ");
    const lastName = rest.join(" ");
    const params = new URLSearchParams({
      firstName,
      lastName,
      email: user.email ?? "",
      ...(planSlug ? { plan: planSlug } : {}),
    });
    window.location.href = `${prefix}/register/therapist/finish?${params}`;
  };

  const onGoogle = async () => {
    setSocialBusy(true);
    setServerError(null);
    try {
      const user = await auth.signInWithGoogle();
      await handleSocialUser(user);
    } catch (e) {
      if (e instanceof FirebaseError && e.code === "auth/popup-closed-by-user") {
        return;
      }
      console.error("[social-auth] Google sign-in failed:", e);
      setServerError(tErr("unknown"));
    } finally {
      setSocialBusy(false);
    }
  };

  const onApple = async () => {
    setSocialBusy(true);
    setServerError(null);
    try {
      const user = await auth.signInWithApple();
      await handleSocialUser(user);
    } catch (e) {
      if (e instanceof FirebaseError && e.code === "auth/popup-closed-by-user") {
        return;
      }
      console.error("[social-auth] Apple sign-in failed:", e);
      setServerError(tErr("unknown"));
    } finally {
      setSocialBusy(false);
    }
  };

  const onSubmit = handleSubmit(async (data) => {
    if (step < 5) {
      await handleNext();
      return;
    }

    setServerError(null);
    try {
      // 1. Firebase account + verification email.
      const continueUrl = `${window.location.origin}${prefix}/register/therapist/verify-email?email=${encodeURIComponent(data.email)}${planSlug ? `&plan=${encodeURIComponent(planSlug)}` : ""}`;
      const user = await auth.signUpWithEmail(data.email, data.password, continueUrl);

      // 2. CreateUser on identity-svc
      const tz =
        Intl.DateTimeFormat().resolvedOptions().timeZone || "Europe/Warsaw";
      const createReq = create(CreateUserRequestSchema, {
        firebaseUid: user.uid,
        email: data.email,
        role: UserRole.THERAPIST,
        firstName: data.firstName,
        lastName: data.lastName,
        uiLanguage: data.uiLanguage,
        timezone: tz,
        hasAcceptedTos: true,
        initialPlanTier: planSlug?.toUpperCase() === "BETA" ? "BETA" : "",
      });
      const created = await identityClient.createUser(createReq);

      // 3. Optional profile-only fields
      const hasExtras =
        !!data.professionalTitle ||
        !!data.credentialsNumber ||
        !!data.phoneNumber;

      if (hasExtras) {
        const updateReq = create(UpdateProfileRequestSchema, {
          userId: created.id,
          firstName: data.firstName,
          lastName: data.lastName,
          professionalTitle: data.professionalTitle ?? "",
          credentialsNumber: data.credentialsNumber ?? "",
          phoneNumber: data.phoneNumber ?? "",
          hasMarketingConsent: data.hasMarketingConsent ?? false,
        });
        await identityClient.updateProfile(updateReq);
      }

      // 4. Redirect based on plan selection
      await handlePostRegistrationRedirect(
        created.organizationId ?? "",
        planSlug,
        prefix,
        data.email,
        data.phoneNumber ?? undefined,
        `${data.firstName || ""} ${data.lastName || ""}`.trim() || undefined,
      );
    } catch (e) {
      if (e instanceof FirebaseError) {
        if (e.code === "auth/email-already-in-use") {
          setError("email", {
            type: "manual",
            message: "email-already-in-use",
          });
          setServerError(tErr("emailAlreadyInUse"));
          setDirection(-1);
          setStep(3); // Go back to credentials step
          return;
        }
        if (e.code === "auth/weak-password") {
          setError("password", {
            type: "manual",
            message: "weak-password",
          });
          setServerError(tErr("weakPassword"));
          setDirection(-1);
          setStep(3); // Go back to credentials step
          return;
        }
        if (
          e.code === "auth/network-request-failed" ||
          e.code === "auth/internal-error"
        ) {
          setServerError(tErr("networkError"));
          return;
        }
      }
      if (
        e instanceof TypeError &&
        /failed to fetch|network/i.test(e.message)
      ) {
        setServerError(tErr("networkError"));
        return;
      }
      console.error("[register/therapist] unmapped signup error", e);
      setServerError(tErr("unknown"));
    }
  });

  const uiLanguage = watch("uiLanguage");
  const pitchVariant = resolvePitch(planSlug);
  const content = PITCH_CONTENT[pitchVariant][locale === "en" ? "en" : "pl"];

  return (
    <div className="mx-auto w-full grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
      {/* Left Spacer to center the form card on desktop */}
      <div className="hidden lg:block lg:col-span-3" />

      {/* Left Column: Form inside card container */}
      <div className="col-span-12 lg:col-span-6 w-full max-w-[480px] lg:justify-self-center rounded-[20px] border border-frost/10 bg-frost/5 backdrop-blur-md p-6 sm:p-10 shadow-[0_8px_32px_rgba(0,0,0,0.25)] transition-all duration-500">
        {/* Progress Indicator */}
        <div className="flex items-center justify-center gap-2 mb-8">
          {[1, 2, 3, 4, 5].map((n) => (
            <div
              key={n}
              className={`h-1.5 rounded-full transition-all duration-300 ${
                n === step
                  ? "w-10 bg-ember shadow-[0_0_12px_rgba(252,174,47,0.6)]"
                  : n < step
                  ? "w-2.5 bg-ember/50"
                  : "w-2.5 bg-frost/10"
              }`}
            />
          ))}
        </div>

        <form onSubmit={onSubmit} className="grid gap-5" noValidate>
          <div className="relative overflow-hidden min-h-[360px]">
            <AnimatePresence mode="wait" initial={false} custom={direction}>
              {step === 1 && (
                <motion.div
                  key="step1"
                  custom={direction}
                  variants={slideVariants}
                  initial="enter"
                  animate="center"
                  exit="exit"
                  className="flex flex-col gap-6 text-center items-center w-full"
                >
                  {/* Pitch description */}
                  <div className="flex flex-col items-center">
                    <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider bg-ember/15 text-ember border border-ember/25 mb-4 mx-auto">
                      <span className="w-1.5 h-1.5 rounded-full bg-ember animate-pulse" />
                      {content.badge}
                    </span>
                    <h2 className="font-display text-frost text-2xl sm:text-3xl font-extrabold tracking-tight leading-tight text-center">
                      {renderPitchHeading(planSlug, pitchVariant, locale, content.heading, true)}
                    </h2>
                  </div>

                  <div className="p-5 rounded-[12px] bg-frost/[0.03] border border-frost/5 text-left max-w-md w-full mx-auto">
                    <ul className="space-y-3">
                      {content.features.map((feat, i) => (
                        <li key={i} className="flex items-start gap-3 text-mist text-sm leading-relaxed">
                          <svg className="w-5 h-5 text-ember shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                          </svg>
                          <span>{feat}</span>
                        </li>
                      ))}
                    </ul>
                  </div>

                  <p className="text-xs text-mist/60 leading-normal text-center mx-auto max-w-md">
                    {content.footnote}
                  </p>

                  <button
                    type="button"
                    id="start-trial-btn"
                    onClick={handleNext}
                    className="inline-flex items-center justify-center rounded-xl bg-ember text-obsidian font-sans font-bold uppercase tracking-[var(--tracking-label)] text-sm px-6 py-4 shadow-[0_4px_14px_rgba(252,174,47,0.4)] hover:brightness-115 hover:shadow-[0_6px_20px_rgba(252,174,47,0.6)] hover:-translate-y-0.5 active:scale-[0.98] transition-all duration-300 cursor-pointer w-full md:w-auto self-center"
                  >
                    {locale === "pl" ? "TAK, ZAKŁADAM KONTO" : "YES, CREATE MY ACCOUNT"}
                  </button>
                </motion.div>
              )}

            {step === 2 && (
              <motion.div
                key="step2"
                custom={direction}
                variants={slideVariants}
                initial="enter"
                animate="center"
                exit="exit"
                className="grid gap-6 w-full"
              >
                <div className="text-center">
                  <p className="text-xs font-bold uppercase text-ember tracking-[var(--tracking-overline)] mb-2">
                    {locale === "pl" ? "Metoda rejestracji" : "Registration Method"}
                  </p>
                  <h2 className="font-display text-frost text-xl sm:text-2xl font-bold">
                    {locale === "pl" ? "Wybierz jak chcesz założyć konto" : "Choose how to register"}
                  </h2>
                </div>

                <div className="grid gap-3 mt-2">
                  <button
                    type="button"
                    onClick={onGoogle}
                    disabled={socialBusy}
                    className="w-full flex items-center justify-center gap-3 py-3 px-4 rounded-xl bg-frost/5 border border-frost/20 hover:bg-frost/10 hover:border-frost/40 text-frost font-sans font-semibold text-sm transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer group"
                  >
                    <svg aria-hidden width="18" height="18" viewBox="0 0 18 18" fill="currentColor">
                      <path d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84c-.21 1.13-.84 2.08-1.79 2.72v2.26h2.9c1.7-1.56 2.69-3.87 2.69-6.62z" opacity=".9" />
                      <path d="M9 18c2.43 0 4.47-.81 5.96-2.18l-2.9-2.26c-.81.54-1.84.86-3.06.86-2.36 0-4.36-1.59-5.07-3.74H.96v2.34A9 9 0 0 0 9 18z" opacity=".7" />
                      <path d="M3.93 10.71A5.4 5.4 0 0 1 3.64 9c0-.6.1-1.18.29-1.71V4.96H.96A9 9 0 0 0 0 9c0 1.45.35 2.83.96 4.04l2.97-2.33z" opacity=".55" />
                      <path d="M9 3.58c1.32 0 2.51.45 3.44 1.35l2.58-2.58A9 9 0 0 0 9 0 9 9 0 0 0 .96 4.96l2.97 2.33C4.64 5.17 6.64 3.58 9 3.58z" opacity=".85" />
                    </svg>
                    {tCommon("google")}
                  </button>

                  <button
                    type="button"
                    onClick={onApple}
                    disabled={socialBusy}
                    className="w-full flex items-center justify-center gap-3 py-3 px-4 rounded-xl bg-frost/5 border border-frost/20 hover:bg-frost/10 hover:border-frost/40 text-frost font-sans font-semibold text-sm transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer group"
                  >
                    <svg aria-hidden width="17" height="20" viewBox="0 0 814 1000" fill="currentColor">
                      <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105.3-57.8-155.5-127.4C46 790.9 0 663.1 0 541.8c0-207.6 135.4-317.3 268.9-317.3 71.6 0 131 46.5 175.4 46.5 42.8 0 109.6-49.5 190.5-49.5 30.8 0 108.2 2.6 164.4 100.5zm-234.4-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z"/>
                    </svg>
                    {tCommon("apple")}
                  </button>
                </div>

                <div className="relative my-2">
                  <div className="absolute inset-0 flex items-center" aria-hidden>
                    <span className="w-full border-t border-frost/10"></span>
                  </div>
                  <div className="relative flex justify-center">
                    <span className="bg-evergreen px-3 font-sans text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/60">
                      {tCommon("or")}
                    </span>
                  </div>
                </div>

                <button
                  type="button"
                  id="signup-email-btn"
                  onClick={handleNext}
                  className="w-full flex items-center justify-center gap-3 py-4 px-6 rounded-xl bg-ember text-obsidian shadow-[0_4px_14px_rgba(252,174,47,0.4)] hover:brightness-115 hover:shadow-[0_6px_20px_rgba(252,174,47,0.6)] hover:-translate-y-0.5 transition-all duration-300 group cursor-pointer font-sans text-[18px] font-semibold text-obsidian"
                >
                  <svg className="w-5 h-5 text-obsidian" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                  </svg>
                  <span>{locale === "pl" ? "Załóż konto adresem e-mail" : "Sign up with Email"}</span>
                </button>

                <div className="flex justify-between items-center mt-4 border-t border-frost/5 pt-4">
                  <button
                    type="button"
                    onClick={handleBack}
                    className="inline-flex items-center gap-1.5 text-xs text-mist hover:text-frost font-sans transition cursor-pointer"
                  >
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                    </svg>
                    {tCommon("back")}
                  </button>
                </div>
              </motion.div>
            )}

            {step === 3 && (
              <motion.div
                key="step3"
                custom={direction}
                variants={slideVariants}
                initial="enter"
                animate="center"
                exit="exit"
                className="grid gap-4 w-full"
              >
                <div className="text-center mb-2">
                  <p className="text-xs font-bold uppercase text-ember tracking-[var(--tracking-overline)] mb-2">
                    {locale === "pl" ? "Ścieżka e-mail \u00b7 Krok 1/3" : "Email path \u00b7 Step 1/3"}
                  </p>
                  <h2 className="font-display text-frost text-xl sm:text-2xl font-bold">
                    {locale === "pl" ? "Ustaw hasło i adres e-mail" : "Set your email and password"}
                  </h2>
                </div>

                <FieldShell
                  id="email"
                  label={t("email")}
                  required
                  error={
                    errors.email?.message === "email-already-in-use"
                      ? tErr("emailAlreadyInUse")
                      : errors.email
                      ? tErr("emailInvalid")
                      : undefined
                  }
                >
                  <TextInput
                    id="email"
                    type="email"
                    autoComplete="email"
                    {...register("email")}
                  />
                </FieldShell>

                <FieldShell
                  id="password"
                  label={t("password")}
                  hint={t("passwordHint")}
                  required
                  error={
                    errors.password?.message === "password-no-digit"
                      ? tErr("passwordNoNumber")
                      : errors.password?.message === "weak-password"
                      ? tErr("weakPassword")
                      : errors.password
                      ? tErr("passwordTooShort")
                      : undefined
                  }
                >
                  <TextInput
                    id="password"
                    type="password"
                    autoComplete="new-password"
                    {...register("password")}
                  />
                </FieldShell>

                <div className="grid gap-2 mt-2">
                  <Checkbox
                    id="tos"
                    {...register("hasAcceptedTos")}
                    label={tCommon.rich("consentToS", {
                      termsLink: (chunks) => (
                        <a className="text-ember underline font-sans" href={`${prefix}/legal/terms`} target="_blank" rel="noreferrer">
                          {chunks}
                        </a>
                      ),
                      privacyLink: (chunks) => (
                        <a className="text-ember underline font-sans" href={`${prefix}/legal/privacy`} target="_blank" rel="noreferrer">
                          {chunks}
                        </a>
                      ),
                    })}
                  />
                  {errors.hasAcceptedTos && (
                    <p role="alert" className="font-sans text-[10px] font-semibold uppercase tracking-[var(--tracking-label)] text-magma">
                      {tErr("tosRequired")}
                    </p>
                  )}
                </div>

                {serverError && (
                  <p role="alert" className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-sans text-sm text-frost">
                    {serverError}
                  </p>
                )}

                <div className="flex gap-3 mt-4 pt-4 border-t border-frost/5">
                  <button
                    type="button"
                    onClick={handleBack}
                    className="flex-1 inline-flex items-center justify-center rounded-xl border border-frost/25 text-frost font-sans font-semibold text-sm px-6 py-3 hover:bg-frost/5 transition cursor-pointer"
                  >
                    {tCommon("back")}
                  </button>
                  <button
                    type="button"
                    id="next-step-btn"
                    onClick={handleNext}
                    disabled={checkingEmail}
                    className="flex-[2] inline-flex items-center justify-center rounded-xl bg-ember text-obsidian font-sans font-bold uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[0_4px_12px_rgba(252,174,47,0.3)] hover:brightness-115 hover:shadow-[0_6px_16px_rgba(252,174,47,0.5)] hover:-translate-y-0.5 transition-all duration-300 cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed"
                  >
                    {checkingEmail ? (locale === "pl" ? "Sprawdzam..." : "Checking...") : tCommon("continue")}
                  </button>
                </div>
              </motion.div>
            )}

            {step === 4 && (
              <motion.div
                key="step4"
                custom={direction}
                variants={slideVariants}
                initial="enter"
                animate="center"
                exit="exit"
                className="grid gap-4 w-full"
              >
                <div className="text-center mb-2">
                  <p className="text-xs font-bold uppercase text-ember tracking-[var(--tracking-overline)] mb-2">
                    {locale === "pl" ? "Ścieżka e-mail \u00b7 Krok 2/3" : "Email path \u00b7 Step 2/3"}
                  </p>
                  <h2 className="font-display text-frost text-xl sm:text-2xl font-bold">
                    {locale === "pl" ? "Przedstaw się" : "Tell us about yourself"}
                  </h2>
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <FieldShell id="firstName" label={t("firstName")} required error={errors.firstName && tErr("firstNameRequired")}>
                    <TextInput id="firstName" autoComplete="given-name" {...register("firstName")} />
                  </FieldShell>
                  <FieldShell id="lastName" label={t("lastName")} required error={errors.lastName && tErr("lastNameRequired")}>
                    <TextInput id="lastName" autoComplete="family-name" {...register("lastName")} />
                  </FieldShell>
                </div>

                <FieldShell
                  id="phoneNumber"
                  label={t("phoneNumber")}
                  hint={t("phoneNumberHint")}
                  required
                  error={
                    errors.phoneNumber?.message === "phone-required"
                      ? tErr("phoneRequired")
                      : errors.phoneNumber
                      ? tErr("phoneInvalid")
                      : undefined
                  }
                >
                  <Controller
                    control={control}
                    name="phoneNumber"
                    render={({ field }) => (
                      <PhoneInput
                        id="phoneNumber"
                        value={field.value ?? ""}
                        onChange={field.onChange}
                        error={!!errors.phoneNumber}
                        defaultDialCode={locale === "pl" ? "+48" : "+44"}
                        placeholder={t("phoneNumberPlaceholder")}
                      />
                    )}
                  />
                </FieldShell>

                {serverError && (
                  <p role="alert" className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-sans text-sm text-frost">
                    {serverError}
                  </p>
                )}

                <div className="flex gap-3 mt-4 pt-4 border-t border-frost/5">
                  <button
                    type="button"
                    onClick={handleBack}
                    className="flex-1 inline-flex items-center justify-center rounded-xl border border-frost/25 text-frost font-sans font-semibold text-sm px-6 py-3 hover:bg-frost/5 transition cursor-pointer"
                  >
                    {tCommon("back")}
                  </button>
                  <button
                    type="button"
                    id="next-step-btn"
                    onClick={handleNext}
                    className="flex-[2] inline-flex items-center justify-center rounded-xl bg-ember text-obsidian font-sans font-bold uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[0_4px_12px_rgba(252,174,47,0.3)] hover:brightness-115 hover:shadow-[0_6px_16px_rgba(252,174,47,0.5)] hover:-translate-y-0.5 transition-all duration-300 cursor-pointer"
                  >
                    {tCommon("continue")}
                  </button>
                </div>
              </motion.div>
            )}

            {step === 5 && (
              <motion.div
                key="step5"
                custom={direction}
                variants={slideVariants}
                initial="enter"
                animate="center"
                exit="exit"
                className="grid gap-4 w-full"
              >
                <div className="text-center mb-2">
                  <p className="text-xs font-bold uppercase text-ember tracking-[var(--tracking-overline)] mb-2">
                    {locale === "pl" ? "Ścieżka e-mail \u00b7 Krok 3/3" : "Email path \u00b7 Step 3/3"}
                  </p>
                  <h2 className="font-display text-frost text-xl sm:text-2xl font-bold">
                    {locale === "pl" ? "Specjalizacja i preferencje" : "Specialization and preferences"}
                  </h2>
                </div>



                <FieldShell id="uiLanguage" label={t("uiLanguage")} required>
                  <RadioGroup
                    name="uiLanguage"
                    value={uiLanguage}
                    onChange={(v) => setValue("uiLanguage", v as "pl" | "en", { shouldValidate: true })}
                    options={[
                      { value: "pl", label: `🇵🇱 ${t("polish")}` },
                      { value: "en", label: `🇬🇧 ${t("english")}` },
                    ]}
                  />
                </FieldShell>

                <FieldShell id="professionalTitle" label={t("professionalTitle")}>
                  <TextInput
                    id="professionalTitle"
                    placeholder={t("professionalTitlePlaceholder")}
                    {...register("professionalTitle")}
                  />
                </FieldShell>

                <div className="grid gap-2 mt-2">
                  <Checkbox
                    id="marketing"
                    {...register("hasMarketingConsent")}
                    label={tCommon("consentMarketing")}
                  />
                </div>

                {serverError && (
                  <p role="alert" className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-sans text-sm text-frost">
                    {serverError}
                  </p>
                )}

                <div className="flex gap-3 mt-4 pt-4 border-t border-frost/5">
                  <button
                    type="button"
                    onClick={handleBack}
                    disabled={isSubmitting}
                    className="flex-1 inline-flex items-center justify-center rounded-xl border border-frost/25 text-frost font-sans font-semibold text-sm px-6 py-3 hover:bg-frost/5 transition disabled:opacity-60 cursor-pointer"
                  >
                    {tCommon("back")}
                  </button>
                  <button
                    type="submit"
                    disabled={isSubmitting}
                    className="flex-[2] inline-flex items-center justify-center rounded-xl bg-ember text-obsidian font-sans font-bold uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[0_4px_12px_rgba(252,174,47,0.3)] hover:brightness-115 hover:shadow-[0_6px_16px_rgba(252,174,47,0.5)] hover:-translate-y-0.5 transition-all duration-300 disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer"
                  >
                    {isSubmitting ? tCommon("submitting") : tCommon("submit")}
                  </button>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
        </form>

        <p className="font-sans text-sm text-mist/60 text-center mt-6 pt-4 border-t border-frost/5">
          {tCommon("alreadyHaveAccount")}{" "}
          <a href={`${prefix}/login`} className="text-ember font-semibold hover:underline">
            {tCommon("loginCta")}
          </a>
        </p>
      </div>

      {/* Right Column: Photo & Testimonial outside card container */}
      <div className="col-span-12 lg:col-span-3 w-full lg:items-end lg:justify-self-end">
        <AnimatePresence>
          {step === 1 && (
            <motion.div
              key="right-column-marketing"
              initial={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
              exit={{
                opacity: 0,
                scale: 0.95,
                filter: "blur(12px)",
                transition: { duration: 0.6, ease: "easeInOut" }
              }}
              className="flex flex-col gap-5 w-full lg:items-end lg:justify-self-end"
            >
              {/* Photo */}
              <div className="relative aspect-[4/3] md:aspect-[1.15] w-full max-w-[360px] overflow-hidden rounded-tl-[80px] rounded-br-[20px] rounded-tr-[20px] rounded-bl-[20px] border border-frost/10 shadow-[0_8px_24px_rgba(0,0,0,0.3)]">
                <img
                  src="/assets/therapy-banana.webp"
                  alt="Therapist working"
                  className="object-cover w-full h-full brightness-90 contrast-[1.05]"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-obsidian/40 to-transparent" />
              </div>

              {/* Testimonial Card */}
              <div className="bg-frost/[0.03] border border-frost/10 p-5 rounded-[20px] flex flex-col gap-3.5 shadow-md w-full max-w-[360px]">
                {/* Stars */}
                <div className="flex gap-1">
                  {[1, 2, 3, 4, 5].map((s) => (
                    <svg key={s} className="w-4 h-4 text-ember fill-ember" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  ))}
                </div>

                <p className="font-sans text-xs sm:text-[13px] text-frost/90 italic leading-relaxed before:content-['„'] after:content-['”']">
                  {locale === "pl"
                    ? "Pozwala uniknąć utraty od 30 do 40% informacji, które tracę przy ręcznym przygotowywaniu notatek."
                    : "It prevents losing 30 to 40% of information that is normally lost when writing notes by hand."}
                </p>

                <div className="flex items-center gap-3 pt-3 border-t border-frost/5">
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#0e3b33] to-[#165c50] flex items-center justify-center font-sans font-bold text-xs text-[#5bf4bc] shadow-inner select-none shrink-0">
                    A
                  </div>
                  <div className="flex flex-col text-left overflow-hidden">
                    <span className="font-sans font-bold text-xs text-white">Agnieszka</span>
                    <span className="font-sans text-[10px] text-[#5bf4bc] font-semibold">
                      {locale === "pl" ? "psychoterapeutka CBT" : "CBT psychotherapist"}
                    </span>
                  </div>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
