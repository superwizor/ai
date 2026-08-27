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
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { ConnectError, Code } from "@connectrpc/connect";
import { FirebaseError } from "firebase/app";

import {
  acceptInviteSchema,
  clientAcceptInviteSchema,
  type AcceptInviteForm,
} from "@/lib/register/schema";
import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient } from "@/lib/connect/clients";
import {
  AcceptInvitationRequestSchema,
  GetInvitationPreviewRequestSchema,
  UserRole,
  type InvitationPreview,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import { openAppWithSso } from "@/lib/auth/open-app-sso";
import { Checkbox, FieldShell, PhoneInput, RadioGroup, Select, TextInput } from "@/components/forms/Field";
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
  // docs/42: kod parowania od terapeuty — wymagany, gdy zaproszenie go
  // niesie (requiresPairingCode z preview). Normalizowany ze spacji.
  const [pairingCode, setPairingCode] = useState("");
  const [pairingCodeError, setPairingCodeError] = useState<string | null>(null);
  useEffect(() => {
    let cancelled = false;
    identityClient
      .getInvitationPreview(create(GetInvitationPreviewRequestSchema, { token }))
      .then((p) => {
        if (cancelled) return;
        // Client invitations have their own onboarding page (docs/39
        // C-PR10). Already-sent e-mails still point here — bounce them.
        const role = p.invitedRole as unknown;
        if (role === UserRole.PATIENT || role === "USER_ROLE_PATIENT") {
          const prefix = locale === "en" ? "/en" : "";
          window.location.replace(
            `${prefix}/register/client?token=${encodeURIComponent(token)}`,
          );
          return;
        }
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
  // Org managers don't practice under a modality — the field is a
  // therapist-only concept and showing it (required!) on the manager
  // accept made the screen read like therapist onboarding
  // (live-tested 2026-07-04).
  const isOrgAdminInvite =
    (preview?.invitedRole as unknown) === UserRole.ORG_ADMIN ||
    (preview?.invitedRole as unknown) === "USER_ROLE_ORG_ADMIN";
  const isTherapistInvite =
    (preview?.invitedRole as unknown) === UserRole.THERAPIST ||
    (preview?.invitedRole as unknown) === "USER_ROLE_THERAPIST";
  const needsModality = !isPatientInvite && !isOrgAdminInvite;
  // Social auth applies to manager AND therapist invites (live-feedback
  // 2026-07-04). Requires a loaded preview — legacy tokens without a
  // resolvable role keep the classic password form.
  const socialCapable = isOrgAdminInvite || isTherapistInvite;

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
    control,
    formState: { errors, isSubmitting },
  } = useForm<AcceptInviteForm>({
    // PATIENT invites redirect to /register/client above, but if one
    // ever renders here the pseudonymous variant applies — no names
    // required (docs/43 §4). Staff invites keep the strict schema.
    resolver: zodResolver(
      isPatientInvite ? clientAcceptInviteSchema : acceptInviteSchema,
    ),
    defaultValues: {
      uiLanguage: locale === "en" ? "en" : "pl",
      hasMarketingConsent: false,
    },
  });

  const [serverError, setServerError] = useState<string | null>(null);

  // Social auth for manager invites (live-feedback 2026-07-04): after
  // Google/Apple the SAME form finishes the profile — the password
  // fields disappear and submit accepts with the social identity.
  const [socialUid, setSocialUid] = useState<string | null>(null);
  const [socialEmail, setSocialEmail] = useState("");
  const tOnb = useTranslations("register.clientOnboarding");

  const onSocial = async (kind: "google" | "apple") => {
    setServerError(null);
    try {
      const user =
        kind === "google"
          ? await auth.signInWithGoogle()
          : await auth.signInWithApple();
      const dn = (user.displayName ?? "").trim();
      const [dnFirst = "", ...dnRest] = dn.split(/\s+/);
      if (dnFirst && !watch("firstName")) setValue("firstName", dnFirst);
      if (dnRest.length && !watch("lastName")) {
        setValue("lastName", dnRest.join(" "));
      }
      setSocialUid(user.uid);
      setSocialEmail(user.email ?? "");
      // The password never leaves the browser on this path — satisfy the
      // schema so handleSubmit validates the visible fields only.
      setValue("password", "social-authenticated-1", { shouldValidate: true });
    } catch (e) {
      if (e instanceof FirebaseError && e.code === "auth/popup-closed-by-user") {
        return;
      }
      console.error("[accept-invite] social sign-in failed", e);
      setServerError(tErr("unknown"));
    }
  };

  const onSubmit = handleSubmit(async (data) => {
    setServerError(null);
    if (needsModality && !data.modalityId) {
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
      if (socialUid) {
        // Already authenticated via Google/Apple — accept with that
        // identity, no password account created.
        user = { uid: socialUid };
      } else {
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
      }

      if (preview?.requiresPairingCode) {
        const normalized = pairingCode.replace(/\s+/g, "");
        if (!/^\d{6}$/.test(normalized)) {
          setPairingCodeError(tInv("pairingCodeFormat"));
          return;
        }
      }
      setPairingCodeError(null);

      const tz =
        Intl.DateTimeFormat().resolvedOptions().timeZone || "Europe/Warsaw";
      const req = create(AcceptInvitationRequestSchema, {
        token,
        pairingCode: pairingCode.replace(/\s+/g, ""),
        firebaseUid: user.uid,
        // PATIENT accounts are pseudonymous (docs/43 §4) — never send
        // names for them; the backend ignores the fields anyway.
        ...(isPatientInvite
          ? {}
          : {
              firstName: data.firstName ?? "",
              lastName: data.lastName ?? "",
              phoneNumber: data.phoneNumber ?? "",
            }),
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
        // Single-role MVP: the invited e-mail (or the signed-in social
        // account) already owns an account — a second role can't be
        // minted (live-tested 2026-07-04: a THERAPIST accepting their
        // own ORG_ADMIN invite).
        // docs/42: kod parowania — zły kod vs blokada po 5 próbach.
        if (e.message.includes("PAIRING_CODE_INVALID")) {
          setPairingCodeError(tInv("pairingCodeInvalid"));
          return;
        }
        if (e.message.includes("INVITATION_BLOCKED")) {
          setServerError(tInv("invitationBlocked"));
          return;
        }
        if (e.message.includes("EMAIL_ALREADY_REGISTERED")) {
          setServerError(tInv("emailAlreadyRegistered"));
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
      {/* ── Manager invites: social first, two labeled options (same
             pattern as /register/client and /login) ── */}
      {socialCapable && !socialUid && (
        <>
          <section className="rounded-button border border-frost/15 bg-frost/[0.03] p-5 grid gap-3">
            <h2 className="font-display text-frost text-sm font-semibold">
              {tOnb("option1Title")}
            </h2>
            <button
              type="button"
              onClick={() => onSocial("google")}
              className="inline-flex items-center justify-center gap-3 rounded-button border border-frost/20 bg-frost/5 hover:bg-frost/10 text-frost font-display text-sm px-4 py-3 transition"
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
              onClick={() => onSocial("apple")}
              className="inline-flex items-center justify-center gap-3 rounded-button border border-frost/20 bg-frost/5 hover:bg-frost/10 text-frost font-display text-sm px-4 py-3 transition"
            >
              <svg aria-hidden width="17" height="20" viewBox="0 0 814 1000" fill="currentColor">
                <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105.3-57.8-155.5-127.4C46 790.9 0 663.1 0 541.8c0-207.6 135.4-317.3 268.9-317.3 71.6 0 131 46.5 175.4 46.5 42.8 0 109.6-49.5 190.5-49.5 30.8 0 108.2 2.6 164.4 100.5zm-234.4-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z"/>
              </svg>
              {tCommon("apple")}
            </button>
          </section>
          <div className="relative" aria-hidden>
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t border-frost/10"></span>
            </div>
            <div className="relative flex justify-center">
              <span className="bg-evergreen px-3 font-sans text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/60">
                {tCommon("or")}
              </span>
            </div>
          </div>
          <h2 className="font-display text-frost text-sm font-semibold">
            {tOnb("option2Title")}
          </h2>
        </>
      )}
      {socialCapable && socialUid && (
        <div className="rounded-button border border-aurora/30 bg-aurora/5 px-4 py-3">
          <p className="font-sans text-sm text-frost font-semibold">
            {tOnb("socialConnectedTitle")}
          </p>
          <p className="font-sans text-xs text-mist mt-1">
            {tOnb("socialConnectedBody", { email: socialEmail })}
          </p>
        </div>
      )}

      <div className="grid gap-4">
        {!socialUid && (
          <FieldShell id="email" label={t("email")} required error={errors.email && tErr("emailInvalid")}>
            <TextInput
              id="email"
              type="email"
              autoComplete="email"
              placeholder={t("email")}
              {...register("email")}
            />
          </FieldShell>
        )}

        {!socialUid && (
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
        )}

        {/* Pseudonymous PATIENT accounts have no names (docs/43 §4). */}
        {!isPatientInvite && (
          <div className="grid gap-4 sm:grid-cols-2">
            <FieldShell id="firstName" label={t("firstName")} required error={errors.firstName && tErr("firstNameRequired")}>
              <TextInput id="firstName" autoComplete="given-name" {...register("firstName")} />
            </FieldShell>
            <FieldShell id="lastName" label={t("lastName")} required error={errors.lastName && tErr("lastNameRequired")}>
              <TextInput id="lastName" autoComplete="family-name" {...register("lastName")} />
            </FieldShell>
          </div>
        )}

        {/* Telefon tylko dla personelu — konto klienta jest pseudonimowe
            (docs/43 §4), a ścieżka samodzielnej rejestracji terapeuty
            wymaga numeru „ze względów bezpieczeństwa". Bez tego pola
            akceptacja zaproszenia była furtką omijającą ten wymóg. */}
        {!isPatientInvite && (
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
        )}

        {preview?.requiresPairingCode && (
          <FieldShell
            id="pairingCode"
            label={tInv("pairingCodeLabel")}
            hint={tInv("pairingCodeHint")}
            required
            error={pairingCodeError ?? undefined}
          >
            <TextInput
              id="pairingCode"
              inputMode="numeric"
              autoComplete="one-time-code"
              placeholder="123 456"
              maxLength={7}
              value={pairingCode}
              onChange={(e) => {
                setPairingCode(e.target.value);
                setPairingCodeError(null);
              }}
            />
          </FieldShell>
        )}

        {needsModality && (
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
