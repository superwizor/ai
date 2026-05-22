#!/usr/bin/env python3
"""
Generate a Postgres migration that seeds a new psychotherapy modality.

Per-modality content lives in a single JSON file under
`modality_prompts/`. This script reads that file, builds the system
prompt by concatenating the general instructions + each category +
the standard footer, then emits the up/down SQL migration files.

JSON shape (see modality_prompts/gestalt.json for a worked example):

    {
      "system_code":   "GESTALT",            // required, uppercase
      "display_name":  "Gestalt",            // required, UI label
      "general_instructions": "...",         // required, preamble text
      "category_prompts": {                  // required, ≥1 section
        "<section name 1>": "Cel: ...",      // section names are per-modality;
        "<section name 2>": "Cel: ...",      // see PPT for an example using
        ...                                   // PPT-specific section labels
      }
    }

Each modality picks its own section names — there is NO globally-fixed
set. PPT uses "Bilans Sesji", "Analiza w Modelu Równowagi", etc.;
UNIV/CBT/PSYCHO/Gestalt use "Podsumowanie sesji", "Wnikliwe obserwacje",
etc. The downstream llm-worker takes the modality prompt verbatim;
section names surface in `report_markdown` headers as-is.

Why JSON, not inline Python: each modality is a standalone artefact
the prompt-engineering team can version, diff, and re-generate
independently. Editing one modality never risks touching another.

Usage
-----
Default (auto-pick next migration number, write to ./migrations/):
    python3 add_modality.py modality_prompts/gestalt.json

Override migration number (useful when several modalities land in one
batch and you want stable filenames):
    python3 add_modality.py modality_prompts/foo.json --number 000023

Dry-run (print SQL to stdout, write nothing):
    python3 add_modality.py modality_prompts/gestalt.json --dry-run

The migrator service picks up new .up.sql files on next CI deploy of
superwizor-backend. To smoke-test locally against staging, point
cloud-sql-proxy at the staging instance and run `psql -f <file>`.

Follow-up edits (printed as a checklist at end of run) — these are
human-driven because the right value for each can't be auto-derived:
  • flutter-app/superwizor/lib/constants/modalities.dart    (add to kModalities)
  • flutter-app/superwizor/lib/widgets/modality_sheet.dart  (add to switch)
  • flutter-app/superwizor/lib/l10n/app_pl.arb + app_en.arb (display + abbrev)
  • docs/03_DATA_MODEL.md                                   (refresh enum comment)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

# ───────────────────────────────────────────────────────────────────
# Constants
# ───────────────────────────────────────────────────────────────────

# DELIBERATELY NO LEGACY FOOTER. Migration 000016 stripped three
# legacy bullets — "Speaker Role Inference", "HiTOP Dimensions",
# "RAG Summary Chunk" — from every existing modality's
# therapist_ai_general_prompt because the LLM was emitting them as
# section headers in report_markdown (the pre-call-1/call-2-split
# residue, ADR-IMPL-007). New modalities MUST NOT reintroduce them
# via this script; the worker derives speaker_role_inference,
# hitop_dimensions, and rag_summary_chunk as STRUCTURED columns from
# the call-1 metadata pass. If a modality JSON does provide a
# `footer` field, it's appended verbatim — but the canonical answer
# is "no footer".

VALID_SYSTEM_CODE = re.compile(r"^[A-Z][A-Z0-9_]{1,15}$")
MIN_CATEGORIES = 1
MAX_CATEGORY_NAME_CHARS = 100

# ───────────────────────────────────────────────────────────────────
# Validation
# ───────────────────────────────────────────────────────────────────


class ModalitySpecError(ValueError):
    """Raised when the per-modality JSON fails validation."""


def load_spec(path: Path) -> dict[str, Any]:
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as e:
        raise ModalitySpecError(f"cannot read {path}: {e}") from e
    try:
        spec = json.loads(raw)
    except json.JSONDecodeError as e:
        raise ModalitySpecError(f"{path}: invalid JSON at line {e.lineno}: {e.msg}") from e
    if not isinstance(spec, dict):
        raise ModalitySpecError(f"{path}: top level must be an object")
    return spec


def validate_spec(spec: dict[str, Any], source: Path) -> None:
    """Fail fast and loud — every error caught here saves a failed
    `terragrunt apply` later."""

    def require_str(key: str, *, max_len: int | None = None) -> str:
        v = spec.get(key)
        if not isinstance(v, str) or not v.strip():
            raise ModalitySpecError(f"{source}: '{key}' must be a non-empty string")
        if max_len and len(v) > max_len:
            raise ModalitySpecError(
                f"{source}: '{key}' is {len(v)} chars, max {max_len}"
            )
        return v

    code = require_str("system_code", max_len=20)
    if not VALID_SYSTEM_CODE.match(code):
        raise ModalitySpecError(
            f"{source}: system_code={code!r} must match {VALID_SYSTEM_CODE.pattern}; "
            "uppercase letters/digits/underscore only, 2–16 chars"
        )

    require_str("display_name", max_len=255)
    require_str("general_instructions")

    cats = spec.get("category_prompts")
    if not isinstance(cats, dict):
        raise ModalitySpecError(f"{source}: 'category_prompts' must be an object")
    if len(cats) < MIN_CATEGORIES:
        raise ModalitySpecError(
            f"{source}: category_prompts must contain at least "
            f"{MIN_CATEGORIES} entry; got {len(cats)}"
        )

    # Each modality picks its own section names — PPT uses
    # "Bilans Sesji" etc., Gestalt uses "Podsumowanie sesji" etc.
    # We only enforce that names are sane and bodies are present.
    for cat_name, body in cats.items():
        if not isinstance(cat_name, str) or not cat_name.strip():
            raise ModalitySpecError(
                f"{source}: category_prompts has an empty key"
            )
        if len(cat_name) > MAX_CATEGORY_NAME_CHARS:
            raise ModalitySpecError(
                f"{source}: category name {cat_name!r} exceeds "
                f"{MAX_CATEGORY_NAME_CHARS} chars; report-rendering UI "
                "won't truncate header lines gracefully"
            )
        if "\n" in cat_name or "\r" in cat_name:
            raise ModalitySpecError(
                f"{source}: category name {cat_name!r} contains newlines"
            )
        if not isinstance(body, str) or not body.strip():
            raise ModalitySpecError(
                f"{source}: category_prompts[{cat_name!r}] must be a non-empty string"
            )

    # Block the legacy bullets that 000016 explicitly stripped — if
    # someone copy-pastes an old prompt into a new JSON spec, fail
    # fast so the bug doesn't get reintroduced.
    for legacy in ("Speaker Role Inference", "HiTOP Dimensions", "RAG Summary Chunk"):
        if any(legacy in body for body in cats.values()):
            raise ModalitySpecError(
                f"{source}: category body mentions {legacy!r} — these are "
                "structured call-1 metadata columns post-ADR-IMPL-007. "
                "Migration 000016 stripped them from every existing modality. "
                "Don't reintroduce in new specs."
            )
        if legacy in spec.get("general_instructions", ""):
            raise ModalitySpecError(
                f"{source}: general_instructions mentions {legacy!r} — "
                "same reason: this would land verbatim in the LLM prompt "
                "and the model would echo it back as a report header. "
                "Remove the reference."
            )

    footer = spec.get("footer")
    if footer is not None and (not isinstance(footer, str) or not footer.strip()):
        raise ModalitySpecError(
            f"{source}: 'footer' (when set) must be a non-empty string; "
            "omit the key entirely if you don't want a footer (recommended)"
        )


# ───────────────────────────────────────────────────────────────────
# Migration assembly
# ───────────────────────────────────────────────────────────────────


def build_system_prompt(spec: dict[str, Any]) -> str:
    parts: list[str] = [spec["general_instructions"].rstrip(), ""]
    parts.append("Wytyczne do poszczególnych sekcji raportu:")
    # Iterate in the JSON's declared order — Python 3.7+ dicts preserve
    # insertion order, and our load_spec uses json.loads which honours
    # that. Section ordering matters for the rendered report layout.
    for name, body in spec["category_prompts"].items():
        parts.append(f"- {name}: {body}")
    footer = spec.get("footer")
    if footer:
        # Optional, modality-specific. The canonical answer is "no
        # footer" — see DELIBERATELY NO LEGACY FOOTER comment at top
        # of this file. A footer is only appropriate if the modality
        # has a genuinely modality-specific closing instruction that
        # belongs in the system prompt rather than the call-1 metadata
        # pass.
        parts.append("")
        parts.append(footer.strip())
    return "\n".join(parts)


def sql_escape_jsonb(payload: dict[str, Any]) -> str:
    """JSON-encode (UTF-8, no ASCII escapes for readability) then
    double single quotes for embedding inside a Postgres SQL literal."""
    return json.dumps(payload, ensure_ascii=False).replace("'", "''")


def sql_escape_literal(value: str) -> str:
    """Double single quotes for Postgres literals. Don't use json.dumps
    on plain strings — it would add wrapping double-quotes."""
    return value.replace("'", "''")


def render_up_sql(spec: dict[str, Any], system_prompt: str) -> str:
    code = spec["system_code"]
    display = spec["display_name"]
    payload = {"system": system_prompt}
    jsonb_literal = sql_escape_jsonb(payload)
    display_literal = sql_escape_literal(display)

    return f"""-- Seed the {code} modality + Polish prompt.
