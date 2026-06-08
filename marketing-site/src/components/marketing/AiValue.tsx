"use client";

import { useLocale } from "next-intl";

export function AiValue() {
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  const features = locale === "en"
    ? [
        { icon: "brain", title: "Modality-aware reports", body: "The AI understands your therapeutic approach. Reports adapt to CBT, psychodynamic, gestalt, and other modalities." },
        { icon: "memory", title: "Clinical memory across sessions", body: "The system connects threads from previous sessions. You see the full picture before each meeting." },
        { icon: "shield", title: "Safe by design", body: "Audio deleted after transcription. Envelope encryption. EU servers. GDPR-ready with DPA included." },
      ]
    : [
        { icon: "brain", title: "Raporty dopasowane do nurtu", body: "AI rozumie Twoje podejście terapeutyczne. Raporty dostosowują się do CBT, psychodynamiki, gestaltu i innych modalności." },
        { icon: "memory", title: "Pamięć kliniczna między sesjami", body: "System łączy wątki z poprzednich sesji. Widzisz pełny obraz klienta przed każdym spotkaniem." },
        { icon: "shield", title: "Bezpieczeństwo w standardzie", body: "Audio usuwane po transkrypcji. Szyfrowanie kopertowe. Serwery w UE. Zgodność z RODO i gotowa umowa DPA." },
      ];

  return (
    <section className="relative w-full bg-gradient-to-b from-[#002E32] to-[#001A1D] text-frost py-20 sm:py-24 overflow-hidden border-y border-frost/5">
      {/* === Dense full-width icon field === */}
      <div className="absolute inset-0 pointer-events-none select-none flex justify-between px-1 sm:px-2 lg:px-4" aria-hidden="true">
        <IconCol icons={colA} speed={22} dir="up" className="block" />
        <IconCol icons={colC} speed={28} dir="down" className="hidden md:block" />
        <IconCol icons={colB} speed={25} dir="up" className="hidden lg:block" />
        <IconCol icons={colD} speed={32} dir="down" className="hidden md:block" />
        <IconCol icons={colE} speed={27} dir="up" className="hidden lg:block" />
        <IconCol icons={colA} speed={34} dir="down" className="hidden md:block" />
        <IconCol icons={colF} speed={23} dir="up" className="hidden sm:block" />
        <IconCol icons={colC} speed={30} dir="down" className="hidden md:block" />
        <IconCol icons={colD} speed={26} dir="up" className="hidden lg:block" />
        <IconCol icons={colB} speed={29} dir="down" className="hidden md:block" />
        <IconCol icons={colE} speed={31} dir="up" className="hidden lg:block" />
        <IconCol icons={colF} speed={24} dir="down" className="hidden md:block" />
        <IconCol icons={colA} speed={33} dir="up" className="hidden sm:block" />
        <IconCol icons={colD} speed={28} dir="down" className="hidden md:block" />
        <IconCol icons={colC} speed={22} dir="up" className="hidden lg:block" />
        <IconCol icons={colB} speed={35} dir="down" className="hidden md:block" />
        <IconCol icons={colE} speed={26} dir="up" className="hidden lg:block" />
        <IconCol icons={colF} speed={30} dir="down" className="block" />
      </div>

      {/* Center fade — wide radial mask so text area is clear */}
      <div className="absolute inset-0 pointer-events-none z-10 bg-[radial-gradient(ellipse_55%_65%_at_50%_50%,rgba(0,46,50,0.97)_0%,rgba(0,46,50,0.85)_35%,rgba(0,46,50,0.4)_65%,transparent_100%)]" />

      {/* Top/bottom fade */}
      <div className="absolute inset-x-0 top-0 h-24 bg-gradient-to-b from-[#002E32] to-transparent pointer-events-none z-10" />
      <div className="absolute inset-x-0 bottom-0 h-24 bg-gradient-to-t from-[#001A1D] to-transparent pointer-events-none z-10" />

      {/* Content — above icons */}
      <div className="relative mx-auto w-full max-w-[1080px] px-6 z-20">
        <div className="text-center mb-14">
          <h2 className="font-display text-frost text-2xl sm:text-3xl lg:text-4xl font-bold tracking-tight leading-tight max-w-3xl mx-auto">
            {locale === "en"
              ? "A tool built for psychotherapy. Designed with care and attention to your needs."
              : "Narzędzie stworzone dla psychoterapii. Z uwagą i starannością na Twoje potrzeby."}
          </h2>
          <p className="font-sans text-frost/60 text-base sm:text-lg mt-4 max-w-2xl mx-auto leading-relaxed">
            {locale === "en"
              ? "Every report is generated through prompts designed by clinical specialists, tailored to your modality and your way of working."
              : "Każdy raport generowany jest przez prompty zaprojektowane ze specjalistami klinicznymi, dopasowane do Twojego nurtu i sposobu pracy."}
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          {features.map((f, i) => (
            <div key={i} className="rounded-[20px] bg-[#001A1D]/80 backdrop-blur-sm border border-white/[0.06] p-7 hover:bg-white/[0.06] hover:border-white/[0.1] transition-all duration-300">
              <div className="w-10 h-10 rounded-full bg-ember/10 border border-ember/20 flex items-center justify-center mb-5">
                <FeatureIcon name={f.icon} />
              </div>
              <h3 className="font-display text-frost text-base font-semibold tracking-tight mb-2">{f.title}</h3>
              <p className="font-sans text-frost/45 text-sm leading-relaxed">{f.body}</p>
            </div>
          ))}
        </div>

        <div className="mt-12 text-center">
          <a href="#cennik" className="inline-flex items-center justify-center rounded-[12px] bg-frost text-[#004D54] font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 hover:bg-white transition-all duration-200 active:scale-[0.97] whitespace-nowrap">
            {locale === "en" ? "Start for free" : "Rozpocznij za darmo"}
            <span className="ml-2">→</span>
          </a>
        </div>
      </div>

      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes scroll-up { 0% { transform: translateY(0); } 100% { transform: translateY(-50%); } }
        @keyframes scroll-down { 0% { transform: translateY(-50%); } 100% { transform: translateY(0); } }
      `}} />
    </section>
  );
}

/* ─── Single icon column — 4x repeat for seamless loop ───────── */
function IconCol({ icons, speed, dir, className }: { icons: React.ReactNode[]; speed: number; dir: "up" | "down"; className?: string }) {
  // Quadruple the list so there's always enough content for seamless scrolling
  const quad = [...icons, ...icons, ...icons, ...icons];
  return (
    <div className={`w-6 sm:w-7 shrink-0 h-full overflow-hidden opacity-[0.05] md:opacity-[0.12] ${className || ""}`}>
      <div className="flex flex-col gap-3 sm:gap-4 py-2" style={{ animation: `scroll-${dir} ${speed}s linear infinite` }}>
        {quad.map((ic, i) => <div key={i} className="w-6 sm:w-7 h-6 sm:h-7 flex items-center justify-center shrink-0">{ic}</div>)}
      </div>
    </div>
  );
}


/* ─── 12 icon columns (diverse themes) ───────────────────────── */
const C = "w-6 h-6 sm:w-7 sm:h-7 text-frost";
const S = "1.2";

// People & conversation
const colA = [
  <svg key="1" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="7" r="4"/><path d="M5.5 21c0-4.1 2.9-7.5 6.5-7.5s6.5 3.4 6.5 7.5"/></svg>,
  <svg key="2" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>,
  <svg key="3" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z"/></svg>,
  <svg key="4" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/></svg>,
  <svg key="5" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/></svg>,
  <svg key="6" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M12 22V12"/><path d="M5 12c0-4.5 3-7 7-7s7 2.5 7 7"/></svg>,
];
// Brain & AI
const colB = [
  <svg key="1" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M12 2a7 7 0 00-7 7c0 2.38 1.19 4.47 3 5.74V17a2 2 0 002 2h4a2 2 0 002-2v-2.26c1.81-1.27 3-3.36 3-5.74a7 7 0 00-7-7z"/><path d="M9 21h6"/></svg>,
  <svg key="2" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/></svg>,
  <svg key="3" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>,
  <svg key="4" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>,
  <svg key="5" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>,
  <svg key="6" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>,
];
// Security & privacy
const colC = [
  <svg key="1" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>,
  <svg key="2" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>,
  <svg key="3" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>,
  <svg key="4" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/></svg>,
  <svg key="5" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 11-7.778 7.778 5.5 5.5 0 017.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>,
  <svg key="6" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M22 11.08V12a10 10 0 11-5.93-9.14"/><path d="M22 4L12 14.01l-3-3"/></svg>,
];
// Health & growth
const colD = [
  <svg key="1" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M8 2h8v6h6v8h-6v6H8v-6H2V8h6z"/></svg>,
  <svg key="2" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M17 18a5 5 0 00-10 0"/><line x1="12" y1="9" x2="12" y2="2"/><line x1="4.22" y1="10.22" x2="5.64" y2="11.64"/><line x1="1" y1="18" x2="3" y2="18"/><line x1="21" y1="18" x2="23" y2="18"/><line x1="18.36" y1="11.64" x2="19.78" y2="10.22"/></svg>,
  <svg key="3" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><path d="M14 2v6h6"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>,
  <svg key="4" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/></svg>,
  <svg key="5" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z"/></svg>,
  <svg key="6" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="M9 12l2 2 4-4"/></svg>,
];
// Documents & data
const colE = [
  <svg key="1" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><path d="M14 2v6h6"/></svg>,
  <svg key="2" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M12 2a7 7 0 00-7 7c0 2.38 1.19 4.47 3 5.74V17a2 2 0 002 2h4a2 2 0 002-2v-2.26c1.81-1.27 3-3.36 3-5.74a7 7 0 00-7-7z"/><path d="M9 21h6"/></svg>,
  <svg key="3" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>,
  <svg key="4" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>,
  <svg key="5" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>,
  <svg key="6" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>,
];
// Mixed therapy
const colF = [
  <svg key="1" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/></svg>,
  <svg key="2" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>,
  <svg key="3" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>,
  <svg key="4" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>,
  <svg key="5" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M12 22V12"/><path d="M5 12c0-4.5 3-7 7-7s7 2.5 7 7"/></svg>,
  <svg key="6" className={C} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={S} strokeLinecap="round" strokeLinejoin="round"><path d="M8 2h8v6h6v8h-6v6H8v-6H2V8h6z"/></svg>,
];
// colA–colF are used directly in the IconCol grid above.
// Aliases colG–colL were removed as unused dead code.

/* ─── Feature card icons ─────────────────────────────────────── */
function FeatureIcon({ name }: { name: string }) {
  const cls = "w-4.5 h-4.5 text-ember";
  switch (name) {
    case "brain": return <svg className={cls} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d="M12 2a7 7 0 00-7 7c0 2.38 1.19 4.47 3 5.74V17a2 2 0 002 2h4a2 2 0 002-2v-2.26c1.81-1.27 3-3.36 3-5.74a7 7 0 00-7-7z"/><path d="M9 21h6M10 17v4M14 17v4"/></svg>;
    case "memory": return <svg className={cls} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/></svg>;
    case "shield": return <svg className={cls} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="M9 12l2 2 4-4"/></svg>;
    default: return null;
  }
}
