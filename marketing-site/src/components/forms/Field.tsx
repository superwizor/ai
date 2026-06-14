// route through this set so input feel stays consistent.
import { forwardRef, Children, cloneElement, isValidElement, useState, useEffect, type InputHTMLAttributes, type SelectHTMLAttributes, type TextareaHTMLAttributes } from "react";

type FieldShellProps = {
  id: string;
  label: string;
  hint?: string;
  error?: string;
  required?: boolean;
  children: React.ReactNode;
};

export function FieldShell({ id, label, hint, error, required, children }: FieldShellProps) {
  const styledChildren = Children.map(children, (child) => {
    if (error && isValidElement(child)) {
      const childProps = (child as any).props || {};
      return cloneElement(child as any, {
        className: `${childProps.className ?? ""} !border-magma !focus:border-magma`,
      });
    }
    return child;
  });

  return (
    <div className="flex flex-col">
      <label
        htmlFor={id}
        className="font-sans text-[10px] font-semibold uppercase tracking-[var(--tracking-label)] text-mist mb-2 min-h-[2lh] leading-snug"
      >
        {label}
        {required && <span aria-hidden className="text-ember ml-1">*</span>}
      </label>
      {styledChildren}
      {hint && !error && (
        <p className="font-sans text-xs text-mist/70 mt-1.5">{hint}</p>
      )}
      {error && (
        <p
          role="alert"
          className="font-sans text-[10px] font-semibold uppercase tracking-[var(--tracking-label)] text-magma mt-1.5"
        >
          {error}
        </p>
      )}
    </div>
  );
}
const inputClasses =
  "rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember focus:bg-frost/[0.07] placeholder:text-mist/40 transition";

export const TextInput = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  function TextInput(props, ref) {
    return <input ref={ref} {...props} className={`${inputClasses} ${props.className ?? ""}`} />;
  },
);

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(
  function Select(props, ref) {
    return (
      <select
        ref={ref}
        {...props}
        className={`${inputClasses} appearance-none cursor-pointer ${props.className ?? ""}`}
      >
        {props.children}
      </select>
    );
  },
);

export const TextArea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(
  function TextArea(props, ref) {
    return (
      <textarea
        ref={ref}
        {...props}
        className={`${inputClasses} min-h-[6rem] resize-vertical ${props.className ?? ""}`}
      />
    );
  },
);

// Checkbox + radio: brand-coloured custom controls. Keyboard
// focus-visible rings come from the global :focus-visible style.
export function Checkbox(
  props: InputHTMLAttributes<HTMLInputElement> & { label: React.ReactNode },
) {
  const { label, id, ...rest } = props;
  return (
    <label htmlFor={id} className="flex items-start gap-3 cursor-pointer select-none">
      <input
        id={id}
        type="checkbox"
        {...rest}
        className="mt-1 h-4 w-4 rounded border-frost/30 bg-frost/5 text-ember accent-ember focus:ring-ember"
      />
      <span className="font-sans text-sm text-mist leading-relaxed">{label}</span>
    </label>
  );
}

export function RadioGroup({
  name,
  options,
  value,
  onChange,
}: {
  name: string;
  options: { value: string; label: string }[];
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div role="radiogroup" className="flex gap-2 flex-wrap">
      {options.map((o) => {
        const active = o.value === value;
        return (
          <label
            key={o.value}
            className={`cursor-pointer rounded-button border px-4 py-2 font-display text-sm transition ${active
                ? "border-ember bg-ember/10 text-frost"
                : "border-frost/15 bg-frost/5 text-mist hover:border-frost/30"
              }`}
          >
            <input
              type="radio"
              name={name}
              value={o.value}
              checked={active}
              onChange={(e) => onChange(e.target.value)}
              className="sr-only"
            />
            {o.label}
          </label>
        );
      })}
    </div>
  );
}

type PhoneInputProps = {
  value: string;
  onChange: (val: string) => void;
  error?: boolean;
  defaultDialCode?: string;
  placeholder?: string;
  id?: string;
};

