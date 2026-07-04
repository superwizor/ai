// Client (patient) onboarding — the dedicated magic-link landing for
// docs/39 invitations, replacing the org-flavoured /accept-invite page
// for invited_role=PATIENT.
//
// Flow:
//   1. Social login (Google / Apple) → a short "you're connected" step
//      confirming first/last name → AcceptInvitation → SSO handoff
//      straight into the client panel on the app origin.
//   2. Or e-mail + password (mirrors the therapist registration): a
//      new account is created; when the e-mail already has one, the
//      same form degrades to a LOGIN (returning client / second
//      kartoteka — the backend re-points instead of duplicating), with
//      a password-reset link for the forgotten-password case.
//
// The invited e-mail comes from GetInvitationPreview and is shown
// read-only — InviteClient guarantees it exists, and AcceptInvitation
// binds the account by token, not by whatever e-mail is typed here.

"use client";

import { useEffect, useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { ConnectError, Code } from "@connectrpc/connect";
import { FirebaseError } from "firebase/app";
import { sendPasswordResetEmail } from "firebase/auth";

import { useAuth } from "@/lib/firebase/auth-provider";
import { getFirebaseAuth } from "@/lib/firebase/init";
import { identityClient } from "@/lib/connect/clients";
import {
  AcceptInvitationRequestSchema,
  GetInvitationPreviewRequestSchema,
  UserRole,
  type InvitationPreview,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import { openAppWithSso } from "@/lib/auth/open-app-sso";
import { FieldShell, TextInput } from "@/components/forms/Field";

type Step = "auth" | "social-name";

export function ClientOnboardingForm({ token }: { token: string }) {
  const t = useTranslations("register.clientOnboarding");
  const tFields = useTranslations("register.fields");
  const tCommon = useTranslations("register.common");
  const tErr = useTranslations("register.errors");
  const locale = useLocale();
  const auth = useAuth();

  const [preview, setPreview] = useState<InvitationPreview | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);
  useEffect(() => {
    let cancelled = false;
    identityClient
      .getInvitationPreview(create(GetInvitationPreviewRequestSchema, { token }))
      .then((p) => {
        if (cancelled) return;
        setPreview(p);
        if (p.firstName) setFirstName((v) => v || p.firstName);
        if (p.lastName) setLastName((v) => v || p.lastName);
      })
      .catch((e: unknown) => {
        if (cancelled) return;
        if (e instanceof ConnectError && e.code === Code.NotFound) {
          setPreviewError(t("invalidToken"));
        } else {
          setPreviewError(tErr("unknown"));
        }
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  const isPatientInvite =
    (preview?.invitedRole as unknown) === UserRole.PATIENT ||
    (preview?.invitedRole as unknown) === "USER_ROLE_PATIENT";
  const invitedEmail = preview?.email ?? "";

  const [step, setStep] = useState<Step>("auth");
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  // Firebase user from the social path, carried into the name step.
  const [socialUid, setSocialUid] = useState<string | null>(null);
  const [socialEmail, setSocialEmail] = useState<string>("");

  // Shared tail: exchange the token for the PATIENT account and hand
  // off to the client panel (app origin) via SSO.
  const acceptAndEnter = async (uid: string, ssoEmail: string) => {
    const tz =
      Intl.DateTimeFormat().resolvedOptions().timeZone || "Europe/Warsaw";
    await identityClient.acceptInvitation(
      create(AcceptInvitationRequestSchema, {
        token,
        firebaseUid: uid,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        uiLanguage: locale === "en" ? "en" : "pl",
        timezone: tz,
        hasAcceptedTos: true,
        hasMarketingConsent: false,
      }),
    );
    await openAppWithSso(ssoEmail);
  };

  const mapAcceptError = (e: unknown): string => {
    if (e instanceof ConnectError) {
      if (e.code === Code.NotFound) return t("invalidToken");
      if (e.code === Code.PermissionDenied) {
        return e.message.toLowerCase().includes("expired")
          ? t("expired")
          : t("alreadyAccepted");
      }
      if (e.message.includes("CLIENT_EMAIL_TAKEN")) return t("emailTaken");
    }
    return tErr("unknown");
  };

  const requireNames = (): boolean => {
    if (!firstName.trim() || !lastName.trim()) {
      setError(t("namesRequired"));
      return false;
    }
    return true;
  };

  // ── Social path ────────────────────────────────────────────────
  const onSocial = async (kind: "google" | "apple") => {
    setBusy(true);
    setError(null);
    try {
      const user =
        kind === "google"
          ? await auth.signInWithGoogle()
          : await auth.signInWithApple();
      // Prefill names from the provider when the invite had none.
      // (Apple only supplies displayName on the FIRST sign-in.)
      const dn = user.displayName ?? "";
      const [dnFirst = "", ...dnRest] = dn.split(" ");
      setFirstName((v) => v || dnFirst);
      setLastName((v) => v || dnRest.join(" "));
      setSocialUid(user.uid);
      setSocialEmail(user.email ?? invitedEmail);
      setStep("social-name");
    } catch (e) {
      if (e instanceof FirebaseError && e.code === "auth/popup-closed-by-user") {
        return;
      }
      console.error("[client-onboarding] social sign-in failed", e);
      setError(tErr("unknown"));
    } finally {
      setBusy(false);
    }
  };

  const onSocialFinish = async () => {
    if (!socialUid || !requireNames()) return;
    setBusy(true);
    setError(null);
    try {
      await acceptAndEnter(socialUid, socialEmail || invitedEmail);
    } catch (e) {
      console.error("[client-onboarding] accept (social) failed", e);
      setError(mapAcceptError(e));
      setBusy(false);
    }
  };

  // ── Password path ──────────────────────────────────────────────
  const onPasswordSubmit = async () => {
    setError(null);
    setInfo(null);
    if (!requireNames()) return;
    if (password.length < 8 || !/\d/.test(password)) {
      setError(tFields("passwordHint"));
      return;
    }
    setBusy(true);
    try {
      let user;
      try {
        user = await auth.signUpWithEmail(invitedEmail, password);
      } catch (e) {
        if (
          e instanceof FirebaseError &&
          e.code === "auth/email-already-in-use"
        ) {
          // Returning client — same form works as a login.
          try {
            user = await auth.signInWithEmail(invitedEmail, password);
          } catch {
            setError(t("existingAccountWrongPassword"));
            setBusy(false);
            return;
          }
        } else if (
          e instanceof FirebaseError &&
          e.code === "auth/weak-password"
        ) {
          setError(tErr("weakPassword"));
          setBusy(false);
          return;
        } else {
          throw e;
        }
      }
      await acceptAndEnter(user.uid, invitedEmail);
    } catch (e) {
      console.error("[client-onboarding] accept (password) failed", e);
      setError(mapAcceptError(e));
      setBusy(false);
    }
  };

  const onResetPassword = async () => {
    if (!invitedEmail) return;
    setError(null);
    try {
      await sendPasswordResetEmail(getFirebaseAuth(), invitedEmail);
      setInfo(t("resetSent"));
    } catch (e) {
      console.error("[client-onboarding] reset failed", e);
      setError(tErr("unknown"));
    }
  };

  // ── Render ─────────────────────────────────────────────────────
  if (previewError) {
    return (
      <p
        role="alert"
        className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-sans text-sm text-frost text-center"
      >
        {previewError}
      </p>
    );
  }
  if (!preview) {
    return (
      <p className="font-sans text-sm text-mist text-center">{t("loading")}</p>
    );
  }
  if (!isPatientInvite) {
    // A therapist/manager token landed here — send it to the generic
    // accept page instead of dead-ending.
    const prefix = locale === "en" ? "/en" : "";
    return (
      <p className="font-sans text-sm text-mist text-center">
        <a
          className="text-ember underline"
          href={`${prefix}/accept-invite?token=${encodeURIComponent(token)}`}
        >
          {t("notClientInvite")}
        </a>
      </p>
    );
  }

  const alertBox = (
    <>
      {error && (
        <p
          role="alert"
          className="rounded-button border border-magma/40 bg-magma/10 px-4 py-2 font-sans text-sm text-frost text-center"
        >
          {error}
        </p>
      )}
      {info && (
        <p className="rounded-button border border-aurora/40 bg-aurora/10 px-4 py-2 font-sans text-sm text-frost text-center">
          {info}
        </p>
      )}
    </>
  );

  if (step === "social-name") {
    return (
      <div className="grid gap-5">
        <div className="rounded-button border border-aurora/30 bg-aurora/5 px-4 py-3">
          <p className="font-sans text-sm text-frost">{t("socialConnectedTitle")}</p>
          <p className="font-sans text-xs text-mist mt-1">
            {t("socialConnectedBody", { email: socialEmail || invitedEmail })}
          </p>
        </div>
        <FieldShell id="cl-first" label={tFields("firstName")} required>
          <TextInput
            id="cl-first"
            value={firstName}
            autoComplete="given-name"
            onChange={(e) => setFirstName(e.target.value)}
          />
        </FieldShell>
        <FieldShell id="cl-last" label={tFields("lastName")} required>
          <TextInput
            id="cl-last"
            value={lastName}
            autoComplete="family-name"
            onChange={(e) => setLastName(e.target.value)}
          />
        </FieldShell>
        {alertBox}
        <button
          type="button"
          disabled={busy}
          onClick={onSocialFinish}
          className="rounded-button bg-ember text-evergreen font-display text-sm font-semibold px-4 py-3 hover:brightness-110 transition disabled:opacity-50"
        >
          {busy ? tCommon("submitting") : t("enterPanel")}
        </button>
        <p className="font-sans text-[11px] text-mist/70 text-center">
          {t("tosNote")}
        </p>
      </div>
    );
  }

  return (
    <div className="grid gap-3">
      {/* Social — the simplest path first. */}
      <button
        type="button"
        onClick={() => onSocial("google")}
        disabled={busy}
        className="inline-flex items-center justify-center gap-3 rounded-button border border-frost/20 bg-frost/5 hover:bg-frost/10 text-frost font-display text-sm px-4 py-3 transition disabled:opacity-50"
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
        disabled={busy}
        className="inline-flex items-center justify-center gap-3 rounded-button border border-frost/20 bg-frost/5 hover:bg-frost/10 text-frost font-display text-sm px-4 py-3 transition disabled:opacity-50"
      >
        <svg aria-hidden width="17" height="20" viewBox="0 0 814 1000" fill="currentColor">
          <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105.3-57.8-155.5-127.4C46 790.9 0 663.1 0 541.8c0-207.6 135.4-317.3 268.9-317.3 71.6 0 131 46.5 175.4 46.5 42.8 0 109.6-49.5 190.5-49.5 30.8 0 108.2 2.6 164.4 100.5zm-234.4-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z"/>
        </svg>
        {tCommon("apple")}
      </button>

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

      {/* Password path — like the therapist registration. */}
      <FieldShell id="cl-email" label={tFields("email")}>
        <TextInput id="cl-email" value={invitedEmail} readOnly disabled />
      </FieldShell>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <FieldShell id="cl-first-p" label={tFields("firstName")} required>
          <TextInput
            id="cl-first-p"
            value={firstName}
            autoComplete="given-name"
            onChange={(e) => setFirstName(e.target.value)}
          />
        </FieldShell>
        <FieldShell id="cl-last-p" label={tFields("lastName")} required>
          <TextInput
            id="cl-last-p"
            value={lastName}
            autoComplete="family-name"
            onChange={(e) => setLastName(e.target.value)}
          />
        </FieldShell>
      </div>
      <FieldShell
        id="cl-password"
        label={tFields("password")}
        hint={tFields("passwordHint")}
        required
      >
        <TextInput
          id="cl-password"
          type="password"
          value={password}
          autoComplete="new-password"
          onChange={(e) => setPassword(e.target.value)}
        />
      </FieldShell>

      {alertBox}

      <button
        type="button"
        disabled={busy}
        onClick={onPasswordSubmit}
        className="rounded-button bg-ember text-evergreen font-display text-sm font-semibold px-4 py-3 hover:brightness-110 transition disabled:opacity-50"
      >
        {busy ? tCommon("submitting") : t("submit")}
      </button>

      <p className="font-sans text-xs text-mist text-center">
        {t("haveAccountHint")}{" "}
        <button
          type="button"
          onClick={onResetPassword}
          className="text-ember underline"
        >
          {t("forgotPassword")}
        </button>
      </p>
      <p className="font-sans text-[11px] text-mist/70 text-center">
        {t("tosNote")}
      </p>
    </div>
  );
}
