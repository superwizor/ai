"use client";

import { useTranslations, useLocale } from "next-intl";
import { useRef, useState, useEffect } from "react";

const galleryItems = [
  {
    src: "/assets/screen_record.webp",
    pl: { title: "Ekran Nagrywania", desc: "Przejrzysty i bezpieczny interfejs nagrywania sesji." },
    en: { title: "Recording Screen", desc: "Clean and secure interface for recording sessions." }
  },
  {
    src: "/assets/gallery_menu.webp",
    pl: { title: "Menu Główne", desc: "Szybki dostęp do wszystkich narzędzi klinicznych." },
    en: { title: "Main Menu", desc: "Quick access to all key clinical tools." }
  },
  {
    src: "/assets/gallery_upload.webp",
    pl: { title: "Wysyłanie Pliku", desc: "Szyfrowane przesyłanie plików audio z sesji." },
    en: { title: "File Upload", desc: "Encrypted upload of session audio files." }
  },
  {
    src: "/assets/gallery_transcript.webp",
    pl: { title: "Podgląd Transkrypcji", desc: "Automatycznie wygenerowany zapis sesji." },
    en: { title: "Transcript View", desc: "Automatically generated verbatim transcription." }
  },
  {
    src: "/assets/screen_status.webp",
    pl: { title: "Stan Przetwarzania", desc: "Bieżące informacje o postępie analizy AI." },
    en: { title: "Processing Status", desc: "Real-time updates on AI analysis progress." }
  },
  {
    src: "/assets/screen_report.webp",
    pl: { title: "Raport Kliniczny", desc: "Strukturyzowane podsumowanie sesji w Twoim nurcie." },
    en: { title: "Clinical Report", desc: "Structured session summaries in your modality." }
  },
  {
    src: "/assets/gallery_doc.webp",
    pl: { title: "Kartoteka Pacjenta", desc: "Historia sesji klienta uporządkowana w czasie." },
    en: { title: "Client Records", desc: "Client session history organized over time." }
  },
  {
    src: "/assets/gallery_settings.webp",
    pl: { title: "Ustawienia Aplikacji", desc: "Konfiguracja szablonów i poziomu bezpieczeństwa." },
    en: { title: "App Settings", desc: "Configure reporting templates and security options." }
  },
  {
    src: "/assets/gallery_options.webp",
    pl: { title: "Dodatkowe Opcje", desc: "Eksport, udostępnianie i zarządzanie danymi." },
    en: { title: "More Options", desc: "Export, sharing, and clinical data management." }
  }
];

