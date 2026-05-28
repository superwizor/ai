// Form primitives styled with Euphire tokens. Keep these dumb +
// composable — registration / profile / admin forms across slices all
// route through this set so input feel stays consistent.

import { forwardRef, type InputHTMLAttributes, type SelectHTMLAttributes, type TextareaHTMLAttributes } from "react";

type FieldShellProps = {
  id: string;
  label: string;
  hint?: string;
  error?: string;
  required?: boolean;
  children: React.ReactNode;
};

export function FieldShell({ id, label, hint, error, required, children }: FieldShellProps) {
  return (
    <div className="flex flex-col">
      <label
        htmlFor={id}
        className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
      >
        {label}
        {required && <span aria-hidden className="text-ember ml-1">*</span>}
      </label>
      {children}
      {hint && !error && (
        <p className="font-serif text-xs text-mist/70 mt-1.5">{hint}</p>
      )}
      {error && (
        <p
          role="alert"
          className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-magma mt-1.5"
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
      <span className="font-serif text-sm text-mist leading-relaxed">{label}</span>
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
            className={`cursor-pointer rounded-button border px-4 py-2 font-display text-sm transition ${
              active
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
