// ContactForm — client-side contact form with mailto fallback.
//
// For MVP, this opens a mailto: link with pre-filled subject and body.
// When a backend /api/contact endpoint lands, swap to fetch().

"use client";

import { useState, type FormEvent } from "react";
import { useTranslations } from "next-intl";

export function ContactForm() {
  const t = useTranslations("contact");
  const [sent, setSent] = useState(false);
  const [sending, setSending] = useState(false);

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setSending(true);

    const form = e.currentTarget;
    const data = new FormData(form);
    const name = data.get("name") as string;
    const email = data.get("email") as string;
    const subject = data.get("subject") as string;
    const message = data.get("message") as string;

    const billingUrl = process.env.NEXT_PUBLIC_BILLING_URL || "http://localhost:8081";
    const endpoint = `${billingUrl}/contact`;

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ name, email, subject, message }),
      });

      if (!response.ok) {
        throw new Error(`Server returned status: ${response.status}`);
      }

      setSent(true);
    } catch (err) {
      console.warn("Błąd wysyłania przez backend, uruchamiam mailto fallback...", err);
      // Fallback to mailto link
      const body = `${message}\n\n---\nOd: ${name}\nE-mail: ${email}`;
      const mailto = `mailto:kontakt@superwizor.ai?subject=${encodeURIComponent(
        subject
      )}&body=${encodeURIComponent(body)}`;

      window.location.href = mailto;
      setSent(true);
    } finally {
      setSending(false);
    }
  };

  if (sent) {
    return (
      <div className="rounded-[16px] border border-[#B2DFD8] bg-gradient-to-br from-[#E6F2F0] to-[#F2F0EA] p-8 text-center">
        <div className="w-12 h-12 rounded-full bg-[#2F6B62]/10 flex items-center justify-center mx-auto mb-4">
          <svg
            className="w-6 h-6 text-[#2F6B62]"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M5 13l4 4L19 7"
            />
          </svg>
        </div>
        <p className="font-display text-[#004D54] text-lg font-bold">
          {t("success")}
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      {/* Name */}
      <div>
        <label
          htmlFor="contact-name"
          className="block font-sans text-sm font-medium text-frost mb-1.5"
        >
          {t("fields.name")}
        </label>
        <input
          id="contact-name"
          name="name"
          type="text"
          required
          className="w-full rounded-[10px] border border-frost/10 bg-white/5 backdrop-blur-sm px-4 py-3 font-sans text-sm text-white placeholder:text-mist/40 focus:outline-none focus:ring-2 focus:ring-ember/20 focus:border-ember/40 transition"
        />
      </div>

      {/* Email */}
      <div>
        <label
          htmlFor="contact-email"
          className="block font-sans text-sm font-medium text-frost mb-1.5"
        >
          {t("fields.email")}
        </label>
        <input
          id="contact-email"
          name="email"
          type="email"
          required
          className="w-full rounded-[10px] border border-frost/10 bg-white/5 backdrop-blur-sm px-4 py-3 font-sans text-sm text-white placeholder:text-mist/40 focus:outline-none focus:ring-2 focus:ring-ember/20 focus:border-ember/40 transition"
        />
      </div>

      {/* Subject */}
      <div>
        <label
          htmlFor="contact-subject"
          className="block font-sans text-sm font-medium text-frost mb-1.5"
        >
          {t("fields.subject")}
        </label>
        <input
          id="contact-subject"
          name="subject"
          type="text"
          required
          placeholder={t("fields.subjectPlaceholder")}
          className="w-full rounded-[10px] border border-frost/10 bg-white/5 backdrop-blur-sm px-4 py-3 font-sans text-sm text-white placeholder:text-mist/40 focus:outline-none focus:ring-2 focus:ring-ember/20 focus:border-ember/40 transition"
        />
      </div>

      {/* Message */}
      <div>
        <label
          htmlFor="contact-message"
          className="block font-sans text-sm font-medium text-frost mb-1.5"
        >
          {t("fields.message")}
        </label>
        <textarea
          id="contact-message"
          name="message"
          required
          rows={5}
          placeholder={t("fields.messagePlaceholder")}
          className="w-full rounded-[10px] border border-frost/10 bg-white/5 backdrop-blur-sm px-4 py-3 font-sans text-sm text-white placeholder:text-mist/40 focus:outline-none focus:ring-2 focus:ring-ember/20 focus:border-ember/40 transition resize-none"
        />
      </div>

      {/* Submit */}
      <button
        type="submit"
        disabled={sending}
        className="w-full rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs px-6 py-4 hover:brightness-110 transition-all duration-200 active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed shadow-[0_4px_12px_rgba(252,174,47,0.20)]"
      >
        {sending ? t("submitting") : t("submit")}
      </button>

      {/* Direct email fallback */}
      <p className="text-center font-sans text-xs text-mist/60 mt-4">
        {t("directEmail")}{" "}
        <a
          href="mailto:kontakt@superwizor.ai"
          className="text-ember hover:underline font-semibold"
        >
          {t("emailAddress")}
        </a>
      </p>
    </form>
  );
}
