// Client wrapper that reads ?email= from the URL and renders the
// "we sent it to <email>" intro line. Lives separately from the
// surrounding page shell so the page can stay statically exportable
// — the email value isn't known until the user actually hits the
// route after signup.

"use client";

import { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";

function Inner() {
  const t = useTranslations("register.verifyEmail");
  const params = useSearchParams();
  const email = params?.get("email") ?? "";

  return (
    <p className="font-serif text-mist mt-4 leading-relaxed">
      {t("intro", { email })}
    </p>
  );
}

export function VerifyEmailIntro() {
  return (
    <Suspense fallback={null}>
      <Inner />
    </Suspense>
  );
}