export function ScreenshotGallery() {
  const locale = useLocale();
  const scrollRef = useRef<HTMLDivElement>(null);
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(true);

  const checkScrollLimits = () => {
    if (scrollRef.current) {
      const { scrollLeft, scrollWidth, clientWidth } = scrollRef.current;
      setCanScrollLeft(scrollLeft > 5);
      setCanScrollRight(scrollLeft + clientWidth < scrollWidth - 5);
    }
  };

  useEffect(() => {
    const el = scrollRef.current;
    if (el) {
      el.addEventListener("scroll", checkScrollLimits);
      checkScrollLimits();
    }
    return () => {
      if (el) el.removeEventListener("scroll", checkScrollLimits);
    };
  }, []);

  // Handle escape key to close lightbox
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setSelectedImage(null);
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  const handleScroll = (direction: "left" | "right") => {
    if (scrollRef.current) {
      const { scrollLeft, clientWidth } = scrollRef.current;
      const scrollAmount = clientWidth * 0.75;
      scrollRef.current.scrollTo({
        left: direction === "left" ? scrollLeft - scrollAmount : scrollLeft + scrollAmount,
        behavior: "smooth"
      });
    }
  };

  const activeLang = locale === "en" ? "en" : "pl";
  const currentSelectedDetails = selectedImage 
    ? galleryItems.find(item => item.src === selectedImage)?.[activeLang]
    : null;

  return (
    <section className="w-full bg-[#FBFAF7] text-[#1B2522] py-24 border-b border-[#E2DED5]/60 relative">
      <div className="mx-auto w-full max-w-[1080px] px-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-end mb-12 gap-6">
          <div>
            <p className="font-mono text-[10px] sm:text-xs uppercase text-[#004D54] tracking-[var(--tracking-overline)] mb-3 font-semibold">
              {locale === "en" ? "App Interface Showcase" : "Prezentacja interfejsu aplikacji"}
            </p>
            <h3 className="font-display text-[#004D54] text-2xl sm:text-3xl font-semibold tracking-[var(--tracking-display)]">
              {locale === "en" ? "Every corner of Superwizor AI in high definition" : "Każdy ekran Superwizor AI z bliska"}
            </h3>
          </div>
          
          {/* Carousel Buttons */}
          <div className="flex gap-2">
            <button
              onClick={() => handleScroll("left")}
              disabled={!canScrollLeft}
              className="w-11 h-11 rounded-full bg-white border border-[#E2DED5] flex items-center justify-center text-[#004D54] hover:bg-[#F2F0EA] active:scale-[0.96] transition shadow-sm disabled:opacity-30 disabled:pointer-events-none"
              aria-label="Previous screens"
            >
              <svg className="w-5 h-5 stroke-[2]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path d="M15 19l-7-7 7-7" />
              </svg>
            </button>
            <button
              onClick={() => handleScroll("right")}
              disabled={!canScrollRight}
              className="w-11 h-11 rounded-full bg-white border border-[#E2DED5] flex items-center justify-center text-[#004D54] hover:bg-[#F2F0EA] active:scale-[0.96] transition shadow-sm disabled:opacity-30 disabled:pointer-events-none"
              aria-label="Next screens"
            >
              <svg className="w-5 h-5 stroke-[2]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>
        </div>

        {/* Horizontal Scrolling Gallery */}
        <div
          ref={scrollRef}
          className="flex gap-6 overflow-x-auto snap-x snap-mandatory scrollbar-none pb-6 cursor-grab active:cursor-grabbing select-none"
          style={{ scrollbarWidth: "none" }}
        >
          {galleryItems.map((item, index) => {
            const details = item[activeLang];
            return (
              <div
                key={index}
                onClick={() => setSelectedImage(item.src)}
                className="w-[280px] sm:w-[320px] shrink-0 snap-start bg-white border border-[#E2DED5] rounded-glass p-4 hover:border-[#004D54]/30 shadow-card hover:shadow-medium transition duration-300 cursor-pointer flex flex-col justify-between group"
              >
                <div className="aspect-[9/19] rounded-[16px] overflow-hidden border border-[#E2DED5]/60 bg-[#FBFAF7] relative">
                  <img
                    src={item.src}
                    alt={details.title}
                    loading="lazy"
                    className="w-full h-full object-cover select-none pointer-events-none transition duration-500 group-hover:scale-[1.03]"
                    draggable="false"
                  />
                  <div className="absolute inset-0 bg-[#004D54]/5 opacity-0 group-hover:opacity-100 transition duration-300 flex items-center justify-center">
                    <div className="bg-[#004D54] text-white rounded-full p-2.5 shadow-medium transform scale-75 group-hover:scale-100 transition duration-300">
                      <svg className="w-5 h-5 stroke-[2.2]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v6m-3-3h6" />
                      </svg>
                    </div>
                  </div>
                </div>
                <div className="mt-4 text-left">
                  <h4 className="font-display font-bold text-[#004D54] text-sm">
                    {details.title}
                  </h4>
                  <p className="font-serif text-[#4E5A55] text-xs leading-relaxed mt-1">
                    {details.desc}
                  </p>
                </div>
              </div>
            );
          })}
        </div>

        {/* Full-Screen Lightbox Modal overlay */}
        {selectedImage && currentSelectedDetails && (
          <div
            className="fixed inset-0 z-50 bg-[#1B2522]/90 backdrop-blur-md flex items-center justify-center p-4 sm:p-6 md:p-8 animate-fade-in"
            onClick={() => setSelectedImage(null)}
          >
            {/* Modal Container */}
            <div
              className="relative max-w-lg w-full bg-[#FBFAF7] rounded-[24px] border border-white/10 p-6 flex flex-col justify-between items-center text-center shadow-large animate-scale-up"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Close Button */}
              <button
                onClick={() => setSelectedImage(null)}
                className="absolute top-4 right-4 w-9 h-9 rounded-full bg-[#E9EFEC] hover:bg-[#D4E0DC] text-[#004D54] flex items-center justify-center transition active:scale-[0.95]"
                aria-label="Close details"
              >
                <svg className="w-4 h-4 stroke-[2.5]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>

              {/* High-Resolution Screenshot */}
              <div className="aspect-[9/19] rounded-[20px] overflow-hidden border border-[#E2DED5]/80 bg-white max-h-[60vh] w-auto flex justify-center mb-6">
                <img
                  src={selectedImage}
                  alt={currentSelectedDetails.title}
                  className="h-full w-auto object-contain select-none"
                />
              </div>

              {/* Text Meta info */}
              <div className="w-full">
                <h4 className="font-display font-bold text-[#004D54] text-lg sm:text-xl">
                  {currentSelectedDetails.title}
                </h4>
                <p className="font-serif text-[#4E5A55] text-sm leading-relaxed mt-2 max-w-[45ch] mx-auto">
                  {currentSelectedDetails.desc}
                </p>
              </div>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
