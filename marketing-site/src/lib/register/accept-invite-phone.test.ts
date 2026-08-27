// Telefon przy akceptacji zaproszenia.
//
// Ścieżka samodzielnej rejestracji terapeuty opisuje numer jako
// „potrzebny ze względów bezpieczeństwa" i wymaga go od zawsze.
// Akceptacja zaproszenia go NIE zbierała — a że ten sam ekran pozwala
// założyć konto przez Google/Apple, była to cicha furtka: terapeuta
// wchodzący z zaproszenia zakładał konto personelu bez numeru.
//
// Konto klienta (PATIENT) jest pseudonimowe (docs/43 §4) — e-mail jest
// jedynym identyfikatorem, więc tam telefonu nie ma i nie może być
// wymagany.

import { describe, expect, it } from "vitest";

import { acceptInviteSchema, clientAcceptInviteSchema } from "./schema";

const base = {
  email: "terapeuta@example.com",
  password: "Sup3rwizor!x",
  uiLanguage: "pl" as const,
  hasAcceptedTos: true as const,
  firstName: "Jan",
  lastName: "Kowalski",
  modalityId: "44f77c8e-8a71-4770-96f3-42e13297a7e8",
};

describe("acceptInviteSchema (THERAPIST / ORG_ADMIN)", () => {
  it("odrzuca brak numeru telefonu", () => {
    const r = acceptInviteSchema.safeParse(base);
    expect(r.success).toBe(false);
  });

  it("odrzuca numer w złym formacie", () => {
    const r = acceptInviteSchema.safeParse({ ...base, phoneNumber: "123" });
    expect(r.success).toBe(false);
  });

  // Uwaga na dobór numeru: walidator celowo odrzuca ciągi rosnące i
  // malejące (np. +48123456789) jako oczywiste fałszywki, więc test
  // musi używać numeru, który wygląda jak prawdziwy.
  it("przyjmuje poprawny numer", () => {
    const r = acceptInviteSchema.safeParse({
      ...base,
      phoneNumber: "+48512837461",
    });
    expect(r.success).toBe(true);
  });
});

describe("clientAcceptInviteSchema (PATIENT)", () => {
  it("przechodzi bez telefonu — konto klienta jest pseudonimowe", () => {
    const { firstName, lastName, ...withoutNames } = base;
    void firstName;
    void lastName;
    const r = clientAcceptInviteSchema.safeParse(withoutNames);
    expect(r.success).toBe(true);
  });
});
