"use client";

import { useLocale } from "next-intl";

interface Testimonial {
  quote: string;
  quoteEn: string;
  author: string;
  role: string;
  roleEn: string;
  nurt?: string;
  nurtEn?: string;
}

const TESTIMONIALS_DATA: Testimonial[] = [
  {
    quote: "To nie chodzi o czas - apka ściąga ciężar myślenia o kliencie.",
    quoteEn: "It's not about time - the app takes the cognitive load of thinking about the client off your shoulders.",
    author: "Bartek",
    role: "psychoterapeuta",
    roleEn: "psychotherapist",
    nurt: "nurt integracyjny",
    nurtEn: "integrative approach",
  },
  {
    quote: "Pozwala uniknąć utraty 30-40% informacji, które tracę przy ręcznym przygotowywaniu notatek.",
    quoteEn: "It prevents losing 30-40% of information that is normally lost when writing notes by hand.",
    author: "Katarzyna",
    role: "psychoterapeutka",
    roleEn: "psychotherapist",
    nurt: "nurt CBT",
    nurtEn: "CBT approach",
  },
  {
    quote: "Wyłapuje subtelne rzeczy w rozmowie, które łatwo przeoczyć.",
    quoteEn: "It catches subtle details in the dialogue that are very easy to miss.",
    author: "Andrzej",
    role: "psychoterapeuta",
    roleEn: "psychotherapist",
    nurt: "nurt psychodynamiczny",
    nurtEn: "psychodynamic approach",
  },
  {
    quote: "Poszerza perspektywę, ale nie zastępuje ekspertyzy - to stoper refleksyjny, pomoc w »co dalej«.",
    quoteEn: "It broadens the perspective but doesn't replace expertise - it's a reflective stop, helping with 'what's next'.",
    author: "Iwona",
    role: "psychoterapeutka",
    roleEn: "psychotherapist",
    nurt: "terapia EFT",
    nurtEn: "EFT therapy",
  },
  {
    quote: "Ja sobie odpalam apkę trzy minuty przed sesją. Zczytuję, co mieliśmy robić i już wiem, od czego zacząć.",
    quoteEn: "I launch the app three minutes before the session. I scan what we were supposed to do and know exactly where to start.",
    author: "Bartek",
    role: "psychoterapeuta",
    roleEn: "psychotherapist",
    nurt: "nurt integracyjny",
    nurtEn: "integrative approach",
  },
  {
    quote: "Doraźny superwizor po wizycie - pomoc w nadaniu kierunku pracy przy wielu pacjentach miesięcznie.",
    quoteEn: "An ad-hoc supervisor after the session - helping to steer the treatment direction with dozens of patients a month.",
    author: "Marcin",
    role: "psychoterapeuta",
    roleEn: "psychotherapist",
    nurt: "nurt Gestalt",
    nurtEn: "Gestalt approach",
  },
  {
    quote: "Pomaga w przygotowaniu do superwizji i pozwala znacząco zmniejszyć lęk z tym związany.",
    quoteEn: "It helps in preparing for supervision and significantly reduces the anxiety associated with it.",
    author: "Andrzej",
    role: "psychoterapeuta",
    roleEn: "psychotherapist",
    nurt: "nurt psychodynamiczny",
    nurtEn: "psychodynamic approach",
  },
  {
    quote: "Wyłapuje cytaty, które mogłabym przeoczyć, i daje trafne propozycje interwencji, co zmusza do refleksji.",
    quoteEn: "It catches client quotes I might have missed and suggests interventions that prompt clinical reflection.",
    author: "Katarzyna",
    role: "psychoterapeutka",
    roleEn: "psychotherapist",
    nurt: "nurt CBT",
    nurtEn: "CBT approach",
  },
  {
    quote: "Raporty dają wieloperspektywiczne spojrzenie (różne nurty), co pobudza refleksję.",
    quoteEn: "The reports provide a multi-perspective view across different modalities, which inspires deeper clinical reflection.",
    author: "Iwona",
    role: "psychoterapeutka",
    roleEn: "psychotherapist",
    nurt: "terapia EFT",
    nurtEn: "EFT therapy",
  },
  {
    quote: "Dzwonię do pięciu-sześciu kumpli i mówię: weźcie to przetestujcie, to jest genialne.",
    quoteEn: "I call five or six therapist friends and tell them: you guys have to try this out, it's brilliant.",
    author: "Bartek",
    role: "psychoterapeuta",
    roleEn: "psychotherapist",
    nurt: "nurt integracyjny",
    nurtEn: "integrative approach",
  },
  {
    quote: "99 zł miesięcznie za 30 sesji to kwota zupełnie bezbolesna, chętnie zapłacę nawet przy sporadycznym użyciu.",
    quoteEn: "99 PLN per month for 30 sessions is completely painless, I would gladly pay even for occasional use.",
    author: "Kasia",
    role: "psychoterapeutka",
    roleEn: "psychotherapist",
    nurt: "terapia pozytywna",
    nurtEn: "positive therapy",
  }
];

