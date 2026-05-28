// Auth gate for /account. If the visitor isn't signed in on this
// origin, bounce them to /login. If they're signed in, render the
// account surface. Keeps the page shell server-rendered while
// putting the redirect decision on the client (auth state lives in
// Firebase's IndexedDB).

"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useLocale } from "next-intl";

import { useAuth } from "@/lib/firebase/auth-provider";
import { AccountSections } from "./AccountSections";

export function AccountGuard() {
  const router = useRouter();
  const locale = useLocale();
  const { status } = useAuth();

  useEffect(() => {
    if (status === "signed-out") {
      const prefix = locale === "en" ? "/en" : "/pl";
      router.replace(`${prefix}/login`);
    }
  }, [status, locale, router]);

  if (status === "loading" || status === "signed-out") {
    return null;
  }
  return <AccountSections />;
}
