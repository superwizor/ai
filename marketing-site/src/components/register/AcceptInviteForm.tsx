// Accept-invitation form — invitee sets password + profile after
// clicking the email link `/accept-invite?token=<base64url>`.
//
// docs/18 §9 spec: the link the email contains points at
// app.superwizor.ai/accept-invite, but until Slice 5 ships the
// Flutter Web app shell, this Next.js route is the stopgap. The
// notification-svc template's URL can be flipped between origins
// without code change here.
//
// Why the user types their email even though they got the link:
// the gen/ts proto has no GetInvitationByToken RPC for pre-flight
// lookup. We could (a) extend the proto, or (b) include `&email=`
// in the link, or (c) take a small UX hit and have them retype.
// We chose (c) — backend cross-checks email against invitations
// row by hashing the incoming token; mismatch = error code surfaced
// via setServerError.

"use client";

import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { ConnectError, Code } from "@connectrpc/connect";
import { FirebaseError } from "firebase/app";

import { acceptInviteSchema, type AcceptInviteForm } from "@/lib/register/schema";
import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient } from "@/lib/connect/clients";
import { AcceptInvitationRequestSchema } from "@superwizor/proto-ts/identity/v1/identity_pb";
import { Checkbox, FieldShell, RadioGroup, Select, TextInput } from "@/components/forms/Field";
import {
  getModalityCatalog,
  type ModalityRow,
} from "@/lib/clinical/modalities";

export function AcceptInviteForm({ token }: { token: string }) {
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
        console.error("[accept-invite] modality fetch failed", err);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const t = useTranslations("register.fields");
  const tCommon = useTranslations("register.common");
  const tErr = useTranslations("register.errors");
  const tInv = useTranslations("register.acceptInvite");
  const locale = useLocale();
  const auth = useAuth();
  const prefix = locale === "en" ? "/en" : "";

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<AcceptInviteForm>({
    resolver: zodResolver(acceptInviteSchema),
    defaultValues: {
      uiLanguage: locale === "en" ? "en" : "pl",
      hasMarketingConsent: false,
    },
  });

  const [serverError, setServerError] = useState<string | null>(null);

  const onSubmit = handleSubmit(async (data) => {
    setServerError(null);
    try {
      const user = await auth.signUpWithEmail(data.email, data.password);

      const tz =
        Intl.DateTimeFormat().resolvedOptions().timeZone || "Europe/Warsaw";
      const req = create(AcceptInvitationRequestSchema, {
        token,
        firebaseUid: user.uid,
        firstName: data.firstName,
        lastName: data.lastName,
        defaultModalityId: data.modalityId,
        uiLanguage: data.uiLanguage,
        timezone: tz,
        hasAcceptedTos: true,
        hasMarketingConsent: data.hasMarketingConsent ?? false,
      });
      await identityClient.acceptInvitation(req);

      // Email already verified at the inviting org's side (the
      // user just clicked an email link), but Firebase doesn't
      // know that. Send a fresh verification so the user can
      // confirm + land on app.superwizor.ai. Slice 5 may move
      // the post-acceptance landing to the app origin directly.
      window.location.href = `${prefix}/register/therapist/verify-email?email=${encodeURIComponent(data.email)}`;
    } catch (e) {
      if (e instanceof FirebaseError) {
        if (e.code === "auth/email-already-in-use") {
          setServerError(tErr("emailAlreadyInUse"));
          return;
        }
        if (e.code === "auth/weak-password") {
          setServerError(tErr("weakPassword"));
          return;
        }
      }
      if (e instanceof ConnectError) {
        // Backend codes for invitation issues. We don't have
        // dedicated proto error-codes yet; the handler returns
        // PermissionDenied for expired / already-accepted,
        // NotFound for invalid token. See identity-svc
        // AcceptInvitation handler.
        if (e.code === Code.NotFound) {
          setServerError(tInv("invalidToken"));
          return;
        }
        if (e.code === Code.PermissionDenied) {
          // Could be expired OR already accepted — backend
          // distinguishes via message text. For copy we pick the
          // "already accepted" path as the more common case.
          if (e.message.toLowerCase().includes("expired")) {
            setServerError(tInv("expired"));
          } else {
            setServerError(tInv("alreadyAccepted"));
          }
          return;
        }
      }
      setServerError(tErr("unknown"));
    }
  });

  const uiLanguage = watch("uiLanguage");

  return (
    <form onSubmit={onSubmit} className="grid gap-5" noValidate>
      <div className="grid gap-4">
        <FieldShell id="email" label={t("email")} required error={errors.email && tErr("emailInvalid")}>
          <TextInput
            id="email"
            type="email"
            autoComplete="email"
            placeholder={t("email")}
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
      </div>

      <section className="grid gap-3">
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
        {isSubmitting ? tInv("submitting") : tInv("submit")}
      </button>
    </form>
  );
}