// Split testimonials into two sets for the two scrolling rows
const ROW1_DATA = TESTIMONIALS_DATA.slice(0, 6);
const ROW2_DATA = TESTIMONIALS_DATA.slice(5);

export function Testimonials() {
  const locale = useLocale();
  const isPl = locale === "pl";

  return (
    <section className="relative w-full bg-gradient-to-b from-[#001A1D] to-[#002e32] text-frost py-24 overflow-hidden border-y border-frost/5">
      <style dangerouslySetInnerHTML={{
        __html: `
        @keyframes marquee {
          0% { transform: translateX(0); }
          100% { transform: translateX(-50%); }
        }
        @keyframes marquee-reverse {
          0% { transform: translateX(-50%); }
          100% { transform: translateX(0); }
        }
        .animate-marquee-row {
          display: flex;
          width: max-content;
          animation: marquee 95s linear infinite;
        }
        .animate-marquee-row-reverse {
          display: flex;
          width: max-content;
          animation: marquee-reverse 95s linear infinite;
        }
        .marquee-container:hover .animate-marquee-row,
        .marquee-container:hover .animate-marquee-row-reverse {
          animation-play-state: paused;
        }

        @keyframes waveFloat1 {
          0%, 100% { transform: translateY(0px); }
          50% { transform: translateY(-5px); }
        }
        @keyframes waveFloat2 {
          0%, 100% { transform: translateY(0px); }
          50% { transform: translateY(5px); }
        }
        .animate-wave-1 {
          animation: waveFloat1 6s ease-in-out infinite;
        }
        .animate-wave-2 {
          animation: waveFloat2 7s ease-in-out infinite;
        }
      `}} />

      {/* Decorative background glow elements */}
      <div className="absolute top-1/4 left-1/10 w-[400px] h-[400px] bg-[#5bf4bc]/[0.02] rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-1/4 right-1/10 w-[400px] h-[400px] bg-[#fcae2f]/[0.02] rounded-full blur-[120px] pointer-events-none" />

      <div className="relative mx-auto w-full max-w-[1200px] px-6 mb-16 text-center">
        <p className="font-mono text-[10px] sm:text-xs uppercase text-[#5bf4bc] tracking-[3px] font-bold mb-3">
          {isPl ? "Głosy z gabinetów" : "Voices from the practices"}
        </p>
        <h2 className="font-display text-white text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight leading-[1.12]">
          {isPl ? "Co mówią nasi pierwsi testerzy?" : "What do our first testers say?"}
        </h2>
        <p className="font-serif text-mist/75 text-base sm:text-lg mt-4 max-w-2xl mx-auto">
          {isPl
            ? "Prawdziwe opinie psychoterapeutów, którzy wdrożyli Superwizor AI do pracy z pacjentami."
            : "Real reviews from psychotherapists who integrated Superwizor AI into their work with clients."}
        </p>
      </div>

      {/* Marquee Wrapper Container */}
      <div className="relative w-full overflow-hidden marquee-container flex flex-col gap-6 lg:gap-8 z-10">

        {/* Portal Fade Overlays (dark theme matching background) */}
        <div className="absolute top-0 bottom-0 left-0 w-24 md:w-48 bg-gradient-to-r from-[#001A1D] to-transparent z-20 pointer-events-none" />
        <div className="absolute top-0 bottom-0 right-0 w-24 md:w-48 bg-gradient-to-l from-[#002e32] to-transparent z-20 pointer-events-none" />

        {/* Row 1: Left to Right (Moving backwards) */}
        <div className="flex w-full">
          <div className="animate-marquee-row-reverse flex gap-6 lg:gap-8 px-4">
            {[...ROW1_DATA, ...ROW1_DATA].map((item, idx) => (
              <div
                key={`r1-${idx}`}
                className={`w-[290px] sm:w-[360px] flex-shrink-0 bg-[#122B2E]/50 border border-white/[0.08] hover:border-white/15 p-5 sm:p-6 rounded-[20px] shadow-[0_12px_32px_-8px_rgba(0,0,0,0.3)] hover:bg-[#153235]/65 transition-all duration-300 flex flex-col justify-between select-text ${idx % 2 === 0 ? "animate-wave-1" : "animate-wave-2"
                  }`}
              >
                <p className="font-sans text-[12.5px] sm:text-[14px] leading-relaxed text-white/90 italic font-medium relative before:content-['„'] after:content-['”']">
                  {isPl ? item.quote : item.quoteEn}
                </p>

                <div className="mt-5 pt-4 border-t border-white/5 flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#0e3b33] to-[#165c50] flex items-center justify-center font-sans font-bold text-xs text-[#5bf4bc] shadow-inner select-none shrink-0">
                    {item.author[0]}
                  </div>
                  <div className="flex flex-col text-left overflow-hidden">
                    <span className="font-sans font-bold text-xs sm:text-[13px] text-white truncate">{item.author}</span>
                    <span className="font-sans text-[10px] sm:text-[11px] text-[#5bf4bc] font-semibold mt-0.5 truncate flex items-center gap-1.5">
                      <span>{isPl ? item.role : item.roleEn}</span>
                      {item.nurt && (
                        <>
                          <span className="text-white/20">•</span>
                          <span className="text-[#fcae2f] border border-[#fcae2f]/20 bg-[#fcae2f]/5 px-1.5 py-0.5 rounded-full text-[9px] font-bold shrink-0">
                            {isPl ? item.nurt : item.nurtEn}
                          </span>
                        </>
                      )}
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Row 2: Right to Left (Moving forward) */}
        <div className="flex w-full">
          <div className="animate-marquee-row flex gap-6 lg:gap-8 px-4">
            {[...ROW2_DATA, ...ROW2_DATA].map((item, idx) => (
              <div
                key={`r2-${idx}`}
                className={`w-[290px] sm:w-[360px] flex-shrink-0 bg-[#122B2E]/50 border border-white/[0.08] hover:border-white/15 p-5 sm:p-6 rounded-[20px] shadow-[0_12px_32px_-8px_rgba(0,0,0,0.3)] hover:bg-[#153235]/65 transition-all duration-300 flex flex-col justify-between select-text ${idx % 2 === 0 ? "animate-wave-2" : "animate-wave-1"
                  }`}
              >
                <p className="font-sans text-[12.5px] sm:text-[14px] leading-relaxed text-white/90 italic font-medium relative before:content-['„'] after:content-['”']">
                  {isPl ? item.quote : item.quoteEn}
                </p>

                <div className="mt-5 pt-4 border-t border-white/5 flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#122e2a] to-[#2b5952] flex items-center justify-center font-sans font-bold text-xs text-[#fcae2f] shadow-inner select-none shrink-0">
                    {item.author[0]}
                  </div>
                  <div className="flex flex-col text-left overflow-hidden">
                    <span className="font-sans font-bold text-xs sm:text-[13px] text-white truncate">{item.author}</span>
                    <span className="font-sans text-[10px] sm:text-[11px] text-[#5bf4bc] font-semibold mt-0.5 truncate flex items-center gap-1.5">
                      <span>{isPl ? item.role : item.roleEn}</span>
                      {item.nurt && (
                        <>
                          <span className="text-white/20">•</span>
                          <span className="text-[#fcae2f] border border-[#fcae2f]/20 bg-[#fcae2f]/5 px-1.5 py-0.5 rounded-full text-[9px] font-bold shrink-0">
                            {isPl ? item.nurt : item.nurtEn}
                          </span>
                        </>
                      )}
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

      </div>
    </section>
  );
}
