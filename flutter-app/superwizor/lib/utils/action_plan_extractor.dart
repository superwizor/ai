// action_plan_extractor.dart
//
// Pure, Flutter-free heuristic that pulls the "Plan działania klienta"
// (client action plan) section out of a session's report markdown so the
// therapist can review/send it from the existing note editor.
//
// This MIRRORS the planned server-side extractor (see docs/22): the
// backend will eventually resolve the same section from the canonical
// report and deliver it to the patient. Until then this client-side
// version drives the UX prototype. Keep the two heuristics in sync — the
// heading priority list and the same-or-higher-level capture rule are the
// contract.
//
// Design note: no Flutter imports here so this stays unit-test-friendly.

/// A draft action plan extracted from a report, ready to seed the note
/// editor (title + body).
class ActionPlanDraft {
  final String title;
  final String text;

  const ActionPlanDraft({required this.title, required this.text});
}

/// Heading names (already normalized to lowercase, accent-free) we look
/// for, in priority order. The first heading whose text *contains* one of
/// these phrases wins.
const List<String> _kHeadingPriority = [
  'plan dzialania klienta',
  'plan dzialania',
  'propozycje interwencji',
  'ustalone z klientem zadania',
  'zadania',
];

/// Lowercases and strips Polish diacritics so heading matching is both
/// case- and accent-insensitive.
String _normalize(String s) {
  final lower = s.toLowerCase();
  const map = {
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ź': 'z',
    'ż': 'z',
  };
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}

/// Returns the markdown heading level (number of leading `#`) for [line],
/// or null if the line is not an ATX heading.
int? _headingLevel(String line) {
  final trimmed = line.trimLeft();
  if (!trimmed.startsWith('#')) return null;
  var level = 0;
  while (level < trimmed.length && trimmed[level] == '#') {
    level++;
  }
  // A valid ATX heading needs whitespace (or end) after the hashes.
  if (level < trimmed.length && trimmed[level] != ' ') return null;
  return level;
}

/// Heading text after the leading `#`s, trimmed.
String _headingText(String line) {
  final trimmed = line.trimLeft();
  return trimmed.replaceFirst(RegExp(r'^#+\s*'), '').trim();
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// Extracts the action plan section from [reportMarkdown].
///
/// Heuristic:
///  1. Scan ATX headings (`#`, `##`, `###`, …), case- and
///     accent-insensitive, against [_kHeadingPriority].
///  2. For the first heading whose text contains a priority phrase,
///     capture every line after it up to (but excluding) the next heading
///     of the same-or-higher level (fewer-or-equal `#`).
///  3. Trim. If nothing matches, `text` is empty.
///
/// `title` is "Plan działania" optionally suffixed with the session date
/// as "— dd.MM.yyyy" when [sessionDate] is provided.
ActionPlanDraft extractActionPlan(String reportMarkdown,
    {DateTime? sessionDate}) {
  final title = sessionDate != null
      ? 'Plan działania — '
          '${_twoDigits(sessionDate.day)}.${_twoDigits(sessionDate.month)}.${sessionDate.year}'
      : 'Plan działania';

  final lines = reportMarkdown.split('\n');

  // Find the highest-priority matching heading.
  int matchIndex = -1;
  int matchLevel = 0;
  int bestPriority = _kHeadingPriority.length; // lower == better

  for (var i = 0; i < lines.length; i++) {
    final level = _headingLevel(lines[i]);
    if (level == null) continue;
    final normalized = _normalize(_headingText(lines[i]));
    for (var p = 0; p < _kHeadingPriority.length; p++) {
      if (p >= bestPriority) break; // can't improve
      if (normalized.contains(_kHeadingPriority[p])) {
        bestPriority = p;
        matchIndex = i;
        matchLevel = level;
        break;
      }
    }
    if (bestPriority == 0) break; // top priority found, stop early
  }

  if (matchIndex < 0) {
    return ActionPlanDraft(title: title, text: '');
  }

  // Capture raw body lines until the next heading of same-or-higher level.
  final raw = <String>[];
  for (var i = matchIndex + 1; i < lines.length; i++) {
    final level = _headingLevel(lines[i]);
    if (level != null && level <= matchLevel) break;
    raw.add(lines[i]);
  }

  return ActionPlanDraft(title: title, text: _toPlainText(raw));
}

/// Converts captured markdown body lines into clean, readable plain text for
/// the note editor: strips markdown emphasis (**bold**, *italic*, `code`),
/// turns list bullets (`- `/`* `/`+ `) into "• ", unwraps links to their
/// text, and inserts a blank line before each bullet so items breathe.
String _toPlainText(List<String> rawLines) {
  final out = <String>[];
  for (final line in rawLines) {
    final cleaned = _cleanInline(line);
    final isBullet = cleaned.trimLeft().startsWith('• ');
    if (isBullet && out.isNotEmpty && out.last.trim().isNotEmpty) {
      out.add(''); // paragraph spacing before a new bullet
    }
    out.add(cleaned);
  }
  return out.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Strips inline markdown from a single line. NOTE: Dart's `replaceFirst`
/// does NOT expand `$1` backreferences (that inserts a literal "$1") — we
/// use `replaceFirstMapped`/`replaceAllMapped` where a capture is needed.
String _cleanInline(String line) {
  var s = line;
  // List bullet → "• " (preserve indentation).
  s = s.replaceFirstMapped(RegExp(r'^(\s*)([-*+])\s+'), (m) => '${m[1]}• ');
  // Links [text](url) → text.
  s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1] ?? '');
  // Emphasis / code markers: ** __ * `  (single _ left alone to avoid
  // mangling words).
  s = s.replaceAll(RegExp(r'\*\*|__|\*|`'), '');
  // Defensive: any leading heading hashes.
  s = s.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
  return s.trimRight();
}
