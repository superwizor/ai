// Organisation registration form (email/password path) per
// docs/18 §13.3.
//
// One submit packs founder + organisation + headquarters address into
// a single RegisterOrganization request — the backend opens one
// transaction and writes all three rows atomically (commit 0a25ac7
// reference from the design doc).
//
// Founder lands as role=ORG_ADMIN with no THERAPIST row. The "invite
// myself as therapist" pattern from docs/18 §6.3 is a Slice 5 task
// once the Flutter Web org-admin console ships.

"use client";

import { useId, useState } from "react";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { FirebaseError } from "firebase/app";

import {
  organizationEmailSchema,
  type OrganizationEmailForm,
} from "@/lib/register/schema";
import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient } from "@/lib/connect/clients";
import {
  OrganizationType,
  RegisterOrganizationRequestSchema,
  AddressSchema,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import {
  Checkbox,
  FieldShell,
  Select,
  TextInput,
  PhoneInput,
} from "@/components/forms/Field";

export function OrganizationEmailForm() {
  const t = useTranslations("register.fields");
  const tOrg = useTranslations("register.orgFields");
  const tOrgErr = useTranslations("register.orgErrors");
  const tCommon = useTranslations("register.common");
  const tErr = useTranslations("register.errors");
  const tBody = useTranslations("register.organization");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";

  // Stable random idempotency-key for this browser tab's submit. A
  // double-submit (e.g. user double-clicks) hands the same key to the
  // backend; it returns the existing org instead of creating a second
  // one. See RegisterOrganizationRequest field 15.
  const idempotencyKey = useId();

  const {
    register,
    handleSubmit,
    control,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<OrganizationEmailForm>({
    resolver: zodResolver(organizationEmailSchema),
    defaultValues: {
      uiLanguage: locale === "en" ? "en" : "pl",
      orgType: "CLINIC",
      countryCode: "PL",
      hasMarketingConsent: false,
    },
  });

  const [serverError, setServerError] = useState<string | null>(null);

  const onSubmit = handleSubmit(async (data) => {
    setServerError(null);
    try {
      const continueUrl = `${window.location.origin}${prefix}/register/therapist/verify-email?email=${encodeURIComponent(data.email)}`;
      const user = await auth.signUpWithEmail(data.email, data.password, continueUrl);

      const tz =
        Intl.DateTimeFormat().resolvedOptions().timeZone || "Europe/Warsaw";
      const address = create(AddressSchema, {
        countryCode: data.countryCode,
        region: data.region ?? "",
        city: data.city,
        postalCode: data.postalCode,
        streetLine: data.streetLine,
        buildingNumber: data.buildingNumber,
        unitNumber: data.unitNumber ?? "",
        directions: data.directions ?? "",
      });
      const orgTypeMap = {
        SOLO: OrganizationType.SOLO,
        CLINIC: OrganizationType.CLINIC,
        ENTERPRISE: OrganizationType.ENTERPRISE,
      } as const;
      const req = create(RegisterOrganizationRequestSchema, {
        firebaseUid: user.uid,
        email: data.email,
        firstName: data.firstName,
        lastName: data.lastName,
        phoneNumber: data.phoneNumber,
        uiLanguage: data.uiLanguage,
        timezone: tz,
        hasAcceptedTos: true,
        hasMarketingConsent: data.hasMarketingConsent ?? false,
        legalName: data.legalName,
        type: orgTypeMap[data.orgType],
        taxId: data.taxId,
        vatIdEu: data.vatIdEu ?? "",
        headquartersAddress: address,
        idempotencyKey,
      });
      await identityClient.registerOrganization(req);

      // eslint-disable-next-line react-hooks/immutability
      window.location.href = `${prefix}/register/therapist/verify-email?email=${encodeURIComponent(data.email)}`;
    } catch (e) {
      if (e instanceof FirebaseError) {
        if (e.code === "auth/email-already-in-use") {
          setError("email", {
            type: "manual",
            message: "email-already-in-use",
          });
          setServerError(tErr("emailAlreadyInUse"));
          return;
        }
        if (e.code === "auth/weak-password") {
          setError("password", {
            type: "manual",
            message: "weak-password",
          });
          setServerError(tErr("weakPassword"));
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
      console.error("[register/organization] unmapped signup error", e);
      setServerError(tErr("unknown"));
    }
  });

  return (
    <form onSubmit={onSubmit} className="grid gap-5" noValidate>
      {/* Founder section --------------------------------------------- */}
      <section>
        <h2 className="font-sans text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-4">
          {tBody("sectionFounder")}
        </h2>
        <div className="grid gap-4">
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
            <TextInput id="email" type="email" autoComplete="email" {...register("email")} />
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
            <TextInput id="password" type="password" autoComplete="new-password" {...register("password")} />
          </FieldShell>
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
            // The zod schema (requiredPhone) emits "phone-required"
            // for empty and "phone-invalid" for a malformed value; we
            // localize each separately so the user knows whether to
            // fill the field or just fix its format.
            error={
              errors.phoneNumber &&
              (errors.phoneNumber.message === "phone-invalid"
                ? tErr("phoneInvalid")
                : tOrgErr("phoneRequired"))
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
      </section>

      {/* Organisation section ---------------------------------------- */}
      <section>
        <h2 className="font-sans text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-4">
          {tBody("sectionOrg")}
        </h2>
        <div className="grid gap-4">
          <FieldShell id="legalName" label={tOrg("legalName")} required error={errors.legalName && tOrgErr("legalNameRequired")}>
            <TextInput id="legalName" placeholder={tOrg("legalNamePlaceholder")} {...register("legalName")} />
          </FieldShell>
          <FieldShell id="orgType" label={tOrg("orgType")} required>
            <Select id="orgType" {...register("orgType")}>
              <option value="CLINIC">{tOrg("orgTypeClinic")}</option>
              <option value="SOLO">{tOrg("orgTypeSolo")}</option>
              <option value="ENTERPRISE">{tOrg("orgTypeEnterprise")}</option>
            </Select>
          </FieldShell>
          <div className="grid gap-4 sm:grid-cols-2">
            <FieldShell id="taxId" label={tOrg("taxId")} required error={errors.taxId && tOrgErr("taxIdInvalid")}>
              <TextInput id="taxId" inputMode="numeric" placeholder={tOrg("taxIdPlaceholder")} {...register("taxId")} />
            </FieldShell>
            <FieldShell id="vatIdEu" label={tOrg("vatIdEu")}>
              <TextInput id="vatIdEu" placeholder={tOrg("vatIdEuPlaceholder")} {...register("vatIdEu")} />
            </FieldShell>
          </div>
        </div>
      </section>

      {/* Headquarters address section ------------------------------- */}
      <section>
        <h2 className="font-sans text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-4">
          {tBody("sectionAddress")}
        </h2>
        <div className="grid gap-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <FieldShell id="countryCode" label={tOrg("country")} required>
              {/* Single-option select for MVP — PL only. Future locales add entries. */}
              <Select id="countryCode" {...register("countryCode")} defaultValue="PL">
                <option value="PL">PL — Polska</option>
              </Select>
            </FieldShell>
            <FieldShell id="region" label={tOrg("region")}>
              <TextInput id="region" {...register("region")} />
            </FieldShell>
          </div>
          <div className="grid gap-4 sm:grid-cols-[1fr_140px]">
            <FieldShell id="city" label={tOrg("city")} required error={errors.city && tOrgErr("cityRequired")}>
              <TextInput id="city" autoComplete="address-level2" {...register("city")} />
            </FieldShell>
            <FieldShell
              id="postalCode"
              label={tOrg("postalCode")}
              required
              error={errors.postalCode && tOrgErr("postalCodeInvalid")}
            >
              <TextInput
                id="postalCode"
                inputMode="numeric"
                autoComplete="postal-code"
                placeholder={tOrg("postalCodePlaceholder")}
                {...register("postalCode")}
              />
            </FieldShell>
          </div>
          <div className="grid gap-4 sm:grid-cols-[2fr_120px_120px]">
            <FieldShell id="streetLine" label={tOrg("streetLine")} required error={errors.streetLine && tOrgErr("streetRequired")}>
              <TextInput id="streetLine" autoComplete="address-line1" {...register("streetLine")} />
            </FieldShell>
            <FieldShell id="buildingNumber" label={tOrg("buildingNumber")} required error={errors.buildingNumber && tOrgErr("buildingRequired")}>
              <TextInput id="buildingNumber" {...register("buildingNumber")} />
            </FieldShell>
            <FieldShell id="unitNumber" label={tOrg("unitNumber")}>
              <TextInput id="unitNumber" {...register("unitNumber")} />
            </FieldShell>
          </div>
          <FieldShell id="directions" label={tOrg("directions")}>
            <TextInput id="directions" {...register("directions")} />
          </FieldShell>
        </div>
      </section>

      {/* Consents ---------------------------------------------------- */}
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
          <p role="alert" className="font-sans text-[10px] uppercase tracking-[var(--tracking-label)] text-magma">
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
        className="mt-2 inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-sans uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-60 disabled:cursor-not-allowed"
      >
        {isSubmitting ? tCommon("submitting") : tCommon("submit")}
      </button>

      <p className="font-sans text-sm text-mist text-center">
        {tCommon("alreadyHaveAccount")}{" "}
        <a href={`${prefix}/login`} className="text-ember underline">
          {tCommon("loginCta")}
        </a>
      </p>
    </form>
  );
}
