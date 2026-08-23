// Dokad kieruje uzytkownika po zalogowaniu.
//
// Logika mieszkala inline w LoginForm i przez to nie miala testu — a
// pomylka w KOLEJNOSCI galezi kosztowala juz dwa incydenty: klient
// ladujacy na onboardingu terapeuty (2026-07-04) i redaktor ontologii
// prowadzony przez kreator zbierajacy numer licencji (2026-08-23). Oba
// wynikly z tego samego: galaz domyslna (`brak modalnosci`) lapie kazda
// role, ktora nie zostala nazwana wczesniej.
//
// Funkcja jest czysta, zeby dalo sie ja przetestowac bez przegladarki.

import { UserRole } from "@superwizor/proto-ts/identity/v1/identity_pb";

export type PostLoginRoute =
  | { kind: "path"; path: string; phase: "redirect_admin" | "redirect_app" }
  // SSO do panelu klienta na innym originie — nie jest sciezka Next.js.
  | { kind: "sso_client" };

export interface PostLoginProfile {
  role: unknown;
  defaultModalityId?: string;
}

const matches = (role: unknown, enumVal: UserRole, name: string) =>
  role === enumVal || role === name;

export function postLoginRoute(
  me: PostLoginProfile,
  adminPrefix: string,
): PostLoginRoute {
  const { role } = me;

  if (matches(role, UserRole.SUPERWIZOR_ADMIN, "USER_ROLE_SUPERWIZOR_ADMIN")) {
    return { kind: "path", path: `${adminPrefix}/admin/`, phase: "redirect_admin" };
  }
  // MUSI stac przed sprawdzeniem modalnosci: redaktor ontologii nie jest
  // terapeuta i nie dostanie modalnosci nigdy, wiec galaz domyslna
  // trzymalaby go w kreatorze w nieskonczonosc.
  if (matches(role, UserRole.ONTOLOGY_EDITOR, "USER_ROLE_ONTOLOGY_EDITOR")) {
    return {
      kind: "path",
      path: `${adminPrefix}/admin/ontologies/`,
      phase: "redirect_admin",
    };
  }
  if (matches(role, UserRole.PATIENT, "USER_ROLE_PATIENT")) {
    return { kind: "sso_client" };
  }
  if (matches(role, UserRole.ORG_ADMIN, "USER_ROLE_ORG_ADMIN")) {
    return { kind: "path", path: `${adminPrefix}/org/`, phase: "redirect_app" };
  }
  if (!me.defaultModalityId) {
    return { kind: "path", path: `${adminPrefix}/onboarding/`, phase: "redirect_app" };
  }
  return { kind: "path", path: `${adminPrefix}/dashboard/`, phase: "redirect_app" };
}
