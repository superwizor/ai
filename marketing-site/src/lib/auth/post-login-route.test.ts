import { describe, it, expect } from "vitest";
import { UserRole } from "@superwizor/proto-ts/identity/v1/identity_pb";

import { postLoginRoute } from "./post-login-route";

describe("postLoginRoute", () => {
  it("kieruje redaktora ontologii do Studio, a NIE na onboarding", () => {
    // Regres 2026-08-23: rola bez modalnosci wpadala do galezi domyslnej
    // i szla przez kreator terapeuty. To jest ten test.
    const r = postLoginRoute({ role: UserRole.ONTOLOGY_EDITOR }, "/pl");
    expect(r).toEqual({
      kind: "path",
      path: "/pl/admin/ontologies/",
      phase: "redirect_admin",
    });
  });

  it("kieruje redaktora ontologii tak samo przy nazwie stringowej roli", () => {
    // Connect zwraca enum liczbowo albo nazwa, zaleznie od transportu —
    // obsluga tylko jednej formy dawala cichy przelot do galezi domyslnej.
    const r = postLoginRoute({ role: "USER_ROLE_ONTOLOGY_EDITOR" }, "/en");
    expect(r).toMatchObject({ path: "/en/admin/ontologies/" });
  });

  it("redaktor ontologii z przypadkowo ustawiona modalnoscia nadal idzie do Studio", () => {
    // Kreator zdazyl zapisac modalnosc, zanim blad naprawiono. Rola ma
    // wygrywac z tym polem, inaczej naprawa dziala tylko dla nowych kont.
    const r = postLoginRoute(
      { role: UserRole.ONTOLOGY_EDITOR, defaultModalityId: "081ce34d" },
      "/pl",
    );
    expect(r).toMatchObject({ path: "/pl/admin/ontologies/" });
  });

  it("admin superwizora idzie do panelu", () => {
    expect(postLoginRoute({ role: UserRole.SUPERWIZOR_ADMIN }, "/pl")).toMatchObject({
      path: "/pl/admin/",
    });
  });

  it("pacjent idzie przez SSO, nie na sciezke Next.js", () => {
    expect(postLoginRoute({ role: UserRole.PATIENT }, "/pl")).toEqual({
      kind: "sso_client",
    });
  });

  it("admin organizacji idzie do panelu organizacji", () => {
    expect(postLoginRoute({ role: UserRole.ORG_ADMIN }, "/pl")).toMatchObject({
      path: "/pl/org/",
    });
  });

  it("terapeuta bez modalnosci idzie na onboarding", () => {
    expect(postLoginRoute({ role: UserRole.THERAPIST }, "/pl")).toMatchObject({
      path: "/pl/onboarding/",
    });
  });

  it("terapeuta z modalnoscia idzie na dashboard", () => {
    expect(
      postLoginRoute({ role: UserRole.THERAPIST, defaultModalityId: "m1" }, "/pl"),
    ).toMatchObject({ path: "/pl/dashboard/" });
  });
});
