// Site footer.
//
// Structured in a premium dark-themed 5-column grid with a white brand logo,
// clean line spacing, and a giant subtle backdrop watermark.

import { useTranslations, useLocale } from "next-intl";

export function Footer() {
  const t = useTranslations("footer");
  const tLinks = useTranslations("footer.links");
  const tSections = useTranslations("footer.sections");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  return (
    <footer className="relative w-full bg-[#080E0D] text-[#FAFAFA] pt-16 pb-12 sm:pb-16 overflow-hidden border-t border-[#142320]/60 z-10">
      <div className="relative mx-auto w-full max-w-[1080px] px-6 z-10">
        <div className="grid grid-cols-2 md:grid-cols-5 gap-8 sm:gap-12 pb-16">
          {/* Column 1: Brand logo, tagline & copyright */}
          <div className="col-span-2 md:col-span-1 flex flex-col items-start gap-4 z-10">
            <a href={`${prefix}/`} className="flex items-center">
              <span className="font-display font-bold text-lg sm:text-xl tracking-tight text-[#FAFAFA]">
                Superwizor AI
              </span>
            </a>
            <p className="font-sans text-xs text-mist/70 leading-relaxed max-w-[200px]">
              {t("tagline")}
            </p>
            <div className="mt-4 space-y-1">
              <p className="font-mono text-[9px] sm:text-[10px] uppercase tracking-wider text-mist/40">
                {t("copyright")}
              </p>
              <p className="font-mono text-[9px] sm:text-[10px] uppercase tracking-wider text-mist/40">
                {t("made")}
              </p>
            </div>
          </div>

          {/* Column 2: Product / Pages */}
          <FooterColumn title={tSections("product")}>
            <FooterLink href="#jak">
              {locale === "en" ? "How it works" : "Jak to działa"}
            </FooterLink>
            <FooterLink href="#cennik">
              {tLinks("pricing")}
            </FooterLink>
            <FooterLink href="#bezpieczenstwo">
              {locale === "en" ? "GDPR & Security" : "RODO i bezpieczeństwo"}
            </FooterLink>
            <FooterLink href={`${prefix}/o-nas`}>
              {locale === "en" ? "About Us" : "O nas"}
            </FooterLink>
          </FooterColumn>

          {/* Column 3: Socials */}
          <FooterColumn title={locale === "en" ? "Socials" : "Social media"}>
            <FooterLink href="https://www.facebook.com/EUPHIRE/" target="_blank" rel="noopener noreferrer">
              Facebook
            </FooterLink>
            <FooterLink href="https://www.instagram.com/euphire_pl/" target="_blank" rel="noopener noreferrer">
              Instagram
            </FooterLink>
            <FooterLink href="https://www.youtube.com/euphire" target="_blank" rel="noopener noreferrer">
              YouTube
            </FooterLink>
            <FooterLink href="https://www.tiktok.com/@euphire7" target="_blank" rel="noopener noreferrer">
              TikTok
            </FooterLink>
            <FooterLink href="https://www.linkedin.com/company/superwizor-ai" target="_blank" rel="noopener noreferrer">
              LinkedIn
            </FooterLink>
          </FooterColumn>

          {/* Column 4: Legal */}
          <FooterColumn title={locale === "en" ? "Legal" : "Kwestie prawne"}>
            <FooterLink href={`${prefix}/legal/privacy`}>
              {tLinks("privacy")}
            </FooterLink>
            <FooterLink href={`${prefix}/legal/terms`}>
              {tLinks("terms")}
            </FooterLink>
            <FooterLink href={`${prefix}/legal/dpa`}>
              {tLinks("dpa")}
            </FooterLink>
          </FooterColumn>

          {/* Column 5: Register / Sign In */}
          <FooterColumn title={locale === "en" ? "Register" : "Konto"}>
            <FooterLink href="#cennik">
              {tLinks("register")}
            </FooterLink>
            <FooterLink href={`${prefix}/login`}>
              {tLinks("login")}
            </FooterLink>
            <FooterLink href={`${prefix}/kontakt`}>
              {tLinks("contact")}
            </FooterLink>
          </FooterColumn>
        </div>
      </div>
    </footer>
  );
}

function FooterColumn({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex flex-col gap-4 z-10">
      <h3 className="font-display text-xs uppercase tracking-wider text-[#FAFAFA] font-bold">
        {title}
      </h3>
      <ul className="flex flex-col gap-2.5">{children}</ul>
    </div>
  );
}

function FooterLink({
  href,
  children,
  target,
  rel,
}: {
  href: string;
  children: React.ReactNode;
  target?: string;
  rel?: string;
}) {
  return (
    <li>
      <a
        href={href}
        target={target}
        rel={rel}
        className="font-sans text-xs sm:text-sm text-mist/70 hover:text-[#FAFAFA] transition duration-200 font-medium"
      >
        {children}
      </a>
    </li>
  );
}
