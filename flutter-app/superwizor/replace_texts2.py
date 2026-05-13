import re

filepath = 'lib/screens/menu_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

replacements = [
    ("'Usuń konto bezpowrotnie'", "AppLocalizations.of(context)!.settings_delete_account"),
    ("'Czy na pewno chcesz\\nusunąć konto?'", "AppLocalizations.of(context)!.settings_delete_confirm_title"),
    ("'Ta operacja jest NIEODWRACALNA.\\nUstracisz całą dokumentację kliniczną i dane pacjentów.'", "AppLocalizations.of(context)!.settings_delete_confirm_body"),
    ("'Rozumiem — przejdź dalej.'", "AppLocalizations.of(context)!.settings_delete_confirm_proceed"),
    ("'Anuluj — zachowaj konto.'", "AppLocalizations.of(context)!.settings_delete_confirm_cancel"),
]

for old, new in replacements:
    content = content.replace(old, new)

with open(filepath, 'w') as f:
    f.write(content)