-- Generated by add_modality.py from modality_prompts/*.json — edit the
-- JSON spec and re-run the generator if the prompt needs changes.
--
-- UPSERT pattern matches 000008_modality_prompts_pl.up.sql so the
-- migration is idempotent across re-runs (e.g. after a failed deploy).

INSERT INTO modalities (system_code, display_name, therapist_ai_general_prompt, is_supported)
VALUES (
    '{code}',
    '{display_literal}',
    '{jsonb_literal}',
    TRUE
)
ON CONFLICT (system_code) DO UPDATE
SET therapist_ai_general_prompt = EXCLUDED.therapist_ai_general_prompt,
    display_name                = EXCLUDED.display_name,
    is_supported                = TRUE,
    updated_at                  = NOW();
"""


def render_down_sql(spec: dict[str, Any]) -> str:
    code = spec["system_code"]
    return f"""-- Reversal: remove the {code} modality.
--
-- Safety note: this DELETE will fail if any patient_files reference
-- modality_id of this row (FK from migration 000005 + 000007). That is
-- intended — modality_code is immutable per ADR (see
-- docs/agents/06_flutter-therapist-app.md guardrails). If you need to
-- roll this back AND patient_files exist, first reassign their
-- modality_id manually before applying this down migration.

DELETE FROM modalities WHERE system_code = '{code}';
"""


# ───────────────────────────────────────────────────────────────────
# Migration number resolution
# ───────────────────────────────────────────────────────────────────

MIGRATION_NUMBER_RE = re.compile(r"^(\d{6})_")


def next_migration_number(migrations_dir: Path) -> str:
    """Picks the lowest free 6-digit prefix higher than every existing
    *_*.up.sql / *_*.down.sql in [migrations_dir]. Returns zero-padded."""
    used: set[int] = set()
    for entry in migrations_dir.iterdir():
        if not entry.is_file():
            continue
        m = MIGRATION_NUMBER_RE.match(entry.name)
        if m:
            used.add(int(m.group(1)))
    nxt = max(used, default=0) + 1
    if nxt > 999_999:
        raise RuntimeError("migration number overflow — out of 6-digit IDs")
    return f"{nxt:06d}"


def slug_for_filename(system_code: str) -> str:
    """`GESTALT` → `gestalt` for the migration filename. Lowercase
    matches the convention of existing migrations (seed_modalities,
    patient_users, etc.)."""
    return system_code.lower()


# ───────────────────────────────────────────────────────────────────
# Entrypoint
# ───────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="Seed a new psychotherapy modality from a JSON spec.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "spec",
        type=Path,
        help="Path to modality JSON (see modality_prompts/gestalt.json)",
    )
    p.add_argument(
        "--number",
        help="6-digit migration prefix. Omit to auto-pick the next free one.",
    )
    p.add_argument(
        "--out-dir",
        type=Path,
        default=None,
        help="Where to write the .up.sql / .down.sql (default: spec's parent's parent / current dir if not nested)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print SQL to stdout instead of writing files.",
    )
    args = p.parse_args(argv)

    try:
        spec = load_spec(args.spec)
        validate_spec(spec, args.spec)
    except ModalitySpecError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    system_prompt = build_system_prompt(spec)
    up_sql = render_up_sql(spec, system_prompt)
    down_sql = render_down_sql(spec)

    if args.dry_run:
        print(up_sql)
        print("\n-- ─── down ─── --\n")
        print(down_sql)
        return 0

    # Default out_dir: the migrations/ directory the script itself
    # lives in. Override via --out-dir for sandboxed runs.
    out_dir = args.out_dir or Path(__file__).resolve().parent
    out_dir.mkdir(parents=True, exist_ok=True)

    number = args.number or next_migration_number(out_dir)
    if not re.fullmatch(r"\d{6}", number):
        print(f"error: --number must be 6 digits, got {number!r}", file=sys.stderr)
        return 2

    slug = slug_for_filename(spec["system_code"])
    up_path = out_dir / f"{number}_seed_{slug}_modality.up.sql"
    down_path = out_dir / f"{number}_seed_{slug}_modality.down.sql"

    # Refuse to clobber pre-existing files unless they were emitted by
    # this script for the same modality (byte-identical regenerations
    # are fine — that's the dev loop). Detect via comment line 2,
    # which carries the generator's signature.
    for path, new_content in ((up_path, up_sql), (down_path, down_sql)):
        if path.exists():
            existing = path.read_text(encoding="utf-8")
            if existing == new_content:
                continue
            if "Generated by add_modality.py" not in existing.splitlines()[1]:
                print(
                    f"error: {path} already exists and was not generated by this script. "
                    f"Refusing to overwrite. Pick a different --number or remove the file.",
                    file=sys.stderr,
                )
                return 2

    up_path.write_text(up_sql, encoding="utf-8")
    down_path.write_text(down_sql, encoding="utf-8")

    print(f"wrote {up_path.relative_to(Path.cwd())}  ({up_path.stat().st_size} bytes)")
    print(f"wrote {down_path.relative_to(Path.cwd())} ({down_path.stat().st_size} bytes)")

    # Follow-up checklist — these can't be derived from the spec
    # (icon choice, Polish/English UI labels, abbreviation form).
    code = spec["system_code"]
    display = spec["display_name"]
    print(
        f"""
Next: wire {code!r} into the Flutter UI (the backend migration handles
the DB side). Add to:

  • lib/constants/modalities.dart
        Modality(code: '{code}', displayKey: 'modality_{slug}',
                 icon: Icons.<pick_one>_outlined),
  • lib/widgets/modality_sheet.dart
        case '{code}': return t.modality_{slug};
  • lib/l10n/app_pl.arb / app_en.arb
        "modality_{slug}":      "{display}",
        "modality_abbr_{slug}": "<short label>",
  • docs/03_DATA_MODEL.md   (refresh the system_code enum comment)

Then: `flutter gen-l10n && flutter analyze && flutter test`.
Migrator service picks up the new .up.sql on next CI deploy of
superwizor-backend.
"""
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
