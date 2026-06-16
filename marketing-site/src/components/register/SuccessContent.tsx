"use client";

import { useEffect, useState, useCallback } from "react";
import { motion } from "framer-motion";

type Particle = {
  id: number;
  x: number;
  y: number;
  color: string;
  size: number;
  delay: number;
  duration: number;
  rotate: number;
  shape: "circle" | "square" | "triangle";
};

// Web Audio API Synthesizer for a premium, clean iOS-style success chime.
// PROGRAMMATIC: No external asset requests, zero 404s, instantaneous load.
export function playSuccessSound() {
  const AudioContext = window.AudioContext || (window as any).webkitAudioContext;
  if (!AudioContext) return;
  const ctx = new AudioContext();

  const startTime = ctx.currentTime;

  // Uplifting chord progression: C5 -> E5 -> G5 -> C6 (staggered arpeggio)
  const chordFreqs = [523.25, 659.25, 783.99, 1046.50];

  chordFreqs.forEach((freq, index) => {
    const osc = ctx.createOscillator();
    const gainNode = ctx.createGain();

    osc.type = "sine";
    osc.frequency.setValueAtTime(freq, startTime);

    // Harmonics for a warmer, richer bell tone
    const harmonicOsc = ctx.createOscillator();
    const harmonicGain = ctx.createGain();
    harmonicOsc.type = "triangle";
    harmonicOsc.frequency.setValueAtTime(freq * 2, startTime); // 1st overtone

    // Stagger start times of notes slightly for a harp/strum effect
    const noteStart = startTime + index * 0.06;

    // Main envelope
    gainNode.gain.setValueAtTime(0, startTime);
    gainNode.gain.linearRampToValueAtTime(0.12, noteStart + 0.03);
    gainNode.gain.exponentialRampToValueAtTime(0.0001, noteStart + 0.8);

    // Harmonic envelope (quieter, decays faster)
    harmonicGain.gain.setValueAtTime(0, startTime);
    harmonicGain.gain.linearRampToValueAtTime(0.04, noteStart + 0.02);
    harmonicGain.gain.exponentialRampToValueAtTime(0.0001, noteStart + 0.3);

    osc.connect(gainNode);
    gainNode.connect(ctx.destination);

    harmonicOsc.connect(harmonicGain);
    harmonicGain.connect(ctx.destination);

    osc.start(noteStart);
    osc.stop(noteStart + 1.0);

    harmonicOsc.start(noteStart);
    harmonicOsc.stop(noteStart + 0.5);
  });

  // Soft sparkle notes (high frequency chime) at the tail
  const sparkles = [
    { freq: 1318.51, delay: 0.32 }, // E6
    { freq: 1567.98, delay: 0.40 }, // G6
    { freq: 2093.00, delay: 0.48 }, // C7
  ];

  sparkles.forEach((sparkle) => {
    const sparkOsc = ctx.createOscillator();
    const sparkGain = ctx.createGain();

    sparkOsc.type = "sine";
    sparkOsc.frequency.setValueAtTime(sparkle.freq, startTime + sparkle.delay);

    const start = startTime + sparkle.delay;
    sparkGain.gain.setValueAtTime(0, start);
    sparkGain.gain.linearRampToValueAtTime(0.05, start + 0.02);
    sparkGain.gain.exponentialRampToValueAtTime(0.0001, start + 0.25);

    sparkOsc.connect(sparkGain);
    sparkGain.connect(ctx.destination);

    sparkOsc.start(start);
    sparkOsc.stop(start + 0.4);
  });
}

