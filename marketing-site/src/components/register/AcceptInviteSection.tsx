// Client wrapper around AcceptInviteForm — reads the magic-link
// token from URL search params at runtime so the parent page can
// stay statically exportable. The server component shell used to
// read `searchParams` directly which forced dynamic rendering and
// broke the Firebase Hosting static-export deploy.
//
// Note (2026-05-28): the `modalities` prop is gone. AcceptInviteForm
// now fetches the catalogue itself via clinical-svc.ListModalities
// (anonymous, allowlisted). The Section only needs to hand off the
// token + the "no token" copy.

"use client";

import { useSearchParams } from "next/navigation";
import { Suspense } from "react";

import { AcceptInviteForm } from "./AcceptInviteForm";

type Props = {
  missingTokenMessage: string;
};

function AcceptInviteSectionInner({ missingTokenMessage }: Props) {
  const params = useSearchParams();
  const token = params?.get("token") ?? "";

  if (!token) {
    return (
      <p
        role="alert"
        className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-sm text-frost text-center"
      >
        {missingTokenMessage}
      </p>
    );
  }

  return <AcceptInviteForm token={token} />;
}

export function AcceptInviteSection(props: Props) {
  // useSearchParams() requires a Suspense boundary in App Router —
  // otherwise the static prerender bails. Empty fallback is fine
  // here; the form area is below the hero copy which has already
  // rendered.
  return (
    <Suspense fallback={null}>
      <AcceptInviteSectionInner {...props} />
    </Suspense>
  );
}
