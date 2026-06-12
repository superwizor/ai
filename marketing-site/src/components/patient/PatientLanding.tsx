"use client";

import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";

const stepImages = [
  "/assets/mockup_record_green_real.webp",
  "/assets/mockup_status_green_real.webp",
  "/assets/mockup_transcript_green_real.webp",
];

interface PatientLandingProps {
  locale: string;
}

export function PatientLanding({ locale }: PatientLandingProps) {
  const isPl = locale === "pl";
  const [activeFaq, setActiveFaq] = useState<number | null>(null);

  const tallyLink = "https://tally.so/r/1ABr6O";

  const containerRef = useRef<HTMLDivElement>(null);
  const [maxProgress, setMaxProgress] = useState(0);
  const [activeSteps, setActiveSteps] = useState([false, false, false]);

  useEffect(() => {
    const handleScroll = () => {
      const container = containerRef.current;
      if (!container) return;

      const rect = container.getBoundingClientRect();
      const windowHeight = window.innerHeight;
      const isMobile = window.innerWidth < 1024;

      const containerTop = rect.top;
      const containerHeight = rect.height;

      const triggerPoint = windowHeight * 0.60;

      const scrolledDistance = triggerPoint - containerTop;
      let pct = (scrolledDistance / containerHeight) * 100;
      pct = Math.max(0, Math.min(100, pct));

      setMaxProgress((prevMax) => Math.max(prevMax, pct));

      setActiveSteps((prev) => {
        if (!isMobile) {
          return [
            pct >= 2 || prev[0],
            pct >= 50 || prev[1],
            pct >= 95 || prev[2],
          ];
        } else {
          const mobileTriggerPoint = windowHeight * 0.72;
          const nextActive = [...prev];
          for (let i = 0; i < 3; i++) {
            const el = container.querySelector(`#step-row-${i}`);
            if (el) {
              const elTop = el.getBoundingClientRect().top;
              if (elTop <= mobileTriggerPoint) {
                nextActive[i] = true;
              }
            }
          }
          return nextActive;
        }
      });
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    window.addEventListener("resize", handleScroll);
    handleScroll();

    return () => {
      window.removeEventListener("scroll", handleScroll);
      window.removeEventListener("resize", handleScroll);
    };
  }, []);

  const content = {
    hero: {
      overline: isPl ? "Program dla Klientów" : "Client Companion Program",
      heading: isPl ? "Wyciągnij 100% z każdej sesji psychoterapii" : "Get 100% Out of Every Therapy Session",
      subtitle: isPl 
        ? "Twój osobisty, w 100% bezpieczny asystent terapii. Pomoże Ci uporządkować myśli po sesji, zapisać wnioski i aktywnie wdrażać wypracowany plan działania w codzienne życie. Z nami nic Ci nie ucieknie."
        : "Your personal, 100% secure therapy companion. Organize your post-session thoughts, capture key insights, and actively practice your action plan in daily life. Nothing slips away.",
      cta: isPl ? "Zarezerwuj wczesny dostęp" : "Get Early Access",
      badgeRODO: isPl ? "Szyfrowanie i RODO" : "Encrypted & GDPR",
      badgeNoTrain: isPl ? "Prywatne dane (brak treningu AI)" : "Zero AI Model Training",
      badgeFloatPrivacy: isPl ? "100% Prywatności" : "100% Privacy",
      badgeFloatPrivacySub: isPl ? "Tylko do Twojego wglądu" : "For your eyes only",
      badgeFloatGDPR: isPl ? "Zgodne z RODO" : "GDPR Compliant",
    },
    mockup: {
      title: isPl ? "Moja Terapia" : "My Therapy Journal",
      subtitle: isPl ? "Ostatnie podsumowanie sesji" : "Latest Session Summary",
      status: isPl ? "Zapisano bezpiecznie" : "Secured & Encrypted",
      sectionTranscript: isPl ? "Pełny zapis sesji (Transkrypcja)" : "Full Session Transcript",
      transcriptDesc: isPl 
        ? "„...wtedy zrozumiałem, że to poczucie winy nie jest moje, ale przejęte od rodziców. Poczułem ogromną ulgę.”" 
        : "\"...that's when I realized this guilt isn't mine, but inherited from my parents. I felt a huge relief.\"",
      sectionInsights: isPl ? "Kluczowe wglądy i wnioski" : "Key Insights & Takeaways",
      insight1: isPl 
        ? "Łatwiej mi stawiać granice w pracy niż w relacjach z rodziną – to ważny punkt do dalszej pracy." 
        : "I find it easier to set boundaries at work than with my family – a key focus area going forward.",
      insight2: isPl 
        ? "Poczucie winy przy odmawianiu bliskim wynika z głębokiego lęku przed odrzuceniem." 
        : "Feeling guilty when saying no to loved ones stems from a deep fear of rejection.",
      sectionHomework: isPl ? "Zadania i obszary do obserwacji" : "Homework & Reflections",
      homework1: isPl 
        ? "Wdrożyć plan z sesji: 1. Zauważyć momenty uległości w relacjach, 2. Ćwiczyć odmawianie z łagodnością. Nic mi nie umknie." 
        : "Implement session plan: 1. Notice submissive moments in relationships, 2. Practice saying no with kindness. Nothing slips away.",
      sectionPatterns: isPl ? "Wykryte wzorce emocjonalne" : "Detected Emotional Patterns",
      pattern1: isPl ? "Lęk przed konfrontacją (wystąpił w 3 ostatnich sesjach)" : "Fear of confrontation (seen in last 3 sessions)",
    },
    painPoints: {
      title: isPl ? "Dlaczego tradycyjne notatki nie działają?" : "Why Traditional Notes Fail?",
      subtitle: isPl 
        ? "Proces terapeutyczny to nie tylko czas spędzony w gabinecie. To przede wszystkim praca własna pomiędzy sesjami."
        : "The therapeutic process isn't just about the 50 minutes in the office. It's about reflection between sessions.",
      traditional: {
        title: isPl ? "Klasyczne podejście" : "Traditional Way",
        item1: isPl ? "Chaos w głowie tuż po wyjściu z sesji" : "Mental chaos right after leaving the session",
        item2: isPl ? "Ulotne wnioski, które zapominasz w ciągu 48h" : "Fleetings insights forgotten within 48 hours",
        item3: isPl ? "Stres przed kolejną sesją: 'O czym ja właściwie miałem porozmawiać?'" : "Pre-session stress: 'What was I supposed to talk about?'",
        item4: isPl ? "Rozproszone notatki w telefonie, do których nigdy nie wracasz" : "Scattered phone notes you never read again",
      },
      superwizor: {
        title: isPl ? "Z asystentem Superwizor AI" : "With Superwizor AI",
        item1: isPl ? "Uporządkowanie emocji w 2 minuty po sesji" : "Decompress and structure your mind in 2 minutes",
        item2: isPl ? "Bezpiecznie zapisane wglądy i zadania domowe" : "Safely stored insights and homework from your therapist",
        item3: isPl ? "Przejrzysty brief przed kolejnym spotkaniem" : "A concise brief ready before your next appointment",
        item4: isPl ? "Jedno bezpieczne miejsce na całą historię Twojego rozwoju" : "One secure space for your entire growth history",
      }
    },
    how: {
      overline: isPl ? "Jak to działa" : "How It Works",
      heading: isPl ? "Trzy kroki do pełnego wdrożenia wniosków z terapii" : "Three Steps to Actionable Therapy Progress",
      cta: isPl ? "Zapisz się na listę oczekujących" : "Join the Waitlist Now",
      micro: isPl ? "Wczesny dostęp do zamkniętej bety. Całkowicie za darmo." : "Early access to closed beta. Completely free.",
      steps: [
        {
          tag: "01",
          title: isPl ? "Nagraj swoje myśli zaraz po sesji" : "Record Your Thoughts Post-Session",
          body: isPl 
            ? "Po wyjściu z gabinetu otwórz aplikację i nagraj krótką notatkę głosową. Opowiedz o tym, co było ważne, jakie emocje Ci towarzyszyły i co chcesz zapamiętać. Nie przejmuj się chaosem – aplikacja uporządkuje Twoje myśli." 
            : "Right after leaving your session, open the app and record a quick voice note. Share what was important, how you felt, and what you want to remember. Don't worry about flow – the AI structures it for you.",
        },
        {
          tag: "02",
          title: isPl ? "Odbierz ustrukturyzowane podsumowanie" : "Get a Structured Summary",
          body: isPl 
            ? "Aplikacja automatycznie wygeneruje pełną transkrypcję (zapis słowo w słowo) oraz czytelne podsumowanie. Zobaczysz w nim kluczowe wglądy, wnioski, zadane ćwiczenia oraz powtarzające się wzorce emocjonalne." 
            : "The app automatically transcribes your voice note word-for-word and generates a clean summary. You'll see key insights, conclusions, homework exercises, and recurring emotional patterns.",
        },
        {
          tag: "03",
          title: isPl ? "Wdrażaj plan działania w życie" : "Actively Implement Your Plan",
          body: isPl 
            ? "Aplikacja pomaga Ci przekuć teorię w praktykę. Twoje cele i zadania domowe są zawsze pod ręką – śledzisz postępy między sesjami, zauważasz zmiany i wchodzisz na kolejne spotkanie w pełni przygotowanym." 
            : "The app helps you translate theory into everyday practice. Your goals and homework are always at hand – track progress between sessions, notice changes, and enter your next session fully prepared.",
        }
      ]
    },
    features: {
      title: isPl ? "Zaprojektowane z myślą o Twoim spokoju" : "Designed For Your Peace of Mind",
      subtitle: isPl 
        ? "Wykastrowaliśmy nasz model językowy ze zbędnych interpretacji i diagnoz. Aplikacja skupia się wyłącznie na strukturze i faktach."
        : "We stripped our language models of unsolicited advice and diagnoses. The app focuses purely on structure and facts.",
      list: [
        {
          icon: (
            <svg className="w-6 h-6 text-ember" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.042A8.967 8.967 0 0 0 6 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 0 1 6 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 0 1 6-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0 0 18 18a8.967 8.967 0 0 0-6 2.292m0-14.25v14.25" />
            </svg>
          ),
          title: isPl ? "Pełna transkrypcja słowo w słowo" : "Full Word-for-Word Transcript",
          desc: isPl 
            ? "Otrzymujesz kompletny tekstowy zapis całej rozmowy. Możesz łatwo przeszukać tekst, aby wrócić do konkretnego zdania czy myśli." 
            : "Get a complete text record of the entire conversation. Easily search through the transcript to find specific quotes or thoughts.",
        },
        {
          icon: (
            <svg className="w-6 h-6 text-ember" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" viewBox="0 0 24 24">
              <rect x="3" y="3" width="18" height="18" rx="2" />
              <line x1="9" y1="9" x2="15" y2="9" />
              <line x1="9" y1="13" x2="15" y2="13" />
              <line x1="9" y1="17" x2="13" y2="17" />
            </svg>
          ),
          title: isPl ? "Wdrażanie planów i działań w życie" : "Action Plan Implementation",
          desc: isPl 
            ? "Aplikacja wspiera Cię w praktycznym wdrażaniu planu działania wypracowanego na sesjach. Twoje wnioski i zadania są zawsze pod ręką – nic Ci nie ucieknie." 
            : "The app supports you in putting your therapy action plans into practice between sessions. Your insights and homework are always within reach, so nothing slips away.",
        },
        {
          icon: (
            <svg className="w-6 h-6 text-ember" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.57-.598-3.751h-.152c-3.196 0-6.1-1.249-8.25-3.286zm0 13.036h.008v.008H12v-.008z" />
            </svg>
          ),
          title: isPl ? "Bezpieczeństwo i poufność" : "Privacy and Security",
          desc: isPl 
            ? "Twoje dane są chronione szyfrowaniem AES-256 (Zero-Knowledge). Pliki audio są nieodwracalnie kasowane natychmiast po wygenerowaniu tekstu." 
            : "Your data is protected with AES-256 (Zero-Knowledge) encryption. Audio files are permanently deleted immediately after processing.",
        }
      ]
    },
    security: {
      title: isPl ? "Bezkompromisowe bezpieczeństwo danych" : "Uncompromised Data Security",
      desc: isPl 
        ? "Dane z psychoterapii to najbardziej wrażliwe informacje. Zbudowaliśmy system w oparciu o architekturę Zero-Knowledge i restrykcyjne wymogi RODO."
        : "Therapy details are highly sensitive. We built our app around Zero-Knowledge architecture and strict GDPR compliance.",
      points: [
        { title: isPl ? "Pełne szyfrowanie (AES-256)" : "Envelope Encryption (AES-256)", desc: isPl ? "Nawet my nie mamy technicznej możliwości odczytania Twoich notatek." : "Even our developers cannot read or access your therapy summaries." },
        { title: isPl ? "Hosting w Unii Europejskiej" : "EU Data Hosting", desc: isPl ? "Wszystkie nagrania i teksty są przetwarzane w regionie europejskim (Warszawa/Frankfurt)." : "All recordings and text data are processed within secure EU regions." },
        { title: isPl ? "Brak treningu modeli AI" : "No AI Model Training", desc: isPl ? "Twoje dane nigdy nie posłużą do uczenia modeli językowych podmiotów trzecich." : "Your data is strictly yours and never used for machine learning models." },
      ]
    },
    faq: {
      title: isPl ? "Często zadawane pytania" : "Frequently Asked Questions",
      list: [
        {
          q: isPl ? "Czy ta aplikacja zastępuje psychoterapeutę?" : "Does this app replace a psychotherapist?",
          a: isPl 
            ? "Zdecydowanie nie. Aplikacja jest bezpiecznym, cyfrowym notatnikiem, który ma Ci pomóc w pracy własnej pomiędzy sesjami. Nie diagnozuje, nie sugeruje rozwiązań i nie prowadzi terapii."
            : "Absolutely not. The app is a secure digital journal designed to support your own work between sessions. It does not diagnose, suggest treatment, or provide therapy.",
        },
        {
          q: isPl ? "Czy mój terapeuta będzie widział moje notatki?" : "Will my therapist see my notes?",
          a: isPl 
            ? "Nie. Twoje konto jest całkowicie prywatne. Twoje notatki są widoczne tylko dla Ciebie. Możesz oczywiście samodzielnie skopiować i wysłać podsumowanie swojemu terapeucie lub pokazać mu je w gabinecie na telefonie, jeśli zechcesz."
            : "No. Your account is entirely private. Your notes are only visible to you. You can, of course, copy and share summaries with your therapist or show them during a session if you choose to.",
        },
        {
          q: isPl ? "W jaki sposób chronione są moje wrażliwe dane?" : "How is my sensitive data protected?",
          a: isPl 
            ? "Wszystkie podsumowania są szyfrowane kluczem, do którego dostęp masz wyłącznie Ty. Serwery bazy danych znajdują się w Unii Europejskiej (zgodnie z RODO). Po przetworzeniu nagrania audio, plik dźwiękowy jest natychmiast bezpowrotnie usuwany – przechowujemy wyłącznie tekstowe podsumowanie i transkrypcję."
            : "All summaries are encrypted using a key accessible only by you. Our database servers are located in the EU (GDPR compliant). Once your audio recording is processed, it is immediately and permanently deleted – we only store the text summary and transcript.",
        },
        {
          q: isPl ? "Ile kosztuje korzystanie z aplikacji?" : "How much does it cost?",
          a: isPl 
            ? "Dla osób, które dołączą do programu wczesnego dostępu (Beta) za pośrednictwem listy oczekujących, korzystanie z podstawowych funkcji aplikacji będzie całkowicie bezpłatne."
            : "For users who join the early access program (Beta) via the waitlist, access to core features will be completely free.",
        }
      ]
    },
    ctaBlock: {
      title: isPl ? "Zacznij wyciągać więcej ze swojej terapii" : "Start Getting More From Your Therapy",
      subtitle: isPl 
        ? "Dołącz do zamkniętej bety i przetestuj asystenta Superwizor AI całkowicie za darmo."
        : "Join the closed beta program and test Superwizor AI companion completely for free.",
      button: isPl ? "Zapisz się na listę oczekujących" : "Join the Waitlist Now",
    }
  };

  const GLYPH_ICONS = [
    // Lock
    <svg key="g_lock" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" className="w-10 h-10 text-frost/25">
      <rect x="5" y="9" width="10" height="7" rx="1.5" />
      <path d="M7 9V7a3 3 0 0 1 6 0v2" />
    </svg>,
    // Shield
    <svg key="g_shield" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" className="w-10 h-10 text-frost/25">
      <path d="M10 2l6 2.5v4c0 4-2.5 7-6 8.5-3.5-1.5-6-4.5-6-8.5v-4L10 2Z" />
    </svg>,
    // Fingerprint
    <svg key="g_fp" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" className="w-10 h-10 text-frost/25">
      <path d="M10 3a7 7 0 0 0-7 7M10 3a7 7 0 0 1 7 7M10 6a4 4 0 0 0-4 4M10 6a4 4 0 0 1 4 4v2" />
    </svg>,
    // Brain
    <svg key="g_brain" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2" className="w-10 h-10 text-frost/25">
      <circle cx="10" cy="6" r="1.5" /><circle cx="6" cy="11" r="1.5" /><circle cx="14" cy="11" r="1.5" /><circle cx="10" cy="15.5" r="1.5" />
      <line x1="10" y1="7.5" x2="6.8" y2="9.8" /><line x1="10" y1="7.5" x2="13.2" y2="9.8" />
    </svg>
  ];

  const traditionalIcons = [
    // 1. Chaos w głowie (Spirala/Wir)
    <svg key="t1" className="w-4 h-4 text-magma shrink-0 mt-0.5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" viewBox="0 0 24 24">
      <path d="M12 2a10 10 0 0 0-10 10c0 5.5 4.5 10 10 10s10-4.5 10-10c0-4.5-3.5-8-8-8s-8 3.5-8 8c0 3.5 2.5 6 6 6s6-2.5 6-6c0-2.5-1.5-4-4-4s-4 1.5-4 4" />
    </svg>,
    // 2. Ulotne wnioski (Klepsydra uciekającego czasu)
    <svg key="t2" className="w-4 h-4 text-magma shrink-0 mt-0.5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" viewBox="0 0 24 24">
      <path d="M5 2h14M5 22h14M19 2v6.5c0 1.5-1 3-2.5 4L12 15l-4.5-2.5C6 11.5 5 10 5 8.5V2" />
      <path d="M5 22v-6.5c0-1.5 1-3 2.5-4L12 9l4.5 2.5c1.5 1 2.5 2.5 2.5 4v6.5" />
    </svg>,
    // 3. Stres przed kolejną sesją (Trójkąt ostrzegawczy / napięcie)
    <svg key="t3" className="w-4 h-4 text-magma shrink-0 mt-0.5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" viewBox="0 0 24 24">
      <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
      <line x1="12" y1="9" x2="12" y2="13" />
      <line x1="12" y1="17" x2="12.01" y2="17" />
    </svg>,
    // 4. Rozproszone notatki (Rozrzucone, przekreślone kartki)
    <svg key="t4" className="w-4 h-4 text-magma shrink-0 mt-0.5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" viewBox="0 0 24 24">
      <path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="8" y1="13" x2="16" y2="13" strokeDasharray="2 2" />
      <line x1="8" y1="17" x2="12" y2="17" strokeDasharray="2 2" />
      <line x1="3" y1="3" x2="21" y2="21" />
    </svg>
  ];

  // Helper to build scrolling rows of glyphs
  const buildRow = (icons: React.ReactNode[], offset: number) => {
    const list = [];
    for (let i = 0; i < 24; i++) {
      list.push(icons[(i + offset) % icons.length]);
    }
    return list;
  };

  const featureRow1 = buildRow(GLYPH_ICONS, 0);
  const featureRow2 = buildRow(GLYPH_ICONS, 2);
  const featureRow3 = buildRow(GLYPH_ICONS, 1);

  return (
    <div className="w-full bg-[#001114] text-frost overflow-x-hidden">
      
      {/* SCOPED ANIMATIONS FOR BEAM & GRADIENT & FLOATING EFFECTS */}
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes rotateBeam {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        .animate-rotate-beam { animation: rotateBeam 7s linear infinite; }

        @keyframes pulseGlow {
          0%, 100% { opacity: 0.2; transform: scale(1); }
          50% { opacity: 0.35; transform: scale(1.1); }
        }
        .animate-pulse-glow { animation: pulseGlow 10s ease-in-out infinite; }

        @keyframes floaty {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-8px); }
        }
        .animate-floaty-1 { animation: floaty 5s ease-in-out infinite; }
        .animate-floaty-2 { animation: floaty 5s ease-in-out infinite 0.8s; }

        @keyframes scrollGlyphRight {
          0% { transform: translate3d(-50%, 0, 0); }
          100% { transform: translate3d(0, 0, 0); }
        }
        @keyframes scrollGlyphLeft {
          0% { transform: translate3d(0, 0, 0); }
          100% { transform: translate3d(-50%, 0, 0); }
        }
        .glyph-row-1 { animation: scrollGlyphRight 120s linear infinite; }
        .glyph-row-2 { animation: scrollGlyphLeft 100s linear infinite; }
        .glyph-row-3 { animation: scrollGlyphRight 140s linear infinite; }

        @keyframes security-pulse {
          0%, 100% { box-shadow: 0 0 0 0 rgba(250,250,250,0), 0 0 40px rgba(250,250,250,0.06); }
          50% { box-shadow: 0 0 0 12px rgba(250,250,250,0), 0 0 60px rgba(250,250,250,0.16); }
        }
        .security-card-pulse { animation: security-pulse 4s ease-in-out infinite; }

        @keyframes driftGlow {
          0% { transform: translate(0, 0) scale(1) rotate(0deg); }
          33% { transform: translate(60px, -50px) scale(1.15) rotate(120deg); }
          66% { transform: translate(-30px, 30px) scale(0.9) rotate(240deg); }
          100% { transform: translate(0, 0) scale(1) rotate(360deg); }
        }
        .animate-drift-1 { animation: driftGlow 22s ease-in-out infinite; }
        .animate-drift-2 { animation: driftGlow 28s ease-in-out infinite 2s; }
        .animate-drift-3 { animation: driftGlow 25s ease-in-out infinite 4s; }
      `}} />

      {/* HERO SECTION */}
      <section className="relative w-full pt-28 sm:pt-36 lg:pt-44 pb-20 lg:pb-32 bg-gradient-to-b from-[#001114] via-[#002E32] to-[#004D54] border-b border-frost/5 overflow-hidden">
        
        {/* Decorative background ambient glows */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[90vw] max-w-[1000px] h-[600px] bg-gradient-to-b from-ember/[0.08] to-transparent blur-[160px] pointer-events-none rounded-full animate-pulse-glow" />
        <div className="absolute -top-40 -right-40 w-[400px] h-[400px] bg-[#004D54]/20 blur-[100px] pointer-events-none rounded-full" />

        <div className="relative mx-auto w-full max-w-[1080px] px-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
            
            {/* Left Column: Copy & Actions */}
            <div className="lg:col-span-7 flex flex-col items-center lg:items-start text-center lg:text-left">
              
              {/* Overline badge */}
              <motion.div 
                initial={{ opacity: 0, y: 15 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6 }}
                className="inline-flex items-center gap-2 mb-6 bg-white/[0.04] border border-white/[0.08] backdrop-blur-md rounded-full px-4 py-1.5"
              >
                <span className="w-2 h-2 rounded-full bg-ember animate-ping" />
                <span className="font-mono text-[10px] sm:text-[11px] uppercase tracking-[2.5px] text-ember font-semibold">
                  {content.hero.overline}
                </span>
              </motion.div>

              {/* Title */}
              <motion.h1 
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.15 }}
                className="font-display text-frost text-4xl sm:text-5xl md:text-6xl font-bold tracking-tight leading-[1.1] mb-6 max-w-2xl"
              >
                {content.hero.heading}
              </motion.h1>

              {/* Description */}
              <motion.p 
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.3 }}
                className="font-serif text-mist/80 text-base sm:text-lg md:text-xl leading-relaxed max-w-xl mb-10"
              >
                {content.hero.subtitle}
              </motion.p>

              {/* Action and Value Seals */}
              <motion.div 
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.45 }}
                className="flex flex-col sm:flex-row items-center gap-4 w-full sm:w-auto mb-8"
              >
                <a
                  href={tallyLink}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="group relative inline-flex items-center justify-center rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4.5 transition-all duration-300 active:scale-[0.97] w-full sm:w-auto whitespace-nowrap overflow-hidden shadow-ember-glow"
                >
                  <span className="absolute inset-0 rounded-[12px] bg-ember/30 blur-lg group-hover:blur-xl transition-all duration-500 -z-10 scale-110" />
                  <span className="relative z-10 flex items-center gap-2">
                    {content.hero.cta}
                    <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
                  </span>
                </a>
              </motion.div>

              {/* GDPR and trust microtexts */}
              <motion.div 
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.6, delay: 0.6 }}
                className="flex flex-wrap items-center justify-center lg:justify-start gap-x-6 gap-y-3 text-xs font-mono uppercase tracking-wider text-mist/60"
              >
                <span className="flex items-center gap-2">
                  <svg className="w-4 h-4 text-emerald-400 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                  {content.hero.badgeRODO}
                </span>
                <span className="flex items-center gap-2">
                  <svg className="w-4 h-4 text-emerald-400 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                  {content.hero.badgeNoTrain}
                </span>
              </motion.div>
            </div>

            {/* Right Column: Custom HTML Phone Mockup for Patients with Floating Badges */}
            <div className="lg:col-span-5 flex justify-center lg:justify-end relative">
              <motion.div 
                initial={{ opacity: 0, scale: 0.95, y: 30 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                transition={{ duration: 0.8, type: "spring", stiffness: 50 }}
                className="relative w-[300px] z-10"
              >
                
                {/* Backlighting glow */}
                <div className="absolute -inset-16 bg-[radial-gradient(circle_at_center,rgba(252,174,47,0.08),transparent_60%)] blur-[40px] pointer-events-none" />
                <div className="absolute -inset-10 bg-[radial-gradient(circle_at_center,rgba(255,255,255,0.06),transparent_50%)] blur-[25px] pointer-events-none" />

                {/* Floating Badge 1: Top-Left (100% Privacy) */}
                <div className="absolute top-[58px] -left-8 z-20 bg-white border border-[#e2ded5] rounded-xl px-3.5 py-2.5 shadow-[0_12px_32px_-12px_rgba(27,37,34,0.3)] flex items-center gap-2.5 animate-floaty-1">
                  <svg className="w-4.5 h-4.5 text-[#2f6b62] shrink-0" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="5" y="9" width="10" height="7" rx="1.5" />
                    <path d="M7 9V7a3 3 0 0 1 6 0v2" />
                  </svg>
                  <div className="flex flex-col text-left">
                    <span className="font-sans text-[12px] font-bold text-[#1b2522] leading-tight">
                      {content.hero.badgeFloatPrivacy}
                    </span>
                    <span className="font-sans text-[10px] font-semibold text-[#4e5a55]/90 mt-0.5 leading-tight">
                      {content.hero.badgeFloatPrivacySub}
                    </span>
                  </div>
                </div>

                {/* Floating Badge 2: Bottom-Right (RODO Compliant) */}
                <div className="absolute bottom-[90px] -right-8 z-20 bg-white border border-[#e2ded5] rounded-xl px-3.5 py-2.5 shadow-[0_12px_32px_-12px_rgba(27,37,34,0.3)] flex items-center gap-2 animate-floaty-2">
                  <svg className="w-4 h-4 text-[#2f6b62] shrink-0" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M10 2l6 2.5v4c0 4-2.5 7-6 8.5-3.5-1.5-6-4.5-6-8.5v-4L10 2Z" />
                  </svg>
                  <span className="font-sans text-[12px] font-bold text-[#1b2522]">
                    {content.hero.badgeFloatGDPR}
                  </span>
                </div>

                {/* Outer Phone Frame (Rotating border beam) */}
                <div className="relative w-full rounded-[42px] p-[1.5px] overflow-hidden bg-white/[0.08] shadow-[0_20px_50px_rgba(0,0,0,0.6)]">
                  <div className="absolute inset-[-100%] bg-[conic-gradient(from_0deg,transparent_70%,rgba(252,174,47,0.25)_80%,#FCAE2F_90%,#FAFAFA_98%,transparent_100%)] animate-rotate-beam pointer-events-none" />
                  
                  {/* Phone body shell */}
                  <div className="relative w-full rounded-[40.5px] p-2.5 bg-[#10211d] border border-[#0b1714]">
                    {/* Notch */}
                    <div className="absolute top-2.5 left-1/2 -translate-x-1/2 w-[110px] h-[22px] bg-[#10211d] rounded-b-2xl z-30" />
                    
                    {/* Screen Content */}
                    <div className="relative w-full rounded-[30px] overflow-hidden bg-[#0d2729] p-4 pt-9 min-h-[510px] text-white">
                      
                      {/* Fake Status Bar */}
                      <div className="flex justify-between items-center text-[9px] text-white/50 px-2 mb-4">
                        <span>12:45</span>
                        <div className="flex items-center gap-1">
                          <span className="w-2 h-2 rounded-full bg-emerald-500 inline-block animate-pulse" />
                          <span>{content.mockup.status}</span>
                        </div>
                      </div>

                      {/* Fake App Bar */}
                      <div className="flex items-center gap-2 mb-5 px-1 border-b border-white/5 pb-3">
                        <div className="w-7 h-7 rounded-full bg-ember/15 flex items-center justify-center text-ember font-bold text-xs shrink-0">
                          S
                        </div>
                        <div>
                          <h4 className="text-[11px] font-bold tracking-wide leading-none">{content.mockup.title}</h4>
                          <span className="text-[8.5px] text-[#8ba4a6]">{content.mockup.subtitle}</span>
                        </div>
                      </div>

                      {/* Simulated Session Pod */}
                      <div className="space-y-3 max-h-[390px] overflow-y-auto pr-0.5 scrollbar-thin">
                        
                        {/* Section: Transcript */}
                        <div className="bg-[#143437] border border-[#1e484c] rounded-xl p-3">
                          <div className="flex items-center gap-1.5 mb-2">
                            <svg className="w-3.5 h-3.5 text-ember shrink-0" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M12 7.5h1.5m-1.5 3h1.5m-7.5-6h7.5m-7.5 3h7.5m-7.5 3h7.5m-.75 6h7.5M12 16.5h1.5M6 21h12a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2Z" />
                            </svg>
                            <span className="text-[9.5px] font-bold uppercase tracking-wider text-mist">
                              {content.mockup.sectionTranscript}
                            </span>
                          </div>
                          <p className="text-[10px] text-frost/95 italic pl-1.5 border-l-2 border-ember/70 leading-relaxed font-serif">
                            {content.mockup.transcriptDesc}
                          </p>
                        </div>

                        {/* Section: Insights */}
                        <div className="bg-[#143437] border border-[#1e484c] rounded-xl p-3">
                          <div className="flex items-center gap-1.5 mb-2">
                            <svg className="w-3.5 h-3.5 text-ember shrink-0" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M12 18a3.75 3.75 0 1 0 0-7.5 3.75 3.75 0 0 0 0 7.5ZM21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                            </svg>
                            <span className="text-[9.5px] font-bold uppercase tracking-wider text-mist">
                              {content.mockup.sectionInsights}
                            </span>
                          </div>
                          <ul className="space-y-2 text-[10px] text-frost/90 pl-1">
                            <li className="flex items-start gap-1.5 leading-relaxed">
                              <span className="text-ember mt-0.5">•</span>
                              <span>{content.mockup.insight1}</span>
                            </li>
                            <li className="flex items-start gap-1.5 leading-relaxed">
                              <span className="text-ember mt-0.5">•</span>
                              <span>{content.mockup.insight2}</span>
                            </li>
                          </ul>
                        </div>

                        {/* Section: Homework */}
                        <div className="bg-[#143437] border border-[#1e484c] rounded-xl p-3">
                          <div className="flex items-center gap-1.5 mb-2">
                            <svg className="w-3.5 h-3.5 text-ember shrink-0" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2M9 5a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2M9 5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2" />
                            </svg>
                            <span className="text-[9.5px] font-bold uppercase tracking-wider text-mist">
                              {content.mockup.sectionHomework}
                            </span>
                          </div>
                          <p className="text-[10px] text-frost/90 pl-1 leading-relaxed">
                            {content.mockup.homework1}
                          </p>
                        </div>

                        {/* Section: Patterns */}
                        <div className="bg-[#143437]/50 border border-[#1e484c]/50 rounded-xl p-3 opacity-90">
                          <div className="flex items-center gap-1.5 mb-1.5">
                            <svg className="w-3.5 h-3.5 text-ember shrink-0" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M7.5 14.25v2.25m3-4.5v4.5m3-6.75v6.75m3-9v9M6 20.25h12A2.25 2.25 0 0 0 20.25 18V6A2.25 2.25 0 0 0 18 3.75H6A2.25 2.25 0 0 0 3.75 6v12A2.25 2.25 0 0 0 6 20.25Z" />
                            </svg>
                            <span className="text-[9.5px] font-bold uppercase tracking-wider text-mist/80">
                              {content.mockup.sectionPatterns}
                            </span>
                          </div>
                          <div className="inline-flex items-center gap-1 bg-[#d84515]/20 text-[#ff7c54] text-[8.5px] px-2 py-0.5 rounded-full font-semibold">
                            <span className="w-1 h-1 rounded-full bg-[#ff7c54] animate-ping" />
                            {content.mockup.pattern1}
                          </div>
                        </div>

                      </div>

                    </div>
                  </div>
                </div>

              </motion.div>
            </div>

          </div>
        </div>
      </section>

      {/* PAIN POINTS SECTION (TRADITIONAL VS SUPERWIZOR) */}
      <section className="relative py-24 bg-[#002E32]/70 border-b border-frost/5">
        <div className="max-w-[960px] mx-auto px-6">
          <div className="text-center max-w-2xl mx-auto mb-16">
            <h2 className="font-display text-frost text-3xl sm:text-4xl font-bold tracking-tight mb-4">
              {content.painPoints.title}
            </h2>
            <p className="font-serif text-mist/70 text-sm sm:text-base leading-relaxed">
              {content.painPoints.subtitle}
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 lg:gap-12 items-stretch">
            
            {/* Traditional Column */}
            <div className="bg-[#001114]/40 border border-white/5 rounded-2xl p-8 flex flex-col transition-all duration-300 hover:border-white/10">
              <h3 className="font-display text-white/50 text-xl font-bold uppercase tracking-wider mb-6 flex items-center gap-2">
                <span className="w-1.5 h-1.5 rounded-full bg-white/30" />
                {content.painPoints.traditional.title}
              </h3>
              <ul className="space-y-4 flex-1">
                {[
                  content.painPoints.traditional.item1,
                  content.painPoints.traditional.item2,
                  content.painPoints.traditional.item3,
                  content.painPoints.traditional.item4,
                ].map((item, idx) => (
                  <li key={idx} className="flex items-start gap-3 text-sm text-mist/60">
                    {traditionalIcons[idx % traditionalIcons.length]}
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
            </div>

            {/* Superwizor Column */}
            <div className="relative bg-gradient-to-b from-[#1f353a]/50 to-[#0d2729]/30 border border-[#2f6b62]/40 rounded-2xl p-8 flex flex-col shadow-[0_10px_30px_rgba(0,0,0,0.15)] transition-all duration-300 hover:border-[#2f6b62]/70">
              <div className="absolute top-4 right-4 bg-ember/15 text-ember font-mono text-[9px] uppercase tracking-wider px-2 py-0.5 rounded-full font-bold">
                PRO
              </div>
              <h3 className="font-display text-ember text-xl font-bold uppercase tracking-wider mb-6 flex items-center gap-2">
                <span className="w-1.5 h-1.5 rounded-full bg-ember animate-ping" />
                {content.painPoints.superwizor.title}
              </h3>
              <ul className="space-y-4 flex-1">
                {[
                  content.painPoints.superwizor.item1,
                  content.painPoints.superwizor.item2,
                  content.painPoints.superwizor.item3,
                  content.painPoints.superwizor.item4,
                ].map((item, idx) => (
                  <li key={idx} className="flex items-start gap-3 text-sm text-frost">
                    <svg className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
                    </svg>
                    <span className="font-semibold">{item}</span>
                  </li>
                ))}
              </ul>
            </div>

          </div>

          <div className="text-center mt-12">
            <a
              href={tallyLink}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-ember font-sans font-bold uppercase tracking-wider text-xs hover:text-[#ffd387] transition-colors group"
            >
              {isPl ? "Przejdź do formularza zapisu" : "Go to Signup Form"}
              <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
            </a>
          </div>
        </div>
      </section>

      {/* HOW IT WORKS SECTION (3 STEPS) */}
      <section className="relative py-24 sm:py-32 bg-gradient-to-b from-[#002E32]/50 to-[#001114] text-frost border-b border-frost/5 overflow-hidden">
        
        {/* Scoped CSS animations for the pop circles and ripples */}
        <style dangerouslySetInnerHTML={{ __html: `
          @keyframes popCircleDark {
            0% {
              scale: 0.95;
              box-shadow: 0 0 0 0 rgba(252, 174, 47, 0);
            }
            100% {
              scale: 1.12;
              box-shadow: 0 0 18px 4px rgba(252, 174, 47, 0.4);
            }
          }
          @keyframes rippleOuterDark {
            0% {
              scale: 0.9;
              opacity: 0.87;
            }
            100% {
              scale: 2.9;
              opacity: 0;
            }
          }
          .animate-pop-circle-dark {
            animation: popCircleDark 1.1s cubic-bezier(0.25, 1, 0.5, 1) forwards;
          }
          .animate-ripple-1-dark {
            animation: rippleOuterDark 1.9s cubic-bezier(0.1, 0.8, 0.3, 1) forwards;
            filter: blur(1.0px);
          }
          .animate-ripple-2-dark {
            animation: rippleOuterDark 2.4s cubic-bezier(0.1, 0.8, 0.3, 1) 0.4s forwards;
            filter: blur(2.0px);
          }
        `}} />

        <div className="mx-auto w-full max-w-[1080px] px-6 relative z-10">
          <div className="text-center mb-20">
            <p className="font-mono text-[10px] sm:text-xs uppercase text-ember tracking-[var(--tracking-overline)] mb-3 font-semibold">
              {content.how.overline}
            </p>
            <h2 className="font-display text-frost text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight max-w-2xl mx-auto leading-tight">
              {content.how.heading}
            </h2>
          </div>

          {/* Timeline container */}
          <div ref={containerRef} className="relative">
            {/* Vertical connector line — visible on lg only */}
            <div className="hidden lg:block absolute left-1/2 top-8 bottom-8 w-[2px] -translate-x-1/2 bg-white/10">
              {/* Dynamic progress fill (Ember orange/yellow line) */}
              <div 
                className="absolute top-0 left-0 w-[4px] -translate-x-[1px] bg-ember rounded-full transition-all duration-300 ease-out" 
                style={{ height: `${maxProgress}%` }}
              />
            </div>

            <div className="space-y-20 sm:space-y-28">
              {content.how.steps.map((step, i) => {
                const isReversed = i % 2 !== 0;

                return (
                  <div 
                    key={i} 
                    id={`step-row-${i}`}
                    className="relative grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-16 items-center"
                  >
                    {/* Step number node on the timeline — lg only */}
                    <div 
                      className={`hidden lg:flex absolute left-1/2 -translate-x-1/2 w-12 h-12 rounded-full items-center justify-center z-20 border-4 transition-all duration-500 ${
                        activeSteps[i]
                          ? "bg-ember border-[#001114] text-[#10211d] animate-pop-circle-dark font-bold"
                          : "bg-[#004D54] border-[#001114] text-frost shadow-md"
                      }`}
                    >
                      <span className="font-display text-sm font-bold">{step.tag}</span>
                      {activeSteps[i] && (
                        <>
                          <span className="absolute -inset-1.5 rounded-full border-2 border-ember/55 animate-ripple-1-dark pointer-events-none" />
                          <span className="absolute -inset-3 rounded-full border-[3px] border-ember/25 animate-ripple-2-dark pointer-events-none" />
                        </>
                      )}
                    </div>

                    {/* Text side */}
                    <div className={`lg:col-span-5 flex flex-col items-start text-left ${isReversed ? "order-1 lg:order-2 lg:col-start-8 lg:pl-4" : "order-1 lg:order-1 lg:pr-4"}`}>
                      {/* Mobile step indicator */}
                      <div className="lg:hidden flex items-center gap-3 mb-4">
                        <span 
                          className={`w-9 h-9 rounded-full flex items-center justify-center relative border-2 transition-all duration-500 ${
                            activeSteps[i]
                              ? "bg-ember border-[#001114] text-[#10211d] animate-pop-circle-dark font-bold"
                              : "bg-[#004D54] border-[#001114] text-frost shadow-sm"
                          }`}
                        >
                          <span className="font-display text-xs font-bold">{step.tag}</span>
                          {activeSteps[i] && (
                            <>
                              <span className="absolute -inset-1 rounded-full border-2 border-ember/55 animate-ripple-1-dark pointer-events-none" />
                              <span className="absolute -inset-2.5 rounded-full border-[3px] border-ember/25 animate-ripple-2-dark pointer-events-none" />
                            </>
                          )}
                        </span>
                        <span className="font-mono text-[10px] uppercase tracking-[2px] text-ember font-semibold">
                          {isPl ? "Krok" : "Step"} {step.tag}
                        </span>
                      </div>

                      <h3 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-tight leading-snug">
                        {step.title}
                      </h3>
                      <p className="font-serif text-mist/70 text-base leading-relaxed mt-3">
                        {step.body}
                      </p>
                    </div>

                    {/* Image side */}
                    <div className={`lg:col-span-5 flex justify-center relative ${isReversed ? "order-2 lg:order-1 lg:col-start-1" : "order-2 lg:order-2 lg:col-start-8"}`}>
                      <div className="relative group max-w-[320px] w-full">
                        {/* Glow behind */}
                        <div className="absolute -inset-4 rounded-[32px] bg-ember/5 blur-xl group-hover:bg-ember/10 transition-all duration-500" />
                        <div className="relative rounded-[24px] border border-white/10 bg-gradient-to-b from-[#002e32] to-[#001114] shadow-xl overflow-hidden select-none transition-transform duration-300 group-hover:scale-[1.02]">
                          <img
                            src={stepImages[i]}
                            alt={step.title}
                            loading="lazy"
                            width={640}
                            height={480}
                            className="w-full h-auto object-cover"
                          />
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* CTA */}
          <div className="mt-20 flex flex-col items-center">
            <a
              href={tallyLink}
              target="_blank"
              rel="noopener noreferrer"
              className="group relative inline-flex items-center justify-center rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4.5 transition-all duration-300 active:scale-[0.97] whitespace-nowrap overflow-hidden shadow-ember-glow"
            >
              <span className="absolute inset-0 rounded-[12px] bg-ember/30 blur-lg group-hover:blur-xl transition-all duration-500 -z-10 scale-110" />
              <span className="relative z-10 flex items-center gap-2">
                {content.how.cta}
                <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
              </span>
            </a>
            <span className="mt-3 font-mono text-[10px] uppercase text-mist/60 tracking-[2px]">
              {content.how.micro}
            </span>
          </div>
        </div>
      </section>

      {/* CORE FEATURES (INTERACTIVE HOVER ICONS & 3 SCROLLING ROWS OF GLYPHS IN BACKGROUND) */}
      <section className="relative py-24 lg:py-32 border-b border-frost/5 overflow-hidden">
        
        {/* Continuous scroll of icons in 3 alternating rows in background */}
        <div className="absolute inset-0 flex flex-col justify-center gap-14 pointer-events-none select-none opacity-40 z-0">
          {/* Row 1 */}
          <div className="flex w-full overflow-hidden">
            <div className="flex gap-14 glyph-row-1 whitespace-nowrap min-w-max">
              {[...featureRow1, ...featureRow1].map((icon, idx) => (
                <div key={`fr1-${idx}`} className="w-10 h-10 shrink-0">
                  {icon}
                </div>
              ))}
            </div>
          </div>
          {/* Row 2 */}
          <div className="flex w-full overflow-hidden">
            <div className="flex gap-14 glyph-row-2 whitespace-nowrap min-w-max">
              {[...featureRow2, ...featureRow2].map((icon, idx) => (
                <div key={`fr2-${idx}`} className="w-10 h-10 shrink-0">
                  {icon}
                </div>
              ))}
            </div>
          </div>
          {/* Row 3 */}
          <div className="flex w-full overflow-hidden">
            <div className="flex gap-14 glyph-row-3 whitespace-nowrap min-w-max">
              {[...featureRow3, ...featureRow3].map((icon, idx) => (
                <div key={`fr3-${idx}`} className="w-10 h-10 shrink-0">
                  {icon}
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Ambient background glowing orbs */}
        <div className="absolute top-1/4 left-1/4 w-[350px] h-[350px] bg-ember/[0.04] blur-[100px] rounded-full pointer-events-none animate-drift-1 z-0" />
        <div className="absolute bottom-1/4 right-1/4 w-[400px] h-[400px] bg-[#004D54]/20 blur-[120px] rounded-full pointer-events-none animate-drift-2 z-0" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[300px] h-[300px] bg-aurora/[0.03] blur-[90px] rounded-full pointer-events-none animate-drift-3 z-0" />

        <div className="absolute -bottom-48 -left-48 w-96 h-96 bg-[#004D54]/10 blur-[120px] rounded-full pointer-events-none z-0" />

        <div className="relative max-w-[1080px] mx-auto px-6 z-10">
          <div className="text-center max-w-2xl mx-auto mb-20">
            <h2 className="font-display text-frost text-3xl sm:text-4xl font-bold tracking-tight mb-4">
              {content.features.title}
            </h2>
            <p className="font-serif text-mist/70 text-sm sm:text-base leading-relaxed">
              {content.features.subtitle}
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {content.features.list.map((feat, idx) => (
              <motion.div 
                key={idx} 
                whileHover={{ y: -5, borderColor: "rgba(252,174,47,0.3)" }}
                transition={{ duration: 0.3, ease: "easeOut" }}
                className="bg-gradient-to-b from-white/[0.04] to-white/[0.01] border border-white/[0.06] rounded-[20px] p-8 flex flex-col justify-between backdrop-blur-sm"
              >
                <div>
                  <motion.div 
                    whileHover={{ scale: 1.1, rotate: idx === 1 ? 5 : idx === 2 ? -5 : 0 }}
                    className="w-12 h-12 rounded-xl bg-white/[0.04] border border-white/[0.08] flex items-center justify-center mb-6 cursor-pointer"
                  >
                    {feat.icon}
                  </motion.div>
                  <h3 className="font-display text-frost text-lg font-bold mb-3">{feat.title}</h3>
                  <p className="font-serif text-mist/65 text-xs sm:text-sm leading-relaxed mb-6">{feat.desc}</p>
                </div>
              </motion.div>
            ))}
          </div>

          <div className="text-center mt-16">
            <a
              href={tallyLink}
              target="_blank"
              rel="noopener noreferrer"
              className="group relative inline-flex items-center justify-center rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs px-8 py-4.5 transition-all duration-300 active:scale-[0.97]"
            >
              <span className="relative z-10 flex items-center gap-2">
                {isPl ? "Chcę przetestować program" : "I want to test this"}
                <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
              </span>
            </a>
          </div>
        </div>
      </section>

      {/* SECURITY BAND FOR PATIENT (PULSING GLOW CARD) */}
      <section className="relative py-28 bg-[#002E32] overflow-hidden border-b border-frost/5">
        
        {/* Continuous scroll of icons in 3 alternating rows in background */}
        <div className="absolute inset-0 flex flex-col justify-center gap-14 pointer-events-none select-none opacity-[0.08] z-0">
          {/* Row 1 */}
          <div className="flex w-full overflow-hidden">
            <div className="flex gap-14 glyph-row-1 whitespace-nowrap min-w-max">
              {[...featureRow1, ...featureRow1].map((icon, idx) => (
                <div key={`sr1-${idx}`} className="w-10 h-10 shrink-0 text-frost/40">
                  {icon}
                </div>
              ))}
            </div>
          </div>
          {/* Row 2 */}
          <div className="flex w-full overflow-hidden">
            <div className="flex gap-14 glyph-row-2 whitespace-nowrap min-w-max">
              {[...featureRow2, ...featureRow2].map((icon, idx) => (
                <div key={`sr2-${idx}`} className="w-10 h-10 shrink-0 text-frost/40">
                  {icon}
                </div>
              ))}
            </div>
          </div>
          {/* Row 3 */}
          <div className="flex w-full overflow-hidden">
            <div className="flex gap-14 glyph-row-3 whitespace-nowrap min-w-max">
              {[...featureRow3, ...featureRow3].map((icon, idx) => (
                <div key={`sr3-${idx}`} className="w-10 h-10 shrink-0 text-frost/40">
                  {icon}
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="relative max-w-[960px] mx-auto px-6 z-10">
          
          {/* Pulsing glow container */}
          <div className="security-card-pulse max-w-2xl mx-auto text-center bg-gradient-to-b from-white/[0.05] to-white/[0.01] border border-white/[0.08] backdrop-blur-xl rounded-[28px] p-10 sm:p-14">
            <div className="w-14 h-14 rounded-2xl bg-white/[0.04] border border-white/[0.08] flex items-center justify-center mx-auto mb-8 text-frost/90">
              <svg className="w-7 h-7 animate-pulse" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.2">
                <path d="M10 2l6 2.5v4c0 4-2.5 7-6 8.5-3.5-1.5-6-4.5-6-8.5v-4L10 2Z" />
              </svg>
            </div>

            <h2 className="font-display text-frost text-2xl sm:text-3xl lg:text-4xl font-bold tracking-tight leading-tight mb-5">
              {content.security.title}
            </h2>
            <p className="font-serif text-mist/70 text-sm sm:text-base leading-relaxed mb-8">
              {content.security.desc}
            </p>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 text-left border-t border-white/10 pt-8">
              {content.security.points.map((pt, idx) => (
                <div key={idx} className="space-y-1.5">
                  <h4 className="font-sans text-frost text-[11px] font-bold uppercase tracking-wider">
                    {pt.title}
                  </h4>
                  <p className="font-serif text-mist/60 text-xs leading-relaxed">
                    {pt.desc}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* FAQ SECTION */}
      <section className="relative py-24 lg:py-32">
        <div className="max-w-[760px] mx-auto px-6">
          <div className="text-center mb-16">
            <h2 className="font-display text-frost text-3xl font-bold tracking-tight">
              {content.faq.title}
            </h2>
          </div>

          <div className="space-y-4">
            {content.faq.list.map((item, idx) => (
              <div 
                key={idx} 
                className="border-b border-white/5 pb-4 transition-colors duration-200"
              >
                <button
                  onClick={() => setActiveFaq(activeFaq === idx ? null : idx)}
                  className="w-full flex justify-between items-center text-left py-4 focus:outline-none"
                >
                  <span className="font-sans text-frost text-sm sm:text-base font-bold pr-4">
                    {item.q}
                  </span>
                  <span className="text-ember text-xl shrink-0 transition-transform duration-200" style={{ transform: activeFaq === idx ? 'rotate(45deg)' : 'rotate(0)' }}>
                    +
                  </span>
                </button>
                <AnimatePresence initial={false}>
                  {activeFaq === idx && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.25, ease: "easeInOut" }}
                      className="overflow-hidden"
                    >
                      <p className="font-serif text-mist/75 text-xs sm:text-sm leading-relaxed pb-4 pl-1">
                        {item.a}
                      </p>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* FINAL CTA SECTION */}
      <section className="relative py-28 lg:py-36 bg-gradient-to-b from-[#001114] to-[#002e32] overflow-hidden text-center">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[80vw] max-w-[600px] h-[300px] bg-ember/[0.04] blur-[120px] rounded-full pointer-events-none" />
        
        <div className="relative max-w-[640px] mx-auto px-6 z-10">
          <h2 className="font-display text-frost text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight leading-tight mb-6">
            {content.ctaBlock.title}
          </h2>
          <p className="font-serif text-mist/75 text-base sm:text-lg mb-10 max-w-md mx-auto leading-relaxed">
            {content.ctaBlock.subtitle}
          </p>
          
          <a
            href={tallyLink}
            target="_blank"
            rel="noopener noreferrer"
            className="group relative inline-flex items-center justify-center rounded-[12px] bg-ember text-obsidian font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-10 py-5 transition-all duration-300 active:scale-[0.97] shadow-ember-glow"
          >
            <span className="absolute inset-0 rounded-[12px] bg-ember/30 blur-lg group-hover:blur-xl transition-all duration-500 -z-10 scale-110" />
            <span className="relative z-10 flex items-center gap-2.5">
              {content.ctaBlock.button}
              <span className="transition-transform duration-300 group-hover:translate-x-1">→</span>
            </span>
          </a>
        </div>
      </section>

    </div>
  );
}
