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
import { useTranslations } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";
import { ConnectError, Code } from "@connectrpc/connect";

import { useAuth } from "@/lib/firebase/auth-provider";
import { identityClient, billingClient } from "@/lib/connect/clients";
import { GetSubscriptionRequestSchema } from "@superwizor/proto-ts/billing/v1/billing_pb";
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
      {/* Email + sign-out + kartoteki link. Sizes here are 20% bigger
          than the original spec — email label 10→12px, hint xs→sm
          (12→14px), kartoteki CTA xs→sm with bigger padding, sign-out
          link 10→12px. Keeps proportions intact while reading more
          comfortably on a desktop browser. */}
      <header className="rounded-glass border border-glass-border/40 bg-frost/[0.04] p-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <p className="font-mono text-[12px] uppercase tracking-[var(--tracking-label)] text-mist">
            {fbUser.email}
          </p>
          <p className="font-serif text-sm text-mist/70 mt-1">
            {t("emailReadOnly")}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <OpenKartotekiButton email={fbUser.email ?? ""} />
          <button
            type="button"
            onClick={() => signOut()}
            className="font-mono text-[12px] uppercase tracking-[var(--tracking-label)] text-mist hover:text-ember transition"
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
      <OrgSection profile={profile} />
      <BillingSection organizationId={profile?.organizationId ?? null} />
      <StripePlaceholder />
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────
// Otwórz kartoteki — cross-origin SSO into the Flutter web app
// ────────────────────────────────────────────────────────────────────
//
// Firebase Auth IndexedDB is origin-scoped, so a signed-in user on
// superwizor.web.app has NO session on superwizor-app.web.app. We
// bridge by calling identity-svc.MintAppLoginToken (returns a
// short-lived Firebase custom token) and handing it to the Flutter
// origin via URL fragment (#auth_token=...). The Flutter app reads
// the hash on bootstrap, calls signInWithCustomToken, then strips
// the hash from the URL.
//
// Why fragment, not query: the hash isn't sent to the server, isn't
// stored in server access logs, and isn't included in the Referer
// header on cross-origin links. Defence-in-depth for a credential
// that's already short-lived (~1h).
//
// UX detail — popup blocking: window.open() must be called
// synchronously inside the click handler or Safari/Firefox block
// it. We open a placeholder window first, mint the token, then set
// the window's location. If the mint fails we still navigate to
// the Flutter origin with just the email prefill so the user can
// type their password — degrades to the pre-SSO behaviour.
function OpenKartotekiButton({ email }: { email: string }) {
  const t = useTranslations("account");
  const [busy, setBusy] = useState(false);

  const onClick = async () => {
    if (busy) return;
    setBusy(true);
    // Open the popup IMMEDIATELY (during the user-gesture frame) so
    // browser popup heuristics let it through. We update its
    // location after the mint completes.
    const popup = window.open("about:blank", "_blank");
    try {
      const res = await identityClient.mintAppLoginToken(create(EmptySchema, {}));
      const token = res?.token ?? "";
      // Fragment shape: #auth_token=<jwt>&email=<email>. Email kept
      // around purely so the Flutter app can still pre-fill on the
      // very rare path where signInWithCustomToken fails and falls
      // through to the email login form.
      const url = token
        ? `${APP_URL}#auth_token=${encodeURIComponent(token)}&email=${encodeURIComponent(email)}`
        : `${APP_URL}?email=${encodeURIComponent(email)}`;
      if (popup) {
        popup.location.href = url;
      } else {
        // Popup blocked anyway — best-effort: navigate the current
        // tab. Loses the marketing-site /account context, but better
        // than silently failing.
        window.location.href = url;
      }
    } catch (e) {
      console.error("[account] mintAppLoginToken failed", e);
      // Graceful degradation: open the Flutter app with just the
      // email prefill, exactly like the pre-SSO version did.
      const fallback = `${APP_URL}?email=${encodeURIComponent(email)}`;
      if (popup) popup.location.href = fallback;
      else window.location.href = fallback;
    } finally {
      setBusy(false);
    }
  };

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={busy}
      className="inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-5 py-2.5 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-60 disabled:cursor-progress"
      title={t("kartotekiHint")}
    >
      {busy ? t("kartotekiOpening") : t("kartotekiCta")} →
    </button>
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
    return <Section title={t("profileSection")} collapsible defaultOpen={false}>{t("orgLoading")}</Section>;
  }

  return (
    <Section title={t("profileSection")} collapsible defaultOpen={false}>
      <form onSubmit={onSubmit} className="grid gap-4" noValidate>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("firstName")} large>
            <input
              type="text"
              value={draft.firstName}
              onChange={(e) => setDraft((d) => ({ ...d, firstName: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
          <Field label={t("lastName")} large>
            <input
              type="text"
              value={draft.lastName}
              onChange={(e) => setDraft((d) => ({ ...d, lastName: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
        </div>
        <Field label={t("phoneNumber")} large>
          <input
            type="tel"
            value={draft.phoneNumber}
            onChange={(e) => setDraft((d) => ({ ...d, phoneNumber: e.target.value }))}
            className={inputClassLg}
          />
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("professionalTitle")} large>
            <input
              type="text"
              value={draft.professionalTitle}
              onChange={(e) => setDraft((d) => ({ ...d, professionalTitle: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
          <Field label={t("credentialsNumber")} large>
            <input
              type="text"
              value={draft.credentialsNumber}
              onChange={(e) => setDraft((d) => ({ ...d, credentialsNumber: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
        </div>
        <Field label={t("biography")} large>
          <textarea
            rows={3}
            value={draft.biography}
            onChange={(e) => setDraft((d) => ({ ...d, biography: e.target.value }))}
            className={`${inputClassLg} resize-y`}
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
function OrgSection({ profile }: { profile: User | null }) {
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
    return <Section title={t("orgSection")} collapsible defaultOpen={false}>{t("orgLoading")}</Section>;
  }
  if (phase === "noOrg") {
    return <Section title={t("orgSection")} collapsible defaultOpen={false}>{t("orgNone")}</Section>;
  }
  if (phase === "notAllowed") {
    return (
      <Section title={t("orgSection")} collapsible defaultOpen={false}>
        <p className="font-serif text-sm text-mist">{t("orgNotAllowed")}</p>
      </Section>
    );
  }
  if (phase === "error") {
    return <Section title={t("orgSection")} collapsible defaultOpen={false}>{t("errLoad")}</Section>;
  }

  return (
    <Section title={t("orgSection")} collapsible defaultOpen={false}>
      <form onSubmit={onSubmit} className="grid gap-4" noValidate>
        <Field label={t("legalName")} large>
          <input
            type="text"
            value={draft.legalName}
            onChange={(e) => setDraft((d) => ({ ...d, legalName: e.target.value }))}
            className={inputClassLg}
          />
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("taxId")} large>
            <input
              type="text"
              value={draft.taxId}
              onChange={(e) => setDraft((d) => ({ ...d, taxId: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
          <Field label={t("vatIdEu")} large>
            <input
              type="text"
              value={draft.vatIdEu}
              onChange={(e) => setDraft((d) => ({ ...d, vatIdEu: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
        </div>

        {/* HQ address — flat inputs; AddressFields wasn't reused
            because it lives under /admin and is tied to an admin
            UpdateUserParams shape. Keep this lightweight. */}
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="Ulica" large>
            <input
              type="text"
              value={draft.streetLine}
              onChange={(e) => setDraft((d) => ({ ...d, streetLine: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
          <Field label="Nr budynku" large>
            <input
              type="text"
              value={draft.buildingNumber}
              onChange={(e) => setDraft((d) => ({ ...d, buildingNumber: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
          <Field label="Nr lokalu" large>
            <input
              type="text"
              value={draft.unitNumber}
              onChange={(e) => setDraft((d) => ({ ...d, unitNumber: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="Kod pocztowy" large>
            <input
              type="text"
              value={draft.postalCode}
              onChange={(e) => setDraft((d) => ({ ...d, postalCode: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
          <Field label="Miasto" large>
            <input
              type="text"
              value={draft.city}
              onChange={(e) => setDraft((d) => ({ ...d, city: e.target.value }))}
              className={inputClassLg}
            />
          </Field>
          <Field label="Województwo" large>
            <input
              type="text"
              value={draft.region}
              onChange={(e) => setDraft((d) => ({ ...d, region: e.target.value }))}
              className={inputClassLg}
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
// Subscription (read-only — calls billing-svc directly, bypassing the
// clinical-svc.GetMyBillingState proxy because that hop intermittently
// returns PROTOCOL_ERROR (RST_STREAM) inside Cloud Run. The admin
// /admin/orgs ZMIEŃ PLAN button uses the same direct billingClient
// pattern and works reliably. The backend GetSubscription handler
// enforces caller-org scope so any authenticated user can only fetch
// their own organization's subscription (SUPERWIZOR_ADMIN bypasses).
// ────────────────────────────────────────────────────────────────────
function BillingSection({ organizationId }: { organizationId: string | null }) {
  const t = useTranslations("account");
  const [sub, setSub] = useState<Subscription | null>(null);
  const [phase, setPhase] = useState<"loading" | "ready" | "none" | "error">("loading");

  useEffect(() => {
    // Wait until the profile arrives — we need organizationId to scope
    // the call. While we wait we stay in "loading" so the section
    // doesn't flash an empty state.
    if (!organizationId) return;
    let cancelled = false;
    (async () => {
      try {
        const s = await billingClient.getSubscription(
          create(GetSubscriptionRequestSchema, { organizationId }),
        );
        if (cancelled) return;
        if (!s || !s.planTier) {
          setPhase("none");
        } else {
          setSub(s);
          setPhase("ready");
        }
      } catch (e) {
        // Distinguish "no active subscription" (NotFound) and "user
        // has no organization" (FailedPrecondition) from real errors.
        // Both manifest as ConnectError; show the calmer "no
        // subscription" copy instead of the alarming generic banner.
        // Anything else still becomes the error state — kept for
        // debugging visibility.
        if (e instanceof ConnectError &&
            (e.code === Code.NotFound || e.code === Code.FailedPrecondition)) {
          if (!cancelled) setPhase("none");
          return;
        }
        console.error("[account] load subscription failed", e);
        if (!cancelled) setPhase("error");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [organizationId]);

  if (phase === "loading") return <Section title={t("billingSection")}>{t("billingLoading")}</Section>;
  if (phase === "none") {
    // No subscription yet — give the user a CTA placeholder for the
    // future Stripe-driven plan picker. Same disabled-button language
    // as the active-sub upgrade CTA below so the two states feel
    // consistent.
    return (
      <Section title={t("billingSection")}>
        <p className="font-serif text-sm text-mist mb-4">{t("billingNone")}</p>
        <UpgradeCta label={t("billingNoneCta")} hint={t("billingUpgradeHint")} />
      </Section>
    );
  }
  if (phase === "error")   return <Section title={t("billingSection")}>{t("errLoad")}</Section>;
  if (!sub)                return <Section title={t("billingSection")}>{t("billingNone")}</Section>;

  const total = sub.tokensPerPeriod;
  const used = sub.tokensUsedThisPeriod + sub.tokensReservedThisPeriod;
  const left = Math.max(0, total - used);
  const pct = total > 0 ? Math.min(100, Math.round((used / total) * 100)) : 0;
  const planName = planLabel(t, sub.planTier);
  const statusName = statusLabel(t, sub.status);
  const periodEnd = sub.currentPeriodEnd
    ? new Date(Number(sub.currentPeriodEnd.seconds) * 1000).toLocaleDateString()
    : "—";

  return (
    <Section title={t("billingSection")}>
      <dl className="grid gap-3 sm:grid-cols-2">
        <Stat label={t("billingPlanName")}    value={planName} />
        <Stat label={t("billingStatus")}      value={statusName} />
        <Stat label={t("billingTokensLeft")}  value={String(left)} />
        <Stat label={t("billingTokensTotal")} value={String(total)} />
        <Stat label={t("billingPeriodEnd")}   value={periodEnd} />
      </dl>

      {/* Usage bar — visual reinforcement of "tokens left / total" so
          the user can eyeball where they are in the cycle. */}
      {total > 0 && (
        <div className="mt-6">
          <div className="h-2 w-full rounded-full bg-frost/10 overflow-hidden">
            <div
              className="h-full bg-ember transition-all"
              style={{ width: `${pct}%` }}
            />
          </div>
          <p className="mt-2 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist/70">
            {t("billingUsedBar", { used: used, total: total })}
          </p>
        </div>
      )}

      <div className="mt-6">
        <UpgradeCta label={t("billingUpgrade")} hint={t("billingUpgradeHint")} />
      </div>
    </Section>
  );
}

// Disabled CTA placeholder for the future Stripe-driven plan upgrade
// flow. Looks like a primary button so the user knows where the
// action will live; hover reveals the "coming soon" hint.
function UpgradeCta({ label, hint }: { label: string; hint: string }) {
  return (
    <button
      type="button"
      disabled
      title={hint}
      className="inline-flex items-center justify-center rounded-button bg-ember/70 text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] cursor-not-allowed opacity-80"
    >
      {label}
    </button>
  );
}

// planLabel + statusLabel map raw enum strings off the wire to
// localised display copy. Falls back to the raw value if a new tier /
// status lands before we update the i18n table — visible but ugly,
// which is the right default.
function planLabel(t: ReturnType<typeof useTranslations>, raw: string): string {
  if (!raw) return "—";
  const k = `plan${raw.toUpperCase()}`;
  try {
    const val = t(k);
    if (val && val !== k) return val;
  } catch {}
  return raw;
}
function statusLabel(t: ReturnType<typeof useTranslations>, raw: string): string {
  if (!raw) return "—";
  const k = `status${raw.toUpperCase()}`;
  try {
    const val = t(k);
    if (val && val !== k) return val;
  } catch {}
  return raw;
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
// inputClass removed — superseded by inputClassLg (20% larger variant).
// 20% larger variant for the Profil + Organizacja sections per the
// 2026-05-29 design tweak. Bumps label (10px→12px), input (14px→17px,
// roughly text-base + a tenth) and uses py-2.5 to keep proportions.
const inputClassLg =
  "rounded-button bg-frost/5 border border-frost/15 px-3 py-2.5 font-mono text-[17px] text-frost focus:outline-none focus:border-ember w-full";
const submitBtnClass =
  "inline-flex items-center justify-center rounded-button bg-ember text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-sm px-6 py-3 shadow-[var(--shadow-ember-glow)] hover:brightness-110 transition disabled:opacity-60 disabled:cursor-not-allowed";

function Section({
  title,
  children,
  collapsible = false,
  defaultOpen = true,
}: {
  title: string;
  children: React.ReactNode;
  collapsible?: boolean;
  defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);
  if (!collapsible) {
    return (
      <section className="rounded-glass border border-glass-border/40 bg-frost/[0.04] p-6">
        <h2 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-4">
          {title}
        </h2>
        <div>{children}</div>
      </section>
    );
  }
  return (
    <section className="rounded-glass border border-glass-border/40 bg-frost/[0.04] p-6">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="flex w-full items-center justify-between gap-4 text-left"
      >
        <h2 className="font-mono text-[12px] uppercase tracking-[var(--tracking-overline)] text-ember">
          {title}
        </h2>
        <span
          aria-hidden="true"
          className={`font-mono text-xs text-mist/70 transition-transform ${open ? "rotate-180" : ""}`}
        >
          ▾
        </span>
      </button>
      {open && <div className="mt-4">{children}</div>}
    </section>
  );
}

function Field({
  label,
  children,
  large = false,
}: {
  label: string;
  children: React.ReactNode;
  large?: boolean;
}) {
  // `large` shifts the label up from 10px to 12px (also 20% bigger)
  // so it stays proportional to the bigger input next to it.
  const labelClass = large
    ? "font-mono text-[12px] uppercase tracking-[var(--tracking-label)] text-mist"
    : "font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist";
  return (
    <label className="grid gap-2">
      <span className={labelClass}>{label}</span>
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
