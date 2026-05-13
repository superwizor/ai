import re
import os

filepath = 'lib/screens/menu_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Add import
if 'package:flutter_gen/gen_l10n/app_localizations.dart' not in content:
    content = content.replace("import '../widgets/profile_edit_sheet.dart';", "import '../widgets/profile_edit_sheet.dart';\nimport 'package:flutter_gen/gen_l10n/app_localizations.dart';")

# Add final t = AppLocalizations.of(context)!; in build
if 'final t = AppLocalizations.of(context)!;' not in content:
    content = content.replace("final theme = Theme.of(context);", "final theme = Theme.of(context);\n    final t = AppLocalizations.of(context)!;")

# Replace strings
replacements = [
    ("'Ustawienia'", "t.settings_title"),
    ("'DOSTOSUJ SWOJE DOŚWIADCZENIE'", "t.settings_subtitle"),
    ("'TWOJE KONTO'", "t.settings_section_account"),
    ("'Zalogowano jako: $email'", "t.settings_logged_in_as(email)"),
    ("title: 'Nazwa'", "title: t.settings_name"),
    ("title: 'Email'", "title: t.settings_email"),
    ("title: 'Zdjęcie profilowe'", "title: t.settings_avatar"),
    ("title: 'Domyślny nurt terapii'", "title: t.settings_modality"),
    ("'PREFERENCJE'", "t.settings_section_preferences"),
    ("title: 'Dźwięki'", "title: t.settings_sounds"),
    ("'Dźwięki włączone' : 'Dźwięki wyłączone'", "t.settings_sounds_on : t.settings_sounds_off"),
    ("title: 'Wibracje'", "title: t.settings_haptics"),
    ("'Wibracje włączone' : 'Wibracje wyłączone'", "t.settings_haptics_on : t.settings_haptics_off"),
    ("'WSPARCIE'", "t.settings_section_support"),
    ("title: 'Napisz do nas'", "title: t.settings_contact"),
    ("title: 'Lista oczekujących'", "title: t.settings_waitlist"),
    ("'INFORMACJE PRAWNE'", "t.settings_section_legal"),
    ("title: 'Regulamin'", "title: t.settings_terms"),
    ("'Regulamin'", "t.settings_terms"),
    ("title: 'Polityka Prywatności'", "title: t.settings_privacy"),
    ("'Polityka Prywatności'", "t.settings_privacy"),
    ("title: 'DPA / RODO'", "title: t.settings_dpa"),
    ("'DPA / RODO'", "t.settings_dpa"),
    ("title: 'Licencje oprogramowania'", "title: t.settings_licenses"),
    ("'ZARZĄDZANIE KONTEM'", "t.settings_section_account_management"),
    ("title: 'Wyloguj się'", "title: t.settings_logout"),
    ("title: 'Usuń konto bezpowrotnie'", "title: t.settings_delete_account"),
]

for old, new in replacements:
    content = content.replace(old, new)

# Helper function
helper_code = """
String _modalityAbbr(BuildContext context, String code) {
  final t = AppLocalizations.of(context)!;
  switch (code) {
    case 'UNIV': return t.modality_abbr_univ;
    case 'CBT':  return t.modality_abbr_cbt;
    case 'PSYCHO': return t.modality_abbr_psycho;
    case 'PPT':  return t.modality_abbr_ppt;
    case 'ST':   return t.modality_abbr_st;
    case 'SYS':  return t.modality_abbr_sys;
    case 'EFT':  return t.modality_abbr_eft;
    case 'COACH': return t.modality_abbr_coach;
    default:     return code;
  }
}
"""
content = re.sub(r'String _modalityAbbr\(String code\) \{.*?\n\}', helper_code.strip(), content, flags=re.DOTALL)
content = content.replace("_modalityAbbr(patientModality)", "_modalityAbbr(context, patientModality)")

# Update logout sheet
logout_repl = [
    ("'Wylogować się?'", "AppLocalizations.of(context)!.settings_logout_confirm_title"),
    ("'Twoje dane są bezpieczne.\\nMożesz zalogować się ponownie w każdej chwili.'", "AppLocalizations.of(context)!.settings_logout_confirm_body"),
    ("'Wyloguj się.'", "AppLocalizations.of(context)!.settings_logout_confirm_logout"),
    ("'Zostań zalogowany.'", "AppLocalizations.of(context)!.settings_logout_confirm_cancel"),
]
for old, new in logout_repl:
    content = content.replace(old, new)

# Update Language tile
content = content.replace("Text('Język aplikacji'", "Text(AppLocalizations.of(context)!.settings_language_app")
content = content.replace("Text('Wybierz język'", "Text(AppLocalizations.of(context)!.settings_choose_language")

with open(filepath, 'w') as f:
    f.write(content)