export function SuccessContent({
  heading,
  subtext,
  cta,
  prefix,
  ctaHref,
}: {
  locale: string;
  heading: string;
  subtext: string;
  cta: string;
  prefix: string;
  ctaHref?: string;
}) {
  const [particles, setParticles] = useState<Particle[]>([]);

  const triggerEffects = useCallback(() => {
    // Play success chime
    try {
      playSuccessSound();
    } catch (e) {
      console.warn("Chime blocked by browser autoplay policy:", e);
    }

    // Generate confetti burst
    const generated: Particle[] = [];
    const colors = [
      "#F5A623", // Gold
      "#4FC097", // Emerald
      "#38B2AC", // Teal
      "#F6AD55", // Orange
      "#EC4899", // Pink
      "#3B82F6", // Blue
      "#A855F7", // Purple
      "#10B981", // Green
    ];
    const shapes: ("circle" | "square" | "triangle")[] = ["circle", "square", "triangle"];

    // Multi-angle explosion (left and right arches + central burst)
    for (let i = 0; i < 90; i++) {
      const angle = (Math.random() * 120 + 210) * (Math.PI / 180); // 210 to 330 deg (upwards arch)
      const distance = 160 + Math.random() * 280;
      const x = Math.cos(angle) * distance;
      const y = Math.sin(angle) * distance;

      generated.push({
        id: i,
        x,
        y,
        color: colors[Math.floor(Math.random() * colors.length)],
        size: 6 + Math.random() * 8,
        delay: Math.random() * 0.15,
        duration: 1.6 + Math.random() * 0.8,
        rotate: Math.random() * 360,
        shape: shapes[Math.floor(Math.random() * shapes.length)],
      });
    }
    setParticles(generated);
  }, []);

  // Play effects automatically on mount
  useEffect(() => {
    const timer = setTimeout(() => {
      triggerEffects();
    }, 200);
    return () => clearTimeout(timer);
  }, [triggerEffects]);

  return (
    <section className="relative mx-auto w-full max-w-lg px-6 py-16 sm:py-24 text-center overflow-visible">
      {/* Slow-rotating background glow to add premium atmosphere */}
      <div className="absolute -inset-10 -z-10 flex items-center justify-center opacity-30 blur-[100px] pointer-events-none">
        <div className="w-[300px] h-[300px] rounded-full bg-gradient-to-tr from-[#2F6B62] via-[#F5A623] to-[#004D54] animate-spin-slow" />
      </div>

      {/* Confetti Container */}
      <div className="absolute inset-0 overflow-visible pointer-events-none z-50">
        {particles.map((p) => (
          <motion.div
            key={p.id}
            className="absolute"
            initial={{ x: 0, y: 0, scale: 0, rotate: 0, opacity: 1 }}
            animate={{
              x: p.x,
              y: [0, p.y * 0.4, p.y, p.y + 200], // Parabolic gravity path
              scale: [0, 1, 1, 0.7, 0],
              rotate: [0, p.rotate, p.rotate * 2.5, p.rotate * 4],
              opacity: [1, 1, 1, 0.9, 0],
            }}
            transition={{
              duration: p.duration,
              ease: [0.1, 0.8, 0.25, 1], // Custom overshoot bezier
              delay: p.delay,
            }}
            style={{
              width: p.shape === "triangle" ? 0 : p.size,
              height: p.shape === "triangle" ? 0 : p.size,
              backgroundColor: p.shape !== "triangle" ? p.color : undefined,
              borderRadius: p.shape === "circle" ? "50%" : p.shape === "square" ? "4px" : undefined,
              borderLeft: p.shape === "triangle" ? `${p.size / 2}px solid transparent` : undefined,
              borderRight: p.shape === "triangle" ? `${p.size / 2}px solid transparent` : undefined,
              borderBottom: p.shape === "triangle" ? `${p.size}px solid ${p.color}` : undefined,
              left: "50%",
              top: "20%", // Sparkle relative to checkmark position
            }}
          />
        ))}
      </div>

      {/* Premium Glassmorphic Card */}
      <motion.div
        initial={{ opacity: 0, y: 30, scale: 0.96 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ type: "spring", stiffness: 100, damping: 20 }}
        className="relative rounded-3xl bg-gradient-to-b from-[#0F2E32]/90 to-[#0A2326]/95 border border-[#1A3A3E] p-8 sm:p-12 shadow-[0_20px_50px_rgba(0,0,0,0.4)] backdrop-blur-xl"
      >
        {/* Interactive sound & confetti trigger on clicking the top icon */}
        <button
          onClick={triggerEffects}
          title="Odtwórz sukces!"
          className="group relative w-20 h-20 rounded-full bg-gradient-to-br from-[#2F6B62]/20 to-[#4FC097]/10 flex items-center justify-center mx-auto mb-8 border border-[#2F6B62]/40 hover:border-[#4FC097] hover:shadow-[0_0_25px_rgba(79,192,151,0.25)] transition-all duration-300 active:scale-95"
        >
          {/* Animated checkmark that draws itself */}
          <svg
            className="w-10 h-10 text-[#4FC097] group-hover:scale-110 transition-transform duration-300"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={3}
          >
            <motion.path
              initial={{ pathLength: 0 }}
              animate={{ pathLength: 1 }}
              transition={{ duration: 0.6, ease: "easeOut", delay: 0.3 }}
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M5 13l4 4L19 7"
            />
          </svg>

          {/* Micro-sparkle icons around ring */}
          <span className="absolute -top-1 -right-1 text-base animate-bounce opacity-80">✨</span>
          <span className="absolute -bottom-2 -left-1 text-xs opacity-60">✨</span>
        </button>

        {/* Localized Heading */}
        <motion.h1
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.5 }}
          className="font-serif text-[#F2F0EA] text-3xl sm:text-4xl font-bold tracking-tight mb-4 leading-tight"
        >
          {heading}
        </motion.h1>

        {/* Localized Description */}
        <motion.p
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, duration: 0.5 }}
          className="font-sans text-[#8FA5A0] text-sm sm:text-base leading-relaxed max-w-sm mx-auto mb-8"
        >
          {subtext}
        </motion.p>

        {/* CTA Button with subtle hover glow/pulse */}
        <motion.div
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4, duration: 0.5 }}
        >
          <a
            href={ctaHref ?? `${prefix}/login`}
            onClick={playSuccessSound}
            className="relative inline-flex items-center justify-center w-full sm:w-auto min-w-[200px] rounded-2xl bg-gradient-to-r from-[#F5A623] to-[#E09500] text-[#1B2522] font-sans font-bold text-xs uppercase tracking-wider px-8 py-4.5 overflow-hidden shadow-lg shadow-black/25 hover:shadow-[0_8px_30px_rgba(245,166,35,0.4)] hover:scale-[1.02] active:scale-[0.98] transition-all duration-300"
          >
            {/* Shimmer background animation */}
            <span className="absolute inset-0 -translate-x-full bg-gradient-to-r from-transparent via-white/25 to-transparent animate-shimmer" />
            {cta}
          </a>
        </motion.div>
      </motion.div>
    </section>
  );
}
