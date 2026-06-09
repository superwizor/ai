// Organisation "finish profile" form — post-Google-OAuth half of
// docs/18 §13.3's clinic registration. Shares its schema/UX with
// OrganizationEmailForm but skips the password section (Google handled
// auth) and pre-fills founder names from the social profile.

"use client";

import { useId, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";

import {
  organizationFinishSchema,
  type OrganizationFinishForm,
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
} from "@/components/forms/Field";

export function OrganizationFinishForm({
  email,
  firstName,
  lastName,
}: {
  email: string;
  firstName: string;
  lastName: string;
}) {
  const t = useTranslations("register.fields");
  const tOrg = useTranslations("register.orgFields");
  const tOrgErr = useTranslations("register.orgErrors");
  const tCommon = useTranslations("register.common");
  const tErr = useTranslations("register.errors");
  const tBody = useTranslations("register.organization");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";
  const idempotencyKey = useId();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<OrganizationFinishForm>({
    resolver: zodResolver(organizationFinishSchema),
    defaultValues: {
      firstName,
      lastName,
      uiLanguage: locale === "en" ? "en" : "pl",
      orgType: "CLINIC",
      countryCode: "PL",
      hasMarketingConsent: false,
    },
  });

  const [serverError, setServerError] = useState<string | null>(null);

  const onSubmit = handleSubmit(async (data) => {
    setServerError(null);
    const user = auth.user;
    if (!user) {
      setServerError(tErr("unknown"));
      return;
    }
    try {
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
      await identityClient.registerOrganization(
        create(RegisterOrganizationRequestSchema, {
          firebaseUid: user.uid,
          email,
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
        }),
      );

      // Google already verified the email server-side — straight to the app.
      // app.superwizor.ai DNS not wired; web.app subdomain is the live host.
      // eslint-disable-next-line react-hooks/immutability
      window.location.href = "https://superwizor-app.web.app/";
    } catch {
      setServerError(tErr("unknown"));
    }
  });

  return (
    <form onSubmit={onSubmit} className="grid gap-5" noValidate>
      <section>
        <h2 className="font-sans text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-4">
          {tBody("sectionFounder")}
        </h2>
        <div className="grid gap-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <FieldShell id="firstName" label={t("firstName")} required error={errors.firstName && tErr("firstNameRequired")}>
              <TextInput id="firstName" autoComplete="given-name" {...register("firstName")} />
            </FieldShell>
            <FieldShell id="lastName" label={t("lastName")} required error={errors.lastName && tErr("lastNameRequired")}>
              <TextInput id="lastName" autoComplete="family-name" {...register("lastName")} />
            </FieldShell>
          </div>
          <FieldShell id="phoneNumber" label={t("phoneNumber")} required error={errors.phoneNumber && tOrgErr("phoneRequired")}>
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
      </section>

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

      <section>
        <h2 className="font-sans text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-4">
          {tBody("sectionAddress")}
        </h2>
        <div className="grid gap-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <FieldShell id="countryCode" label={tOrg("country")} required>
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
    </form>
  );
}
