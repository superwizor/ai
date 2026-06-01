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

  // Capture body until the next heading of same-or-higher level.
  final body = <String>[];
  for (var i = matchIndex + 1; i < lines.length; i++) {
    final level = _headingLevel(lines[i]);
    if (level != null && level <= matchLevel) break;
    body.add(_stripBullet(lines[i]));
  }

  return ActionPlanDraft(title: title, text: body.join('\n').trim());
}

/// Trivially strips a single leading markdown list bullet (`- `, `* `,
/// `+ `, or `1. `) so the seeded note reads as plain text rather than
/// markdown source. Leaves indentation-only and prose lines untouched.
String _stripBullet(String line) {
  return line.replaceFirst(RegExp(r'^(\s*)([-*+]|\d+\.)\s+'), r'$1');
}
