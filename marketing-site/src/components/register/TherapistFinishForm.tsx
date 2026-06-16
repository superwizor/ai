// Therapist "finish profile" form — the post-social-OAuth half of
// docs/18 §8.1's therapist registration flow.
//
// Pre-conditions: the user has signed in via Google (or future Apple/
// Microsoft) and identityClient.getUserByFirebaseUID returned NotFound.
// The pre-filled email + names come from the social provider via
// SocialButtons' redirect query (?email=&firstName=&lastName=).
//
// Submit calls identityClient.createUser({role=THERAPIST, ...}) using
// the still-signed-in Firebase user. Optional profile fields go to
// updateProfile in a follow-up call. Lands on /verify-email so the
// user can confirm the email Firebase already pinged.

"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";

import {
  therapistFinishSchema,
  type TherapistFinishForm,
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
  PhoneInput,
} from "@/components/forms/Field";

import { handlePostRegistrationRedirect } from "@/lib/register/post-registration";

export function TherapistFinishForm({
  email,
  firstName,
  lastName,
}: {
  email: string;
  firstName: string;
  lastName: string;
}) {


  const t = useTranslations("register.fields");
  const tCommon = useTranslations("register.common");
  const tErr = useTranslations("register.errors");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";
  const searchParams = useSearchParams();
  const planSlug = searchParams.get("plan");

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    control,
    formState: { errors, isSubmitting },
  } = useForm<TherapistFinishForm>({
    resolver: zodResolver(therapistFinishSchema),
    defaultValues: {
      firstName,
      lastName,
      uiLanguage: locale === "en" ? "en" : "pl",
      hasMarketingConsent: false,
    },
  });

  const [serverError, setServerError] = useState<string | null>(null);

  const onSubmit = handleSubmit(async (data) => {
    setServerError(null);
    const user = auth.user;
    if (!user) {
      // The OAuth popup result lives in Firebase's local persistence,
      // so the auth-provider should have hydrated by now. If not,
      // ask the user to retry from the previous page.
      setServerError(tErr("unknown"));
      return;
    }
    try {
      const tz =
        Intl.DateTimeFormat().resolvedOptions().timeZone || "Europe/Warsaw";
      const created = await identityClient.createUser(
        create(CreateUserRequestSchema, {
          firebaseUid: user.uid,
          email,
          role: UserRole.THERAPIST,
          firstName: data.firstName,
          lastName: data.lastName,
          uiLanguage: data.uiLanguage,
          timezone: tz,
          hasAcceptedTos: true,
          initialPlanTier: planSlug?.toUpperCase() === "BETA" ? "BETA" : "",
        }),
      );

      const extras =
        !!data.phoneNumber ||
        !!data.professionalTitle ||
        data.hasMarketingConsent === true;
      if (extras) {
        await identityClient.updateProfile(
          create(UpdateProfileRequestSchema, {
            userId: "", // server resolves from token if blank
            firstName: data.firstName,
            lastName: data.lastName,
            professionalTitle: data.professionalTitle ?? "",
            phoneNumber: data.phoneNumber ?? "",
            hasMarketingConsent: data.hasMarketingConsent ?? false,
          }),
        );
      }

      // For social sign-in with a paid plan → Stripe Checkout.
      // For free plans or no plan → straight to the app (Google sign-in
      // marks emailVerified=true so no verify-email interstitial needed).
      const orgId = created.organizationId ?? "";
      const priceNeeded = planSlug && !['trial', 'beta'].includes(planSlug.toLowerCase());
      if (priceNeeded && orgId) {
        await handlePostRegistrationRedirect(
          orgId,
          planSlug,
          prefix,
          email,
          data.phoneNumber ?? undefined,
          `${data.firstName || ""} ${data.lastName || ""}`.trim() || undefined,
        );
      } else {
        // Google/Apple sign-in → email already verified → go to onboarding
        window.location.replace(prefix ? `${prefix}/onboarding/` : "/onboarding/");
      }
    } catch {
      setServerError(tErr("unknown"));
    }
  });

  const uiLanguage = watch("uiLanguage");

  return (
    <form onSubmit={onSubmit} className="grid gap-5" noValidate>
      <div className="grid gap-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <FieldShell id="firstName" label={t("firstName")} required error={errors.firstName && tErr("firstNameRequired")}>
            <TextInput id="firstName" autoComplete="given-name" {...register("firstName")} />
          </FieldShell>
          <FieldShell id="lastName" label={t("lastName")} required error={errors.lastName && tErr("lastNameRequired")}>
            <TextInput id="lastName" autoComplete="family-name" {...register("lastName")} />
          </FieldShell>
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

        <FieldShell
          id="phoneNumber"
          label={t("phoneNumber")}
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
      </div>

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
          <p role="alert" className="font-sans text-[10px] font-semibold uppercase tracking-[var(--tracking-label)] text-magma">
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
          className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-sans text-sm text-frost"
        >
          {serverError}
        </p>
      )}

      <button
        type="submit"
        disabled={isSubmitting}
        className="mt-2 w-full flex items-center justify-center gap-3 py-4 px-6 rounded-xl bg-ember text-obsidian shadow-[0_4px_14px_rgba(252,174,47,0.4)] hover:brightness-115 hover:shadow-[0_6px_20px_rgba(252,174,47,0.6)] hover:-translate-y-0.5 transition-all duration-300 group cursor-pointer font-sans text-[18px] font-semibold text-obsidian disabled:opacity-60 disabled:cursor-not-allowed disabled:transform-none disabled:shadow-none"
      >
        {isSubmitting ? tCommon("submitting") : tCommon("submit")}
      </button>
    </form>
  );
}
