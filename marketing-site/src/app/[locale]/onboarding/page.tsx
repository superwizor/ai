// /onboarding — Post-registration onboarding wizard.
//
// Plan Phase 3: 6 steps
//   Step 1: Email verification (Firebase link)
//   Step 2: Profile details (first name, last name, title, license number)
//   Step 3: Phone + SMS 2FA (required, anti-abuse)
//   Step 4: Practice setup (name, size, modality)
//   Step 5: Preferences (optional checkboxes)
//   Step 6: Done → /dashboard
//
// Resume after browser close via progress stored in localStorage.

import { setRequestLocale } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { OnboardingWizard } from "@/components/onboarding/OnboardingWizard";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  return {
    title:
      locale === "en"
        ? "Set up your account · Superwizor AI"
        : "Skonfiguruj swoje konto · Superwizor AI",
    description:
      locale === "en"
        ? "Complete your profile to start using Superwizor AI."
        : "Uzupełnij swój profil, aby rozpocząć pracę z Superwizor AI.",
  };
}

export default async function OnboardingPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <>
      <Navbar variant="tunnel" />
      <main className="flex-1 bg-gradient-to-b from-[#0A2326] to-[#0D1B1E] min-h-screen">
        <OnboardingWizard locale={locale} />
      </main>
    </>
  );
}
