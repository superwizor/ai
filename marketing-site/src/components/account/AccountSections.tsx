// Therapist account management surface — landing page after sign-in
// on the marketing origin for users with role != SUPERWIZOR_ADMIN.
//
// Three independent sections, each with its own load / save state:
//   1. Profile (UpdateProfile)             — all roles can self-edit
//   2. Organisation (UpdateMyOrganization) — SOLO therapists + ORG_ADMIN
//   3. Subscription (read-only via clinical.GetMyBillingState) + a
//      placeholder for the future Stripe connect button.
//
// Plus a "kartoteki" CTA that opens the Flutter console in a new tab.
// Email is shown read-only — Firebase Auth owns email changes and
// they need their own verification roundtrip.
//
// The org section silently degrades when the caller can't manage the
// org (e.g. THERAPIST in a CLINIC org): we catch PermissionDenied on
// GetMyOrganization and render a neutral "not allowed" notice with no
// editable controls. Keeps the page useful for users whose admin
// lives elsewhere.

"use client";

import { useEffect, useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { ConnectError, Code } from "@connectrpc/connect";

import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient, clinicalClient } from "@/lib/connect/clients";
import {
  UpdateProfileRequestSchema,
  UpdateMyOrganizationRequestSchema,
  AddressSchema,
  OrganizationType,
  type User,
  type Organization,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import type { Subscription } from "@superwizor/proto-ts/billing/v1/billing_pb";

const APP_URL = "https://superwizor-app.web.app/";

export function AccountSections() {
  const t = useTranslations("account");
  const locale = useLocale();
  const { user: fbUser, signOut } = useAuth();

  const [profile, setProfile] = useState<User | null>(null);
  const [profileError, setProfileError] = useState<string | null>(null);

  useEffect(() => {
    if (!fbUser) return;
    let cancelled = false;
    (async () => {
      try {
        const me = await identityClient.getMyProfile(create(EmptySchema, {}));
        if (!cancelled) setProfile(me);
      } catch (e) {
        console.error("[account] load profile failed", e);
        if (!cancelled) setProfileError(t("errLoad"));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [fbUser, t]);

  if (!fbUser) {
    // Should not happen — the page-level guard redirects to /login —
    // but render nothing rather than crash if the auth hook is
    // hydrating mid-render.
    return null;
  }

  return (
    <div className="grid gap-8">
      {/* Email + sign-out + kartoteki link */}
      <header className="rounded-glass border border-glass-border/40 bg-frost/[0.04] p-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
            {fbUser.email}
          </p>
          <p className="font-serif text-xs text-mist/70 mt-1">
            {t("emailReadOnly")}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <a
            href={APP_URL}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-xs px-4 py-2 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition"
            title={t("kartotekiHint")}
          >
            {t("kartotekiCta")} →
          </a>
          <button
            type="button"
            onClick={() => signOut()}
            className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist hover:text-ember transition"
          >
            {t("signOut")}
          </button>
        </div>
      </header>

      {profileError && (
        <p role="alert" className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-sm text-frost">
          {profileError}
        </p>
      )}

      <ProfileSection profile={profile} onUpdate={setProfile} />
      <OrgSection profile={profile} locale={locale} />
      <BillingSection />
      <StripePlaceholder />
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────
// Profile
// ────────────────────────────────────────────────────────────────────
function ProfileSection({
  profile,
  onUpdate,
}: {
  profile: User | null;
  onUpdate: (u: User) => void;
}) {
  const t = useTranslations("account");
  const [draft, setDraft] = useState({
    firstName: "",
    lastName: "",
    phoneNumber: "",
    professionalTitle: "",
    credentialsNumber: "",
    biography: "",
  });
  const [submitting, setSubmitting] = useState(false);
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Hydrate the draft once the profile arrives.
  useEffect(() => {
    if (!profile) return;
    setDraft({
      firstName: profile.firstName ?? "",
      lastName: profile.lastName ?? "",
      phoneNumber: profile.phoneNumber ?? "",
      professionalTitle: profile.professionalTitle ?? "",
      credentialsNumber: profile.credentialsNumber ?? "",
      biography: profile.biography ?? "",
    });
  }, [profile]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      // UpdateProfile expects empty userId — server resolves from the
      // auth context. Send field values as-is; the handler treats
      // empty strings as "leave alone" for legacy fields (firstName,
      // lastName, phoneNumber, professionalTitle, credentialsNumber,
      // biography). proto-optional fields (avatarUrl, modalityId,
      // uiLanguage, etc.) are not included here.
      const req = create(UpdateProfileRequestSchema, {
        userId: "",
        firstName: draft.firstName,
        lastName: draft.lastName,
        phoneNumber: draft.phoneNumber,
        professionalTitle: draft.professionalTitle,
        credentialsNumber: draft.credentialsNumber,
        biography: draft.biography,
      });
      const updated = await identityClient.updateProfile(req);
      onUpdate(updated);
      setSavedAt(Date.now());
    } catch (e) {
      console.error("[account] update profile failed", e);
      setError(t("errGeneric"));
    } finally {
      setSubmitting(false);
    }
  }

  if (!profile) {
    return <Section title={t("profileSection")}>{t("orgLoading")}</Section>;
  }

  return (
    <Section title={t("profileSection")}>
      <form onSubmit={onSubmit} className="grid gap-4" noValidate>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("firstName")}>
            <input
              type="text"
              value={draft.firstName}
              onChange={(e) => setDraft((d) => ({ ...d, firstName: e.target.value }))}
              className={inputClass}
            />
          </Field>
          <Field label={t("lastName")}>
            <input
              type="text"
              value={draft.lastName}
              onChange={(e) => setDraft((d) => ({ ...d, lastName: e.target.value }))}
              className={inputClass}
            />
          </Field>
        </div>
        <Field label={t("phoneNumber")}>
          <input
            type="tel"
            value={draft.phoneNumber}
            onChange={(e) => setDraft((d) => ({ ...d, phoneNumber: e.target.value }))}
            className={inputClass}
          />
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("professionalTitle")}>
            <input
              type="text"
              value={draft.professionalTitle}
              onChange={(e) => setDraft((d) => ({ ...d, professionalTitle: e.target.value }))}
              className={inputClass}
            />
          </Field>
          <Field label={t("credentialsNumber")}>
            <input
              type="text"
              value={draft.credentialsNumber}
              onChange={(e) => setDraft((d) => ({ ...d, credentialsNumber: e.target.value }))}
              className={inputClass}
            />
          </Field>
        </div>
        <Field label={t("biography")}>
          <textarea
            rows={3}
            value={draft.biography}
            onChange={(e) => setDraft((d) => ({ ...d, biography: e.target.value }))}
            className={`${inputClass} resize-y`}
          />
        </Field>

        {error && (
          <p role="alert" className="rounded-button border border-magma/40 bg-magma/10 px-3 py-2 font-serif text-xs text-frost">
            {error}
          </p>
        )}
        {savedAt && !error && !submitting && (
          <p role="status" className="rounded-button border border-aurora/40 bg-aurora/10 px-3 py-2 font-serif text-xs text-frost">
            {t("profileSaved")}
          </p>
        )}

        <div>
          <button type="submit" disabled={submitting} className={submitBtnClass}>
            {submitting ? t("profileSubmitting") : t("profileSubmit")}
          </button>
        </div>
      </form>
    </Section>
  );
}

// ────────────────────────────────────────────────────────────────────
// Organisation (SOLO-therapists + ORG_ADMIN only — graceful skip otherwise)
// ────────────────────────────────────────────────────────────────────
function OrgSection({ profile, locale: _locale }: { profile: User | null; locale: string }) {
  const t = useTranslations("account");
  const [phase, setPhase] = useState<"loading" | "ready" | "notAllowed" | "noOrg" | "error">("loading");
  const [org, setOrg] = useState<Organization | null>(null);
  const [draft, setDraft] = useState({
    legalName: "",
    taxId: "",
    vatIdEu: "",
    countryCode: "PL",
    region: "",
    city: "",
    postalCode: "",
    streetLine: "",
    buildingNumber: "",
    unitNumber: "",
    directions: "",
  });
  const [submitting, setSubmitting] = useState(false);
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Wait until the parent has loaded the profile so we know whether
    // the user even has an organization. Avoids a noisy NotFound on
    // accounts that signed up as a lone therapist with no org row.
    if (!profile) return;
    if (!profile.organizationId) {
      setPhase("noOrg");
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const o = await identityClient.getMyOrganization(create(EmptySchema, {}));
        if (cancelled) return;
        setOrg(o);
        setDraft({
          legalName: o.legalName ?? "",
          taxId: o.taxId ?? "",
          vatIdEu: o.vatIdEu ?? "",
          countryCode: o.headquartersAddress?.countryCode ?? "PL",
          region: o.headquartersAddress?.region ?? "",
          city: o.headquartersAddress?.city ?? "",
          postalCode: o.headquartersAddress?.postalCode ?? "",
          streetLine: o.headquartersAddress?.streetLine ?? "",
          buildingNumber: o.headquartersAddress?.buildingNumber ?? "",
          unitNumber: o.headquartersAddress?.unitNumber ?? "",
          directions: o.headquartersAddress?.directions ?? "",
        });
        setPhase("ready");
      } catch (e) {
        if (cancelled) return;
        if (e instanceof ConnectError && e.code === Code.PermissionDenied) {
          setPhase("notAllowed");
        } else {
          console.error("[account] load org failed", e);
          setPhase("error");
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [profile]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      // Build address only if any field is set. Send legalName/taxId/
      // vatIdEu unconditionally — backend honours proto-optional
      // presence so missing-field means leave-alone (we always pass
      // them so the user can blank one if they want).
      const address = create(AddressSchema, {
        countryCode: draft.countryCode || "PL",
        region: draft.region,
        city: draft.city,
        postalCode: draft.postalCode,
        streetLine: draft.streetLine,
        buildingNumber: draft.buildingNumber,
        unitNumber: draft.unitNumber,
        directions: draft.directions,
      });
      const req = create(UpdateMyOrganizationRequestSchema, {
        legalName: draft.legalName,
        taxId: draft.taxId,
        vatIdEu: draft.vatIdEu,
        headquartersAddress: address,
      });
      const updated = await identityClient.updateMyOrganization(req);
      setOrg(updated);
      setSavedAt(Date.now());
    } catch (e) {
      console.error("[account] update org failed", e);
      setError(t("errGeneric"));
    } finally {
      setSubmitting(false);
    }
  }

  if (phase === "loading") {
    return <Section title={t("orgSection")}>{t("orgLoading")}</Section>;
  }
  if (phase === "noOrg") {
    return <Section title={t("orgSection")}>{t("orgNone")}</Section>;
  }
  if (phase === "notAllowed") {
    return (
      <Section title={t("orgSection")}>
        <p className="font-serif text-sm text-mist">{t("orgNotAllowed")}</p>
      </Section>
    );
  }
  if (phase === "error") {
    return <Section title={t("orgSection")}>{t("errLoad")}</Section>;
  }

  return (
    <Section title={t("orgSection")}>
      <form onSubmit={onSubmit} className="grid gap-4" noValidate>
        <Field label={t("legalName")}>
          <input
            type="text"
            value={draft.legalName}
            onChange={(e) => setDraft((d) => ({ ...d, legalName: e.target.value }))}
            className={inputClass}
          />
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("taxId")}>
            <input
              type="text"
              value={draft.taxId}
              onChange={(e) => setDraft((d) => ({ ...d, taxId: e.target.value }))}
              className={inputClass}
            />
          </Field>
          <Field label={t("vatIdEu")}>
            <input
              type="text"
              value={draft.vatIdEu}
              onChange={(e) => setDraft((d) => ({ ...d, vatIdEu: e.target.value }))}
              className={inputClass}
            />
          </Field>
        </div>

        {/* HQ address — flat inputs; AddressFields wasn't reused
            because it lives under /admin and is tied to an admin
            UpdateUserParams shape. Keep this lightweight. */}
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="Ulica">
            <input
              type="text"
              value={draft.streetLine}
              onChange={(e) => setDraft((d) => ({ ...d, streetLine: e.target.value }))}
              className={inputClass}
            />
          </Field>
          <Field label="Nr budynku">
            <input
              type="text"
              value={draft.buildingNumber}
              onChange={(e) => setDraft((d) => ({ ...d, buildingNumber: e.target.value }))}
              className={inputClass}
            />
          </Field>
          <Field label="Nr lokalu">
            <input
              type="text"
              value={draft.unitNumber}
              onChange={(e) => setDraft((d) => ({ ...d, unitNumber: e.target.value }))}
              className={inputClass}
            />
          </Field>
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="Kod pocztowy">
            <input
              type="text"
              value={draft.postalCode}
              onChange={(e) => setDraft((d) => ({ ...d, postalCode: e.target.value }))}
              className={inputClass}
            />
          </Field>
          <Field label="Miasto">
            <input
              type="text"
              value={draft.city}
              onChange={(e) => setDraft((d) => ({ ...d, city: e.target.value }))}
              className={inputClass}
            />
          </Field>
          <Field label="Województwo">
            <input
              type="text"
              value={draft.region}
              onChange={(e) => setDraft((d) => ({ ...d, region: e.target.value }))}
              className={inputClass}
            />
          </Field>
        </div>

        {error && (
          <p role="alert" className="rounded-button border border-magma/40 bg-magma/10 px-3 py-2 font-serif text-xs text-frost">
            {error}
          </p>
        )}
        {savedAt && !error && !submitting && (
          <p role="status" className="rounded-button border border-aurora/40 bg-aurora/10 px-3 py-2 font-serif text-xs text-frost">
            {t("orgSaved")}
          </p>
        )}

        <div className="flex items-center gap-3">
          <button type="submit" disabled={submitting} className={submitBtnClass}>
            {submitting ? t("orgSubmitting") : t("orgSubmit")}
          </button>
          {org && (
            <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist/70">
              {t("orgType")}: {orgTypeName(org.type)}
            </span>
          )}
        </div>
      </form>
    </Section>
  );
}

function orgTypeName(t: OrganizationType): string {
  switch (t) {
    case OrganizationType.SOLO: return "SOLO";
    case OrganizationType.CLINIC: return "CLINIC";
    case OrganizationType.ENTERPRISE: return "ENTERPRISE";
    default: return "—";
  }
}

// ────────────────────────────────────────────────────────────────────
// Subscription (read-only — uses clinical.GetMyBillingState proxy)
// ────────────────────────────────────────────────────────────────────
function BillingSection() {
  const t = useTranslations("account");
  const [sub, setSub] = useState<Subscription | null>(null);
  const [phase, setPhase] = useState<"loading" | "ready" | "none" | "error">("loading");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const s = await clinicalClient.getMyBillingState(create(EmptySchema, {}));
        if (cancelled) return;
        // The RPC returns the Subscription directly (no wrapper). If
        // there's no active sub, plan id will be empty.
        if (!s || !s.planTier) {
          setPhase("none");
        } else {
          setSub(s);
          setPhase("ready");
        }
      } catch (e) {
        console.error("[account] load subscription failed", e);
        if (!cancelled) setPhase("error");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  if (phase === "loading") return <Section title={t("billingSection")}>{t("billingLoading")}</Section>;
  if (phase === "none")    return <Section title={t("billingSection")}>{t("billingNone")}</Section>;
  if (phase === "error")   return <Section title={t("billingSection")}>{t("errLoad")}</Section>;
  if (!sub)                return <Section title={t("billingSection")}>{t("billingNone")}</Section>;

  return (
    <Section title={t("billingSection")}>
      <dl className="grid gap-3 sm:grid-cols-2">
        <Stat label={t("billingPlan")}    value={sub.planTier || "—"} />
        <Stat label={t("billingStatus")}  value={sub.status || "—"} />
        <Stat
          label={t("billingTokens")}
          value={`${Math.max(0, sub.tokensPerPeriod - sub.tokensUsedThisPeriod - sub.tokensReservedThisPeriod)} / ${sub.tokensPerPeriod}`}
        />
        <Stat
          label={t("billingPeriodEnd")}
          value={
            sub.currentPeriodEnd
              ? new Date(Number(sub.currentPeriodEnd.seconds) * 1000).toLocaleDateString()
              : "—"
          }
        />
      </dl>
    </Section>
  );
}

// ────────────────────────────────────────────────────────────────────
// Stripe placeholder
// ────────────────────────────────────────────────────────────────────
function StripePlaceholder() {
  const t = useTranslations("account");
  return (
    <Section title={t("stripeSection")}>
      <p className="font-serif text-sm text-mist mb-4">{t("stripeBody")}</p>
      <button
        type="button"
        disabled
        className="inline-flex items-center justify-center rounded-button bg-frost/10 text-mist font-mono uppercase tracking-[var(--tracking-label)] text-xs px-4 py-2 border border-frost/15 cursor-not-allowed opacity-70"
      >
        {t("stripeConnect")}
      </button>
    </Section>
  );
}

// ────────────────────────────────────────────────────────────────────
// Shared bits
// ────────────────────────────────────────────────────────────────────
const inputClass =
  "rounded-button bg-frost/5 border border-frost/15 px-3 py-2 font-mono text-sm text-frost focus:outline-none focus:border-ember w-full";
const submitBtnClass =
  "inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-60 disabled:cursor-not-allowed";

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="rounded-glass border border-glass-border/40 bg-frost/[0.04] p-6">
      <h2 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-4">
        {title}
      </h2>
      <div>{children}</div>
    </section>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="grid gap-2">
      <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">{label}</span>
      {children}
    </label>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">{label}</dt>
      <dd className="font-display text-lg text-frost mt-1">{value}</dd>
    </div>
  );
}
