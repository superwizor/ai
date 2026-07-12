---
name: modality-manager
description: Adding new psychotherapy modalities (CBT, Gestalt, IFS) to the backend via SQL migrations and to the Flutter UI.
---

# Modality Manager Skill

This skill governs the addition of new psychotherapy modalities.

## 1. Backend Migration
1. Copy an existing template to `superwizor-backend/migrations/modality_prompts/<modality_code>.json`.
2. Edit the JSON file (ensure `system_code`, `display_name`, and exact 7 category headers are set). **DO NOT include a footer** (footer prompts are stripped to avoid redundant LLM outputs).
3. Generate the SQL migration safely using Python:
   ```bash
   cd superwizor-backend
   python3 migrations/add_modality.py migrations/modality_prompts/<modality_code>.json
   ```

## 2. Flutter UI Integration
1. Add the Modality object to `kModalities` in `flutter-app/superwizor/lib/constants/modalities.dart`.
2. Map the label in the switch case in `flutter-app/superwizor/lib/widgets/modality_sheet.dart`.
3. Add localization keys in `flutter-app/superwizor/lib/l10n/app_pl.arb` and `app_en.arb`.
4. Re-generate ARB mapping:
   ```bash
   cd flutter-app/superwizor
   flutter gen-l10n
   ```
