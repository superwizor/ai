"use client";

import { useLocale } from "next-intl";

/* ────────────────────────────────────────────────────────────
 * Refined SVG glyphs — single-stroke, monochromatic (frost/ember).
 * Each glyph sits inside a 20×20 viewBox, thin stroke (1.2-1.5),
 * soft round caps. Matches the premium feel of the CtaBand.
 * ──────────────────────────────────────────────────────────── */
const GLYPHS = [
  // Fingerprint (identity / privacy)
  <svg key="g1" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round">
    <path d="M10 3a7 7 0 0 0-7 7" /><path d="M10 3a7 7 0 0 1 7 7" />
    <path d="M10 6a4 4 0 0 0-4 4" /><path d="M10 6a4 4 0 0 1 4 4v2" />
    <path d="M10 9a1 1 0 0 0-1 1v3" /><path d="M10 9a1 1 0 0 1 1 1v4" />
  </svg>,
  // Shield with check
  <svg key="g2" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M10 2l6 2.5v4c0 4-2.5 7-6 8.5-3.5-1.5-6-4.5-6-8.5v-4L10 2Z" />
    <path d="M7.5 10l2 2 3.5-3.5" />
  </svg>,
  // Lock (minimal)
  <svg key="g3" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="5" y="9" width="10" height="7" rx="1.5" />
    <path d="M7 9V7a3 3 0 0 1 6 0v2" />
    <circle cx="10" cy="12.5" r="0.8" fill="currentColor" stroke="none" />
  </svg>,
  // Eye with slash (no watching)
  <svg key="g4" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M3 3l14 14" />
    <path d="M8.5 8.8a2 2 0 0 0 2.7 2.7" />
    <path d="M4 10s2.5-4 6-4c.8 0 1.5.2 2.2.4" />
    <path d="M16 10s-2.5 4-6 4c-.8 0-1.5-.2-2.2-.4" />
  </svg>,
  // Server rack (EU data)
  <svg key="g5" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="4" y="3" width="12" height="5" rx="1" /><rect x="4" y="11" width="12" height="5" rx="1" />
    <circle cx="7" cy="5.5" r="0.6" fill="currentColor" stroke="none" />
    <circle cx="7" cy="13.5" r="0.6" fill="currentColor" stroke="none" />
    <line x1="9.5" y1="5.5" x2="13" y2="5.5" /><line x1="9.5" y1="13.5" x2="13" y2="13.5" />
  </svg>,
  // Waveform/audio (deleting)
  <svg key="g6" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round">
    <line x1="4" y1="10" x2="4" y2="10.01" />
    <line x1="6.5" y1="7" x2="6.5" y2="13" />
    <line x1="9" y1="5" x2="9" y2="15" />
    <line x1="11.5" y1="7" x2="11.5" y2="13" />
    <line x1="14" y1="8" x2="14" y2="12" />
    <line x1="16" y1="10" x2="16" y2="10.01" />
  </svg>,
  // Document with seal
  <svg key="g7" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M6 2h5l4 4v10a1.5 1.5 0 0 1-1.5 1.5h-7A1.5 1.5 0 0 1 5 16V3.5A1.5 1.5 0 0 1 6.5 2Z" />
    <path d="M11 2v4h4" />
    <line x1="7.5" y1="10" x2="12.5" y2="10" /><line x1="7.5" y1="13" x2="11" y2="13" />
  </svg>,
  // Brain/neural (AI)
  <svg key="g8" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="10" cy="6" r="1.5" /><circle cx="6" cy="11" r="1.5" /><circle cx="14" cy="11" r="1.5" /><circle cx="10" cy="15.5" r="1.5" />
    <line x1="10" y1="7.5" x2="6.8" y2="9.8" /><line x1="10" y1="7.5" x2="13.2" y2="9.8" />
    <line x1="6.8" y1="12.2" x2="9" y2="14.5" /><line x1="13.2" y1="12.2" x2="11" y2="14.5" />
  </svg>,
];

