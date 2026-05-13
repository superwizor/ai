import re

filepath = 'lib/screens/menu_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

content = content.replace("const Text(\n                    AppLocalizations", "Text(\n                    AppLocalizations")
content = content.replace("const Text(\n                    t.", "Text(\n                    t.")
content = content.replace("const Text(AppLocalizations", "Text(AppLocalizations")
content = content.replace("const Text(t.", "Text(t.")
content = content.replace("const Text(\n                    t.", "Text(\n                    t.")

with open(filepath, 'w') as f:
    f.write(content)
