// /kontakt — contact page with form.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { ContactForm } from "@/components/contact/ContactForm";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "metadata.contact" });
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

export default async function ContactPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("contact");

  return (
    <>
      <Navbar />
      <main className="flex-1 bg-gradient-to-b from-[#001A1D] to-[#002e32] min-h-[calc(100vh-80px)] flex flex-col justify-center">
        <section className="mx-auto w-full max-w-[1240px] px-6 py-16 sm:py-24">
          {/* Header */}
          <div className="text-center mb-16">
            <p className="font-sans text-[10px] sm:text-xs uppercase text-ember tracking-[var(--tracking-overline)] mb-3 font-bold">
              {t("overline")}
            </p>
            <h1 className="font-display text-white text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight leading-tight max-w-2xl mx-auto">
              {t("heading")}
            </h1>
            <p className="font-sans text-mist/80 mt-4 max-w-md mx-auto text-base sm:text-lg leading-relaxed">
              {t("subhead")}
            </p>
          </div>

          {/* Split Content */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-start">
            {/* Left Column: Contact Form */}
            <div className="lg:col-span-7 w-full rounded-[24px] border border-frost/10 bg-frost/5 backdrop-blur-md p-6 sm:p-10 shadow-[0_8px_32px_rgba(0,0,0,0.25)]">
              <ContactForm />
            </div>

            {/* Right Column: Visual Therapy Office & Testimonial Showcase */}
            <div className="lg:col-span-5 flex flex-col gap-6 lg:sticky lg:top-28">
              <div className="rounded-[24px] border border-frost/10 bg-frost/5 backdrop-blur-md p-6 shadow-[0_8px_32px_rgba(0,0,0,0.25)]">
                {/* Elegant Image Container */}
                <div className="relative aspect-[1.1] w-full overflow-hidden rounded-[16px] border border-frost/10 shadow-inner mb-5">
                  <img
                    src="/assets/therapy-contact.webp"
                    alt={locale === "en" ? "Cozy therapy space" : "Gabinet terapeutyczny"}
                    className="object-cover w-full h-full brightness-[0.98] contrast-[1.02]"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-obsidian/60 to-transparent" />
                </div>

                {/* Testimonial Quote */}
                <div className="flex flex-col gap-4 text-left">
                  {/* Star Rating */}
                  <div className="flex gap-1">
                    {[1, 2, 3, 4, 5].map((s) => (
                      <svg key={s} className="w-4.5 h-4.5 text-[#FCAE2F] fill-[#FCAE2F]" viewBox="0 0 20 20">
                        <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                      </svg>
                    ))}
                  </div>

                  <p className="font-serif text-white text-[13.5px] sm:text-[14px] italic leading-relaxed before:content-['„'] after:content-['”'] font-medium">
                    {locale === "en"
                      ? "It prevents losing 30 to 40% of information that is normally lost when writing notes by hand."
                      : "Pozwala uniknąć utraty od 30 do 40% informacji, które tracę przy ręcznym przygotowywaniu notatek."}
                  </p>

                  {/* Author Info */}
                  <div className="flex items-center gap-3 pt-4 border-t border-frost/10">
                    <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#0e3b33] to-[#165c50] flex items-center justify-center font-sans font-bold text-xs text-[#5bf4bc] shadow-md select-none shrink-0">
                      A
                    </div>
                    <div className="flex flex-col text-left overflow-hidden">
                      <span className="font-sans font-bold text-xs text-white">Agnieszka</span>
                      <span className="font-sans text-[10px] text-[#5bf4bc] font-semibold flex items-center gap-1.5">
                        <span>{locale === "en" ? "psychotherapist" : "psychoterapeutka"}</span>
                        <span className="text-white/20">•</span>
                        <span className="text-[#FCAE2F] border border-[#FCAE2F]/20 bg-[#FCAE2F]/5 px-1.5 py-0.5 rounded-full text-[8.5px] font-bold shrink-0">
                          {locale === "en" ? "CBT approach" : "nurt CBT"}
                        </span>
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