export function AiSecurityBand() {
  const locale = useLocale();

  // Build rows of glyphs for smooth infinite scroll — 24 items each
  const buildRow = (offset: number) => {
    const list = [];
    for (let i = 0; i < 24; i++) {
      list.push(GLYPHS[(i + offset) % GLYPHS.length]);
    }
    return list;
  };

  const row1 = buildRow(0);
  const row2 = buildRow(3);
  const row3 = buildRow(5);

  return (
    <section className="relative w-full bg-[#002E32] py-28 sm:py-32 overflow-hidden">
      {/* Section-scoped animations */}
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes scrollGlyphRight {
          0% { transform: translate3d(-50%, 0, 0); }
          100% { transform: translate3d(0, 0, 0); }
        }
        @keyframes scrollGlyphLeft {
          0% { transform: translate3d(0, 0, 0); }
          100% { transform: translate3d(-50%, 0, 0); }
        }
        .glyph-row-1 { animation: scrollGlyphRight 100s linear infinite; }
        .glyph-row-2 { animation: scrollGlyphLeft 80s linear infinite; }
        .glyph-row-3 { animation: scrollGlyphRight 110s linear infinite; }
        @keyframes security-pulse {
          0%, 100% { box-shadow: 0 0 0 0 rgba(252,174,47,0), 0 0 40px rgba(252,174,47,0.08); }
          50% { box-shadow: 0 0 0 12px rgba(252,174,47,0), 0 0 60px rgba(252,174,47,0.15); }
        }
        .security-card-pulse { animation: security-pulse 4s ease-in-out infinite; }
      `}} />

      {/* Ultra-subtle radial glow behind center */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_50%_50%_at_50%_50%,rgba(0,77,84,0.12),transparent_70%)] pointer-events-none" />

      {/* Scrolling glyph rows — muted, monochrome */}
      <div className="absolute inset-0 flex flex-col justify-center gap-8 pointer-events-none select-none" style={{ opacity: 0.12 }}>
        {/* Row 1 */}
        <div className="flex w-full overflow-hidden">
          <div className="flex gap-10 glyph-row-1 whitespace-nowrap min-w-max">
            {[...row1, ...row1].map((glyph, idx) => (
              <div key={`r1-${idx}`} className="w-10 h-10 text-frost/60">
                {glyph}
              </div>
            ))}
          </div>
        </div>

        {/* Row 2 — opposite direction */}
        <div className="flex w-full overflow-hidden">
          <div className="flex gap-10 glyph-row-2 whitespace-nowrap min-w-max">
            {[...row2, ...row2].map((glyph, idx) => (
              <div key={`r2-${idx}`} className="w-10 h-10 text-frost/60">
                {glyph}
              </div>
            ))}
          </div>
        </div>

        {/* Row 3 */}
        <div className="flex w-full overflow-hidden">
          <div className="flex gap-10 glyph-row-3 whitespace-nowrap min-w-max">
            {[...row3, ...row3].map((glyph, idx) => (
              <div key={`r3-${idx}`} className="w-10 h-10 text-frost/60">
                {glyph}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Central content card */}
      <div className="relative mx-auto w-full max-w-[1080px] px-6 z-10">
        <div className="security-card-pulse max-w-2xl mx-auto text-center bg-gradient-to-b from-white/[0.04] to-white/[0.01] border border-white/[0.08] backdrop-blur-xl rounded-[28px] p-10 sm:p-14">
          {/* Shield glyph — refined, single-color, breathing */}
          <div className="w-14 h-14 rounded-2xl bg-white/[0.04] border border-white/[0.08] flex items-center justify-center mx-auto mb-8 text-ember/80">
            <svg className="w-7 h-7" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M10 2l6 2.5v4c0 4-2.5 7-6 8.5-3.5-1.5-6-4.5-6-8.5v-4L10 2Z" />
              <path d="M7.5 10l2 2 3.5-3.5" />
            </svg>
          </div>

          <h2 className="font-display text-frost text-2xl sm:text-3xl lg:text-4xl font-bold tracking-tight leading-tight mb-5">
            {locale === "pl" ? (
              <>
                Korzystaj z AI{" "}
                <span className="bg-gradient-to-r from-ember to-[#FFD080] bg-clip-text text-transparent">BEZPIECZNIE</span>
                <br className="hidden sm:block" />
                <span className="text-frost/80 font-semibold"> w swojej praktyce psychoterapeutycznej.</span>
              </>
            ) : (
              <>
                Use AI{" "}
                <span className="bg-gradient-to-r from-ember to-[#FFD080] bg-clip-text text-transparent">SAFELY</span>
                <br className="hidden sm:block" />
                <span className="text-frost/80 font-semibold"> in your psychotherapeutic practice.</span>
              </>
            )}
          </h2>

          <p className="font-serif text-mist/60 text-sm sm:text-base max-w-[48ch] mx-auto leading-relaxed">
            {locale === "pl"
              ? "Przechowywanie danych w UE (Warszawa/Frankfurt), pełna zgodność z RODO, gotowa umowa DPA oraz automatyczne niszczenie nagrań natychmiast po sesji."
              : "Data hosting in the EU (Warsaw/Frankfurt), full GDPR compliance, ready-to-sign DPA agreement, and automatic audio deletion right after processing."}
          </p>

          {/* Divider */}
          <div className="w-16 h-px bg-gradient-to-r from-transparent via-frost/10 to-transparent mx-auto my-8" />

          <a
            href={`${locale === "en" ? "/en" : "/pl"}/register/therapist`}
            className="group relative inline-flex items-center justify-center rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 transition-all duration-300 active:scale-[0.97] whitespace-nowrap overflow-hidden"
          >
            <span className="absolute inset-0 rounded-[12px] bg-ember/30 blur-xl group-hover:blur-2xl transition-all duration-500 -z-10 scale-110" />
            <span className="relative z-10 flex items-center gap-2">
              {locale === "pl" ? "Rozpocznij za darmo" : "Start For Free"}
              <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
            </span>
          </a>
        </div>
      </div>
    </section>
  );
}
