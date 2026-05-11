import re

with open('/Users/maciekckoklormam91/Desktop/APP - Superwizor AI/flutter-app/superwizor/lib/screens/menu_screen.dart', 'r') as f:
    content = f.read()

# Replace showModalBottomSheet
content = content.replace('showModalBottomSheet<void>(', 'showEuphireBottomSheet(context: context, builder: (_) => const _PlaceholderSheet(title: \'Mój profil\'));')

