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
import { useForm } from "react-hook-form";
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
} from "@/components/forms/Field";
import {
  getModalityCatalog,
  type ModalityRow,
} from "@/lib/clinical/modalities";

export function TherapistFinishForm({
  email,
  firstName,
  lastName,
}: {
  email: string;
  firstName: string;
  lastName: string;
}) {
  // See TherapistEmailForm for the rationale on client-side modality
  // fetch (mirror the same pattern).
  const [modalities, setModalities] = useState<ReadonlyArray<ModalityRow>>([]);
  useEffect(() => {
    let cancelled = false;
    getModalityCatalog()
      .then((rows) => {
        if (!cancelled) setModalities(rows);
      })
      .catch((err) => {
        console.error("[register/therapist/finish] modality fetch failed", err);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const t = useTranslations("register.fields");
  const tCommon = useTranslations("register.common");
  const tErr = useTranslations("register.errors");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";

  const {
    register,
    handleSubmit,
    watch,
    setValue,
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
      await identityClient.createUser(
        create(CreateUserRequestSchema, {
          firebaseUid: user.uid,
          email,
          role: UserRole.THERAPIST,
          firstName: data.firstName,
          lastName: data.lastName,
          uiLanguage: data.uiLanguage,
          timezone: tz,
          hasAcceptedTos: true,
        }),
      );

      const extras =
        !!data.phoneNumber ||
        !!data.professionalTitle ||
        !!data.modalityId ||
        data.hasMarketingConsent === true;
      if (extras) {
        await identityClient.updateProfile(
          create(UpdateProfileRequestSchema, {
            userId: "", // server resolves from token if blank
            firstName: data.firstName,
            lastName: data.lastName,
            professionalTitle: data.professionalTitle ?? "",
            phoneNumber: data.phoneNumber ?? "",
            defaultModalityId: data.modalityId,
            hasMarketingConsent: data.hasMarketingConsent ?? false,
          }),
        );
      }

      // Google sign-in marks emailVerified=true automatically (Google
      // already vetted the address). Skip the "check your inbox" page
      // and bounce straight to the app.
      window.location.href = "https://app.superwizor.ai/login";
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

        <FieldShell id="modality" label={t("defaultModality")} required error={errors.modalityId && tErr("modalityRequired")}>
          <Select id="modality" {...register("modalityId")} defaultValue="">
            <option value="" disabled>—</option>
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

        <FieldShell id="professionalTitle" label={t("professionalTitle")}>
          <TextInput
            id="professionalTitle"
            placeholder={t("professionalTitlePlaceholder")}
            {...register("professionalTitle")}
          />
        </FieldShell>

        <FieldShell id="phoneNumber" label={t("phoneNumber")}>
          <TextInput
            id="phoneNumber"
            type="tel"
            inputMode="tel"
            autoComplete="tel"
            placeholder={t("phoneNumberPlaceholder")}
            {...register("phoneNumber")}
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

      <button
        type="submit"
        disabled={isSubmitting}
        className="mt-2 inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-60 disabled:cursor-not-allowed"
      >
        {isSubmitting ? tCommon("submitting") : tCommon("submit")}
      </button>
    </form>
  );
}
