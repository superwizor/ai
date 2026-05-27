// Site footer.
//
// Three navigation columns (Product / Company / Legal), brand tagline,
// copyright line. Legal pages are wired in feature 7
// (`legal-static-pages`) — until then the Terms/Privacy/DPA links
// point at /<locale>/legal/{terms,privacy,dpa} as placeholders.
//
// Login link goes cross-origin to app.superwizor.ai per docs/18 §5 R3.

import { useTranslations, useLocale } from "next-intl";

export function Footer() {
  const t = useTranslations("footer");
  const tNav = useTranslations("nav"); // for the brand mark — same key as Navbar uses
  const tLinks = useTranslations("footer.links");
  const tSections = useTranslations("footer.sections");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  return (
    <footer className="mt-12 border-t border-frost/10 bg-evergreen/40">
      <div className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8 py-12 grid grid-cols-1 md:grid-cols-4 gap-8">
        <div className="md:col-span-1">
          <p className="font-display text-frost font-semibold text-base">
            {tNav("brand")}
          </p>
          <p className="font-serif text-mist text-sm mt-2 max-w-xs">
            {t("tagline")}
          </p>
        </div>

        <FooterColumn title={tSections("product")}>
          <FooterLink href={`${prefix}/pricing`}>{tLinks("pricing")}</FooterLink>
          <FooterLink href={`${prefix}/register/therapist`}>
            {tLinks("register")}
          </FooterLink>
          <FooterLink href="https://app.superwizor.ai/login">
            {tLinks("login")}
          </FooterLink>
        </FooterColumn>

        <FooterColumn title={tSections("legal")}>
          <FooterLink href={`${prefix}/legal/terms`}>{tLinks("terms")}</FooterLink>
          <FooterLink href={`${prefix}/legal/privacy`}>
            {tLinks("privacy")}
          </FooterLink>
          <FooterLink href={`${prefix}/legal/dpa`}>{tLinks("dpa")}</FooterLink>
        </FooterColumn>

        <FooterColumn title={tSections("company")}>
          <FooterLink href="mailto:hello@superwizor.ai">
            {tLinks("contact")}
          </FooterLink>
        </FooterColumn>
      </div>

      <div className="border-t border-frost/5">
        <div className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8 py-6 flex flex-col sm:flex-row justify-between gap-2">
          <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/60">
            {t("copyright")}
          </p>
          <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/60">
            {t("made")}
          </p>
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
    <div>
      <h3 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist mb-3">
        {title}
      </h3>
      <ul className="space-y-2">{children}</ul>
    </div>
  );
}

function FooterLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <li>
      <a
        href={href}
        className="font-display text-sm text-frost/80 hover:text-frost transition"
      >
        {children}
      </a>
    </li>
  );
}
