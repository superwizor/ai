// bumpPatch — propozycja numeru dla wersji rozgałęzionej z zatwierdzonej.
//
// Rozgałęzienie jest JEDYNĄ drogą edycji wersji `approved`
// (niemutowalność zastąpiła niemutowalność commita), więc numer musi
// się proponować sam — inaczej autor przy każdej poprawce wpisuje go
// ręcznie i prędzej czy później nadpisze istniejący.

import { describe, it, expect } from "vitest";

import { bumpPatch } from "./OntologyStudio";

describe("bumpPatch", () => {
  it("podbija składnik PATCH", () => {
    expect(bumpPatch("0.1.0")).toBe("0.1.1");
    expect(bumpPatch("1.2.9")).toBe("1.2.10");
    expect(bumpPatch("2.0.0")).toBe("2.0.1");
  });

  it("nie rusza MAJOR ani MINOR", () => {
    // Rozgałęzienie z zatwierdzonej wersji częściej jest poprawką niż
    // zmianą taksonomii — wybór konserwatywny jest tu celowy.
    expect(bumpPatch("3.4.5")).toBe("3.4.6");
  });

  it("zwraca wejście bez zmian, gdy to nie semver", () => {
    // Cichy fallback zamiast wyjątku: pole numeru wersji jest edytowalne,
    // a walidacja i tak jest serwerowa (semver musi zgadzać się z treścią).
    expect(bumpPatch("v1")).toBe("v1");
    expect(bumpPatch("")).toBe("");
    expect(bumpPatch("1.0")).toBe("1.0");
  });

  it("znosi otaczające spacje", () => {
    expect(bumpPatch("  1.0.0  ")).toBe("1.0.1");
  });
});
