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
import {
  AcceptInvitationRequestSchema,
  GetInvitationPreviewRequestSchema,
  UserRole,
  type InvitationPreview,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import { openAppWithSso } from "@/lib/auth/open-app-sso";
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

  // Invitation preview (docs/39): adapts the form BEFORE signup —
  // PATIENT invites hide the therapist-only modality field, prefill
  // the e-mail/names, and route to the client panel after acceptance.
  const [preview, setPreview] = useState<InvitationPreview | null>(null);
  useEffect(() => {
    let cancelled = false;
    identityClient
      .getInvitationPreview(create(GetInvitationPreviewRequestSchema, { token }))
      .then((p) => {
        if (cancelled) return;
        setPreview(p);
        if (p.email) setValue("email", p.email);
        if (p.firstName) setValue("firstName", p.firstName);
        if (p.lastName) setValue("lastName", p.lastName);
      })
      .catch(() => {
        // Unknown/expired token — the submit path surfaces the error.
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  const isPatientInvite =
    (preview?.invitedRole as unknown) === UserRole.PATIENT ||
    (preview?.invitedRole as unknown) === "USER_ROLE_PATIENT";

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
    if (!isPatientInvite && !data.modalityId) {
      setServerError(tErr("modalityRequired"));
      return;
    }
    try {
      // Create the Firebase account; when the e-mail already has one
      // (returning client accepting a second kartoteka, or a client
      // re-clicking the link after signup — docs/39 D4), the magic-link
      // accept degrades to a LOGIN with the same form: the backend's
      // AcceptInvitation re-points the kartoteka at the existing
      // PATIENT account instead of creating a duplicate.
      let user;
      try {
        user = await auth.signUpWithEmail(data.email, data.password);
      } catch (e) {
        if (
          e instanceof FirebaseError &&
          e.code === "auth/email-already-in-use"
        ) {
          try {
            user = await auth.signInWithEmail(data.email, data.password);
          } catch {
            setServerError(tErr("existingAccountWrongPassword"));
            return;
          }
        } else {
          throw e;
        }
      }

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
      const accepted = await identityClient.acceptInvitation(req);

      // Clients (docs/39: invited_role=PATIENT) land in the client
      // panel on the app origin — signed in via the SSO handoff.
      const role = accepted.user?.role as unknown;
      if (role === UserRole.PATIENT || role === "USER_ROLE_PATIENT") {
        await openAppWithSso(data.email);
        return;
      }

      // Org managers (docs/38: invitations.invited_role=ORG_ADMIN,
      // minted by AdminCreateOrganization) land straight in their
      // panel — they're already signed in to Firebase on this origin
      // and /org gates on the resolved role, not e-mail verification.
      if (role === UserRole.ORG_ADMIN || role === "USER_ROLE_ORG_ADMIN") {
        window.location.href = `${prefix}/org`;
        return;
      }

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

        {!isPatientInvite && (
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
        )}

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
        className="mt-2 w-full flex items-center justify-center gap-3 py-4 px-6 rounded-xl bg-ember text-obsidian shadow-[0_4px_14px_rgba(252,174,47,0.4)] hover:brightness-115 hover:shadow-[0_6px_20px_rgba(252,174,47,0.6)] hover:-translate-y-0.5 transition-all duration-300 group cursor-pointer font-sans text-[18px] font-semibold text-obsidian disabled:opacity-60 disabled:cursor-not-allowed disabled:transform-none disabled:shadow-none"
      >
        {isSubmitting ? tInv("submitting") : tInv("submit")}
      </button>
    </form>
  );
}
