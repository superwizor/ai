"use client";

import { useTranslations, useLocale } from "next-intl";

export function Hero() {
  const t = useTranslations("hero");
  const tb = useTranslations("b.hero");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";
  const isPl = locale === "pl";

  return (
    <section className="relative w-full bg-gradient-to-b from-[#001114] via-[#002E32] to-[#004D54] text-frost overflow-hidden border-b border-frost/5">
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes rotateBeam {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        .animate-rotate-beam { animation: rotateBeam 6s linear infinite; }
        
        @keyframes hero-fade-up {
          from { opacity: 0; transform: translateY(20px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .hero-s1 { animation: hero-fade-up 0.8s ease-out 0.1s both; }
        .hero-s2 { animation: hero-fade-up 0.8s ease-out 0.3s both; }
        .hero-s3 { animation: hero-fade-up 0.8s ease-out 0.5s both; }
        .hero-s4 { animation: hero-fade-up 0.8s ease-out 0.7s both; }
        .hero-s5 { animation: hero-fade-up 0.8s ease-out 0.9s both; }

        @keyframes floaty {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-8px); }
        }
        .animate-floaty-1 { animation: floaty 5s ease-in-out infinite; }
        .animate-floaty-2 { animation: floaty 5s ease-in-out infinite 0.8s; }
      `}} />

      {/* Subtle background glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[80vw] max-w-[900px] h-[500px] bg-gradient-to-b from-ember/[0.06] to-transparent blur-[140px] pointer-events-none rounded-full" />

      <div className="relative pt-20 sm:pt-28 lg:pt-36 pb-20 lg:pb-28">
        <div className="relative mx-auto w-full max-w-[1080px] px-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
            
            {/* Left Column: Copy & Actions */}
            <div className="lg:col-span-7 flex flex-col items-center lg:items-start text-center lg:text-left">
              {/* Overline */}
              <div className="hero-s1 inline-flex items-center gap-2.5 mb-8">
                <span className="w-6 h-px bg-gradient-to-r from-transparent to-ember/50" />
                <span className="font-mono text-[10px] sm:text-[11px] uppercase tracking-[3px] text-ember/80 font-medium">
                  {t("overline")}
                </span>
                <span className="w-6 h-px bg-gradient-to-l from-transparent to-ember/50 lg:hidden" />
              </div>

              {/* Heading */}
              <h1 className="hero-s2 font-display text-frost text-4xl sm:text-5xl md:text-6xl font-bold tracking-tight leading-[1.08] mb-6 max-w-2xl">
                {t("headingPrefix")}
              </h1>

              {/* Subtitle */}
              <p className="hero-s3 font-serif text-mist/75 text-base sm:text-lg md:text-xl leading-relaxed max-w-xl mb-10">
                {tb("subtitle")}
              </p>

              {/* CTA Buttons */}
              <div className="hero-s4 flex flex-col sm:flex-row items-center gap-3 w-full sm:w-auto">
                <a
                  href={`${prefix}/register/therapist`}
                  className="group relative inline-flex items-center justify-center rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 transition-all duration-300 active:scale-[0.97] w-full sm:w-auto whitespace-nowrap overflow-hidden"
                >
                  <span className="absolute inset-0 rounded-[12px] bg-ember/40 blur-xl group-hover:blur-2xl transition-all duration-500 -z-10 scale-110" />
                  <span className="relative z-10 flex items-center gap-2">
                    {t("ctaPrimary")}
                    <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
                  </span>
                </a>
                <a
                  href="#features"
                  className="inline-flex items-center justify-center rounded-[12px] border border-frost/12 text-frost/80 font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 hover:bg-frost/[0.04] hover:border-frost/20 transition-all duration-300 active:scale-[0.97] w-full sm:w-auto whitespace-nowrap backdrop-blur-sm"
                >
                  {t("ctaSecondary")}
                </a>
              </div>

              {/* Co-created Microtext with Icon */}
              <div className="hero-s4 mt-8 inline-flex items-center justify-center gap-2.5 font-mono text-xs sm:text-[12.5px] uppercase text-frost/85 tracking-[1.5px] font-semibold self-center">
                <svg className="w-[18px] h-[18px] text-ember shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76z" />
                  <path d="m9 12 2 2 4-4" />
                </svg>
                <span>{tb("microtext")}</span>
              </div>
            </div>

            {/* Right Column: HTML Phone Mockup with Floating Badges */}
            <div className="lg:col-span-5 flex justify-center lg:justify-end relative">
              <div className="hero-s5 relative w-[290px] transition-transform duration-500 hover:scale-[1.01] z-10">
                
                {/* Large white backlighting glow for clean, high contrast */}
                <div className="absolute -inset-24 bg-[radial-gradient(circle_at_center,rgba(255,255,255,0.12),transparent_70%)] blur-[80px] pointer-events-none animate-pulse [animation-duration:8s]" />
                <div className="absolute -inset-10 bg-[radial-gradient(circle_at_center,rgba(255,255,255,0.06),transparent_60%)] blur-[40px] pointer-events-none" />
                
                {/* Floating Badge 1: Top-Left */}
                <div className="absolute top-[58px] -left-4 sm:top-[58px] sm:-left-8 z-20 bg-white border border-[#e2ded5] rounded-xl px-2 py-1.5 sm:px-3.5 sm:py-2.5 shadow-[0_12px_32px_-12px_rgba(27,37,34,0.3)] flex items-center gap-1.5 sm:gap-2.5 animate-floaty-1">
                  <svg className="w-3.5 h-3.5 sm:w-4.5 sm:h-4.5 text-[#2f6b62] shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                    <polyline points="9 15 11 17 15 13" />
                  </svg>
                  <div className="flex flex-col text-left">
                    <span className="font-sans text-[11px] sm:text-[13px] font-bold text-[#1b2522] leading-tight">
                      {isPl ? "Raport gotowy" : "Report ready"}
                    </span>
                    <span className="font-sans text-[9px] sm:text-[10.5px] font-semibold text-[#4e5a55]/90 mt-0.5 leading-tight">
                      {isPl ? "Dane bezpieczne" : "Data secure"}
                    </span>
                  </div>
                </div>
                
                {/* Floating Badge 2: Bottom-Right */}
                <div className="absolute bottom-[70px] -right-4 sm:bottom-[90px] sm:-right-8 z-20 bg-white border border-[#e2ded5] rounded-xl px-2 py-1.5 sm:px-3.5 sm:py-2.5 shadow-[0_12px_32px_-12px_rgba(27,37,34,0.3)] flex items-center gap-1.5 sm:gap-2 animate-floaty-2">
                  <svg className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-[#2f6b62] shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                    <polyline points="9 11 11 13 15 9" />
                  </svg>
                  <span className="font-sans text-[11px] sm:text-[13px] font-bold text-[#1b2522]">
                    {isPl ? "Zgodne z RODO" : "GDPR compliant"}
                  </span>
                </div>

                {/* Rotating Border Beam Frame */}
                <div className="relative w-full rounded-[42px] p-[1.5px] overflow-hidden bg-white/[0.06]" style={{ boxShadow: '0 20px 80px rgba(0,0,0,0.5), 0 0 120px rgba(252,174,47,0.06)' }}>
                  <div className="absolute inset-[-100%] bg-[conic-gradient(from_0deg,transparent_75%,rgba(252,174,47,0.2)_85%,#FCAE2F_92%,#FAFAFA_97%,white_99%,transparent_100%)] animate-rotate-beam pointer-events-none" />
                  
                  {/* Phone Shell */}
                  <div className="relative w-full rounded-[40.5px] p-3 overflow-hidden bg-[#10211d] border border-[#0b1714]">
                    {/* Notch */}
                    <div className="absolute top-3 left-1/2 -translate-x-1/2 w-[120px] h-[26px] bg-[#10211d] rounded-b-2xl z-30" />
                    
                    {/* Inner Screen Content */}
                    <div className="relative w-full rounded-[30px] overflow-hidden bg-[#0d2729] p-4 pt-10 min-h-[500px] text-white select-none">
                      
                      {/* Fake Status Bar */}
                      <div className="absolute top-1 left-0 right-0 px-6 flex justify-between items-center text-[10px] text-white/70 font-sans z-20">
                        <span className="font-semibold flex items-center gap-1">
                          20:37 <span className="text-[8px]">👤</span>
                        </span>
                        <div className="flex items-center gap-1.5">
                          {/* signal bars */}
                          <div className="flex items-end gap-[1px] h-2">
                            <div className="w-[1.5px] h-[3px] bg-white" />
                            <div className="w-[1.5px] h-[4.5px] bg-white" />
                            <div className="w-[1.5px] h-[6px] bg-white" />
                            <div className="w-[1.5px] h-[7.5px] bg-white" />
                          </div>
                          {/* wifi */}
                          <svg className="w-2.5 h-2.5 fill-current" viewBox="0 0 24 24">
                            <path d="M12 21l-12-12c4-4 9-6 12-6s8 2 12 6l-12 12z" />
                          </svg>
                          {/* battery */}
                          <div className="w-5 h-2.5 border border-white/60 rounded-[3px] p-[1px] flex items-center">
                            <div className="h-full w-full bg-emerald-400 rounded-[1px]" />
                          </div>
                        </div>
                      </div>
 
                      {/* Fake App Bar */}
                      <div className="flex justify-between items-center mt-3 mb-5 px-1">
                        <div className="flex items-center gap-2">
                           {/* Brandmark SVG Logo */}
                           <svg className="w-5.5 h-5.5 fill-current text-white shrink-0" viewBox="0 0 1200 1200" xmlns="http://www.w3.org/2000/svg">
                             <path d="M600,0C269.17,0,0,269.17,0,600s269.17,600,600,600,600-269.17,600-600S930.83,0,600,0ZM600,1144.8c-300.4,0-544.8-244.4-544.8-544.8S299.6,55.2,600,55.2s544.8,244.4,544.8,544.8-244.4,544.8-544.8,544.8Z"/>
                             <path d="M729.21,278.76c5.62,0,10.17-4.55,10.17-10.17v-33.33c0-5.62-4.55-10.17-10.17-10.17h-212.62c-5.62,0-10.17,4.55-10.17,10.17v33.33c0,5.62,4.55,10.17,10.17,10.17h39.67v156.04h-39.67c-5.62,0-10.17,4.55-10.17,10.17v34.18c0,5.62,4.55,10.17,10.17,10.17h39.67v258.04h-39.67c-5.62,0-10.17,4.55-10.17,10.17v34.18c0,5.62,4.55,10.17,10.17,10.17h15.96c-8.55,9.24-14.57,20.23-17.18,32.12-12.75,2.81-24.67,9.19-34.28,18.78-27.29,27.34-27.29,71.83.03,99.19,9.62,9.58,21.51,15.96,34.23,18.76,2.8,12.76,9.19,24.67,18.81,34.25,13.23,13.24,30.85,20.54,49.58,20.54s36.35-7.3,49.56-20.53c9.62-9.61,16.01-21.51,18.81-34.26,12.72-2.81,24.64-9.19,34.23-18.77,27.37-27.35,27.37-71.84,0-99.2-9.62-9.58-21.51-15.94-34.23-18.76-2.62-11.91-8.65-22.89-17.21-32.12h18.54c5.62,0,10.17-4.55,10.17-10.17v-34.18c0-5.62-4.55-10.17-10.17-10.17h-42.22v-258.04h118c5.62,0,10.17-4.55,10.17-10.17v-34.18c0-5.62-4.55-10.17-10.17-10.17h-118v-51.6h68.16c5.62,0,10.17-4.56,10.17-10.17v-31.24c0-5.62-4.55-10.17-10.17-10.17h-68.16v-52.85h118ZM542.52,875.2c7.44,0,13.46-6.02,13.46-13.46,0-15.35,12.45-27.8,27.8-27.8s26.93,11.99,27.44,26.9c-.02.31,0,.58,0,.89,0,7.43,6.02,13.46,13.46,13.46h.71c15.35,0,27.8,12.45,27.8,27.8s-12.45,27.8-27.8,27.8h-.71c-7.43,0-13.46,6.02-13.46,13.46,0,.37-.03.68,0,1.05-.42,14.99-12.35,27.05-27.44,27.05s-27.8-12.45-27.8-27.8v-.3c0-7.43-6.02-13.46-13.46-13.46h-.45c-15.35,0-27.8-12.45-27.8-27.8s12.45-27.8,27.8-27.8h.45Z"/>
                           </svg>
                          <span className="font-sans font-bold text-xs tracking-wide">Superwizor AI</span>
                        </div>
                        {/* Hamburger icon */}
                        <svg className="w-4 h-4 text-white/90" fill="none" stroke="currentColor" strokeWidth="2.2" viewBox="0 0 24 24">
                          <line x1="4" y1="6" x2="20" y2="6" />
                          <line x1="4" y1="12" x2="20" y2="12" />
                          <line x1="4" y1="18" x2="20" y2="18" />
                        </svg>
                      </div>
 
                      {/* Greeting */}
                      <div className="px-1 mb-4">
                        <div className="font-serif text-2xl font-medium leading-tight">
                          {isPl ? (
                            <>Witaj, <span className="text-amber font-bold italic">Marku :)</span></>
                          ) : (
                            <>Hello, <span className="text-amber font-bold italic">Marc :)</span></>
                          )}
                        </div>
                        <div className="text-[11px] text-[#8ba4a6] mt-0.5">
                          {isPl ? "Z kim dzisiaj pracujemy?" : "Who are we working with today?"}
                        </div>
                      </div>
 
                      {/* Search Bar */}
                      <div className="bg-[#133235] border border-[#1b4043] rounded-lg px-3 py-1.5 flex items-center gap-2 mb-3 mx-1">
                        <svg className="w-3.5 h-3.5 text-[#8ba4a6]" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                          <circle cx="11" cy="11" r="8" />
                          <line x1="21" y1="21" x2="16.65" y2="16.65" />
                        </svg>
                        <span className="text-[11px] text-[#8ba4a6]">
                          {isPl ? "Szukaj klienta..." : "Search client..."}
                        </span>
                      </div>

                      {/* Security Badge */}
                      <div className="bg-[#0f3c32]/40 border border-[#2f6b62]/40 rounded-lg px-2.5 py-1.5 flex items-center gap-2 mb-4 mx-1">
                        <svg className="w-3.5 h-3.5 text-[#5bf4bc] shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                          <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                          <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                        </svg>
                        <span className="font-sans text-[10px] font-semibold text-[#5bf4bc] tracking-wide">
                          {isPl ? "Bezpieczne i szyfrowane dane" : "Secure & encrypted data"}
                        </span>
                      </div>
 
                      {/* Section Header */}
                      <div className="flex justify-between items-center px-1 mb-2">
                        <span className="font-sans text-[10px] uppercase font-bold tracking-wider text-[#8ba4a6]">
                          {isPl ? "Twoje kartoteki" : "Your records"}
                        </span>
                        <span className="font-sans text-[10px] text-[#8ba4a6] font-semibold">4</span>
                      </div>
 
                      {/* Client List */}
                      <div className="space-y-2 px-0.5 max-h-[200px] overflow-hidden">
                        
                        {/* Item 1 */}
                        <div className="bg-[#163639] border border-[#1d4447]/60 rounded-xl p-2.5 flex items-center justify-between shadow-sm">
                          <div className="flex items-center gap-2.5">
                            <div className="w-8 h-8 rounded-full bg-[#526466] flex items-center justify-center font-sans font-bold text-xs text-white">
                              PI
                            </div>
                            <div>
                              <div className="font-sans text-[13px] font-bold text-white">
                                {isPl ? "Próbny Pacjent" : "Demo Patient"}
                              </div>
                              <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                {isPl ? "Sesje: 4 · Ostatnio: 31 Maj" : "Sessions: 4 · Last: May 31"}
                              </div>
                            </div>
                          </div>
                          <span className="text-[#8ba4a6] text-xs">⋮</span>
                        </div>
 
                        {/* Item 2 */}
                        <div className="bg-[#163639] border border-[#1d4447]/60 rounded-xl p-2.5 flex items-center justify-between shadow-sm">
                          <div className="flex items-center gap-2.5">
                            <div className="w-8 h-8 rounded-full bg-[#d6855c] flex items-center justify-center text-[15px]">
                              👍
                            </div>
                            <div>
                              <div className="font-sans text-[13px] font-bold text-white">
                                {isPl ? "Kuba Pacjent" : "Jacob Patient"}
                              </div>
                              <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                {isPl ? "Sesje: 2 · Ostatnio: 28 Maj" : "Sessions: 2 · Last: May 28"}
                              </div>
                            </div>
                          </div>
                          <span className="text-[#8ba4a6] text-xs">⋮</span>
                        </div>
 
                        {/* Item 3 */}
                        <div className="bg-[#163639] border border-[#1d4447]/60 rounded-xl p-2.5 flex items-center justify-between shadow-sm">
                          <div className="flex items-center gap-2.5">
                            <div className="w-8 h-8 rounded-full bg-[#586fa6] flex items-center justify-center text-[15px]">
                              🧘
                            </div>
                            <div>
                              <div className="font-sans text-[13px] font-bold text-white">
                                {isPl ? "Paweł" : "Paul"}
                              </div>
                              <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                {isPl ? "Sesje: 1 · Ostatnio: 28 Maj" : "Sessions: 1 · Last: May 28"}
                              </div>
                            </div>
                          </div>
                          <span className="text-[#8ba4a6] text-xs">⋮</span>
                        </div>
 
                        {/* Item 4 */}
                        <div className="bg-[#163639] border border-[#1d4447]/60 rounded-xl p-2.5 flex items-center justify-between shadow-sm">
                          <div className="flex items-center gap-2.5">
                            <div className="w-8 h-8 rounded-full bg-[#a35b5b] flex items-center justify-center text-[14px]">
                              ✨
                            </div>
                            <div className="min-w-0">
                              <div className="font-sans text-[13px] font-bold text-white flex items-center gap-1.5 flex-wrap">
                                <span className="truncate">
                                  {isPl ? "Nagraniowiec" : "Recorder Client"}
                                </span>
                                <span className="bg-[#1b5042] text-[#5bf4bc] text-[8px] px-1.5 py-0.5 rounded-full font-bold flex items-center gap-1 shrink-0">
                                  <span className="w-1 h-1 rounded-full bg-[#5bf4bc]" /> 
                                  {isPl ? "Nowy raport" : "New report"}
                                </span>
                              </div>
                              <div className="font-sans text-[10px] text-[#8ba4a6] mt-0.5">
                                {isPl ? "Ostatnio: 11 Maj" : "Last: May 11"}
                              </div>
                            </div>
                          </div>
                          <span className="text-[#8ba4a6] text-xs">⋮</span>
                        </div>
 
                      </div>
 
                      {/* collapsed section "WSTRZYMANE (3)" */}
                      <div className="flex items-center gap-1.5 px-1 mt-4 text-[#8ba4a6] opacity-60">
                        <svg className="w-3 h-3" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                          <polyline points="6 9 12 15 18 9" />
                        </svg>
                        <span className="font-sans text-[10px] uppercase font-bold tracking-wider">
                          {isPl ? "Wstrzymane (3)" : "Paused (3)"}
                        </span>
                      </div>

                      {/* FAB button */}
                      <div className="absolute bottom-4 right-4 w-11 h-11 rounded-full bg-[#ffb12c] hover:bg-[#e2991b] shadow-lg flex items-center justify-center text-[#0d2729] cursor-pointer transition active:scale-95 z-20">
                        <svg className="w-6 h-6 stroke-[3]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <line x1="12" y1="5" x2="12" y2="19" />
                          <line x1="5" y1="12" x2="19" y2="12" />
                        </svg>
                      </div>

                    </div>
                  </div>
                </div>

              </div>
            </div>

          </div>
        </div>
      </div>
    </section>
  );
}
