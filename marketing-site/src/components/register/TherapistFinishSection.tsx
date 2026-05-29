// Client wrapper around TherapistFinishForm — reads email/firstName/
// lastName from URL search params at runtime so the parent page can
// stay statically exportable. The personalised "Hi {firstName}"
// subhead is rendered here via useTranslations (next-intl's client
// hook) — passing a function from the server component to here would
// break server-component serialisation.
//
// Note (2026-05-28): the `modalities` prop is gone. TherapistFinishForm
// now fetches the catalogue itself via clinical-svc.ListModalities
// (anonymous, allowlisted). This Section just shuttles the OAuth
// profile fields from the URL into the form.

"use client";

import { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";

import { TherapistFinishForm } from "./TherapistFinishForm";

function Inner() {
  const t = useTranslations("register.therapist");
  const params = useSearchParams();
  const email = params?.get("email") ?? "";
  const firstName = params?.get("firstName") ?? "";
  const lastName = params?.get("lastName") ?? "";

  return (
    <>
      <p className="font-serif text-mist text-center mt-4 max-w-md mx-auto text-base leading-relaxed">
        {firstName
          ? t("finishSubhead", { firstName })
          : t("finishGenericSubhead")}
      </p>
      <div className="mt-10">
        <TherapistFinishForm
          email={email}
          firstName={firstName}
          lastName={lastName}
        />
      </div>
    </>
  );
}

export function TherapistFinishSection() {
  return (
    <Suspense fallback={null}>
      <Inner />
    </Suspense>
  );
}
