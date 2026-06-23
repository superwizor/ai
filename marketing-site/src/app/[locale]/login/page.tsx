// /login — universal sign-in page for the marketing-site origin.
//
// Replaces the previous "go to Flutter app to log in" redirect (see
// LoginForm header for the why). Routes by role after sign-in:
//   SUPERWIZOR_ADMIN → /admin/
//   anything else    → Flutter app (carrying email for prefill)
//
// Static-exportable: the form lives entirely in the client component;
// the server shell is just metadata + i18n copy.

import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";

import { Navbar } from "@/components/marketing/Navbar";
import { Footer } from "@/components/marketing/Footer";
import { LoginForm } from "@/components/auth/LoginForm";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "metadata.login" });
  return {
    title: t("title"),
    description: t("description"),
    robots: {
      index: false,
      follow: false,
    },
  };
}

export default async function LoginPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("login");

  const quote = locale === "en"
    ? "I feel an incredible relief when I don't have to feverishly write during sessions. I have full mindfulness for my client."
    : "Widzę niesamowitą ulgę, gdy nie muszę gorączkowo pisać podczas sesji. Mam pełną uważność na klienta.";
  const roleText = locale === "en" ? "cognitive psychotherapist" : "psychoterapeuta poznawczy";

  return (
    <>
      <Navbar variant="auth" />
      <main className="flex-1">
        <section className="mx-auto w-full max-w-[1440px] px-4 sm:px-6 lg:px-12 xl:px-16 py-12 sm:py-16">
          <p className="font-sans text-[10px] sm:text-xs uppercase text-ember tracking-[var(--tracking-overline)] mb-3 text-center">
            {t("overline")}
          </p>
          <h1 className="font-display text-frost text-center text-3xl sm:text-4xl font-semibold tracking-[var(--tracking-display)] leading-tight">
            {t("title")}
          </h1>
          <p className="font-sans text-mist text-center mt-4 max-w-md mx-auto text-base leading-relaxed mb-8">
            {t("subhead")}
          </p>

          <div className="mx-auto w-full grid grid-cols-1 lg:grid-cols-12 gap-8 items-start text-left">
            {/* Left Spacer to center the login card on desktop */}
            <div className="hidden lg:block lg:col-span-3" />

            {/* Left Column: Form inside card container */}
            <div className="col-span-12 lg:col-span-6 w-full max-w-[480px] lg:justify-self-center rounded-[20px] border border-frost/10 bg-frost/5 backdrop-blur-md p-6 sm:p-10 shadow-[0_8px_32px_rgba(0,0,0,0.25)] flex flex-col gap-6">
              <LoginForm />
            </div>

            {/* Right Column: Photo & Quote outside card container */}
            <div className="col-span-12 lg:col-span-3 flex flex-col gap-5 w-full lg:items-end lg:justify-self-end">
              {/* Photo */}
              <div className="relative aspect-[4/3] md:aspect-[1.15] w-full max-w-[280px] overflow-hidden rounded-tl-[80px] rounded-br-[20px] rounded-tr-[20px] rounded-bl-[20px] border border-frost/10 shadow-[0_8px_24px_rgba(0,0,0,0.3)]">
                <img
                  src="/assets/therapy-banana.webp"
                  alt="Therapy space"
                  className="object-cover w-full h-full brightness-90 contrast-[1.05]"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-obsidian/40 to-transparent" />
              </div>

              {/* Testimonial Card */}
              <div className="bg-frost/[0.03] border border-frost/10 p-5 rounded-[20px] flex flex-col gap-3.5 shadow-md w-full max-w-[280px]">
                {/* Stars */}
                <div className="flex gap-1">
                  {[1, 2, 3, 4, 5].map((s) => (
                    <svg key={s} className="w-4 h-4 text-ember fill-ember" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  ))}
                </div>

                <p className="font-sans text-xs sm:text-[13px] text-frost/90 italic leading-relaxed before:content-['„'] after:content-['”']">
                  {quote}
                </p>

                <div className="flex items-center gap-3 pt-3 border-t border-frost/5">
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#1b3d36] to-[#0e2722] flex items-center justify-center font-sans font-bold text-xs text-[#fcbf49] shadow-inner select-none shrink-0">
                    T
                  </div>
                  <div className="flex flex-col text-left overflow-hidden">
                    <span className="font-sans font-bold text-xs text-white">Tomasz</span>
                    <span className="font-sans text-[10px] text-[#fcbf49] font-semibold">
                      {roleText}
                    </span>
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