export function PhoneInput({
  value,
  onChange,
  error,
  defaultDialCode = "+48",
  placeholder,
  id,
}: PhoneInputProps) {
  const dialCodes = [
    { code: "+48", label: "🇵🇱 +48" },
    { code: "+44", label: "🇬🇧 +44" },
    { code: "+1", label: "🇺🇸 +1" },
    { code: "+49", label: "🇩🇪 +49" },
    { code: "+33", label: "🇫🇷 +33" },
    { code: "+34", label: "🇪🇸 +34" },
    { code: "+39", label: "🇮🇹 +39" },
    { code: "+351", label: "🇵🇹 +351" },
    { code: "+31", label: "🇳🇱 +31" },
    { code: "+32", label: "🇧🇪 +32" },
    { code: "+41", label: "🇨🇭 +41" },
    { code: "+43", label: "🇦🇹 +43" },
    { code: "+46", label: "🇸🇪 +46" },
    { code: "+47", label: "🇳🇴 +47" },
    { code: "+45", label: "🇩🇰 +45" },
    { code: "+358", label: "🇫🇮 +358" },
    { code: "+353", label: "🇮🇪 +353" },
    { code: "+380", label: "🇺🇦 +380" },
    { code: "+420", label: "🇨🇿 +420" },
    { code: "+421", label: "🇸🇰 +421" },
    { code: "+36", label: "🇭🇺 +36" },
    { code: "+30", label: "🇬🇷 +30" },
    { code: "+40", label: "🇷🇴 +40" },
    { code: "+359", label: "🇧🇬 +359" },
    { code: "+385", label: "🇭🇷 +385" },
  ];

  const parseValue = (val: string) => {
    if (!val) return { selectedPrefix: defaultDialCode, localNum: "" };

    // If there is a space, split by it to get the prefix and local number cleanly
    const spaceIndex = val.indexOf(" ");
    if (spaceIndex !== -1) {
      const prefix = val.slice(0, spaceIndex).trim();
      const local = val.slice(spaceIndex + 1).trim();
      return { selectedPrefix: prefix, localNum: local };
    }

    const sortedCodes = [...dialCodes].sort((a, b) => b.code.length - a.code.length);
    for (const dc of sortedCodes) {
      if (val.startsWith(dc.code)) {
        return {
          selectedPrefix: dc.code,
          localNum: val.slice(dc.code.length).trim(),
        };
      }
    }
    if (val.startsWith("+")) {
      const match = val.match(/^(\+\d{1,4})/);
      if (match) {
        return {
          selectedPrefix: match[1],
          localNum: val.slice(match[1].length).trim(),
        };
      }
    }
    return { selectedPrefix: defaultDialCode, localNum: val };
  };

  const { selectedPrefix, localNum } = parseValue(value);

  const handlePrefixInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    let val = e.target.value.trim();
    // Allow digits and a single leading plus
    val = val.replace(/[^\d+]/g, "");
    if (val && !val.startsWith("+")) {
      val = "+" + val;
    }
    onChange(val + " " + localNum);
  };

  const handleLocalChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    let rawLocal = e.target.value;

    // Normalize leading '00' to '+'
    if (rawLocal.startsWith("00")) {
      rawLocal = "+" + rawLocal.slice(2);
    }

    let newPrefix = selectedPrefix;
    let newLocal = rawLocal;

    if (rawLocal.startsWith("+")) {
      const parsed = parseValue(rawLocal);
      newPrefix = parsed.selectedPrefix;
      newLocal = parsed.localNum;
    } else {
      // Check if user typed the prefix digits manually without leading +
      const prefixDigits = selectedPrefix.replace(/[^\d]/g, ""); // e.g. "48"
      const cleanedLocalDigits = rawLocal.replace(/[^\d]/g, "");

      if (prefixDigits && cleanedLocalDigits.startsWith(prefixDigits)) {
        const remainingDigits = cleanedLocalDigits.slice(prefixDigits.length);
        if (remainingDigits.length >= 6) {
          let digitsFound = 0;
          let cutIndex = 0;
          for (let i = 0; i < rawLocal.length; i++) {
            if (/\d/.test(rawLocal[i])) {
              digitsFound++;
              if (digitsFound === prefixDigits.length) {
                cutIndex = i + 1;
                break;
              }
            }
          }
          newLocal = rawLocal.slice(cutIndex).trim();
        }
      }
    }

    // Keep only digits, spaces, dashes, or parentheses
    newLocal = newLocal.replace(/[^\d\s\-()]/g, "");

    onChange(newPrefix + " " + newLocal);
  };

  return (
    <div className="flex gap-2 w-full">
      <div className="relative shrink-0 w-[85px]">
        <input
          id={`${id}-prefix`}
          type="text"
          list="dial-codes"
          value={selectedPrefix}
          onChange={handlePrefixInputChange}
          placeholder="+48"
          className={`rounded-button bg-frost/5 border border-frost/15 text-frost text-center px-3 py-2.5 font-sans text-sm focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition h-full w-full ${error ? "!border-magma !focus:border-magma" : ""
            }`}
        />
        <datalist id="dial-codes">
          {dialCodes.map((dc) => (
            <option key={dc.code} value={dc.code}>
              {dc.label}
            </option>
          ))}
        </datalist>
      </div>
      <TextInput
        id={id}
        type="tel"
        inputMode="tel"
        autoComplete="tel"
        placeholder={placeholder}
        value={localNum}
        onChange={handleLocalChange}
        className="flex-1"
      />
    </div>
  );
}
