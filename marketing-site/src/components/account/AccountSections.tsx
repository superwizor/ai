// Therapist account management surface — Apple Settings-style layout
//
// Five category sections, each as a frosted-glass card:
//   1. TWOJE KONTO (Profile — editable profile fields + modality)
//   2. ORGANIZACJA (Org — legal name, NIP, address, etc.)
//   3. SUBSKRYPCJA (Billing — read-only + active upgrade CTA)
//   4. INFORMACJE PRAWNE (Legal links)
//   5. ZARZĄDZANIE KONTEM (Logout + delete account)
//
// Plus a header card with email + kartoteki CTA + sign-out.
// Typography: Montserrat (font-sans) for all labels, fields, headings.
// Roboto Mono (font-mono) only for tiny meta details (email badge, version).

"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useLocale } from "next-intl";
import Link from "next/link";
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

// ── Shared modality map (same IDs as Flutter's ModalitySheet) ────
const MODALITY_LABELS: Record<string, { pl: string; en: string }> = {
  MODALITY_UNIVERSAL:       { pl: "Uniwersalny", en: "Universal" },
  MODALITY_CBT:             { pl: "Poznawczo-behawioralny (CBT)", en: "Cognitive-Behavioral (CBT)" },
  MODALITY_PSYCHODYNAMIC:   { pl: "Psychodynamiczny", en: "Psychodynamic" },
  MODALITY_HUMANISTIC:      { pl: "Humanistyczno-doświadczeniowy", en: "Humanistic-Experiential" },
  MODALITY_SFBT:            { pl: "Terapia Skoncentrowana na Rozwiązaniach (TSR)", en: "Solution-Focused Brief Therapy (SFBT)" },
  MODALITY_SYSTEMIC:        { pl: "Systemowy", en: "Systemic" },
  MODALITY_EFT:             { pl: "Terapia Skoncentrowana na Emocjach (EFT)", en: "Emotionally Focused Therapy (EFT)" },
  MODALITY_INTEGRATIVE:     { pl: "Integracyjny", en: "Integrative" },
};

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

  if (!fbUser) return null;

  const prefix = locale === "en" ? "/en" : "";

  return (
    <div className="grid gap-5 max-w-2xl mx-auto">
      {/* ── Header card: email + kartoteki + sign out ─────────── */}
      <header className="rounded-2xl border border-white/[0.08] bg-white/[0.04] backdrop-blur-md p-5 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <p className="font-mono text-[11px] uppercase tracking-[0.15em] text-[#8FA5A0]">
            {fbUser.email}
          </p>
          <p className="font-sans text-[13px] text-[#8FA5A0]/70 mt-1">
            {t("emailReadOnly")}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <OpenKartotekiButton email={fbUser.email ?? ""} />
          <button
            type="button"
            onClick={() => signOut()}
            className="font-sans text-[12px] font-medium text-[#8FA5A0] hover:text-[#F5A623] transition"
          >
            {t("signOut")}
          </button>
        </div>
      </header>

      {profileError && (
        <p role="alert" className="rounded-xl border border-[#ff4444]/40 bg-[#ff4444]/10 px-4 py-3 font-sans text-sm text-[#F2F0EA]">
          {profileError}
        </p>
      )}

      {/* ── 1. TWOJE KONTO ──────────────────────────────────── */}
      <ProfileSection profile={profile} onUpdate={setProfile} locale={locale} />

      {/* ── 2. ORGANIZACJA ──────────────────────────────────── */}
      <OrgSection profile={profile} />

      {/* ── 3. SUBSKRYPCJA ──────────────────────────────────── */}
      <BillingSection organizationId={profile?.organizationId ?? null} locale={locale} />

      {/* ── 4. INFORMACJE PRAWNE ────────────────────────────── */}
      <SettingsCard>
        <SectionLabel>{t("sectionLegal")}</SectionLabel>
        <div className="divide-y divide-white/[0.06]">
          <LinkRow href={`${prefix}/legal/terms`} label={t("legalTerms")} />
          <LinkRow href={`${prefix}/legal/privacy`} label={t("legalPrivacy")} />
          <LinkRow href={`${prefix}/legal/dpa`} label={t("legalDpa")} />
        </div>
      </SettingsCard>

      {/* ── 5. ZARZĄDZANIE KONTEM ────────────────────────────── */}
      <SettingsCard>
        <SectionLabel>{t("sectionAccountMgmt")}</SectionLabel>
        <div className="divide-y divide-white/[0.06]">
          <button
            type="button"
            onClick={() => signOut()}
            className="w-full flex items-center justify-between px-4 py-3.5 hover:bg-white/[0.03] transition-colors"
          >
            <span className="font-sans text-[15px] text-[#F2F0EA]">{t("signOut")}</span>
            <ChevronRight />
          </button>
          <a
            href="mailto:kontakt@superwizor.ai?subject=Usunięcie konta"
            className="w-full flex items-center justify-between px-4 py-3.5 hover:bg-white/[0.03] transition-colors"
          >
            <div>
              <span className="font-sans text-[15px] text-[#ff4444]">{t("deleteAccount")}</span>
              <p className="font-sans text-[11px] text-[#8FA5A0]/70 mt-0.5">{t("deleteAccountHint")}</p>
            </div>
            <ChevronRight color="#ff4444" />
          </a>
        </div>
      </SettingsCard>

      {/* ── Footer version ──────────────────────────────────── */}
      <p className="text-center font-mono text-[11px] text-[#8FA5A0]/40 pb-4">
        {t("version")}
      </p>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────
// Otwórz kartoteki — cross-origin SSO into the Flutter web app
// ────────────────────────────────────────────────────────────────────
function OpenKartotekiButton({ email }: { email: string }) {
  const t = useTranslations("account");
  const [busy, setBusy] = useState(false);

  const onClick = async () => {
    if (busy) return;
    setBusy(true);
    const popup = window.open("about:blank", "_blank");
    try {
      const res = await identityClient.mintAppLoginToken(create(EmptySchema, {}));
      const token = res?.token ?? "";
      const url = token
        ? `${APP_URL}#auth_token=${encodeURIComponent(token)}&email=${encodeURIComponent(email)}`
        : `${APP_URL}?email=${encodeURIComponent(email)}`;
      if (popup) {
        popup.location.href = url;
      } else {
        window.location.href = url;
      }
    } catch (e) {
      console.error("[account] mintAppLoginToken failed", e);
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
      className="inline-flex items-center justify-center rounded-xl bg-[#F5A623] text-[#1B2522] font-sans font-bold text-[13px] uppercase tracking-wider px-5 py-2.5 shadow-[0_0_20px_rgba(245,166,35,0.2)] hover:brightness-110 transition disabled:opacity-60 disabled:cursor-progress"
      title={t("kartotekiHint")}
    >
      {busy ? t("kartotekiOpening") : t("kartotekiCta")} →
    </button>
  );
}

// ────────────────────────────────────────────────────────────────────
// Profile Section
// ────────────────────────────────────────────────────────────────────
function ProfileSection({
  profile,
  onUpdate,
  locale,
}: {
  profile: User | null;
  onUpdate: (u: User) => void;
  locale: string;
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

  // Resolve modality label
  const modalityId = profile?.defaultModalityId ?? "";
  const modalityLabel = modalityId
    ? (MODALITY_LABELS[modalityId]?.[locale as "pl" | "en"] ?? modalityId)
    : t("modalityNone");

  if (!profile) {
    return (
      <SettingsCard>
        <SectionLabel>{t("sectionProfile")}</SectionLabel>
        <p className="px-4 pb-4 font-sans text-sm text-[#8FA5A0]">{t("orgLoading")}</p>
      </SettingsCard>
    );
  }

  return (
    <SettingsCard>
      <SectionLabel>{t("sectionProfile")}</SectionLabel>
      <form onSubmit={onSubmit} className="px-4 pb-4 grid gap-4" noValidate>
        <div className="grid gap-4 sm:grid-cols-2">
          <SettingsField label={t("firstName")}>
            <input
              type="text"
              value={draft.firstName}
              onChange={(e) => setDraft((d) => ({ ...d, firstName: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
          <SettingsField label={t("lastName")}>
            <input
              type="text"
              value={draft.lastName}
              onChange={(e) => setDraft((d) => ({ ...d, lastName: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
        </div>
        <SettingsField label={t("phoneNumber")}>
          <input
            type="tel"
            value={draft.phoneNumber}
            onChange={(e) => setDraft((d) => ({ ...d, phoneNumber: e.target.value }))}
            className={inputClass}
          />
        </SettingsField>
        <div className="grid gap-4 sm:grid-cols-2">
          <SettingsField label={t("professionalTitle")}>
            <input
              type="text"
              value={draft.professionalTitle}
              onChange={(e) => setDraft((d) => ({ ...d, professionalTitle: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
          <SettingsField label={t("credentialsNumber")}>
            <input
              type="text"
              value={draft.credentialsNumber}
              onChange={(e) => setDraft((d) => ({ ...d, credentialsNumber: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
        </div>
        <SettingsField label={t("biography")}>
          <textarea
            rows={3}
            value={draft.biography}
            onChange={(e) => setDraft((d) => ({ ...d, biography: e.target.value }))}
            className={`${inputClass} resize-y`}
          />
        </SettingsField>

        {/* Modality (read-only from profile) */}
        <SettingsField label={t("modality")}>
          <div className="flex items-center gap-2">
            <span className="inline-flex items-center px-3 py-1.5 rounded-lg bg-[#F5A623]/10 border border-[#F5A623]/20 font-sans text-[13px] font-semibold text-[#F5A623]">
              {modalityLabel}
            </span>
          </div>
        </SettingsField>

        {error && (
          <p role="alert" className="rounded-xl border border-[#ff4444]/40 bg-[#ff4444]/10 px-3 py-2 font-sans text-xs text-[#F2F0EA]">
            {error}
          </p>
        )}
        {savedAt && !error && !submitting && (
          <p role="status" className="rounded-xl border border-green-500/40 bg-green-500/10 px-3 py-2 font-sans text-xs text-[#F2F0EA]">
            {t("profileSaved")}
          </p>
        )}

        <div>
          <button type="submit" disabled={submitting} className={submitBtnClass}>
            {submitting ? t("profileSubmitting") : t("profileSubmit")}
          </button>
        </div>
      </form>
    </SettingsCard>
  );
}

// ────────────────────────────────────────────────────────────────────
// Organisation
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
    return (
      <SettingsCard>
        <SectionLabel>{t("sectionOrg")}</SectionLabel>
        <p className="px-4 pb-4 font-sans text-sm text-[#8FA5A0]">{t("orgLoading")}</p>
      </SettingsCard>
    );
  }
  if (phase === "noOrg") {
    return (
      <SettingsCard>
        <SectionLabel>{t("sectionOrg")}</SectionLabel>
        <p className="px-4 pb-4 font-sans text-sm text-[#8FA5A0]">{t("orgNone")}</p>
      </SettingsCard>
    );
  }
  if (phase === "notAllowed") {
    return (
      <SettingsCard>
        <SectionLabel>{t("sectionOrg")}</SectionLabel>
        <p className="px-4 pb-4 font-sans text-sm text-[#8FA5A0]">{t("orgNotAllowed")}</p>
      </SettingsCard>
    );
  }
  if (phase === "error") {
    return (
      <SettingsCard>
        <SectionLabel>{t("sectionOrg")}</SectionLabel>
        <p className="px-4 pb-4 font-sans text-sm text-[#8FA5A0]">{t("errLoad")}</p>
      </SettingsCard>
    );
  }

  return (
    <SettingsCard>
      <SectionLabel>{t("sectionOrg")}</SectionLabel>
      <form onSubmit={onSubmit} className="px-4 pb-4 grid gap-4" noValidate>
        <SettingsField label={t("legalName")}>
          <input
            type="text"
            value={draft.legalName}
            onChange={(e) => setDraft((d) => ({ ...d, legalName: e.target.value }))}
            className={inputClass}
          />
        </SettingsField>
        <div className="grid gap-4 sm:grid-cols-2">
          <SettingsField label={t("taxId")}>
            <input
              type="text"
              value={draft.taxId}
              onChange={(e) => setDraft((d) => ({ ...d, taxId: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
          <SettingsField label={t("vatIdEu")}>
            <input
              type="text"
              value={draft.vatIdEu}
              onChange={(e) => setDraft((d) => ({ ...d, vatIdEu: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          <SettingsField label={t("streetLine")}>
            <input
              type="text"
              value={draft.streetLine}
              onChange={(e) => setDraft((d) => ({ ...d, streetLine: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
          <SettingsField label={t("buildingNumber")}>
            <input
              type="text"
              value={draft.buildingNumber}
              onChange={(e) => setDraft((d) => ({ ...d, buildingNumber: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
          <SettingsField label={t("unitNumber")}>
            <input
              type="text"
              value={draft.unitNumber}
              onChange={(e) => setDraft((d) => ({ ...d, unitNumber: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          <SettingsField label={t("postalCode")}>
            <input
              type="text"
              value={draft.postalCode}
              onChange={(e) => setDraft((d) => ({ ...d, postalCode: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
          <SettingsField label={t("city")}>
            <input
              type="text"
              value={draft.city}
              onChange={(e) => setDraft((d) => ({ ...d, city: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
          <SettingsField label={t("region")}>
            <input
              type="text"
              value={draft.region}
              onChange={(e) => setDraft((d) => ({ ...d, region: e.target.value }))}
              className={inputClass}
            />
          </SettingsField>
        </div>

        {error && (
          <p role="alert" className="rounded-xl border border-[#ff4444]/40 bg-[#ff4444]/10 px-3 py-2 font-sans text-xs text-[#F2F0EA]">
            {error}
          </p>
        )}
        {savedAt && !error && !submitting && (
          <p role="status" className="rounded-xl border border-green-500/40 bg-green-500/10 px-3 py-2 font-sans text-xs text-[#F2F0EA]">
            {t("orgSaved")}
          </p>
        )}

        <div className="flex items-center gap-3">
          <button type="submit" disabled={submitting} className={submitBtnClass}>
            {submitting ? t("orgSubmitting") : t("orgSubmit")}
          </button>
          {org && (
            <span className="font-mono text-[10px] uppercase tracking-[0.15em] text-[#8FA5A0]/70">
              {t("orgType")}: {orgTypeName(org.type)}
            </span>
          )}
        </div>
      </form>
    </SettingsCard>
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
// Subscription
// ────────────────────────────────────────────────────────────────────
function BillingSection({ organizationId, locale }: { organizationId: string | null; locale: string }) {
  const t = useTranslations("account");
  const [sub, setSub] = useState<Subscription | null>(null);
  const [phase, setPhase] = useState<"loading" | "ready" | "none" | "error">("loading");
  const prefix = locale === "en" ? "/en" : "";

  useEffect(() => {
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

  if (phase === "loading") {
    return (
      <SettingsCard>
        <SectionLabel>{t("sectionBilling")}</SectionLabel>
        <p className="px-4 pb-4 font-sans text-sm text-[#8FA5A0]">{t("billingLoading")}</p>
      </SettingsCard>
    );
  }
  if (phase === "none") {
    return (
      <SettingsCard>
        <SectionLabel>{t("sectionBilling")}</SectionLabel>
        <div className="px-4 pb-4">
          <p className="font-sans text-sm text-[#8FA5A0] mb-1">{t("billingNone")}</p>
          <p className="font-sans text-[13px] text-[#8FA5A0]/60 mb-4">{t("billingNoneBody")}</p>
          <UpgradeLink href={`${prefix}/upgrade`} label={t("billingNoneCta")} />
        </div>
      </SettingsCard>
    );
  }
  if (phase === "error") {
    return (
      <SettingsCard>
        <SectionLabel>{t("sectionBilling")}</SectionLabel>
        <p className="px-4 pb-4 font-sans text-sm text-[#8FA5A0]">{t("errLoad")}</p>
      </SettingsCard>
    );
  }
  if (!sub) {
    return (
      <SettingsCard>
        <SectionLabel>{t("sectionBilling")}</SectionLabel>
        <p className="px-4 pb-4 font-sans text-sm text-[#8FA5A0]">{t("billingNone")}</p>
      </SettingsCard>
    );
  }

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
    <SettingsCard>
      <SectionLabel>{t("sectionBilling")}</SectionLabel>
      <div className="px-4 pb-4">
        <div className="grid gap-3 sm:grid-cols-2 mb-5">
          <StatRow label={t("billingPlanName")} value={planName} />
          <StatRow label={t("billingStatus")} value={statusName} />
          <StatRow label={t("billingTokensLeft")} value={String(left)} />
          <StatRow label={t("billingTokensTotal")} value={String(total)} />
          <StatRow label={t("billingPeriodEnd")} value={periodEnd} />
        </div>

        {/* Usage bar */}
        {total > 0 && (
          <div className="mb-5">
            <div className="h-2.5 w-full rounded-full bg-white/[0.06] overflow-hidden">
              <div
                className="h-full rounded-full bg-gradient-to-r from-[#F5A623] to-[#E09500] transition-all"
                style={{ width: `${pct}%` }}
              />
            </div>
            <p className="mt-2 font-sans text-[11px] text-[#8FA5A0]/70">
              {t("billingUsedBar", { used, total })}
            </p>
          </div>
        )}

        <UpgradeLink href={`${prefix}/upgrade`} label={t("billingUpgrade")} />
      </div>
    </SettingsCard>
  );
}

// Active upgrade link → navigates to /upgrade page
function UpgradeLink({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="inline-flex items-center justify-center rounded-xl bg-[#F5A623] text-[#1B2522] font-sans font-bold text-[13px] uppercase tracking-wider px-6 py-3 shadow-[0_0_20px_rgba(245,166,35,0.2)] hover:brightness-110 hover:shadow-[0_0_30px_rgba(245,166,35,0.3)] transition-all"
    >
      {label}
    </Link>
  );
}

// planLabel + statusLabel map raw enum strings to localised copy
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
// Shared UI components — Apple Settings style
// ────────────────────────────────────────────────────────────────────

const inputClass =
  "rounded-xl bg-white/[0.04] border border-white/[0.08] px-3.5 py-2.5 font-sans text-[15px] text-[#F2F0EA] focus:outline-none focus:border-[#F5A623]/50 focus:ring-1 focus:ring-[#F5A623]/20 w-full transition placeholder:text-[#8FA5A0]/40";

const submitBtnClass =
  "inline-flex items-center justify-center rounded-xl bg-[#F5A623] text-[#1B2522] font-sans font-bold text-[13px] uppercase tracking-wider px-6 py-3 shadow-[0_0_20px_rgba(245,166,35,0.2)] hover:brightness-110 transition disabled:opacity-60 disabled:cursor-not-allowed";

function SettingsCard({ children }: { children: React.ReactNode }) {
  return (
    <section className="rounded-2xl border border-white/[0.08] bg-white/[0.04] backdrop-blur-md overflow-hidden">
      {children}
    </section>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <h2 className="px-4 pt-4 pb-2 font-sans text-[11px] font-bold uppercase tracking-[0.15em] text-[#8FA5A0]">
      {children}
    </h2>
  );
}

function SettingsField({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="grid gap-1.5">
      <span className="font-sans text-[12px] font-medium uppercase tracking-wider text-[#8FA5A0]">
        {label}
      </span>
      {children}
    </label>
  );
}

function StatRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="font-sans text-[11px] font-medium uppercase tracking-wider text-[#8FA5A0]">{label}</dt>
      <dd className="font-sans text-lg font-semibold text-[#F2F0EA] mt-0.5">{value}</dd>
    </div>
  );
}

function LinkRow({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="flex items-center justify-between px-4 py-3.5 hover:bg-white/[0.03] transition-colors"
    >
      <span className="font-sans text-[15px] text-[#F2F0EA]">{label}</span>
      <ChevronRight />
    </Link>
  );
}

function ChevronRight({ color = "#8FA5A0" }: { color?: string }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="opacity-40 flex-shrink-0">
      <polyline points="9 18 15 12 9 6" />
    </svg>
  );
}
