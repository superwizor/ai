// Regresja: katalog nurtow nie moze wymyslac identyfikatorow.
//
// Tlo. `users.default_modality_id` ma wiez `fk_users_default_modality`
// REFERENCES modalities(id). Galaz awaryjna tego modulu zwracala kiedys
// katalog z UUID-ami, ktorych w bazie nie ma (33e66b8d-..., 44f77c8e-...).
// Zapis takiego id konczyl sie SQLSTATE 23503, UpdateProfile zwracal 500,
// a uzytkownik w onboardingu widzial "Nie udalo sie zapisac preferencji"
// i nie mogl przejsc dalej. Pusty katalog jest poprawna odpowiedzia na
// awarie — wywolujacy ma pokazac blad, a nie zapisac zmyslone dane.

import { describe, it, expect, vi, beforeEach } from "vitest";

const listModalities = vi.fn();

vi.mock("@/lib/connect/clients", () => ({
  clinicalClient: {
    listModalities: (...args: unknown[]) => listModalities(...args),
  },
}));

import { getModalityCatalog, pickModality } from "./modalities";

/** UUID-y, ktore kiedys tu stały na sztywno i nie istnieja w bazie. */
const ZMYSLONE = [
  "33e66b8d-8a71-4770-96f3-42e13297a7e7",
  "44f77c8e-8a71-4770-96f3-42e13297a7e8",
  "55a88c9f-8a71-4770-96f3-42e13297a7e9",
  "66b99ca0-8a71-4770-96f3-42e13297a7ea",
  "77caaab1-8a71-4770-96f3-42e13297a7eb",
  "88dbbbc2-8a71-4770-96f3-42e13297a7ec",
];

describe("getModalityCatalog", () => {
  beforeEach(() => {
    listModalities.mockReset();
    vi.spyOn(console, "error").mockImplementation(() => {});
  });

  it("zwraca pusty katalog, gdy ListModalities padnie", async () => {
    listModalities.mockRejectedValue(new Error("unavailable"));

    const rows = await getModalityCatalog();

    expect(rows).toEqual([]);
  });

  it("nie zwraca zadnego zmyslonego identyfikatora po awarii", async () => {
    listModalities.mockRejectedValue(new Error("unavailable"));

    const rows = await getModalityCatalog();
    const ids = rows.map((r) => r.id);

    for (const bogus of ZMYSLONE) {
      expect(ids).not.toContain(bogus);
    }
  });

  it("nie rzuca wyjatkiem po awarii (AccountSections nie ma .catch())", async () => {
    listModalities.mockRejectedValue(new Error("unavailable"));

    await expect(getModalityCatalog()).resolves.toBeDefined();
  });

  it("przepuszcza identyfikatory serwera bez podmiany", async () => {
    listModalities.mockResolvedValue({
      modalities: [
        {
          id: "081ce34d-43d2-4215-b7f9-8120ac2e430c",
          systemCode: "UNIV",
          displayName: "Universal / Integrative",
          isSupported: true,
        },
        {
          id: "dd8d84ff-16a5-470a-95cc-4b5a99e61f6b",
          systemCode: "CBT",
          displayName: "Cognitive Behavioural",
          isSupported: true,
        },
      ],
    });

    const rows = await getModalityCatalog();

    expect(rows.map((r) => r.id)).toEqual([
      "081ce34d-43d2-4215-b7f9-8120ac2e430c",
      "dd8d84ff-16a5-470a-95cc-4b5a99e61f6b",
    ]);
  });

  it("lokalizuje etykiety po system_code, zachowujac id", async () => {
    listModalities.mockResolvedValue({
      modalities: [
        {
          id: "081ce34d-43d2-4215-b7f9-8120ac2e430c",
          systemCode: "UNIV",
          displayName: "Universal / Integrative",
          isSupported: true,
        },
      ],
    });

    const [row] = await getModalityCatalog();

    expect(row.id).toBe("081ce34d-43d2-4215-b7f9-8120ac2e430c");
    expect(row.labels.pl).toBeTruthy();
    expect(row.labels.en).toBeTruthy();
  });
});

describe("pickModality", () => {
  const row = (systemCode: string, id: string) => ({
    id,
    systemCode,
    displayName: systemCode,
    labels: { pl: systemCode, en: systemCode },
    isSupported: true,
  });
  const CATALOG = [
    row("UNIV", "081ce34d-43d2-4215-b7f9-8120ac2e430c"),
    row("CBT", "dd8d84ff-16a5-470a-95cc-4b5a99e61f6b"),
  ];

  it("zwraca wiersz o zadanym system_code", () => {
    expect(pickModality(CATALOG, "CBT")?.id).toBe("dd8d84ff-16a5-470a-95cc-4b5a99e61f6b");
  });

  it("dla pominietego kroku (UNIV) zwraca id z katalogu, nie stala", () => {
    expect(pickModality(CATALOG, "UNIV")?.id).toBe("081ce34d-43d2-4215-b7f9-8120ac2e430c");
  });

  it("spada na UNIV, gdy zadanego kodu nie ma w katalogu", () => {
    expect(pickModality(CATALOG, "NIEZNANY")?.systemCode).toBe("UNIV");
  });

  it("zwraca undefined dla pustego katalogu — bez wymyslania id", () => {
    expect(pickModality([], "UNIV")).toBeUndefined();
  });

  it("zwraca undefined, gdy katalog nie zawiera ani zadanego kodu, ani UNIV", () => {
    expect(pickModality([row("CBT", "dd8d84ff-16a5-470a-95cc-4b5a99e61f6b")], "GESTALT")).toBeUndefined();
  });
});
