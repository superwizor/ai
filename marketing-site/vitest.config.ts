import { defineConfig } from "vitest/config";
import tsconfigPaths from "vite-tsconfig-paths";

// Testy jednostkowe czystej logiki. Przepływy w przeglądarce pokrywa
// Playwright (tests/e2e) — te dwa zestawy celowo się nie dublują:
// tam sprawdzamy, że ekran działa, tutaj że reguła jest poprawna.
//
// include ograniczone do src/, żeby vitest nie próbował zbierać
// tests/e2e/*.spec.ts — pliki Playwrighta nie uruchamiają się pod
// vitestem i wywaliłyby cały przebieg.
export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
    environment: "node",
    globals: false,
  },
});
