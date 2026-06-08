// Therapist registration form (email/password path) per docs/18 §13.2.
//
// Flow:
//   1. zod-validated client side (immediate error feedback).
//   2. Firebase createUserWithEmailAndPassword → sendEmailVerification.
//   3. identityClient.createUser(role=THERAPIST) — passes Firebase UID +
//      ID token (auth-provider's setTokenProvider already wired the
//      bearer interceptor in feature 4).
//   4. Navigate to /register/therapist/verify-email — feature 5
//      (email-verification-gate) gates further app entry on the
//      verification click coming back.
//
// Failure modes:
//   - email-already-in-use → inline error with a Log-in link
//   - weak-password / Firebase error → inline error
//   - identity-svc Connect error → toast + keep user on form (Firebase
//     account already exists at this point — feature 8 e2e covers the
//     "stale Firebase user" reconciliation path).

"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { FirebaseError } from "firebase/app";
import { motion, AnimatePresence } from "framer-motion";

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
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import {
  Checkbox,
  FieldShell,
  RadioGroup,
  Select,
  TextInput,
} from "@/components/forms/Field";
import {
  getModalityCatalog,
  type ModalityRow,
} from "@/lib/clinical/modalities";
import { handlePostRegistrationRedirect } from "@/lib/register/post-registration";

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
  // Modality catalogue is fetched live on mount via
  // clinical-svc.ListModalities (allowlisted as anonymous on the
  // backend interceptor). Initial value [] keeps the Select rendering
  // a single disabled placeholder option until the RPC returns —
  // typical staging round-trip is <200ms so no spinner is shown.
  const [modalities, setModalities] = useState<ReadonlyArray<ModalityRow>>([]);
  useEffect(() => {
    let cancelled = false;
    getModalityCatalog()
      .then((rows) => {
        if (!cancelled) setModalities(rows);
      })
      .catch((err) => {
        // Don't block the form — log so devtools shows the failure,
        // user can still submit other fields. modalityId is required
        // by zod, so the empty dropdown will surface a normal
        // validation error rather than a silent submit.
        console.error("[register/therapist] modality fetch failed", err);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const t = useTranslations("register.fields");
  const tCommon = useTranslations("register.common");
  const tErr = useTranslations("register.errors");
  const tTher = useTranslations("register.therapist");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";
  const searchParams = useSearchParams();
  const planSlug = searchParams.get("plan");

  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [direction, setDirection] = useState<1 | -1>(1);
  const [serverError, setServerError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    trigger,
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
      const isValid = await trigger(["firstName", "lastName", "email"]);
      if (isValid) {
        setDirection(1);
        setStep(2);
      }
    } else if (step === 2) {
      const isValid = await trigger(["password", "hasAcceptedTos"]);
      if (isValid) {
        setDirection(1);
        setStep(3);
      }
    }
  };

  const handleBack = () => {
    setServerError(null);
    if (step > 1) {
      setDirection(-1);
      setStep((s) => (s - 1) as 1 | 2 | 3);
    }
  };

  const onSubmit = handleSubmit(async (data) => {
    if (step < 3) {
      await handleNext();
      return;
    }

    setServerError(null);
    try {
      // 1. Firebase account + verification email.
      const user = await auth.signUpWithEmail(data.email, data.password);

      // 2. CreateUser on identity-svc. ui_language is the user-chosen
      // locale (defaults to active page locale). Timezone is best-effort
      // from the browser; backend falls back to Europe/Warsaw if blank.
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
        // Beta signups get BETA plan provisioning instead of TRIAL.
        initialPlanTier: planSlug?.toUpperCase() === "BETA" ? "BETA" : "",
      });
      const created = await identityClient.createUser(createReq);

      // 3. Optional profile-only fields (modality, title, credentials,
      // phone, marketing consent) — UpdateProfile call only if at least
      // one is set. Skips the round-trip when nothing extra to write.
      const hasExtras =
        !!data.professionalTitle ||
        !!data.credentialsNumber ||
        !!data.phoneNumber ||
        !!data.modalityId ||
        data.hasMarketingConsent === true;
      if (hasExtras) {
        const updateReq = create(UpdateProfileRequestSchema, {
          userId: created.id,
          firstName: data.firstName,
          lastName: data.lastName,
          professionalTitle: data.professionalTitle ?? "",
          credentialsNumber: data.credentialsNumber ?? "",
          phoneNumber: data.phoneNumber ?? "",
          // UUID straight from clinical-svc.ListModalities — identity-svc
          // stores this as users.default_modality_id (FK into modalities).
          defaultModalityId: data.modalityId,
          hasMarketingConsent: data.hasMarketingConsent ?? false,
        });
        await identityClient.updateProfile(updateReq);
      }

      // 4. Redirect based on plan selection.
      // Trial/beta → verify email. Paid plans → Stripe Checkout.
      await handlePostRegistrationRedirect(
        created.organizationId ?? "",
        planSlug,
        prefix,
        data.email,
      );
    } catch (e) {
      if (e instanceof FirebaseError) {
        if (e.code === "auth/email-already-in-use") {
          setServerError(tErr("emailAlreadyInUse"));
          setDirection(-1);
          setStep(1);
          return;
        }
        if (e.code === "auth/weak-password") {
          setServerError(tErr("weakPassword"));
          setDirection(-1);
          setStep(2);
          return;
        }
        // Firebase Auth emulator unreachable, or live API unreachable
        // (offline, DNS, blocked egress). Surface a network-flavoured
        // message so the user knows to retry / check connectivity
        // rather than the generic "unknown" catch-all that previously
        // hid this case.
        if (
          e.code === "auth/network-request-failed" ||
          e.code === "auth/internal-error"
        ) {
          setServerError(tErr("networkError"));
          return;
        }
      }
      // Plain TypeError("Failed to fetch") from a downed identity-svc
      // (after Firebase succeeded). Same UX as the Firebase network
      // error path — distinguishing the two doesn't help the user.
      if (
        e instanceof TypeError &&
        /failed to fetch|network/i.test(e.message)
      ) {
        setServerError(tErr("networkError"));
        return;
      }
      // Log the full error so devs hitting an unmapped case can
      // diagnose it from devtools; the user still sees the generic
      // fallback so nothing internal leaks.
      console.error("[register/therapist] unmapped signup error", e);
      setServerError(tErr("unknown"));
    }
  });

  const uiLanguage = watch("uiLanguage");

  return (
    <form onSubmit={onSubmit} className="grid gap-5" noValidate>
      {/* Progress Indicator */}
      <div className="flex items-center justify-center gap-2 mb-2">
        {[1, 2, 3].map((n) => (
          <div
            key={n}
            className={`h-1 rounded-full transition-all duration-300 ${
              n === step
                ? "w-8 bg-ember shadow-[0_0_8px_rgba(245,166,35,0.4)]"
                : n < step
                ? "w-2 bg-ember/50"
                : "w-2 bg-frost/10 border border-frost/10"
            }`}
          />
        ))}
      </div>

      <div className="relative overflow-hidden min-h-[350px]">
        <AnimatePresence mode="wait" initial={false} custom={direction}>
          {step === 1 && (
            <motion.div
              key="step1"
              custom={direction}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              className="grid gap-4 w-full"
            >
              <h2 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-1">
                {tTher("sectionAccount")} — {tTher("step")} 1/3
              </h2>

              <div className="grid gap-4 sm:grid-cols-2">
                <FieldShell id="firstName" label={t("firstName")} required error={errors.firstName && tErr("firstNameRequired")}>
                  <TextInput id="firstName" autoComplete="given-name" {...register("firstName")} />
                </FieldShell>
                <FieldShell id="lastName" label={t("lastName")} required error={errors.lastName && tErr("lastNameRequired")}>
                  <TextInput id="lastName" autoComplete="family-name" {...register("lastName")} />
                </FieldShell>
              </div>

              <FieldShell id="email" label={t("email")} required error={errors.email && tErr("emailInvalid")}>
                <TextInput
                  id="email"
                  type="email"
                  autoComplete="email"
                  {...register("email")}
                />
              </FieldShell>

              {serverError && (
                <p
                  role="alert"
                  className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-sm text-frost"
                >
                  {serverError}
                </p>
              )}

              <button
                id="next-step-btn"
                type="button"
                onClick={handleNext}
                className="mt-2 inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition cursor-pointer"
              >
                {tCommon("continue")}
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
              className="grid gap-4 w-full"
            >
              <h2 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-1">
                {tTher("sectionAccount")} — {tTher("step")} 2/3
              </h2>

              <FieldShell
                id="password"
                label={t("password")}
                hint={t("passwordHint")}
                required
                error={
                  errors.password?.message === "password-no-digit"
                    ? tErr("passwordNoNumber")
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

              <section className="grid gap-3 mt-2">
                <Checkbox
                  id="tos"
                  {...register("hasAcceptedTos")}
                  label={tCommon.rich("consentToS", {
                    termsLink: (chunks) => (
                      <a className="text-ember underline" href={`${prefix}/legal/terms`} target="_blank" rel="noreferrer">
                        {chunks}
                      </a>
                    ),
                    privacyLink: (chunks) => (
                      <a className="text-ember underline" href={`${prefix}/legal/privacy`} target="_blank" rel="noreferrer">
                        {chunks}
                      </a>
                    ),
                  })}
                />
                {errors.hasAcceptedTos && (
                  <p role="alert" className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-magma">
                    {tErr("tosRequired")}
                  </p>
                )}

                <Checkbox
                  id="marketing"
                  {...register("hasMarketingConsent")}
                  label={tCommon("consentMarketing")}
                />
              </section>

              {serverError && (
                <p
                  role="alert"
                  className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-sm text-frost"
                >
                  {serverError}
                </p>
              )}

              <div className="flex gap-3 mt-2">
                <button
                  type="button"
                  onClick={handleBack}
                  className="flex-1 inline-flex items-center justify-center rounded-button border border-frost/25 text-frost font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 hover:bg-frost/5 transition cursor-pointer"
                >
                  {tCommon("back")}
                </button>
                <button
                  id="next-step-btn"
                  type="button"
                  onClick={handleNext}
                  className="flex-[2] inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition cursor-pointer"
                >
                  {tCommon("continue")}
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
              <h2 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-1">
                {tTher("sectionProfile")} — {tTher("step")} 3/3
              </h2>

              <FieldShell id="modality" label={t("defaultModality")} required error={errors.modalityId && tErr("modalityRequired")}>
                <Select id="modality" {...register("modalityId")} defaultValue="">
                  <option value="" disabled>
                    —
                  </option>
                  {modalities.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.labels[locale === "en" ? "en" : "pl"]}
                    </option>
                  ))}
                </Select>
              </FieldShell>

              <FieldShell id="uiLanguage" label={t("uiLanguage")} required>
                <RadioGroup
                  name="uiLanguage"
                  value={uiLanguage}
                  onChange={(v) => setValue("uiLanguage", v as "pl" | "en", { shouldValidate: true })}
                  options={[
                    { value: "pl", label: t("polish") },
                    { value: "en", label: t("english") },
                  ]}
                />
              </FieldShell>

              <div className="grid gap-4 sm:grid-cols-2">
                <FieldShell id="professionalTitle" label={t("professionalTitle")}>
                  <TextInput
                    id="professionalTitle"
                    placeholder={t("professionalTitlePlaceholder")}
                    {...register("professionalTitle")}
                  />
                </FieldShell>
                <FieldShell id="credentialsNumber" label={t("credentialsNumber")}>
                  <TextInput id="credentialsNumber" {...register("credentialsNumber")} />
                </FieldShell>
              </div>

              <FieldShell
                id="phoneNumber"
                label={t("phoneNumber")}
                error={errors.phoneNumber && tErr("phoneInvalid")}
              >
                <TextInput
                  id="phoneNumber"
                  type="tel"
                  inputMode="tel"
                  autoComplete="tel"
                  placeholder={t("phoneNumberPlaceholder")}
                  {...register("phoneNumber")}
                />
              </FieldShell>

              {serverError && (
                <p
                  role="alert"
                  className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-sm text-frost"
                >
                  {serverError}
                </p>
              )}

              <div className="flex gap-3 mt-2">
                <button
                  type="button"
                  onClick={handleBack}
                  disabled={isSubmitting}
                  className="flex-1 inline-flex items-center justify-center rounded-button border border-frost/25 text-frost font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 hover:bg-frost/5 transition disabled:opacity-60 cursor-pointer"
                >
                  {tCommon("back")}
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="flex-[2] inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer"
                >
                  {isSubmitting ? tCommon("submitting") : tCommon("submit")}
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <p className="font-serif text-sm text-mist text-center mt-4">
        {tCommon("alreadyHaveAccount")}{" "}
        <a
          href={`${prefix}/login`}
          className="text-ember underline"
        >
          {tCommon("loginCta")}
        </a>
      </p>
    </form>
  );
}
