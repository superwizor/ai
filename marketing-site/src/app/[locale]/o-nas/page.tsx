// /o-nas — About Us page.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { AboutFounders, Founder } from "@/components/marketing/AboutFounders";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "metadata.about" });
  const title = t("title");
  const description = t("description");
  const keywords = t("keywords");
  return {
    title,
    description,
    keywords,
    other: {
      "geo.region": "PL-MZ",
      "geo.placename": "Warszawa",
      "geo.position": "52.2297;21.0122",
      "ICBM": "52.2297, 21.0122",
    },
  };
}

export default async function AboutPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("about");
  const prefix = locale === "en" ? "/en" : "";

  const founders: Founder[] = [
    {
      id: "maciej",
      name: "Maciej Kołodziejczyk",
      role: t("team.maciej.role"),
      description: t("team.maciej.description"),
      bio: t("team.maciej.bio"),
      image: "/assets/team/maciej_kolodziejczyk.webp",
      linkedin: "https://www.linkedin.com/in/maciek-ko%C5%82odziejczyk-59a91a157/",
      euphire: "https://euphire.pl/o-nas/maciej-kolodziejczyk/",
    },
    {
      id: "dariusz",
      name: "Dariusz Piotrak",
      role: t("team.dariusz.role"),
      description: t("team.dariusz.description"),
      bio: t("team.dariusz.bio"),
      image: "/assets/team/dariusz_piotrak.webp",
      linkedin: "https://www.linkedin.com/in/dariusz-piotrak-1812a8?utm_source=share_via&utm_content=profile&utm_medium=member_ios",
    },
    {
      id: "marcin",
      name: "Marcin Archacki",
      role: t("team.marcin.role"),
      description: t("team.marcin.description"),
      bio: t("team.marcin.bio"),
      image: "/assets/team/marcin_archacki.webp",
      linkedin: "https://www.linkedin.com/in/marcin-archacki-ba901425/",
    },
  ];

  return (
    <>
      <Navbar />
      <main className="flex-1 flex flex-col bg-[#001A1D]">
        
        {/* SECTION 1: HEADER & MISSION (DARK TEAL, PREMIUM TYPOGRAPHY) */}
        <section className="relative w-full bg-gradient-to-b from-[#001A1D] via-[#002528] to-[#002e32] pt-28 pb-32 border-b border-white/[0.04] overflow-hidden">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-evergreen/35 via-transparent to-transparent pointer-events-none" />
          
          <div className="relative mx-auto w-full max-w-[1040px] px-6 text-center">
            {/* Eyebrow */}
            <p className="font-sans text-[10px] sm:text-xs uppercase text-ember tracking-[var(--tracking-overline)] mb-8 font-bold block animate-pulse-slow">
              {t("overline")}
            </p>
            
            {/* Typography Masterclass Layout */}
            <div className="flex flex-col max-w-4xl mx-auto">
              
              {/* Giant Serif Headline */}
              <h1 className="font-serif text-3xl sm:text-5xl lg:text-6xl text-frost leading-[1.15] tracking-tight font-medium">
                {locale === "en" ? (
                  <>In psychotherapy, <span className="text-ember italic">presence is what heals</span>.</>
                ) : (
                  <>W psychoterapii <span className="text-ember italic">obecność leczy</span>.</>
                )}
              </h1>
              
              {/* Breathing Sans-Serif Body Paragraph */}
              <p className="font-sans text-lg sm:text-xl lg:text-2xl text-mist/90 leading-relaxed font-normal max-w-3xl mx-auto mt-12">
                {locale === "en" ? (
                  <>
                    Every second spent looking away to take notes is a moment of lost attentiveness. We lift the burden of remembering to restore complete focus on the client. We support process continuity, shortening therapy time and increasing its effectiveness, <span className="text-ember font-semibold">helping to save human lives</span>.
                  </>
                ) : (
                  <>
                    Każda sekunda ucieczki wzrokiem do notatek to chwila utraconej uważności. Zdejmujemy z Ciebie ciężar pamiętania, by przywrócić pełne skupienie na relacji z człowiekiem. Wspieramy ciągłość procesu, skracając czas terapii i zwiększając jej skuteczność, <span className="text-ember font-semibold">pomagając ratować ludzkie życia</span>.
                  </>
                )}
              </p>

            </div>
          </div>
        </section>

        {/* SECTION 2: FOUNDERS (WARM-LIGHT SECTION, SHUFFLED EGALITARIAN ORDER) */}
        <AboutFounders title={t("team.title")} founders={founders} />

        {/* SECTION 3: INTERDISCIPLINARY COLLABORATORS (DARK TEAL GRID) */}
        <section className="w-full bg-[#00272A] py-20 sm:py-24 border-b border-white/[0.04]">
          <div className="mx-auto w-full max-w-[1140px] px-6">
            <div className="text-center mb-16">
              <h2 className="font-display text-white text-2xl sm:text-3xl font-bold tracking-tight">
                {t("collaborators.title")}
              </h2>
              <p className="font-sans text-mist/80 mt-4 max-w-2xl mx-auto text-xs sm:text-sm leading-relaxed">
                {t("collaborators.subtitle")}
              </p>
            </div>

            {/* Collaborators Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 items-stretch">
              
              {/* Item: Clinical */}
              <div className="rounded-[20px] border border-white/[0.06] bg-white/[0.015] p-5 hover:bg-white/[0.03] transition-all duration-300 flex flex-col gap-4">
                <div className="w-full aspect-video rounded-[12px] overflow-hidden bg-[#022123] border border-white/[0.08]">
                  <img 
                    src="/assets/collaborators/clinical_methodology.webp" 
                    alt={t("collaborators.items.clinical.title")}
                    width={1024}
                    height={576}
                    loading="lazy"
                    decoding="async"
                    className="w-full h-full object-cover brightness-[0.9] hover:scale-105 transition-transform duration-500"
                  />
                </div>
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 shrink-0 rounded-lg bg-white/[0.04] border border-white/[0.08] flex items-center justify-center text-ember">
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                    </svg>
                  </div>
                  <h3 className="font-display text-sm font-bold text-white">
                    {t("collaborators.items.clinical.title")}
                  </h3>
                </div>
                <p className="font-sans text-xs text-mist/70 leading-relaxed">
                  {t("collaborators.items.clinical.body")}
                </p>
              </div>

              {/* Item: Law */}
              <div className="rounded-[20px] border border-white/[0.06] bg-white/[0.015] p-5 hover:bg-white/[0.03] transition-all duration-300 flex flex-col gap-4">
                <div className="w-full aspect-video rounded-[12px] overflow-hidden bg-[#022123] border border-white/[0.08]">
                  <img 
                    src="/assets/collaborators/legal_compliance.webp" 
                    alt={t("collaborators.items.compliance.title")}
                    width={1024}
                    height={576}
                    loading="lazy"
                    decoding="async"
                    className="w-full h-full object-cover brightness-[0.9] hover:scale-105 transition-transform duration-500"
                  />
                </div>
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 shrink-0 rounded-lg bg-white/[0.04] border border-white/[0.08] flex items-center justify-center text-ember">
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M3 6l3 1m0 0l-3 9a5.002 5.002 0 006.001 0M6 7l3 9M6 7l6-2m6 2l3-1m-3 1l-3 9a5.002 5.002 0 006.001 0M18 7l3 9m-3-9l-6-2m0-2v2m0 16V5m0 16H9m3 0h3" />
                    </svg>
                  </div>
                  <h3 className="font-display text-sm font-bold text-white">
                    {t("collaborators.items.compliance.title")}
                  </h3>
                </div>
                <p className="font-sans text-xs text-mist/70 leading-relaxed">
                  {t("collaborators.items.compliance.body")}
                </p>
              </div>

              {/* Item: UX */}
              <div className="rounded-[20px] border border-white/[0.06] bg-white/[0.015] p-5 hover:bg-white/[0.03] transition-all duration-300 flex flex-col gap-4">
                <div className="w-full aspect-video rounded-[12px] overflow-hidden bg-[#022123] border border-white/[0.08]">
                  <img 
                    src="/assets/collaborators/ux_ergonomics.webp" 
                    alt={t("collaborators.items.ux.title")}
                    width={1024}
                    height={576}
                    loading="lazy"
                    decoding="async"
                    className="w-full h-full object-cover brightness-[0.9] hover:scale-105 transition-transform duration-500"
                  />
                </div>
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 shrink-0 rounded-lg bg-white/[0.04] border border-white/[0.08] flex items-center justify-center text-ember">
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                    </svg>
                  </div>
                  <h3 className="font-display text-sm font-bold text-white">
                    {t("collaborators.items.ux.title")}
                  </h3>
                </div>
                <p className="font-sans text-xs text-mist/70 leading-relaxed">
                  {t("collaborators.items.ux.body")}
                </p>
              </div>

              {/* Item: Tech */}
              <div className="rounded-[20px] border border-white/[0.06] bg-white/[0.015] p-5 hover:bg-white/[0.03] transition-all duration-300 flex flex-col gap-4">
                <div className="w-full aspect-video rounded-[12px] overflow-hidden bg-[#022123] border border-white/[0.08]">
                  <img 
                    src="/assets/collaborators/cloud_technology.webp" 
                    alt={t("collaborators.items.development.title")}
                    width={1024}
                    height={576}
                    loading="lazy"
                    decoding="async"
                    className="w-full h-full object-cover brightness-[0.9] hover:scale-105 transition-transform duration-500"
                  />
                </div>
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 shrink-0 rounded-lg bg-white/[0.04] border border-white/[0.08] flex items-center justify-center text-ember">
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
                    </svg>
                  </div>
                  <h3 className="font-display text-sm font-bold text-white">
                    {t("collaborators.items.development.title")}
                  </h3>
                </div>
                <p className="font-sans text-xs text-mist/70 leading-relaxed">
                  {t("collaborators.items.development.body")}
                </p>
              </div>

            </div>
          </div>
        </section>

        {/* SECTION 4: CTA BLOCK (DARK GRADIENT) */}
        <section className="relative w-full bg-gradient-to-b from-[#001A1D] to-[#080E0D] py-24 sm:py-32 overflow-hidden text-center">
          <div className="relative mx-auto w-full max-w-[1140px] px-6">
            <h2 className="font-display text-white text-2xl sm:text-3xl lg:text-4xl font-bold tracking-tight">
              {locale === "en"
                ? "Try Superwizor AI in your practice"
                : "Wypróbuj Superwizor AI w swoim gabinecie"}
            </h2>
            <p className="font-sans text-mist/80 mt-4 max-w-xl mx-auto text-sm sm:text-base leading-relaxed">
              {locale === "en"
                ? "Start with 5 free sessions. Test all templates and see how cognitive release works."
                : "Rozpocznij od 5 darmowych sesji. Przetestuj wszystkie szablony i zobacz, jak działa uwolnienie poznawcze."}
            </p>
            <div className="flex flex-col sm:flex-row justify-center items-center gap-4 mt-10">
              <a
                href={`${prefix}/register`}
                className="w-full sm:w-auto px-8 py-4 rounded-button bg-ember hover:bg-white text-obsidian font-sans font-bold text-xs uppercase tracking-wider transition-all duration-200 shadow-ember-glow text-center"
              >
                {locale === "en" ? "Try for free" : "Wypróbuj za darmo"}
              </a>
              <a
                href={`${prefix}/kontakt`}
                className="w-full sm:w-auto px-8 py-4 rounded-button border border-white/20 hover:border-white/40 text-white font-sans font-bold text-xs uppercase tracking-wider transition-all duration-200 text-center"
              >
                {locale === "en" ? "Contact us" : "Skontaktuj się"}
              </a>
            </div>
          </div>
        </section>

      </main>
      <Footer />
    </>
  );
}
