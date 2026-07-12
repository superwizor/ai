---
name: flutter-localization-auditor
description: Auditing UI strings in Flutter to prevent hardcoding, using AST parsers and custom lints.
---

# Flutter Localization Auditor Skill

Never hardcode Polish or English text inside Flutter widgets! All text must reside in ARB files.

## 1. Using ARB Files
* Store translations in `flutter-app/superwizor/lib/l10n/app_pl.arb` and `app_en.arb`.
* Use `AppLocalizations.of(context).keyName`.
* Do not use Dart string interpolation for dynamic text; use ARB variables (e.g., `Raport gotowy, {name}`).

## 2. Auditing Hardcoded Strings
* Run the AST parser to find suspect strings natively in Dart:
  ```bash
  cd flutter-app/superwizor
  dart run lib/scratch/find_hardcoded_ast.dart
  ```
* For automated AI review, run the LLM loop script:
  ```bash
  python3 scratch/llm_audit_loop.py
  ```
* Ensure the IDE `custom_lint` tool is enabled so `avoid_hardcoded_strings_in_widgets` runs during CI and development.
